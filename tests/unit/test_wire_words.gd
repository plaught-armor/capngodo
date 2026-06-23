extends GutTest
## CapnWireWords — little-endian primitives, bit ops, XOR masking.

func test_u32_roundtrip() -> void:
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(8)
	CapnWireWords.write_u32(buf, 0, 0x12345678)
	assert_eq(CapnWireWords.read_u32(buf, 0), 0x12345678)
	# Little-endian byte order.
	assert_eq(buf[0], 0x78)
	assert_eq(buf[3], 0x12)


func test_bit_set_clear() -> void:
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(1)
	CapnWireWords.write_bit(buf, 0, 3, true)
	assert_eq(buf[0], 0x08)
	assert_true(CapnWireWords.read_bit(buf, 0, 3))
	assert_false(CapnWireWords.read_bit(buf, 0, 2))
	CapnWireWords.write_bit(buf, 0, 3, false)
	assert_eq(buf[0], 0x00)


func test_xor_bytes_masks_default() -> void:
	var value: PackedByteArray = PackedByteArray([0xff, 0x0f, 0xaa, 0x00])
	var default_mask: PackedByteArray = PackedByteArray([0x0f, 0x0f, 0xff, 0x00])
	# value XOR default; XOR again restores value (default-XOR is involutive).
	var masked: PackedByteArray = CapnWireWords.xor_bytes(value, default_mask)
	assert_eq(masked, PackedByteArray([0xf0, 0x00, 0x55, 0x00]))
	assert_eq(CapnWireWords.xor_bytes(masked, default_mask), value)


func test_word_helpers() -> void:
	assert_true(CapnWireWords.is_word_aligned(0))
	assert_true(CapnWireWords.is_word_aligned(16))
	assert_false(CapnWireWords.is_word_aligned(4))
	assert_eq(CapnWireWords.words_to_bytes(3), 24)
	assert_eq(CapnWireWords.bytes_to_words(9), 2)
	assert_eq(CapnWireWords.bytes_to_words(8), 1)
	assert_eq(CapnWireWords.bytes_to_words(0), 0)
