extends GutTest
## End-to-end reader test against the canonical TestAllTypes message, encoded
## four ways by the real capnp toolchain. The same logical message appears as:
##   binary           — framed, single segment
##   packed           — framed + packed
##   flat             — one bare segment, no framing
##   segmented        — split across 125 segments (exercises far pointers)
## All four must decode to identical field values via one shared assertion
## helper. Offsets were mapped from the fixture; values come from capnp's
## test-util.c++ initTestMessage().

# TestAllTypes data-section byte offsets (mapped from testdata/binary).
const OFF_INT8: int = 1
const OFF_INT16: int = 2
const OFF_INT32: int = 4
const OFF_INT64: int = 8
const OFF_UINT8: int = 16
const OFF_UINT16: int = 18
const OFF_UINT32: int = 20
const OFF_UINT64: int = 24
const OFF_FLOAT32: int = 32
const OFF_ENUM: int = 36
const OFF_FLOAT64: int = 40

# Pointer-section field indices.
const P_TEXT: int = 0
const P_DATA: int = 1
const P_STRUCT: int = 2
const P_VOID_LIST: int = 3
const P_BOOL_LIST: int = 4
const P_INT8_LIST: int = 5
const P_INT32_LIST: int = 7
const P_UINT32_LIST: int = 11
const P_FLOAT64_LIST: int = 14
const P_TEXT_LIST: int = 15
const P_STRUCT_LIST: int = 17
const P_ENUM_LIST: int = 18


