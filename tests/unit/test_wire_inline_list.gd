extends GutTest
## Parity for the inlined StructReader.get_list fast path: composite, primitive,
## empty, null/absent, and traversal-limit cases must match the layered
## ListReader.from_target semantics.

func _root(bb: CapnBuilder.StructBuilder) -> CapnReader.StructReader:
	return CapnReader.open(CapnBuilder.to_bytes(bb, false), false).get_root()


func test_primitive_int32_list() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = bb.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 3)
	lb.set_i32(0, 10)
	lb.set_i32(1, -20)
	lb.set_i32(2, 30)
	var lr: CapnReader.ListReader = _root(bb).get_list(0)
	assert_eq(lr.size(), 3, "count")
	assert_eq(lr.get_i32(0), 10)
	assert_eq(lr.get_i32(1), -20)
	assert_eq(lr.get_i32(2), 30)


func test_composite_struct_list() -> void:
	# 2 structs, each 1 data word; store an int per element.
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = bb.init_composite_list(0, 2, 1, 0)
	lb.init_struct(0).set_u32(0, 111, 0)
	lb.init_struct(1).set_u32(0, 222, 0)
	var lr: CapnReader.ListReader = _root(bb).get_list(0)
	assert_eq(lr.size(), 2, "composite count from tag")
	assert_eq(lr.get_struct(0).get_u32(0, 0), 111)
	assert_eq(lr.get_struct(1).get_u32(0, 0), 222)


func test_empty_list() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	bb.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 0)
	var lr: CapnReader.ListReader = _root(bb).get_list(0)
	assert_eq(lr.size(), 0, "empty list count")


func test_absent_pointer_returns_empty() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lr: CapnReader.ListReader = _root(bb).get_list(0)
	assert_eq(lr.size(), 0, "null pointer -> empty list")


func test_out_of_range_index_returns_empty() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lr: CapnReader.ListReader = _root(bb).get_list(7)
	assert_eq(lr.size(), 0)


func test_byte_list() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = bb.init_list(0, CapnPointer.ElemSize.BYTE, 4)
	lb.set_u8(0, 1)
	lb.set_u8(1, 2)
	lb.set_u8(2, 3)
	lb.set_u8(3, 255)
	var lr: CapnReader.ListReader = _root(bb).get_list(0)
	assert_eq(lr.size(), 4)
	assert_eq(lr.get_u8(3), 255)


func test_traversal_limit_trips_on_fast_path() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	bb.init_list(0, CapnPointer.ElemSize.EIGHT_BYTES, 16) # 16 words of body
	var limits: CapnLimits = CapnLimits.new(1, 64)
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false, limits)
	var lr: CapnReader.ListReader = msg.get_root().get_list(0)
	assert_eq(lr.size(), 0, "over-budget list read returns empty")
	assert_true(msg.had_error, "traversal limit sets had_error")
