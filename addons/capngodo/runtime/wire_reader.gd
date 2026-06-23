class_name CapnReader
extends RefCounted
## The read side of the codec: Message + StructReader + ListReader, kept in ONE
## file as inner classes because they form a mutual type cycle (a message yields
## struct readers, a struct reader yields list readers, a list reader yields
## struct readers). Godot cannot resolve a static-typed cycle that spans
## separate class_name files, so they live together — the godobuf approach.
##
## Leaves stay in their own files (no cycle): CapnPointer, CapnSegments,
## CapnFraming, CapnPacked, CapnLimits, CapnTarget, CapnTextData.
##
## Entry points: CapnReader.open(bytes, packed) / CapnReader.from_segments(segs).

const WORD_BYTES: int = 8


static func open(bytes: PackedByteArray, packed: bool, limits: CapnLimits = null) -> Message:
	var raw: PackedByteArray = CapnPacked.unpack(bytes) if packed else bytes
	var segs: CapnSegments = CapnFraming.read(raw)
	if segs == null:
		return null
	return _make_message(segs, limits)


## Open from already-parsed segments (no stream framing) — e.g. the `flat`
## fixture is one bare segment.
static func from_segments(segs: CapnSegments, limits: CapnLimits = null) -> Message:
	return _make_message(segs, limits)


static func _make_message(segs: CapnSegments, limits: CapnLimits) -> Message:
	var msg: Message = Message.new()
	msg.segments = segs
	msg.limits = limits if limits != null else CapnLimits.new()
	return msg

# =========================================================================
# Message — segments + limits + pointer-following + traversal accounting.
# =========================================================================


