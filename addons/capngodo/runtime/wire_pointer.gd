class_name CapnPointer
extends RefCounted
## Cap'n Proto pointer-word codec (encoding.md :87-269).
##
## A pointer is exactly one 8-byte little-endian word. The low 2 bits are the
## kind tag. We always read the word as two u32 halves (lo = bytes 0-3, hi =
## bytes 4-7) and bit-extract from those — never as a single i64 — to dodge the
## UInt64-top-bit sign trap (a far pointer's segment id can set bit 63).
##
## decode_at()/decode() return a populated POD (this class). encode_* return a
## fresh 8-byte PackedByteArray. The data carries zero behaviour beyond field
## storage (DOD D1); all logic is in the static functions.

## Pointer kind = bits 0-1 of the word. Enum values ARE the wire tag values
## (D10/D10a): iota 0..3 matches the spec's A field exactly, like capnp's own
## C++ `enum class Kind`.
enum Kind {
	STRUCT, ## 0 — struct pointer
	LIST, ## 1 — list pointer
	FAR, ## 2 — far pointer
	OTHER, ## 3 — "other"; subkind 0 == capability
}

## List element-size code = C field (encoding.md :172-180). Enum values ARE the
## wire codes: iota 0..7 matches capnp's `enum class ElementSize`.
enum ElemSize {
	VOID, ## 0 — List(Void), zero width
	BIT, ## 1 — 1 bit
	BYTE, ## 2 — 1 byte
	TWO_BYTES, ## 3 — 2 bytes
	FOUR_BYTES, ## 4 — 4 bytes
	EIGHT_BYTES, ## 5 — 8 bytes, non-pointer
	POINTER, ## 6 — 8 bytes, pointer
	COMPOSITE, ## 7 — composite (tag word + elements)
}

const _MASK_30: int = 0x3FFFFFFF
const _MASK_29: int = 0x1FFFFFFF
const _SIGN_30: int = 0x20000000
const _SPAN_30: int = 0x40000000

# --- decoded fields (one populated subset per kind) ----------------------

var kind: Kind = Kind.STRUCT
var is_null: bool = false

# struct: signed word offset from end-of-pointer to data section.
# list:   signed word offset from end-of-pointer to first element.
# far:    unsigned landing-pad word offset within target segment.
var offset: int = 0

# struct only.
var data_words: int = 0
var ptr_words: int = 0

# list only.
var elem_size_code: ElemSize = ElemSize.VOID
var elem_count: int = 0 # element count (C<>7) or word count excl. tag (C=7)

# far only.
var far_two_word: bool = false
var far_segment_id: int = 0

# cap only. cap_is_valid is false when an OTHER pointer carries a reserved
# non-zero subkind (bits 2-31 != 0) — encoding.md :265 says only 0 == capability.
var cap_index: int = 0
var cap_is_valid: bool = false

# --- decode --------------------------------------------------------------


static func decode_at(buf: PackedByteArray, byte_off: int) -> CapnPointer:
	var p: CapnPointer = CapnPointer.new()
	decode_at_into(p, buf, byte_off)
	return p


## Populate `p` (a caller-owned scratch) from the pointer word at `byte_off`,
## skipping the per-dereference CapnPointer.new() on the decode hot path. The
## reader keeps a couple of these on the Message and reuses them across every
## follow(); decode is single-threaded and the fields are drained into a
## CapnTarget before the next decode, so one instance per slot is safe.
static func decode_at_into(p: CapnPointer, buf: PackedByteArray, byte_off: int) -> void:
	# Boundary guard: a past-end decode_u32 silently returns 0 in Godot, which
	# would mask truncation as a null pointer. Fail loud instead. (CapnMessage
	# owns the deeper validation that the pointed-to object fits its segment.)
	if byte_off < 0 or byte_off + 8 > buf.size():
		push_error("CapnPointer.decode_at: pointer word out of bounds at %d" % byte_off)
		p.is_null = true
		return
	var lo: int = buf.decode_u32(byte_off)
	var hi: int = buf.decode_u32(byte_off + 4)
	decode_into(p, lo, hi)


static func decode(lo: int, hi: int) -> CapnPointer:
	var p: CapnPointer = CapnPointer.new()
	decode_into(p, lo, hi)
	return p


