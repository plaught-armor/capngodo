class_name CapnBuilder extends RefCounted

## The write side of the codec: Arena + StructBuilder + ListBuilder, kept in ONE
## file (like CapnReader) because they form a static-typed class_name cycle.
##
## Allocation strategy: append into segments, growing freely. With cap_words = 0
## (default) everything lands in segment 0 and no far pointers are ever emitted.
## A positive cap_words forces multi-segment output; any cross-segment pointer is
## written as a self-describing double-far (encoding.md :239-249) — the simplest
## form the reader already handles, with the landing-pad pair allocated anywhere.
##
## Positions are integer (seg, word) handles, never cached buffer refs, so they
## survive PackedByteArray.resize() during growth (Godot mutates Packed* elements
## inside an Array in place, so writes go straight to arena.segments[seg]).
##
## Entry: CapnBuilder.new_message(data_words, ptr_words) -> StructBuilder (root);
## CapnBuilder.to_bytes(root) -> framed bytes.

const WORD_BYTES: int = 8

# Reused scratch for float -> bits, mirroring the reader.
static var _f32_scratch: PackedByteArray = _make_scratch(4)
static var _f64_scratch: PackedByteArray = _make_scratch(8)


static func _make_scratch(n: int) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(n)
	return b


static func new_message(data_words: int, ptr_words: int, cap_words: int = 0) -> StructBuilder:
	var arena: Arena = Arena.new(cap_words)
	var root_ptr: Vector2i = arena.allocate(1)  # segment 0, word 0 = root pointer
	var root: Vector2i = arena.allocate(data_words + ptr_words)
	arena.point_to_struct(root_ptr.x, root_ptr.y, root, data_words, ptr_words)
	return StructBuilder.new(arena, root.x, root.y, data_words, ptr_words)


static func to_bytes(root: StructBuilder, packed: bool = false) -> PackedByteArray:
	var segs: CapnSegments = CapnSegments.new(root.arena.segments)
	var framed: PackedByteArray = CapnFraming.write(segs)
	return CapnPacked.pack(framed) if packed else framed


static func _list_body_words(code: CapnPointer.ElemSize, count: int) -> int:
	if code == CapnPointer.ElemSize.VOID:
		return 0
	elif code == CapnPointer.ElemSize.BIT:
		@warning_ignore("integer_division")
		var bit_words: int = (count + 63) / 64
		return bit_words
	var elem_bytes: int = CapnPointer.elem_size_bytes(code)
	@warning_ignore("integer_division")
	var body_words: int = (count * elem_bytes + WORD_BYTES - 1) / WORD_BYTES
	return body_words


# =========================================================================
# Arena — segment storage, allocation, and pointer-word writing.
# =========================================================================

class Arena extends RefCounted:
	const WORD_BYTES: int = 8

	var segments: Array[PackedByteArray] = []
	var used_words: PackedInt32Array = []
	var cap_words: int = 0  # 0 = unlimited (single growing segment)

	func _init(p_cap_words: int = 0) -> void:
		cap_words = p_cap_words
		_new_segment()

	func _new_segment() -> int:
		segments.append(PackedByteArray())
		used_words.append(0)
		return segments.size() - 1

	## Reserve `words` words; returns (segment, word offset). Picks the first
	## segment with room (or grows segment 0 when uncapped), else a new segment.
	func allocate(words: int) -> Vector2i:
		var seg: int = _pick(words)
		var off: int = used_words[seg]
		used_words[seg] += words
		var need: int = used_words[seg] * WORD_BYTES
		if segments[seg].size() < need:
			segments[seg].resize(need)
		return Vector2i(seg, off)

	func _pick(words: int) -> int:
		for i: int in segments.size():
			if cap_words == 0 or used_words[i] + words <= cap_words:
				return i
		# No segment has room. A single object larger than cap_words can't honour
		# the cap; it spills into its own oversized segment (cap is a split hint,
		# not a hard per-object ceiling).
		if cap_words > 0 and words > cap_words:
			push_warning("CapnBuilder.Arena: object of %d words exceeds cap_words %d; placed in its own segment" % [words, cap_words])
		return _new_segment()

	## Allocate `bytes.size()` bytes as a byte-list body (ceil to words, pad
	## zero) and write them. Returns the body location. Shared by text/data.
	func alloc_bytes(bytes: PackedByteArray) -> Vector2i:
		var n: int = bytes.size()
		var loc: Vector2i = allocate(CapnBuilder._list_body_words(CapnPointer.ElemSize.BYTE, n))
		var base: int = loc.y * WORD_BYTES
		for k: int in n:
			segments[loc.x][base + k] = bytes[k]
		return loc

	# --- pointer writing ---------------------------------------------------

	## Write a struct pointer at (psg, pword) referencing the struct at `target`.
	func point_to_struct(psg: int, pword: int, target: Vector2i, dw: int, pw: int) -> void:
		if psg == target.x:
			_put(psg, pword, CapnPointer.encode_struct(target.y - (pword + 1), dw, pw))
		else:
			_double_far(psg, pword, target, CapnPointer.encode_struct(0, dw, pw))

	## Write a list pointer at (psg, pword). size_field is the element count
	## (non-composite) or the word count excluding the tag (composite).
	func point_to_list(psg: int, pword: int, target: Vector2i, code: CapnPointer.ElemSize, size_field: int) -> void:
		if psg == target.x:
			_put(psg, pword, CapnPointer.encode_list(target.y - (pword + 1), code, size_field))
		else:
			_double_far(psg, pword, target, CapnPointer.encode_list(0, code, size_field))

	## Cross-segment reference as a double-far pointer (encoding.md :239-249):
	## a 2-word landing pad (inner far -> content; tag word -> shape) allocated
	## anywhere, with a double-far at the pointer site.
	func _double_far(psg: int, pword: int, target: Vector2i, tag_word: PackedByteArray) -> void:
		var pad: Vector2i = allocate(2)
		_put(pad.x, pad.y, CapnPointer.encode_far(target.y, false, target.x))
		_put(pad.x, pad.y + 1, tag_word)
		_put(psg, pword, CapnPointer.encode_far(pad.y, true, pad.x))

	## Write an 8-byte pointer word (two u32 halves) at (seg, word).
	func _put(seg: int, word: int, eight_bytes: PackedByteArray) -> void:
		var base: int = word * WORD_BYTES
		segments[seg].encode_u32(base, eight_bytes.decode_u32(0))
		segments[seg].encode_u32(base + 4, eight_bytes.decode_u32(4))


