class_name CapnWireWords
extends RefCounted
## Little-endian byte <-> integer/float helpers over PackedByteArray.
##
## Cap'n Proto is little-endian (encoding.md §"...little-endian"). Godot 4's
## PackedByteArray.decode_*/encode_* are little-endian, so these are thin typed
## wrappers that also centralise the one sign trap that matters: a UInt64 whose
## top bit is set decodes to a negative GDScript int (GDScript int is i64). The
## pointer codec never calls read_u64 for bit extraction — it reads two u32
## halves via read_u32 (see CapnPointer). read_u64 here is only for opaque
## 8-byte value loads where the bit pattern, not the magnitude, is what matters.
##
## All functions are pure: no caller state mutated except the explicit out_buf
## in the write_* helpers (side effect surfaced at call site, NASA rule 8).

const WORD_BYTES: int = 8

# --- reads ---------------------------------------------------------------


static func read_u8(buf: PackedByteArray, off: int) -> int:
	return buf.decode_u8(off)


static func read_u16(buf: PackedByteArray, off: int) -> int:
	return buf.decode_u16(off)


static func read_u32(buf: PackedByteArray, off: int) -> int:
	return buf.decode_u32(off)


static func read_u64(buf: PackedByteArray, off: int) -> int:
	# Bit pattern; negative when the top bit is set. See class note.
	return buf.decode_u64(off)


static func read_i8(buf: PackedByteArray, off: int) -> int:
	return buf.decode_s8(off)


static func read_i16(buf: PackedByteArray, off: int) -> int:
	return buf.decode_s16(off)


static func read_i32(buf: PackedByteArray, off: int) -> int:
	return buf.decode_s32(off)


static func read_i64(buf: PackedByteArray, off: int) -> int:
	return buf.decode_s64(off)


static func read_f32(buf: PackedByteArray, off: int) -> float:
	return buf.decode_float(off)


static func read_f64(buf: PackedByteArray, off: int) -> float:
	return buf.decode_double(off)

# --- writes (mutate out_buf in place) ------------------------------------


static func write_u8(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_u8(off, value)


static func write_u16(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_u16(off, value)


static func write_u32(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_u32(off, value)


static func write_u64(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_u64(off, value)


static func write_i8(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_s8(off, value)


static func write_i16(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_s16(off, value)


static func write_i32(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_s32(off, value)


static func write_i64(out_buf: PackedByteArray, off: int, value: int) -> void:
	out_buf.encode_s64(off, value)


static func write_f32(out_buf: PackedByteArray, off: int, value: float) -> void:
	out_buf.encode_float(off, value)


static func write_f64(out_buf: PackedByteArray, off: int, value: float) -> void:
	out_buf.encode_double(off, value)

# --- bits (bool fields + List(Bool), LSB-first per encoding.md :60/:186) --


static func read_bit(buf: PackedByteArray, byte_off: int, bit_in_byte: int) -> bool:
	var b: int = buf.decode_u8(byte_off)
	return (b & (1 << bit_in_byte)) != 0


static func write_bit(out_buf: PackedByteArray, byte_off: int, bit_in_byte: int, value: bool) -> void:
	var b: int = out_buf.decode_u8(byte_off)
	var mask: int = 1 << bit_in_byte
	if value:
		b = b | mask
	else:
		b = b & (~mask & 0xff)
	out_buf.encode_u8(byte_off, b)

# --- misc ----------------------------------------------------------------


## Per-byte XOR of two equal-length buffers. Used for default-value masking
## (encoding.md :122-137). On length mismatch: push_error + empty result.
static func xor_bytes(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	if a.size() != b.size():
		push_error("CapnWireWords.xor_bytes: length mismatch %d vs %d" % [a.size(), b.size()])
		return PackedByteArray()
	var out: PackedByteArray = PackedByteArray()
	out.resize(a.size())
	var n: int = a.size()
	for i: int in n:
		out[i] = a[i] ^ b[i]
	return out


static func is_word_aligned(byte_off: int) -> bool:
	return (byte_off & 7) == 0


static func words_to_bytes(words: int) -> int:
	return words * WORD_BYTES


static func bytes_to_words(byte_count: int) -> int:
	# Round up to whole words.
	@warning_ignore("integer_division")
	return (byte_count + WORD_BYTES - 1) / WORD_BYTES