class Message extends RefCounted:
	var segments: CapnSegments = null
	var limits: CapnLimits = null
	var traversal_words_used: int = 0
	var had_error: bool = false

	# Reused scratch target — follow() and its callees populate this and the
	# caller copies its fields into a Struct/ListReader before the next follow().
	# Reads are single-threaded with no await between follows, and every target is
	# consumed immediately (from_target/from_inline copy the fields out, never
	# retain the CapnTarget), so one instance per Message is safe and drops a
	# per-pointer-dereference alloc on the decode hot path.
	var _scratch: CapnTarget = CapnTarget.new()

	# Reused scratch pointers for the decode hot path — every follow() decodes a
	# pointer word into one of these instead of allocating a fresh CapnPointer.
	# Two slots: a far pointer's landing pad needs the original (drained to locals)
	# plus an inner + tag word live at once, so the double-far arm uses both _ptr_a
	# (inner) and _ptr_b (tag). Same single-threaded, drain-before-next-decode
	# safety as _scratch above.
	var _ptr_a: CapnPointer = CapnPointer.new()
	var _ptr_b: CapnPointer = CapnPointer.new()


	# Reset the scratch to a null target and return it — used on every
	# null/out-of-bounds/limit path in place of CapnTarget.new().
	func null_target() -> CapnTarget:
		_scratch.is_null = true
		_scratch.is_cap = false
		return _scratch


	# Decode the pointer word at (seg_id, word_off) into the shared scratch and
	# return it — lets ListReader.from_target read a composite tag without its own
	# alloc. Only safe once follow() has drained its decode into a CapnTarget.
	func decode_ptr(seg_id: int, word_off: int) -> CapnPointer:
		CapnPointer.decode_at_into(_ptr_a, segments.segments[seg_id], word_off * WORD_BYTES)
		return _ptr_a


	func get_root() -> StructReader:
		var r: StructReader = StructReader.new()
		fill_root(r)
		return r


	## Populate `out` (a StructReader or a generated Reader subclass) from the root
	## pointer, instead of allocating a fresh reader to wrap. Lets a typed Reader
	## that extends StructReader be the single allocation — see fill_struct. `out`
	## must be freshly constructed: only `msg` is written on the empty path, the
	## other fields are left at their .new() defaults (a zero-size reader).
	func fill_root(out: StructReader) -> void:
		if segments == null or segments.segment_count() == 0:
			fail("empty message")
			out.msg = self
			return
		var target: CapnTarget = follow(0, 0)
		if target.is_null or target.kind != CapnPointer.Kind.STRUCT:
			out.msg = self
			return
		out.set_from_target(self, target, limits.pointer_depth_limit)


	## Follow the pointer word at (seg_id, ptr_word_off). Resolves far pointers.
	## Always returns a CapnTarget (never null); is_null=true on null/error.
	func follow(seg_id: int, ptr_word_off: int) -> CapnTarget:
		if not segments.words_in_bounds(seg_id, ptr_word_off, 1):
			fail("pointer word out of bounds (seg %d word %d)" % [seg_id, ptr_word_off])
			return null_target()
		var ptr: CapnPointer = _ptr_a
		CapnPointer.decode_at_into(ptr, segments.segments[seg_id], ptr_word_off * WORD_BYTES)
		if ptr.is_null:
			return null_target() # null target (not an error)
		if ptr.kind == CapnPointer.Kind.FAR:
			return _follow_far(ptr)
		return _target_from_pointer(seg_id, ptr_word_off + 1 + ptr.offset, ptr)


	## Flattened follow for the decode hot path: merges decode_at_into +
	## _target_from_pointer + _check (and their bounds checks) into one frame,
	## cutting the layered chain's ~8 nested calls to one. The rare far case
	## delegates to follow(). Bounds, traversal charge, and null/error targets
	## match follow() exactly — verified against the full suite. Callers (the
	## reader _follow_ptr/_follow_elem) own the ptr-index and depth guards.
	# Wire->enum boundary: bit-extracted codes assigned to enum fields (D10a).
	@warning_ignore("int_as_enum_without_cast") func follow_flat(seg_id: int, ptr_word_off: int) -> CapnTarget:
		if seg_id < 0 or seg_id >= segments.segments.size():
			fail("pointer word out of bounds (seg %d word %d)" % [seg_id, ptr_word_off])
			return null_target()
		var seg: PackedByteArray = segments.segments[seg_id]
		var seg_words: int = seg.size() >> 3
		if ptr_word_off < 0 or ptr_word_off >= seg_words:
			fail("pointer word out of bounds (seg %d word %d)" % [seg_id, ptr_word_off])
			return null_target()
		var pbase: int = ptr_word_off * WORD_BYTES
		var lo: int = seg.decode_u32(pbase)
		var hi: int = seg.decode_u32(pbase + 4)
		if lo == 0 and hi == 0:
			return null_target()
		var a: int = lo & 0x3
		if a == CapnPointer.Kind.FAR:
			return follow(seg_id, ptr_word_off) # rare; re-decode + chase in the layered path
		var t: CapnTarget = _scratch
		t.is_cap = false
		t.seg_id = seg_id
		if a == CapnPointer.Kind.OTHER: # capability
			t.kind = CapnPointer.Kind.OTHER
			t.is_cap = true
			t.cap_index = hi
			t.is_null = false
			return t
		# struct/list share a signed 30-bit offset, then a bounds + traversal charge.
		var off30: int = (lo >> 2) & 0x3FFFFFFF
		if off30 >= 0x20000000:
			off30 -= 0x40000000
		var content_word: int = ptr_word_off + 1 + off30
		var ecode: int = 0
		var ecount: int = 0
		var dwords: int = 0
		var pwords: int = 0
		var span: int = 0
		if a == CapnPointer.Kind.STRUCT:
			dwords = hi & 0xffff
			pwords = (hi >> 16) & 0xffff
			span = dwords + pwords
		else: # LIST
			ecode = hi & 0x7
			ecount = (hi >> 3) & 0x1FFFFFFF
			span = (1 + ecount) if ecode == CapnPointer.ElemSize.COMPOSITE else _list_body_words(ecode, ecount)
		if content_word < 0 or content_word + span > seg_words:
			fail("object out of bounds (seg %d word %d span %d)" % [seg_id, content_word, span])
			return null_target()
		traversal_words_used += span if span > 0 else 1
		if traversal_words_used > limits.traversal_word_limit:
			fail("traversal limit exceeded")
			return null_target()
		t.content_word = content_word
		t.is_null = false
		if a == CapnPointer.Kind.STRUCT:
			t.kind = CapnPointer.Kind.STRUCT
			t.data_words = dwords
			t.ptr_words = pwords
		else:
			t.kind = CapnPointer.Kind.LIST
			t.elem_size_code = ecode
			t.elem_count = ecount
		return t


	func _follow_far(far: CapnPointer) -> CapnTarget:
		var seg: int = far.far_segment_id
		var pad_word: int = far.offset
		if far.far_two_word:
			# Double-far: word0 = inner far (B=0) -> content directly; word1 = tag.
			if not segments.words_in_bounds(seg, pad_word, 2):
				fail("double-far landing pad out of bounds")
				return null_target()
			# far (== _ptr_a) is drained to seg/pad_word above; reuse it for inner,
			# _ptr_b for tag — both stay live through _target_from_pointer below.
			var inner: CapnPointer = _ptr_a
			CapnPointer.decode_at_into(inner, segments.segments[seg], pad_word * WORD_BYTES)
			var tag: CapnPointer = _ptr_b
			CapnPointer.decode_at_into(tag, segments.segments[seg], (pad_word + 1) * WORD_BYTES)
			if inner.kind != CapnPointer.Kind.FAR or inner.far_two_word:
				fail("double-far inner word is not a single far pointer")
				return null_target()
			# Inner far's offset points at the content start directly (no further pad).
			return _target_from_pointer(inner.far_segment_id, inner.offset, tag)
		# Single-far: one landing-pad pointer, offset relative to end of that word.
		if not segments.words_in_bounds(seg, pad_word, 1):
			fail("far landing pad out of bounds")
			return null_target()
		var pad: CapnPointer = _ptr_a
		CapnPointer.decode_at_into(pad, segments.segments[seg], pad_word * WORD_BYTES)
		if pad.kind == CapnPointer.Kind.FAR:
			fail("far landing pad points to another far pointer")
			return null_target()
		return _target_from_pointer(seg, pad_word + 1 + pad.offset, pad)


	func _target_from_pointer(seg_id: int, content_word: int, ptr: CapnPointer) -> CapnTarget:
		var t: CapnTarget = _scratch
		# Clear the cross-kind sticky flag — the scratch may carry is_cap=true from a
		# prior capability target, and the struct/list arms below never reset it.
		t.is_cap = false
		t.seg_id = seg_id
		t.content_word = content_word
		t.kind = ptr.kind
		if ptr.kind == CapnPointer.Kind.STRUCT:
			t.data_words = ptr.data_words
			t.ptr_words = ptr.ptr_words
			if not _check(seg_id, content_word, ptr.data_words + ptr.ptr_words):
				return null_target()
			t.is_null = false
			return t
		if ptr.kind == CapnPointer.Kind.LIST:
			t.elem_size_code = ptr.elem_size_code
			t.elem_count = ptr.elem_count
			if ptr.elem_size_code == CapnPointer.ElemSize.COMPOSITE:
				# content_word points at the tag word; elem_count = words after tag.
				if not _check(seg_id, content_word, 1 + ptr.elem_count):
					return null_target()
			else:
				var body: int = _list_body_words(ptr.elem_size_code, ptr.elem_count)
				if not _check(seg_id, content_word, body):
					return null_target()
			t.is_null = false
			return t
		# OTHER == capability
		t.is_cap = true
		t.cap_index = ptr.cap_index
		t.is_null = false
		return t


	## Bounds-check the object span and charge it to the traversal counter.
	func _check(seg_id: int, word_off: int, span_words: int) -> bool:
		if not segments.words_in_bounds(seg_id, word_off, span_words):
			fail("object out of bounds (seg %d word %d span %d)" % [seg_id, word_off, span_words])
			return false
		# Charge at least one word per dereference so deeply-nested empties cost.
		traversal_words_used += span_words if span_words > 0 else 1
		if traversal_words_used > limits.traversal_word_limit:
			fail("traversal limit exceeded")
			return false
		return true


	## Physical words occupied by a non-composite list body.
	static func _list_body_words(code: CapnPointer.ElemSize, count: int) -> int:
		if code == CapnPointer.ElemSize.VOID:
			return 0
		if code == CapnPointer.ElemSize.BIT:
			@warning_ignore("integer_division")
			var bit_words: int = (count + 63) / 64 # ceil(count bits / 64)
			return bit_words
		var elem_bytes: int = CapnPointer.elem_size_bytes(code)
		@warning_ignore("integer_division")
		var body_words: int = (count * elem_bytes + WORD_BYTES - 1) / WORD_BYTES
		return body_words


	func fail(message: String) -> void:
		had_error = true
		push_error("CapnReader: %s" % message)


	## Decode a text/data target straight off the CapnTarget, skipping the
	## throwaway ListReader that to_text()/to_data() would otherwise need. Text
	## and Data are always List(UInt8) — non-composite — so the byte span is
	## (content_word, elem_count) directly. The COMPOSITE arm is unreachable on a
	## well-formed message; it falls back to the reader path to stay faithful on
	## malformed input. Safe with the RT4 scratch: the caller reads `t`'s fields
	## here before the next follow() overwrites the scratch.
	func text_from_target(t: CapnTarget) -> String:
		if t.elem_size_code == CapnPointer.ElemSize.COMPOSITE:
			return ListReader.from_target(self, t, 0).to_text()
		return CapnTextData.text_from(
			segments.segments[t.seg_id],
			t.content_word * WORD_BYTES,
			t.elem_count,
		)


	func data_from_target(t: CapnTarget) -> PackedByteArray:
		if t.elem_size_code == CapnPointer.ElemSize.COMPOSITE:
			return ListReader.from_target(self, t, 0).to_data()
		return CapnTextData.data_from(
			segments.segments[t.seg_id],
			t.content_word * WORD_BYTES,
			t.elem_count,
		)

