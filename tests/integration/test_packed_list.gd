extends GutTest

## Bulk primitive-list codec: ListBuilder.set_<kind>_array writes the wire, and
## ListReader.to_<kind>_array reads it back in one slice + reinterpret. Exercised
## at the runtime layer (a struct with one primitive list at ptr 0) so every
## fixed-width packed type is covered, not just the Int32 the goldens reach.


func _read_list(bb: CapnBuilder.StructBuilder) -> CapnReader.ListReader:
	# bb is the root builder; serialize and re-open to read the list at ptr 0.
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false)
	return msg.get_root().get_list(0)


func test_float32_round_trips() -> void:
	var b: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = b.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 4)
	lb.set_float32_array(PackedFloat32Array([0.0, -1.5, 3.25, 1000.0]))
	var got: PackedFloat32Array = _read_list(b).to_float32_array()
	assert_eq(got, PackedFloat32Array([0.0, -1.5, 3.25, 1000.0]), "float32 bulk round-trip")


func test_float64_round_trips() -> void:
	var b: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = b.init_list(0, CapnPointer.ElemSize.EIGHT_BYTES, 3)
	lb.set_float64_array(PackedFloat64Array([0.0, -2.5, 1e9]))
	var got: PackedFloat64Array = _read_list(b).to_float64_array()
	assert_eq(got, PackedFloat64Array([0.0, -2.5, 1e9]), "float64 bulk round-trip")


func test_int32_round_trips_with_negatives() -> void:
	var b: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = b.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 4)
	lb.set_int32_array(PackedInt32Array([0, -20, 2147483647, -2147483648]))
	var got: PackedInt32Array = _read_list(b).to_int32_array()
	assert_eq(got, PackedInt32Array([0, -20, 2147483647, -2147483648]), "int32 bulk round-trip")


func test_int64_round_trips_with_negatives() -> void:
	var b: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = b.init_list(0, CapnPointer.ElemSize.EIGHT_BYTES, 3)
	lb.set_int64_array(PackedInt64Array([0, -1234567890123, 9223372036854775807]))
	var got: PackedInt64Array = _read_list(b).to_int64_array()
	assert_eq(got, PackedInt64Array([0, -1234567890123, 9223372036854775807]), "int64 bulk round-trip")


func test_uint8_round_trips() -> void:
	var b: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = b.init_list(0, CapnPointer.ElemSize.BYTE, 5)
	lb.set_byte_array(PackedByteArray([0, 1, 127, 200, 255]))
	var got: PackedByteArray = _read_list(b).to_byte_array()
	assert_eq(got, PackedByteArray([0, 1, 127, 200, 255]), "uint8 bulk round-trip")


func test_empty_list_decodes_empty() -> void:
	var b: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	b.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 0)
	assert_eq(_read_list(b).to_float32_array().size(), 0, "empty list -> empty packed array")
