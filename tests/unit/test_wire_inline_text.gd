extends GutTest
## Parity for the inlined get_text/get_data fast path (StructReader): the
## fully-inlined byte-list reader must match the layered semantics across
## empty / ascii / multibyte / absent / data / far / traversal-limit cases.

const WORD_BYTES: int = 8


func _round_trip(s: String) -> String:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	bb.set_text(0, s)
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false)
	return msg.get_root().get_text(0, "DEFAULT")


func test_ascii_round_trip() -> void:
	assert_eq(_round_trip("person7@example.com"), "person7@example.com")


func test_empty_string() -> void:
	# Empty Text is a 1-byte list (just the NUL) -> "" via the count>0 path.
	assert_eq(_round_trip(""), "")


func test_multibyte_utf8() -> void:
	assert_eq(_round_trip("naïve 日本語 café"), "naïve 日本語 café")


func test_long_string_spanning_words() -> void:
	var s: String = "x".repeat(500)
	assert_eq(_round_trip(s), s)


func test_absent_pointer_returns_default() -> void:
	# ptr_index in range but the field was never set -> null pointer -> default.
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false)
	assert_eq(msg.get_root().get_text(0, "DEF"), "DEF")


func test_out_of_range_index_returns_default() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false)
	assert_eq(msg.get_root().get_text(5, "DEF"), "DEF")


func test_data_raw_bytes_round_trip() -> void:
	var raw: PackedByteArray = PackedByteArray([0, 1, 2, 255, 0, 7])
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	bb.set_data(0, raw)
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false)
	assert_eq(msg.get_root().get_data(0, PackedByteArray()), raw)


func test_data_preserves_trailing_zero() -> void:
	# Data must NOT drop a trailing zero the way Text drops its NUL.
	var raw: PackedByteArray = PackedByteArray([9, 9, 0])
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	bb.set_data(0, raw)
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false)
	assert_eq(msg.get_root().get_data(0, PackedByteArray()), raw)


func test_traversal_limit_trips_on_fast_path() -> void:
	# A tiny traversal budget must be enforced by the inlined charge, not bypassed.
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	bb.set_text(0, "x".repeat(64))
	var limits: CapnLimits = CapnLimits.new(1, 64) # 1-word traversal budget
	var msg: CapnReader.Message = CapnReader.open(CapnBuilder.to_bytes(bb, false), false, limits)
	var got: String = msg.get_root().get_text(0, "DEF")
	assert_eq(got, "DEF", "over-budget read returns default")
	assert_true(msg.had_error, "traversal limit sets had_error")