# =========================================================================
# StructBuilder — write a struct's data + pointer sections.
# =========================================================================

class StructBuilder extends RefCounted:
	const WORD_BYTES: int = 8

	var arena: Arena = null
	var seg_id: int = 0
	var data_word: int = 0
	var data_words: int = 0
	var ptr_word: int = 0
	var ptr_words: int = 0

	func _init(p_arena: Arena, p_seg_id: int, p_content_word: int, p_data_words: int, p_ptr_words: int) -> void:
		arena = p_arena
		seg_id = p_seg_id
		data_word = p_content_word
		data_words = p_data_words
		ptr_word = p_content_word + p_data_words
		ptr_words = p_ptr_words

	# --- primitive setters (wire = value XOR default) ---------------------

	func set_u8(byte_off: int, value: int, default_value: int = 0) -> void:
		_buf().encode_u8(_d(byte_off), (value ^ default_value) & 0xff)

	func set_u16(byte_off: int, value: int, default_value: int = 0) -> void:
		_buf().encode_u16(_d(byte_off), (value ^ default_value) & 0xffff)

	func set_u32(byte_off: int, value: int, default_value: int = 0) -> void:
		_buf().encode_u32(_d(byte_off), (value ^ default_value) & 0xffffffff)

	func set_u64(byte_off: int, value: int, default_value: int = 0) -> void:
		_buf().encode_u64(_d(byte_off), value ^ default_value)

	# Signed setters share the unsigned write path (XOR is on the bit pattern).
	func set_i8(byte_off: int, value: int, default_value: int = 0) -> void:
		set_u8(byte_off, value, default_value)

	func set_i16(byte_off: int, value: int, default_value: int = 0) -> void:
		set_u16(byte_off, value, default_value)

	func set_i32(byte_off: int, value: int, default_value: int = 0) -> void:
		set_u32(byte_off, value, default_value)

	func set_i64(byte_off: int, value: int, default_value: int = 0) -> void:
		set_u64(byte_off, value, default_value)

	func set_f32(byte_off: int, value: float, default_bits: int = 0) -> void:
		CapnBuilder._f32_scratch.encode_float(0, value)
		var bits: int = CapnBuilder._f32_scratch.decode_u32(0) ^ default_bits
		_buf().encode_u32(_d(byte_off), bits & 0xffffffff)

	func set_f64(byte_off: int, value: float, default_bits: int = 0) -> void:
		CapnBuilder._f64_scratch.encode_double(0, value)
		var bits: int = CapnBuilder._f64_scratch.decode_u64(0) ^ default_bits
		_buf().encode_u64(_d(byte_off), bits)

	func set_bool(bit_off: int, value: bool, default_bit: bool = false) -> void:
		@warning_ignore("integer_division")
		var byte_off: int = _d(bit_off / 8)
		var bit_in_byte: int = bit_off & 7
		var wire: bool = value != default_bit  # XOR
		var b: int = _buf().decode_u8(byte_off)
		var mask: int = 1 << bit_in_byte
		_buf().encode_u8(byte_off, (b | mask) if wire else (b & (~mask & 0xff)))

	# --- pointer setters --------------------------------------------------

	func init_struct(ptr_index: int, dw: int, pw: int) -> StructBuilder:
		var child: Vector2i = arena.allocate(dw + pw)
		arena.point_to_struct(seg_id, ptr_word + ptr_index, child, dw, pw)
		return StructBuilder.new(arena, child.x, child.y, dw, pw)

	## Primitive/pointer list (non-composite). Element width comes from `code`.
	func init_list(ptr_index: int, code: CapnPointer.ElemSize, count: int) -> ListBuilder:
		var body: int = CapnBuilder._list_body_words(code, count)
		var loc: Vector2i = arena.allocate(body)
		arena.point_to_list(seg_id, ptr_word + ptr_index, loc, code, count)
		return ListBuilder.make_primitive(arena, loc.x, loc.y, code, count)

	## Composite (struct) list: tag word + count fixed-width structs.
	func init_composite_list(ptr_index: int, count: int, dw: int, pw: int) -> ListBuilder:
		var step: int = dw + pw
		var total: int = 1 + count * step
		var loc: Vector2i = arena.allocate(total)
		arena._put(loc.x, loc.y, CapnPointer.encode_composite_tag(count, dw, pw))
		arena.point_to_list(seg_id, ptr_word + ptr_index, loc, CapnPointer.ElemSize.COMPOSITE, count * step)
		return ListBuilder.make_composite(arena, loc.x, loc.y + 1, count, dw, pw)

	func set_text(ptr_index: int, s: String) -> void:
		_write_bytes(ptr_index, CapnTextData.text_to_bytes(s))

	func set_data(ptr_index: int, bytes: PackedByteArray) -> void:
		_write_bytes(ptr_index, bytes)

	func _write_bytes(ptr_index: int, bytes: PackedByteArray) -> void:
		var loc: Vector2i = arena.alloc_bytes(bytes)
		arena.point_to_list(seg_id, ptr_word + ptr_index, loc, CapnPointer.ElemSize.BYTE, bytes.size())

	func _d(byte_off: int) -> int:
		return data_word * WORD_BYTES + byte_off

	func _buf() -> PackedByteArray:
		return arena.segments[seg_id]