func _read_fixture(name: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open("res://tests/fixtures/testdata/%s" % name, FileAccess.READ)
	assert_not_null(f, "fixture %s present" % name)
	if f == null:
		return PackedByteArray()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return bytes


func test_binary_fixture() -> void:
	var msg: CapnReader.Message = CapnReader.open(_read_fixture("binary"), false)
	assert_not_null(msg, "binary opened")
	if msg != null:
		_assert_all_types(msg.get_root())


func test_packed_fixture() -> void:
	var msg: CapnReader.Message = CapnReader.open(_read_fixture("packed"), true)
	assert_not_null(msg, "packed opened")
	if msg != null:
		_assert_all_types(msg.get_root())


func test_flat_fixture_no_framing() -> void:
	# flat is one bare segment (351 words), no stream header.
	var blobs: Array[PackedByteArray] = [_read_fixture("flat")]
	var segs: CapnSegments = CapnSegments.new(blobs)
	var msg: CapnReader.Message = CapnReader.from_segments(segs)
	assert_not_null(msg, "flat opened")
	if msg != null:
		_assert_all_types(msg.get_root())


func test_segmented_fixture_far_pointers() -> void:
	var msg: CapnReader.Message = CapnReader.open(_read_fixture("segmented"), false)
	assert_not_null(msg, "segmented opened")
	if msg != null:
		assert_eq(msg.segments.segment_count(), 125, "125 segments")
		_assert_all_types(msg.get_root())

# --- shared assertions ---------------------------------------------------


func _assert_all_types(r: CapnReader.StructReader) -> void:
	# Primitives (default 0 -> XOR no-op).
	assert_true(r.get_bool(0, false), "boolField")
	assert_eq(r.get_i8(OFF_INT8, 0), -123, "int8Field")
	assert_eq(r.get_i16(OFF_INT16, 0), -12345, "int16Field")
	assert_eq(r.get_i32(OFF_INT32, 0), -12345678, "int32Field")
	assert_eq(r.get_i64(OFF_INT64, 0), -123456789012345, "int64Field")
	assert_eq(r.get_u8(OFF_UINT8, 0), 234, "uInt8Field")
	assert_eq(r.get_u16(OFF_UINT16, 0), 45678, "uInt16Field")
	assert_eq(r.get_u32(OFF_UINT32, 0), 3456789012, "uInt32Field")
	# uInt64 12345678901234567890 has bit 63 set -> i64 bit pattern is negative.
	assert_eq(r.get_u64(OFF_UINT64, 0), -6101065172474983726, "uInt64Field bits")
	assert_almost_eq(r.get_f32(OFF_FLOAT32, 0), 1234.5, 0.0001, "float32Field")
	# float64Field == -123e45. GDScript's float parser isn't correctly-rounded
	# for extreme exponents, so comparing against the literal -123e45 picks the
	# neighbouring double. Compare the exact stored bits instead (the reader
	# returns the same double capnp/C++ stored).
	assert_eq(r.get_u64(OFF_FLOAT64, 0), -3912067307603444992, "float64Field bits")
	assert_true(is_equal_approx(r.get_f64(OFF_FLOAT64, 0) / -123e45, 1.0), "float64Field ~= -123e45")
	assert_eq(r.get_u16(OFF_ENUM, 0), 5, "enumField == CORGE(5)")

	# Text + Data.
	assert_eq(r.get_text(P_TEXT), "foo", "textField")
	assert_eq(r.get_data(P_DATA), "bar".to_utf8_buffer(), "dataField")

	# Nested struct chain: baz -> nested -> really nested.
	var sub: CapnReader.StructReader = r.get_struct(P_STRUCT)
	assert_eq(sub.get_text(P_TEXT), "baz", "structField.textField")
	var sub2: CapnReader.StructReader = sub.get_struct(P_STRUCT)
	assert_eq(sub2.get_text(P_TEXT), "nested", "structField.structField.textField")
	var sub3: CapnReader.StructReader = sub2.get_struct(P_STRUCT)
	assert_eq(sub3.get_text(P_TEXT), "really nested", "deep nested textField")

	# Primitive lists.
	assert_eq(r.get_list(P_VOID_LIST).size(), 6, "voidList size")
	var bools: CapnReader.ListReader = r.get_list(P_BOOL_LIST)
	assert_eq(bools.size(), 4, "boolList size")
	assert_true(bools.get_bool(0), "boolList[0]")
	assert_false(bools.get_bool(1), "boolList[1]")
	assert_false(bools.get_bool(2), "boolList[2]")
	assert_true(bools.get_bool(3), "boolList[3]")
	var i8: CapnReader.ListReader = r.get_list(P_INT8_LIST)
	assert_eq(i8.size(), 2)
	assert_eq(i8.get_i8(0), 111)
	assert_eq(i8.get_i8(1), -111)
	var i32: CapnReader.ListReader = r.get_list(P_INT32_LIST)
	assert_eq(i32.get_i32(0), 111111111)
	assert_eq(i32.get_i32(1), -111111111)
	var u32: CapnReader.ListReader = r.get_list(P_UINT32_LIST)
	assert_eq(u32.size(), 1)
	assert_eq(u32.get_u32(0), 3333333333)

	# Float64 list with inf/-inf/nan.
	var f64: CapnReader.ListReader = r.get_list(P_FLOAT64_LIST)
	assert_eq(f64.size(), 4)
	assert_almost_eq(f64.get_f64(0), 7777.75, 0.0001, "float64List[0]")
	assert_eq(f64.get_f64(1), INF, "float64List[1] == inf")
	assert_eq(f64.get_f64(2), -INF, "float64List[2] == -inf")
	assert_true(is_nan(f64.get_f64(3)), "float64List[3] is nan")

	# Text list (List(Text) — pointer elements).
	var texts: CapnReader.ListReader = r.get_list(P_TEXT_LIST)
	assert_eq(texts.size(), 3)
	assert_eq(texts.get_text(0), "plugh")
	assert_eq(texts.get_text(1), "xyzzy")
	assert_eq(texts.get_text(2), "thud")

	# Enum list (2-byte elements): foo(0), garply(7).
	var enums: CapnReader.ListReader = r.get_list(P_ENUM_LIST)
	assert_eq(enums.size(), 2)
	assert_eq(enums.get_u16(0), 0, "enumList[0] foo")
	assert_eq(enums.get_u16(1), 7, "enumList[1] garply")

	# Struct list (composite): 3 elements, each with a textField.
	var structs: CapnReader.ListReader = r.get_list(P_STRUCT_LIST)
	assert_eq(structs.size(), 3, "structList size")
	assert_eq(structs.get_struct(0).get_text(P_TEXT), "structlist 1")
	assert_eq(structs.get_struct(1).get_text(P_TEXT), "structlist 2")
	assert_eq(structs.get_struct(2).get_text(P_TEXT), "structlist 3")
