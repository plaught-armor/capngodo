extends GutTest
## CG10b — List(AnyPointer). capnp admits an erased pointer-element list only via
## List(AnyList) (a literal List(AnyPointer) or List(T) of a generic parameter is
## compiler-rejected). The element type is erased, so the generated reader returns
## the raw outer CapnReader.ListReader and the builder returns the raw
## CapnBuilder.ListBuilder. The caller materializes each element with the
## per-element accessors. Here the outer list holds two *different* inner-list
## kinds (an Int32 list and a Text list) to exercise the erased element flexibility.
## Uses the generated AnylistCapnp.

func test_anylist_heterogeneous_inner_lists_round_trip() -> void:
	var bag: AnylistCapnp.Bag.Builder = AnylistCapnp.new_bag()
	var rows: CapnBuilder.ListBuilder = bag.init_rows(2)

	# row 0: a primitive (Int32) inner list.
	var nums: CapnBuilder.ListBuilder = rows.init_list_at(0, CapnPointer.ElemSize.FOUR_BYTES, 3)
	nums.set_i32(0, 11)
	nums.set_i32(1, 22)
	nums.set_i32(2, 33)
	# row 1: a pointer (Text) inner list — a different element kind in the same
	# erased outer list.
	var words: CapnBuilder.ListBuilder = rows.init_list_at(1, CapnPointer.ElemSize.POINTER, 2)
	words.set_text(0, "alpha")
	words.set_text(1, "beta")

	var r: AnylistCapnp.Bag.Reader = AnylistCapnp.read_bag(bag.to_bytes())
	var rrows: CapnReader.ListReader = r.get_rows()
	assert_eq(rrows.size(), 2, "outer rows length")

	var rnums: CapnReader.ListReader = rrows.get_list(0)
	assert_eq(rnums.size(), 3, "row 0 length")
	assert_eq(rnums.get_i32(0), 11, "rows[0][0]")
	assert_eq(rnums.get_i32(2), 33, "rows[0][2]")

	var rwords: CapnReader.ListReader = rrows.get_list(1)
	assert_eq(rwords.size(), 2, "row 1 length")
	assert_eq(rwords.get_text(0), "alpha", "rows[1][0]")
	assert_eq(rwords.get_text(1), "beta", "rows[1][1]")


func test_anylist_empty_list_round_trips() -> void:
	var bag: AnylistCapnp.Bag.Builder = AnylistCapnp.new_bag()
	bag.init_rows(0)
	var r: AnylistCapnp.Bag.Reader = AnylistCapnp.read_bag(bag.to_bytes())
	assert_eq(r.get_rows().size(), 0, "empty outer list")


func test_anylist_outer_is_a_pointer_list_on_the_wire() -> void:
	# The erased outer list must be encoded as a pointer-element list (each element
	# a list pointer), cross-checked through the runtime reader directly.
	var bag: AnylistCapnp.Bag.Builder = AnylistCapnp.new_bag()
	var rows: CapnBuilder.ListBuilder = bag.init_rows(1)
	rows.init_list_at(0, CapnPointer.ElemSize.FOUR_BYTES, 1).set_i32(0, 7)

	var msg: CapnReader.Message = CapnReader.open(bag.to_bytes(), false)
	var root: CapnReader.StructReader = msg.get_root()
	var outer: CapnReader.ListReader = root.get_list(0)
	assert_eq(outer.size(), 1, "raw reader sees the outer list")
	assert_eq(outer.get_list(0).get_i32(0), 7, "raw reader follows the element list pointer")


func test_codegen_matches_committed_golden() -> void:
	# Generator output for the List(AnyList) schema must equal the committed
	# reader, or the CG10b emission drifted.
	var f: FileAccess = FileAccess.open("res://tests/fixtures/anylist.cgr.bin", FileAccess.READ)
	assert_not_null(f, "fixture present")
	if f == null:
		return
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var cgr: CapnReader.StructReader = CapnSchema.open_request(bytes)
	var files: Dictionary = CapnCodegen.generate_files(cgr)
	assert_true(files.has("anylist.capnp.gd"), "generated the umbrella file")

	var g: FileAccess = FileAccess.open("res://tests/generated/anylist.capnp.gd", FileAccess.READ)
	assert_not_null(g, "committed golden present")
	if g == null:
		return
	var committed: String = g.get_as_text()
	g.close()
	assert_eq(files["anylist.capnp.gd"], committed, "generator output matches committed golden")