# =========================================================================
# ListBuilder — write list elements (primitive, composite, pointer).
# =========================================================================

class ListBuilder extends RefCounted:
	const WORD_BYTES: int = 8

	var arena: Arena = null
	var seg_id: int = 0
	var first_elem_word: int = 0
	var elem_size_code: CapnPointer.ElemSize = CapnPointer.ElemSize.VOID
	var count: int = 0
	var step_bytes: int = 0
	var is_composite: bool = false
	var comp_data_words: int = 0
	var comp_ptr_words: int = 0
	var step_words: int = 0

	static func make_primitive(p_arena: Arena, p_seg_id: int, p_first_elem_word: int, p_code: CapnPointer.ElemSize, p_count: int) -> ListBuilder:
		var b: ListBuilder = ListBuilder.new()
		b.arena = p_arena
		b.seg_id = p_seg_id
		b.first_elem_word = p_first_elem_word
		b.elem_size_code = p_code
		b.count = p_count
		b.step_bytes = CapnPointer.elem_size_bytes(p_code)
		return b

	static func make_composite(p_arena: Arena, p_seg_id: int, p_first_elem_word: int, p_count: int, p_dw: int, p_pw: int) -> ListBuilder:
		var b: ListBuilder = ListBuilder.new()
		b.arena = p_arena
		b.seg_id = p_seg_id
		b.first_elem_word = p_first_elem_word
		b.elem_size_code = CapnPointer.ElemSize.COMPOSITE
		b.count = p_count
		b.is_composite = true
		b.comp_data_words = p_dw
		b.comp_ptr_words = p_pw
		b.step_words = p_dw + p_pw
		return b

	func size() -> int:
		return count

	# Primitive element setters (no XOR; lists carry no per-element defaults).
	func set_u8(i: int, value: int) -> void:
		_buf().encode_u8(_elem(i), value & 0xff)

	func set_u16(i: int, value: int) -> void:
		_buf().encode_u16(_elem(i), value & 0xffff)

	func set_u32(i: int, value: int) -> void:
		_buf().encode_u32(_elem(i), value & 0xffffffff)

	func set_u64(i: int, value: int) -> void:
		_buf().encode_u64(_elem(i), value)

	func set_i8(i: int, value: int) -> void:
		set_u8(i, value)

	func set_i16(i: int, value: int) -> void:
		set_u16(i, value)

	func set_i32(i: int, value: int) -> void:
		set_u32(i, value)

	func set_i64(i: int, value: int) -> void:
		set_u64(i, value)

	func set_f32(i: int, value: float) -> void:
		CapnBuilder._f32_scratch.encode_float(0, value)
		_buf().encode_u32(_elem(i), CapnBuilder._f32_scratch.decode_u32(0))

	func set_f64(i: int, value: float) -> void:
		CapnBuilder._f64_scratch.encode_double(0, value)
		_buf().encode_u64(_elem(i), CapnBuilder._f64_scratch.decode_u64(0))

	func set_bool(i: int, value: bool) -> void:
		@warning_ignore("integer_division")
		var byte_off: int = first_elem_word * WORD_BYTES + (i / 8)
		var bit_in_byte: int = i & 7
		var b: int = _buf().decode_u8(byte_off)
		var mask: int = 1 << bit_in_byte
		_buf().encode_u8(byte_off, (b | mask) if value else (b & (~mask & 0xff)))

	# Bulk primitive-list write — fill the whole list from a Packed*Array. GDScript
	# has no PackedByteArray blit, so these loop internally (no build speedup over
	# per-element set_*); they exist for API symmetry with the bulk reader getters
	# (Packed* in / Packed* out) and ergonomics. n is bounded by the list count.
	func set_float32_array(values: PackedFloat32Array) -> void:
		var n: int = mini(values.size(), count)
		var i: int = 0
		while i < n:
			set_f32(i, values[i])
			i += 1

	func set_float64_array(values: PackedFloat64Array) -> void:
		var n: int = mini(values.size(), count)
		var i: int = 0
		while i < n:
			set_f64(i, values[i])
			i += 1

	func set_int32_array(values: PackedInt32Array) -> void:
		var n: int = mini(values.size(), count)
		var i: int = 0
		while i < n:
			set_u32(i, values[i] & 0xffffffff)
			i += 1

	func set_int64_array(values: PackedInt64Array) -> void:
		var n: int = mini(values.size(), count)
		var i: int = 0
		while i < n:
			set_u64(i, values[i])
			i += 1

	func set_byte_array(values: PackedByteArray) -> void:
		var n: int = mini(values.size(), count)
		var i: int = 0
		while i < n:
			set_u8(i, values[i])
			i += 1

	## Builder for composite element i (valid only on a composite list).
	func init_struct(i: int) -> StructBuilder:
		var base_word: int = first_elem_word + i * step_words
		return StructBuilder.new(arena, seg_id, base_word, comp_data_words, comp_ptr_words)

	## For List(Pointer) elements: allocate a struct and write its pointer at
	## element i (e.g. List(Text) uses set_text; List(AnyStruct) uses this).
	func init_struct_ptr(i: int, dw: int, pw: int) -> StructBuilder:
		var child: Vector2i = arena.allocate(dw + pw)
		arena.point_to_struct(seg_id, first_elem_word + i, child, dw, pw)
		return StructBuilder.new(arena, child.x, child.y, dw, pw)

	## Nested list: init a primitive/pointer list at element i (the outer list must
	## be a pointer-element list), returns the inner list's builder. Mirror of
	## StructBuilder.init_list but anchored at element word i (CG10 List(List(T))).
	func init_list_at(i: int, code: CapnPointer.ElemSize, n: int) -> ListBuilder:
		var body: int = CapnBuilder._list_body_words(code, n)
		var loc: Vector2i = arena.allocate(body)
		arena.point_to_list(seg_id, first_elem_word + i, loc, code, n)
		return ListBuilder.make_primitive(arena, loc.x, loc.y, code, n)

	## Nested composite (struct) list at element i. Mirror of
	## StructBuilder.init_composite_list (CG10 List(List(struct))).
	func init_composite_list_at(i: int, n: int, dw: int, pw: int) -> ListBuilder:
		var step: int = dw + pw
		var total: int = 1 + n * step
		var loc: Vector2i = arena.allocate(total)
		arena._put(loc.x, loc.y, CapnPointer.encode_composite_tag(n, dw, pw))
		arena.point_to_list(seg_id, first_elem_word + i, loc, CapnPointer.ElemSize.COMPOSITE, n * step)
		return ListBuilder.make_composite(arena, loc.x, loc.y + 1, n, dw, pw)

	func set_text(i: int, s: String) -> void:
		_write_bytes(i, CapnTextData.text_to_bytes(s))

	func set_data(i: int, bytes: PackedByteArray) -> void:
		_write_bytes(i, bytes)

	func _write_bytes(i: int, bytes: PackedByteArray) -> void:
		var loc: Vector2i = arena.alloc_bytes(bytes)
		arena.point_to_list(seg_id, first_elem_word + i, loc, CapnPointer.ElemSize.BYTE, bytes.size())

	func _elem(i: int) -> int:
		return first_elem_word * WORD_BYTES + i * step_bytes

	func _buf() -> PackedByteArray:
		return arena.segments[seg_id]
