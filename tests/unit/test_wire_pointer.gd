extends GutTest

## CapnPointer codec — encode/decode round-trips + the hand-verifiable bit
## patterns from encoding.md (:307 struct ptr, :310 text ptr, :141 zero-size).


func _hex(s: String) -> PackedByteArray:
	return PackedByteArray(s.hex_decode())


func test_struct_pointer_example() -> void:
	# encoding.md :307 — struct pointer offset=2, data=3, ptr=2.
	var expected: PackedByteArray = _hex("0800000003000200")
	assert_eq(CapnPointer.encode_struct(2, 3, 2), expected, "struct ptr bytes")
	var p: CapnPointer = CapnPointer.decode_at(expected, 0)
	assert_eq(p.kind, CapnPointer.Kind.STRUCT)
	assert_eq(p.offset, 2)
	assert_eq(p.data_words, 3)
	assert_eq(p.ptr_words, 2)


func test_list_pointer_example() -> void:
	# encoding.md :310 — list/text pointer offset=6, byte elements, len=53.
	var expected: PackedByteArray = _hex("19000000aa010000")
	assert_eq(CapnPointer.encode_list(6, CapnPointer.ElemSize.BYTE, 53), expected, "list ptr bytes")
	var p: CapnPointer = CapnPointer.decode_at(expected, 0)
	assert_eq(p.kind, CapnPointer.Kind.LIST)
	assert_eq(p.offset, 6)
	assert_eq(p.elem_size_code, CapnPointer.ElemSize.BYTE)
	assert_eq(p.elem_count, 53)


func test_zero_size_struct_sentinel() -> void:
	# encoding.md :141 — offset -1, sizes 0. Bytes FC FF FF FF 00 00 00 00.
	var expected: PackedByteArray = _hex("fcffffff00000000")
	assert_eq(CapnPointer.encode_zero_size_struct(), expected)
	var p: CapnPointer = CapnPointer.decode_at(expected, 0)
	assert_false(p.is_null, "zero-size struct is not null")
	assert_eq(p.offset, -1)
	assert_eq(p.data_words, 0)
	assert_eq(p.ptr_words, 0)


func test_null_word() -> void:
	var p: CapnPointer = CapnPointer.decode(0, 0)
	assert_true(p.is_null)


func test_negative_offset_roundtrip() -> void:
	var word: PackedByteArray = CapnPointer.encode_struct(-5, 1, 1)
	var p: CapnPointer = CapnPointer.decode_at(word, 0)
	assert_eq(p.offset, -5)
	assert_eq(p.data_words, 1)
	assert_eq(p.ptr_words, 1)


func test_far_pointer_roundtrip() -> void:
	for two_word: bool in [false, true]:
		for seg: int in [0, 1, 0xdeadbeef]:
			var word: PackedByteArray = CapnPointer.encode_far(123, two_word, seg)
			var p: CapnPointer = CapnPointer.decode_at(word, 0)
			assert_eq(p.kind, CapnPointer.Kind.FAR)
			assert_eq(p.far_two_word, two_word)
			assert_eq(p.offset, 123)
			assert_eq(p.far_segment_id, seg)


func test_capability_pointer() -> void:
	var word: PackedByteArray = CapnPointer.encode_cap(7)
	var p: CapnPointer = CapnPointer.decode_at(word, 0)
	assert_eq(p.kind, CapnPointer.Kind.OTHER)
	assert_eq(p.cap_index, 7)
	assert_true(CapnPointer.is_capability(p))


func test_composite_tag_carries_element_count() -> void:
	# encoding.md :189-194 — tag is struct-ptr-shaped, offset field = elem count.
	var tag: PackedByteArray = CapnPointer.encode_composite_tag(10, 2, 1)
	var p: CapnPointer = CapnPointer.decode_at(tag, 0)
	assert_eq(p.kind, CapnPointer.Kind.STRUCT)
	assert_eq(p.offset, 10, "tag offset stores element count")
	assert_eq(p.data_words, 2)
	assert_eq(p.ptr_words, 1)