# =========================================================================
# StructReader — data + pointer section view (default-XOR primitives).
# =========================================================================


class StructReader extends RefCounted:
	const WORD_BYTES: int = 8

	# Reused scratch for float bit-reinterpretation — avoids a per-call alloc on
	# get_f32/get_f64. Safe: reads are single-threaded with no await between the
	# encode and decode, so no instance can observe a half-written buffer.
	static var _f32_scratch: PackedByteArray = _make_scratch(4)
	static var _f64_scratch: PackedByteArray = _make_scratch(8)

	var msg: Message = null
	var seg_id: int = 0
	var data_byte_off: int = 0
	var data_bytes: int = 0 # data section length in BYTES (supports sub-word upgrade)
	var ptr_word: int = 0
	var ptr_words: int = 0
	# Steps still allowed below this reader: a child gets depth_remaining - 1,
	# and a follow fails once it would go below 0 (exactly pointer_depth_limit deep).
	var depth_remaining: int = 0


	static func _make_scratch(n: int) -> PackedByteArray:
		var b: PackedByteArray = PackedByteArray()
		b.resize(n)
		return b


	static func from_target(msg: Message, t: CapnTarget, depth_remaining: int) -> StructReader:
		var r: StructReader = StructReader.new()
		r.set_from_target(msg, t, depth_remaining)
		return r


	## Explicit byte/word offsets — used by ListReader for composite elements
	## (word-aligned) and upgraded primitive elements (sub-word).
	static func from_inline(
			msg: Message,
			seg_id: int,
			data_byte_off: int,
			data_bytes: int,
			ptr_word: int,
			ptr_words: int,
			depth_remaining: int,
	) -> StructReader:
		var r: StructReader = StructReader.new()
		r.set_from_inline(
			msg,
			seg_id,
			data_byte_off,
			data_bytes,
			ptr_word,
			ptr_words,
			depth_remaining,
		)
		return r


	## In-place population of an existing reader (or a generated Reader subclass)
	## from a target. The fill_* path uses this so a typed Reader that extends
	## StructReader is a single allocation instead of StructReader + a wrapper.
	func set_from_target(p_msg: Message, t: CapnTarget, p_depth: int) -> void:
		set_from_inline(
			p_msg,
			t.seg_id,
			t.content_word * WORD_BYTES,
			t.data_words * WORD_BYTES,
			t.content_word + t.data_words,
			t.ptr_words,
			p_depth,
		)


	func set_from_inline(
			p_msg: Message,
			p_seg_id: int,
			p_data_byte_off: int,
			p_data_bytes: int,
			p_ptr_word: int,
			p_ptr_words: int,
			p_depth: int,
	) -> void:
		msg = p_msg
		seg_id = p_seg_id
		data_byte_off = p_data_byte_off
		data_bytes = p_data_bytes
		ptr_word = p_ptr_word
		ptr_words = p_ptr_words
		depth_remaining = p_depth


	## Zero-size reader: every primitive returns its default, every pointer null.
	static func empty(msg: Message) -> StructReader:
		var r: StructReader = StructReader.new()
		r.msg = msg
		return r


	func get_u8(byte_off: int, default_value: int) -> int:
		if not _in_data(byte_off, 1):
			return default_value
		return _buf().decode_u8(data_byte_off + byte_off) ^ default_value


	func get_u16(byte_off: int, default_value: int) -> int:
		if not _in_data(byte_off, 2):
			return default_value
		return _buf().decode_u16(data_byte_off + byte_off) ^ default_value


	func get_u32(byte_off: int, default_value: int) -> int:
		if not _in_data(byte_off, 4):
			return default_value
		return _buf().decode_u32(data_byte_off + byte_off) ^ default_value


	func get_u64(byte_off: int, default_value: int) -> int:
		# XOR on the i64 bit pattern; caller treats the result as the stored bits.
		if not _in_data(byte_off, 8):
			return default_value
		return _buf().decode_u64(data_byte_off + byte_off) ^ default_value


	func get_i8(byte_off: int, default_value: int) -> int:
		if not _in_data(byte_off, 1):
			return default_value
		var raw: int = _buf().decode_u8(data_byte_off + byte_off) ^ (default_value & 0xff)
		return raw - 0x100 if raw >= 0x80 else raw


	func get_i16(byte_off: int, default_value: int) -> int:
		if not _in_data(byte_off, 2):
			return default_value
		var raw: int = _buf().decode_u16(data_byte_off + byte_off) ^ (default_value & 0xffff)
		return raw - 0x10000 if raw >= 0x8000 else raw


	func get_i32(byte_off: int, default_value: int) -> int:
		if not _in_data(byte_off, 4):
			return default_value
		var raw: int = _buf().decode_u32(data_byte_off + byte_off) ^ (default_value & 0xffffffff)
		return raw - 0x100000000 if raw >= 0x80000000 else raw


	func get_i64(byte_off: int, default_value: int) -> int:
		if not _in_data(byte_off, 8):
			return default_value
		return _buf().decode_u64(data_byte_off + byte_off) ^ default_value


	## Float getters take the default as its IEEE bit pattern (u32/u64), XOR on
	## bits, then reinterpret — float defaults mask on the bit pattern, not the
	## arithmetic value (encoding.md :122-137).
	func get_f32(byte_off: int, default_bits: int) -> float:
		var bits: int = default_bits
		if _in_data(byte_off, 4):
			bits = _buf().decode_u32(data_byte_off + byte_off) ^ default_bits
		_f32_scratch.encode_u32(0, bits & 0xFFFFFFFF)
		return _f32_scratch.decode_float(0)


	func get_f64(byte_off: int, default_bits: int) -> float:
		var bits: int = default_bits
		if _in_data(byte_off, 8):
			bits = _buf().decode_u64(data_byte_off + byte_off) ^ default_bits
		_f64_scratch.encode_u64(0, bits)
		return _f64_scratch.decode_double(0)


	func get_bool(bit_off: int, default_bit: bool) -> bool:
		@warning_ignore("integer_division")
		var byte_off: int = bit_off / 8
		var bit_in_byte: int = bit_off & 7
		if not _in_data(byte_off, 1):
			return default_bit
		var wire_bit: bool = (_buf().decode_u8(data_byte_off + byte_off) & (1 << bit_in_byte)) != 0
		return wire_bit != default_bit # XOR for bools


	func has_ptr(ptr_index: int) -> bool:
		return not _follow_ptr(ptr_index).is_null


	func get_struct(ptr_index: int) -> StructReader:
		var r: StructReader = StructReader.new()
		fill_struct(ptr_index, r)
		return r


	## Populate `out` from the struct pointer at `ptr_index` (or leave it a zero-size
	## reader on null/non-struct), instead of allocating. Generated typed Readers
	## (which extend StructReader) pass a fresh `X.Reader.new()` here so the typed
	## reader is the single allocation — no separate StructReader + wrapper. `out`
	## must be freshly constructed (only `msg` is set on the empty path).
	func fill_struct(ptr_index: int, out: StructReader) -> void:
		var t: CapnTarget = _follow_ptr(ptr_index)
		if t.is_null or t.kind != CapnPointer.Kind.STRUCT:
			out.msg = msg
			return
		out.set_from_target(msg, t, depth_remaining - 1)


	func get_list(ptr_index: int) -> ListReader:
		var t: CapnTarget = _follow_ptr(ptr_index)
		if t.is_null or t.kind != CapnPointer.Kind.LIST:
			return ListReader.empty(msg)
		return ListReader.from_target(msg, t, depth_remaining - 1)


	## Fully-inlined Text read for the common case: an in-segment, in-bounds
	## non-far byte list. Inlines _follow_ptr + follow_flat + the byte-list bounds
	## + traversal charge + the slice/utf8 decode into one frame (no nested calls
	## on the hot path), since Text dominates real payloads. Anything else (absent,
	## null, far, composite, depth/limit) falls to _get_text_slow BEFORE any
	## traversal charge, so the slow re-follow never double-counts. Semantics match
	## the layered path exactly — see test_wire_inline_text.gd.
	# Wire->enum boundary: bit-extracted codes compared against enum values (D10a).
	@warning_ignore("int_as_enum_without_cast") func get_text(ptr_index: int, default_value: String = "") -> String:
		if ptr_index < 0 or ptr_index >= ptr_words:
			return default_value
		if depth_remaining <= 0:
			return _get_text_slow(ptr_index, default_value)
		var word_off: int = ptr_word + ptr_index
		var seg: PackedByteArray = msg.segments.segments[seg_id]
		var seg_words: int = seg.size() >> 3
		if word_off >= seg_words:
			return _get_text_slow(ptr_index, default_value)
		var pbase: int = word_off * WORD_BYTES
		var lo: int = seg.decode_u32(pbase)
		var hi: int = seg.decode_u32(pbase + 4)
		if lo == 0 and hi == 0:
			return default_value # null pointer -> default (no error)
		if (lo & 0x3) != CapnPointer.Kind.LIST or (hi & 0x7) != CapnPointer.ElemSize.BYTE:
			return _get_text_slow(ptr_index, default_value) # far / composite / non-byte
		var off30: int = (lo >> 2) & 0x3FFFFFFF
		if off30 >= 0x20000000:
			off30 -= 0x40000000
		var content_word: int = word_off + 1 + off30
		var count: int = (hi >> 3) & 0x1FFFFFFF
		var span_words: int = (count + 7) >> 3 # _list_body_words(BYTE, count)
		if content_word < 0 or content_word + span_words > seg_words:
			return _get_text_slow(ptr_index, default_value)
		msg.traversal_words_used += span_words if span_words > 0 else 1
		if msg.traversal_words_used > msg.limits.traversal_word_limit:
			msg.fail("traversal limit exceeded")
			return default_value
		if count <= 0:
			return ""
		var cbyte: int = content_word * WORD_BYTES
		var endb: int = cbyte + count
		if seg[endb - 1] == 0:
			endb -= 1 # drop the Text NUL terminator
		return seg.slice(cbyte, endb).get_string_from_utf8()


	# Layered fallback for the non-fast-path Text cases. Reached only before any
	# traversal charge, so re-following here can't double-count.
	func _get_text_slow(ptr_index: int, default_value: String) -> String:
		var t: CapnTarget = _follow_ptr(ptr_index)
		if t.is_null or t.kind != CapnPointer.Kind.LIST:
			return default_value
		return msg.text_from_target(t)


	## Data twin of get_text — same inlined byte-list fast path, but returns the
	## raw bytes (no NUL drop). Falls to _get_data_slow for the rest.
	# Wire->enum boundary: bit-extracted codes compared against enum values (D10a).
	@warning_ignore("int_as_enum_without_cast") func get_data(ptr_index: int, default_value: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if ptr_index < 0 or ptr_index >= ptr_words:
			return default_value
		if depth_remaining <= 0:
			return _get_data_slow(ptr_index, default_value)
		var word_off: int = ptr_word + ptr_index
		var seg: PackedByteArray = msg.segments.segments[seg_id]
		var seg_words: int = seg.size() >> 3
		if word_off >= seg_words:
			return _get_data_slow(ptr_index, default_value)
		var pbase: int = word_off * WORD_BYTES
		var lo: int = seg.decode_u32(pbase)
		var hi: int = seg.decode_u32(pbase + 4)
		if lo == 0 and hi == 0:
			return default_value
		if (lo & 0x3) != CapnPointer.Kind.LIST or (hi & 0x7) != CapnPointer.ElemSize.BYTE:
			return _get_data_slow(ptr_index, default_value)
		var off30: int = (lo >> 2) & 0x3FFFFFFF
		if off30 >= 0x20000000:
			off30 -= 0x40000000
		var content_word: int = word_off + 1 + off30
		var count: int = (hi >> 3) & 0x1FFFFFFF
		var span_words: int = (count + 7) >> 3
		if content_word < 0 or content_word + span_words > seg_words:
			return _get_data_slow(ptr_index, default_value)
		msg.traversal_words_used += span_words if span_words > 0 else 1
		if msg.traversal_words_used > msg.limits.traversal_word_limit:
			msg.fail("traversal limit exceeded")
			return default_value
		if count <= 0:
			return PackedByteArray()
		var cbyte: int = content_word * WORD_BYTES
		return seg.slice(cbyte, cbyte + count)


	func _get_data_slow(ptr_index: int, default_value: PackedByteArray) -> PackedByteArray:
		var t: CapnTarget = _follow_ptr(ptr_index)
		if t.is_null or t.kind != CapnPointer.Kind.LIST:
			return default_value
		return msg.data_from_target(t)


	func get_cap_index(ptr_index: int) -> int:
		# Capability pointers decode to a table index; no RPC layer resolves them.
		var t: CapnTarget = _follow_ptr(ptr_index)
		if t.is_null or not t.is_cap:
			return -1
		return t.cap_index


	func _follow_ptr(ptr_index: int) -> CapnTarget:
		if ptr_index < 0 or ptr_index >= ptr_words:
			return msg.null_target() # absent pointer field -> null target
		if depth_remaining <= 0:
			msg.fail("pointer depth limit exceeded")
			return msg.null_target()
		return msg.follow_flat(seg_id, ptr_word + ptr_index)


	func _in_data(byte_off: int, width: int) -> bool:
		return byte_off >= 0 and (byte_off + width) <= data_bytes


	func _buf() -> PackedByteArray:
		return msg.segments.segments[seg_id]

# =========================================================================
# ListReader — all 8 element codes + composite + struct-upgrade rule.
# =========================================================================


class ListReader extends RefCounted:
	const WORD_BYTES: int = 8

	var msg: Message = null
	var seg_id: int = 0
	var elem_size_code: CapnPointer.ElemSize = CapnPointer.ElemSize.VOID
	var count: int = 0
	var first_elem_word: int = 0
	var is_composite: bool = false
	var step_bytes: int = 0 # non-composite primitive stride
	var step_words: int = 0 # composite element stride (data+ptr words)
	var comp_data_words: int = 0
	var comp_ptr_words: int = 0
	var depth_remaining: int = 0


	static func from_target(msg: Message, t: CapnTarget, depth_remaining: int) -> ListReader:
		var r: ListReader = ListReader.new()
		r.msg = msg
		r.seg_id = t.seg_id
		r.elem_size_code = t.elem_size_code
		r.depth_remaining = depth_remaining
		if t.elem_size_code == CapnPointer.ElemSize.COMPOSITE:
			# content_word points at the tag word; tag.offset carries the count.
			# follow() has already drained its decode into `t`, so its scratch pointer
			# is free to reuse for the tag word here.
			var tag: CapnPointer = msg.decode_ptr(t.seg_id, t.content_word)
			r.is_composite = true
			r.count = tag.offset
			r.comp_data_words = tag.data_words
			r.comp_ptr_words = tag.ptr_words
			r.step_words = tag.data_words + tag.ptr_words
			r.first_elem_word = t.content_word + 1
		else:
			r.count = t.elem_count
			r.first_elem_word = t.content_word
			r.step_bytes = CapnPointer.elem_size_bytes(t.elem_size_code)
		return r


	static func empty(msg: Message) -> ListReader:
		var r: ListReader = ListReader.new()
		r.msg = msg
		return r


	func size() -> int:
		return count


	## Decode this byte-list as Text (drops trailing NUL) / Data (raw bytes).
	func to_text() -> String:
		return CapnTextData.text_from(_buf(), first_elem_word * WORD_BYTES, count)


	func to_data() -> PackedByteArray:
		return CapnTextData.data_from(_buf(), first_elem_word * WORD_BYTES, count)


	# Bulk primitive-list decode: slice the contiguous element span and reinterpret
	# in one C++ call instead of a per-element decode loop (~100x for large lists).
	# The wire stores primitive lists contiguous + little-endian, matching the
	# Packed*Array in-memory layout — correct on little-endian hosts (every platform
	# Godot ships). Caller (codegen) only routes the clean fixed-width types here;
	# the list is never composite, so the span is (first_elem_word, count * width).
	func to_float32_array() -> PackedFloat32Array:
		var off: int = first_elem_word * WORD_BYTES
		return _buf().slice(off, off + count * 4).to_float32_array()


	func to_float64_array() -> PackedFloat64Array:
		var off: int = first_elem_word * WORD_BYTES
		return _buf().slice(off, off + count * 8).to_float64_array()


	func to_int32_array() -> PackedInt32Array:
		var off: int = first_elem_word * WORD_BYTES
		return _buf().slice(off, off + count * 4).to_int32_array()


	func to_int64_array() -> PackedInt64Array:
		var off: int = first_elem_word * WORD_BYTES
		return _buf().slice(off, off + count * 8).to_int64_array()


	func to_byte_array() -> PackedByteArray:
		var off: int = first_elem_word * WORD_BYTES
		return _buf().slice(off, off + count)


	# Primitive element getters (no XOR; lists carry no per-element defaults).
	func get_u8(i: int) -> int:
		return _buf().decode_u8(_elem_byte(i))


	func get_u16(i: int) -> int:
		return _buf().decode_u16(_elem_byte(i))


	func get_u32(i: int) -> int:
		return _buf().decode_u32(_elem_byte(i))


	func get_u64(i: int) -> int:
		return _buf().decode_u64(_elem_byte(i))


	func get_i8(i: int) -> int:
		return _buf().decode_s8(_elem_byte(i))


	func get_i16(i: int) -> int:
		return _buf().decode_s16(_elem_byte(i))


	func get_i32(i: int) -> int:
		return _buf().decode_s32(_elem_byte(i))


	func get_i64(i: int) -> int:
		return _buf().decode_s64(_elem_byte(i))


	func get_f32(i: int) -> float:
		return _buf().decode_float(_elem_byte(i))


	func get_f64(i: int) -> float:
		return _buf().decode_double(_elem_byte(i))


	func get_bool(i: int) -> bool:
		# Bit list: LSB-first packing (encoding.md :186-187).
		@warning_ignore("integer_division")
		var byte_off: int = first_elem_word * WORD_BYTES + (i / 8)
		var bit_in_byte: int = i & 7
		return (_buf().decode_u8(byte_off) & (1 << bit_in_byte)) != 0


	func get_struct(i: int) -> StructReader:
		var r: StructReader = StructReader.new()
		fill_struct(i, r)
		return r


	## Populate `out` from element `i` (composite or struct-upgraded primitive),
	## instead of allocating. Generated list getters pass a fresh `X.Reader.new()`
	## per element so the typed Reader is the single allocation, collapsing the old
	## StructReader + wrapper double-alloc. `out` must be freshly constructed (only
	## `msg` is set on the out-of-range / bit-list paths).
	func fill_struct(i: int, out: StructReader) -> void:
		if i < 0 or i >= count:
			out.msg = msg
			return
		if is_composite:
			var base_word: int = first_elem_word + i * step_words
			out.set_from_inline(
				msg,
				seg_id,
				base_word * WORD_BYTES,
				comp_data_words * WORD_BYTES,
				base_word + comp_data_words,
				comp_ptr_words,
				depth_remaining - 1,
			)
			return
		# Struct-upgrade (encoding.md :204-215).
		if elem_size_code == CapnPointer.ElemSize.BIT:
			msg.fail("cannot read a bit list as a struct list")
			out.msg = msg
			return
		if elem_size_code == CapnPointer.ElemSize.POINTER:
			# One-pointer struct: data empty, single pointer at the element word.
			out.set_from_inline(msg, seg_id, 0, 0, first_elem_word + i, 1, depth_remaining - 1)
			return
		# Void / byte / 2 / 4 / 8: project the element bytes as the data section.
		var data_off: int = first_elem_word * WORD_BYTES + i * step_bytes
		out.set_from_inline(msg, seg_id, data_off, step_bytes, 0, 0, depth_remaining - 1)


	func get_list(i: int) -> ListReader:
		var t: CapnTarget = _follow_elem(i)
		if t.is_null or t.kind != CapnPointer.Kind.LIST:
			return ListReader.empty(msg)
		return ListReader.from_target(msg, t, depth_remaining - 1)


	func get_struct_ptr(i: int) -> StructReader:
		# For List(Pointer) elements that are struct pointers (vs inline composite).
		var t: CapnTarget = _follow_elem(i)
		if t.is_null or t.kind != CapnPointer.Kind.STRUCT:
			return StructReader.empty(msg)
		return StructReader.from_target(msg, t, depth_remaining - 1)


	func get_text(i: int, default_value: String = "") -> String:
		var t: CapnTarget = _follow_elem(i)
		if t.is_null or t.kind != CapnPointer.Kind.LIST:
			return default_value
		return msg.text_from_target(t)


	func get_data(i: int, default_value: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		var t: CapnTarget = _follow_elem(i)
		if t.is_null or t.kind != CapnPointer.Kind.LIST:
			return default_value
		return msg.data_from_target(t)


	func get_cap_index(i: int) -> int:
		# List(interface) element: capability pointer -> cap-table index, -1 when
		# absent. Serialization-only; no RPC layer resolves it (CG10, mirrors the
		# struct-level StructReader.get_cap_index).
		var t: CapnTarget = _follow_elem(i)
		if t.is_null or not t.is_cap:
			return -1
		return t.cap_index


	func _follow_elem(i: int) -> CapnTarget:
		if i < 0 or i >= count:
			return msg.null_target()
		if depth_remaining <= 0:
			msg.fail("pointer depth limit exceeded")
			return msg.null_target()
		return msg.follow_flat(seg_id, first_elem_word + i)


	func _elem_byte(i: int) -> int:
		return first_elem_word * WORD_BYTES + i * step_bytes


	func _buf() -> PackedByteArray:
		return msg.segments.segments[seg_id]