## In-place sibling of decode(). `p` may carry stale fields from a prior decode;
## callers only read the subset selected by p.kind, and is_null is always reset
## here, so cross-kind stale fields are never observed.
# Wire->enum boundary: bit-extracted ints assigned to enum fields (D10a).
@warning_ignore("int_as_enum_without_cast")
static func decode_into(p: CapnPointer, lo: int, hi: int) -> void:
	p.is_null = false
	if lo == 0 and hi == 0:
		p.is_null = true
		return
	var a: int = lo & 0x3
	p.kind = a
	if a == Kind.STRUCT:
		p.offset = _sext30(lo >> 2)
		p.data_words = hi & 0xffff
		p.ptr_words = (hi >> 16) & 0xffff
	elif a == Kind.LIST:
		p.offset = _sext30(lo >> 2)
		p.elem_size_code = hi & 0x7
		p.elem_count = (hi >> 3) & _MASK_29
	elif a == Kind.FAR:
		p.far_two_word = ((lo >> 2) & 0x1) != 0
		p.offset = (lo >> 3) & _MASK_29
		p.far_segment_id = hi
	else: # Kind.OTHER — capability iff subkind (bits 2-31 of lo) is zero
		var subkind: int = (lo >> 2) & _MASK_30
		p.cap_is_valid = subkind == 0
		p.cap_index = hi

# --- encode (each returns a fresh 8-byte word) ---------------------------


static func encode_null() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(8)
	return out


static func encode_struct(offset_words: int, data_words: int, ptr_words: int) -> PackedByteArray:
	var lo: int = Kind.STRUCT | ((offset_words & _MASK_30) << 2)
	var hi: int = (data_words & 0xffff) | ((ptr_words & 0xffff) << 16)
	return _word(lo, hi)


## Zero-sized struct: A=C=D=0, B=-1 (encoding.md :141). NOT the null word.
static func encode_zero_size_struct() -> PackedByteArray:
	return encode_struct(-1, 0, 0)


static func encode_list(offset_words: int, elem_size_code: ElemSize, count_or_words: int) -> PackedByteArray:
	var lo: int = Kind.LIST | ((offset_words & _MASK_30) << 2)
	var hi: int = (elem_size_code & 0x7) | ((count_or_words & _MASK_29) << 3)
	return _word(lo, hi)


static func encode_far(landing_pad_word: int, two_word: bool, segment_id: int) -> PackedByteArray:
	var b: int = 1 if two_word else 0
	var lo: int = Kind.FAR | (b << 2) | ((landing_pad_word & _MASK_29) << 3)
	var hi: int = segment_id & 0xFFFFFFFF
	return _word(lo, hi)


static func encode_cap(index: int) -> PackedByteArray:
	# A=3, B=0, C=index.
	return _word(Kind.OTHER, index & 0xFFFFFFFF)

# --- helpers -------------------------------------------------------------


## Composite-list tag word: struct-pointer-shaped, but the offset field carries
## the element count instead of a word offset (encoding.md :189-194).
static func encode_composite_tag(elem_count: int, data_words: int, ptr_words: int) -> PackedByteArray:
	var lo: int = Kind.STRUCT | ((elem_count & _MASK_30) << 2)
	var hi: int = (data_words & 0xffff) | ((ptr_words & 0xffff) << 16)
	return _word(lo, hi)


## Element stride in bytes for non-composite, non-bit codes. Bit (1) and
## composite (7) are handled by the list reader/builder, not here; they return
## 0 and -1 respectively as sentinels.
static func elem_size_bytes(code: ElemSize) -> int:
	if code == ElemSize.VOID:
		return 0
	if code == ElemSize.BIT:
		return 0 # sub-byte; caller handles bit packing
	if code == ElemSize.BYTE:
		return 1
	if code == ElemSize.TWO_BYTES:
		return 2
	if code == ElemSize.FOUR_BYTES:
		return 4
	if code == ElemSize.EIGHT_BYTES:
		return 8
	if code == ElemSize.POINTER:
		return 8
	return -1 # ElemSize.COMPOSITE


static func is_capability(p: CapnPointer) -> bool:
	return (not p.is_null) and p.kind == Kind.OTHER and p.cap_is_valid


static func _sext30(v: int) -> int:
	var masked: int = v & _MASK_30
	if masked >= _SIGN_30:
		return masked - _SPAN_30
	return masked


static func _word(lo: int, hi: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(8)
	out.encode_u32(0, lo & 0xFFFFFFFF)
	out.encode_u32(4, hi & 0xFFFFFFFF)
	return out
