extends GutTest

## Builder -> bytes -> reader round-trips. Proves the encoder produces wire the
## decoder reads back identically, across primitives, text/data, nesting, every
## list shape, the struct-upgrade rule, packed output, and forced multi-segment
## (double-far) output.


func test_primitives_roundtrip() -> void:
	# data_words=2 (16 bytes), ptr_words=1.
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(2, 1)
	root.set_bool(0, true)            # bit 0 of byte 0
	root.set_u8(1, 250)
	root.set_u16(2, 60000)
	root.set_i32(4, -12345678)
	root.set_f64(8, 1234.5)           # bytes 8-15
	root.set_text(0, "hello")

	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(root), false)
	var r: CapnReader.StructReader = msg.get_root()
	assert_true(r.get_bool(0, false), "bool")
	assert_eq(r.get_u8(1, 0), 250, "u8")
	assert_eq(r.get_u16(2, 0), 60000, "u16")
	assert_eq(r.get_i32(4, 0), -12345678, "i32")
	assert_almost_eq(r.get_f64(8, 0), 1234.5, 0.0001, "f64")
	assert_eq(r.get_text(0), "hello", "text")


func test_default_xor_roundtrip() -> void:
	# A field set to its own default must encode to wire zeros.
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(1, 0)
	root.set_u16(0, 7, 7)             # value == default -> wire 0
	root.set_u16(2, 100, 7)           # value 100, default 7 -> wire 100^7

	var bytes: PackedByteArray = CapnBuilder.to_bytes(root)
	var r: CapnReader.StructReader = CapnReader.open(bytes, false).get_root()
	assert_eq(r.get_u16(0, 7), 7, "default field reads back as default")
	assert_eq(r.get_u16(2, 7), 100, "non-default field round-trips")
	# The data word must be non-zero only in the second field's bytes.
	assert_eq(r.get_u16(0, 0), 0, "field set to default encodes wire 0")


func test_nested_struct_roundtrip() -> void:
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var child: CapnBuilder.StructBuilder = root.init_struct(0, 1, 1)
	child.set_u32(0, 0xCAFE)
	child.set_text(0, "child")

	var r: CapnReader.StructReader = CapnReader.open(CapnBuilder.to_bytes(root), false).get_root()
	var cr: CapnReader.StructReader = r.get_struct(0)
	assert_eq(cr.get_u32(0, 0), 0xCAFE, "nested u32")
	assert_eq(cr.get_text(0), "child", "nested text")


func test_primitive_list_roundtrip() -> void:
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = root.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 4)
	lb.set_i32(0, 10)
	lb.set_i32(1, -20)
	lb.set_i32(2, 30)
	lb.set_i32(3, -40)

	var r: CapnReader.StructReader = CapnReader.open(CapnBuilder.to_bytes(root), false).get_root()
	var lr: CapnReader.ListReader = r.get_list(0)
	assert_eq(lr.size(), 4)
	assert_eq(lr.get_i32(0), 10)
	assert_eq(lr.get_i32(1), -20)
	assert_eq(lr.get_i32(2), 30)
	assert_eq(lr.get_i32(3), -40)


func test_composite_list_roundtrip() -> void:
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = root.init_composite_list(0, 3, 1, 1)  # 3 structs, dw=1 pw=1
	for i: int in 3:
		var e: CapnBuilder.StructBuilder = lb.init_struct(i)
		e.set_u32(0, 100 + i)
		e.set_text(0, "elem%d" % i)

	var r: CapnReader.StructReader = CapnReader.open(CapnBuilder.to_bytes(root), false).get_root()
	var lr: CapnReader.ListReader = r.get_list(0)
	assert_eq(lr.size(), 3, "composite list size")
	for i: int in 3:
		var er: CapnReader.StructReader = lr.get_struct(i)
		assert_eq(er.get_u32(0, 0), 100 + i, "composite elem %d u32" % i)
		assert_eq(er.get_text(0), "elem%d" % i, "composite elem %d text" % i)


func test_struct_upgrade_rule() -> void:
	# Build a List(UInt32) (element code 4), read it back as a struct list:
	# each element projects as a 4-byte data-section struct (encoding.md :204-215).
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = root.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 3)
	lb.set_u32(0, 11)
	lb.set_u32(1, 22)
	lb.set_u32(2, 33)

	var r: CapnReader.StructReader = CapnReader.open(CapnBuilder.to_bytes(root), false).get_root()
	var lr: CapnReader.ListReader = r.get_list(0)
	# Read each primitive element as a struct: field at data offset 0.
	assert_eq(lr.get_struct(0).get_u32(0, 0), 11, "upgraded elem 0")
	assert_eq(lr.get_struct(1).get_u32(0, 0), 22, "upgraded elem 1")
	assert_eq(lr.get_struct(2).get_u32(0, 0), 33, "upgraded elem 2")


func test_data_field_roundtrip() -> void:
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var payload: PackedByteArray = PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x42])
	root.set_data(0, payload)

	var r: CapnReader.StructReader = CapnReader.open(CapnBuilder.to_bytes(root), false).get_root()
	assert_eq(r.get_data(0), payload, "data round-trips incl embedded NUL")


func test_packed_roundtrip() -> void:
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(2, 1)
	root.set_u32(0, 0x11223344)
	root.set_text(0, "packed payload with some length")

	var packed: PackedByteArray = CapnBuilder.to_bytes(root, true)
	var r: CapnReader.StructReader = CapnReader.open(packed, true).get_root()
	assert_eq(r.get_u32(0, 0), 0x11223344, "packed u32")
	assert_eq(r.get_text(0), "packed payload with some length", "packed text")


func test_multi_segment_double_far_roundtrip() -> void:
	# cap_words=4 forces objects past segment 0 -> cross-segment pointers emit
	# double-far landing pads. Exercises the builder's far path + reader's
	# double-far resolution together.
	var root: CapnBuilder.StructBuilder = CapnBuilder.new_message(1, 2, 4)
	root.set_u32(0, 0xABCDEF)
	root.set_text(0, "far away")
	var child: CapnBuilder.StructBuilder = root.init_struct(1, 1, 0)
	child.set_u32(0, 999)

	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(root), false)
	assert_gt(msg.segments.segment_count(), 1, "spilled into multiple segments")
	var r: CapnReader.StructReader = msg.get_root()
	assert_eq(r.get_u32(0, 0), 0xABCDEF, "root u32 across segments")
	assert_eq(r.get_text(0), "far away", "text via double-far")
	assert_eq(r.get_struct(1).get_u32(0, 0), 999, "nested struct via double-far")
