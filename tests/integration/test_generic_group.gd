extends GutTest

## CG1d — a generic parameter slot nested inside a *group* of the generic body.
## The CG1b/CG1c monomorphizer resolved only top-level param slots; a param inside
## a named group or a union group of the generic body emitted erased AnyPointer
## accessors. The bound type is now threaded through the group emitters to each
## leaf, so the mono resolves the nested param to its concrete type:
##   Box(Text)    -> get_holder_value() -> String          (named-group param)
##   Tagged(Text) -> get_body_item()   -> String           (union-group param arm)
## Uses the generated GenericGroupCapnp.


func test_named_group_param_resolves_to_concrete_type() -> void:
	var u: GenericGroupCapnp.Use.Builder = GenericGroupCapnp.new_use()
	var box: GenericGroupCapnp.Box_Text.Builder = u.init_box_text()
	box.set_holder_value("payload")   # typed String setter (was erased AnyPointer)
	box.set_holder_label("tag")

	var r: GenericGroupCapnp.Use.Reader = GenericGroupCapnp.read_use(u.to_bytes())
	var rbox: GenericGroupCapnp.Box_Text.Reader = r.get_box_text()
	# Typed local: a String getter assigns directly; an erased getter would not.
	var v: String = rbox.get_holder_value()
	assert_eq(v, "payload", "named-group param resolved to String")
	assert_eq(rbox.get_holder_label(), "tag", "sibling normal field still works")


func test_union_group_param_arm_resolves_to_concrete_type() -> void:
	var u: GenericGroupCapnp.Use.Builder = GenericGroupCapnp.new_use()
	var tag: GenericGroupCapnp.Tagged_Text.Builder = u.init_tagged_text()
	tag.set_body_item("chosen")       # union param arm, typed String setter

	var r: GenericGroupCapnp.Use.Reader = GenericGroupCapnp.read_use(u.to_bytes())
	var rtag: GenericGroupCapnp.Tagged_Text.Reader = r.get_tagged_text()
	assert_true(rtag.is_body_item(), "union selects the param arm")
	var v: String = rtag.get_body_item()
	assert_eq(v, "chosen", "union-group param arm resolved to String")


func test_union_group_normal_arm_still_works() -> void:
	var u: GenericGroupCapnp.Use.Builder = GenericGroupCapnp.new_use()
	var tag: GenericGroupCapnp.Tagged_Text.Builder = u.init_tagged_text()
	tag.set_body_count(42)

	var r: GenericGroupCapnp.Use.Reader = GenericGroupCapnp.read_use(u.to_bytes())
	var rtag: GenericGroupCapnp.Tagged_Text.Reader = r.get_tagged_text()
	assert_true(rtag.is_body_count(), "union selects the count arm")
	assert_eq(rtag.get_body_count(), 42, "non-param union arm unaffected")


func test_erased_generic_floor_keeps_anypointer_accessors() -> void:
	# The unbound generic (CG1a floor) still exposes the erased AnyPointer accessors
	# for the nested param — the mono adds the typed layer, it does not replace the
	# floor.
	var box: GenericGroupCapnp.Box.Builder = GenericGroupCapnp.new_box()
	box.set_holder_value_text("erased")
	var r: GenericGroupCapnp.Box.Reader = GenericGroupCapnp.read_box(box.to_bytes())
	assert_eq(r.get_holder_value_text(), "erased", "erased floor round-trips via AnyPointer text accessor")


func test_generic_typed_slot_nested_in_group_registers_mono() -> void:
	# The dual of the param-in-group case: a Box(Text)-typed slot nested inside a
	# group. The instantiation collector recurses into group fields, so Box_Text is
	# registered and the leaf resolves to it (not the erased Box floor).
	var h: GenericGroupCapnp.Holder.Builder = GenericGroupCapnp.new_holder()
	var boxed: GenericGroupCapnp.Box_Text.Builder = h.init_inner_boxed()
	boxed.set_holder_value("deep")

	var r: GenericGroupCapnp.Holder.Reader = GenericGroupCapnp.read_holder(h.to_bytes())
	var rboxed: GenericGroupCapnp.Box_Text.Reader = r.get_inner_boxed()
	assert_eq(rboxed.get_holder_value(), "deep", "group-nested generic slot resolved to the typed mono")


func test_codegen_matches_committed_golden() -> void:
	var f: FileAccess = FileAccess.open("res://tests/fixtures/generic_group.cgr.bin", FileAccess.READ)
	assert_not_null(f, "fixture present")
	if f == null:
		return
	var cgr: CapnReader.StructReader = CapnSchema.open_request(f.get_buffer(f.get_length()))
	f.close()
	var files: Dictionary = CapnCodegen.generate_files(cgr)
	assert_true(files.has("generic_group.capnp.gd"), "generated the umbrella file")

	var g: FileAccess = FileAccess.open("res://tests/generated/generic_group.capnp.gd", FileAccess.READ)
	assert_not_null(g, "committed golden present")
	if g == null:
		return
	var committed: String = g.get_as_text()
	g.close()
	assert_eq(files["generic_group.capnp.gd"], committed, "generator output matches committed golden")
