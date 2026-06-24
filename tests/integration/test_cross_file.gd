extends GutTest
## Cross-file type references (CG7): a field of an imported type resolves to the
## imported file's generated umbrella class. ShapesCapnp.Line.start is a
## Common.Point -> CommonCapnp.Point. Uses the generated ShapesCapnp +
## CommonCapnp (from tests/golden/shapes.capnp + common.capnp).

func test_imported_struct_field_round_trips() -> void:
	var line: ShapesCapnp.Line.Builder = ShapesCapnp.new_line()
	var start: CommonCapnp.Point.Builder = line.init_start()
	start.set_x(1)
	start.set_y(2)
	var end_pt: CommonCapnp.Point.Builder = line.init_end()
	end_pt.set_x(3)
	end_pt.set_y(4)
	line.set_label("seg")

	var r: ShapesCapnp.Line.Reader = ShapesCapnp.read_line(line.to_bytes())
	var rs: CommonCapnp.Point.Reader = r.get_start()
	assert_eq(rs.get_x(), 1, "imported start.x")
	assert_eq(rs.get_y(), 2, "imported start.y")
	var re: CommonCapnp.Point.Reader = r.get_end()
	assert_eq(re.get_x(), 3, "imported end.x")
	assert_eq(re.get_y(), 4, "imported end.y")
	assert_eq(r.get_label(), "seg", "own field intact")


func test_single_file_request_optimistically_resolves_import() -> void:
	# Generating shapes ALONE (common imported, not requested) must still resolve
	# Common.Point -> CommonCapnp.Point on both reader and builder — optimistic
	# cross-file resolution. Emits a push_warning (file not in request) by design.
	var cgr: CapnReader.StructReader = CapnSchema.open_request(
		FileAccess.get_file_as_bytes("res://tests/fixtures/shapes.cgr.bin"),
	)
	var files: Dictionary = CapnCodegen.generate_files(cgr)
	var src: String = ""
	for k: String in files:
		if k.ends_with("shapes.capnp.gd"):
			src = files[k]
	assert_false(src.is_empty(), "generated shapes file")
	assert_true("func get_start() -> CommonCapnp.Point.Reader:" in src, "reader field resolves import")
	assert_true("func init_start() -> CommonCapnp.Point.Builder:" in src, "builder field resolves import")
	assert_false("TODO(M6)" in src, "no unresolved cross-file stub")
