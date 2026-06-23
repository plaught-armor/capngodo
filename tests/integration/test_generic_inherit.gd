extends GutTest

## CG1d — inherit scopes. A struct nested inside a generic that uses the generic's
## type parameter (`Outer(T) { struct Inner { value @0 :T } }`) inherits T via an
## INHERIT brand scope. Monomorphizing Outer(Text) emits a per-instantiation inner
## mono Outer_Inner_Text whose `value` resolves to String, and Outer_Text.inner
## resolves to it (not the erased Outer_Inner floor). Uses the generated
## GenericInheritCapnp.


func test_inherited_param_resolves_through_the_inner_mono() -> void:
	var u: GenericInheritCapnp.Use.Builder = GenericInheritCapnp.new_use()
	var inner: GenericInheritCapnp.Outer_Inner_Text.Builder = u.init_o().init_inner()
	inner.set_value("payload")    # typed String setter on the inherited param
	inner.set_label("tag")

	var r: GenericInheritCapnp.Use.Reader = GenericInheritCapnp.read_use(u.to_bytes())
	# get_o() -> Outer_Text.Reader, get_inner() -> Outer_Inner_Text.Reader (typed).
	var rinner: GenericInheritCapnp.Outer_Inner_Text.Reader = r.get_o().get_inner()
	var v: String = rinner.get_value()   # typed local guards the String resolution
	assert_eq(v, "payload", "inherited param T resolved to String")
	assert_eq(rinner.get_label(), "tag", "sibling normal field still works")


func test_erased_inner_floor_keeps_anypointer_accessors() -> void:
	# The unbound nested struct (Outer_Inner) still exposes the erased AnyPointer
	# accessors — the inherit mono adds the typed layer, it does not replace the floor.
	var outer: GenericInheritCapnp.Outer.Builder = GenericInheritCapnp.new_outer()
	outer.init_inner().set_value_text("erased")
	var r: GenericInheritCapnp.Outer.Reader = GenericInheritCapnp.read_outer(outer.to_bytes())
	assert_eq(r.get_inner().get_value_text(), "erased", "erased floor round-trips via the AnyPointer text accessor")


func test_codegen_matches_committed_golden() -> void:
	var f: FileAccess = FileAccess.open("res://tests/fixtures/generic_inherit.cgr.bin", FileAccess.READ)
	assert_not_null(f, "fixture present")
	if f == null:
		return
	var cgr: CapnReader.StructReader = CapnSchema.open_request(f.get_buffer(f.get_length()))
	f.close()
	var files: Dictionary = CapnCodegen.generate_files(cgr)
	assert_true(files.has("generic_inherit.capnp.gd"), "generated the umbrella file")

	var g: FileAccess = FileAccess.open("res://tests/generated/generic_inherit.capnp.gd", FileAccess.READ)
	assert_not_null(g, "committed golden present")
	if g == null:
		return
	var committed: String = g.get_as_text()
	g.close()
	assert_eq(files["generic_inherit.capnp.gd"], committed, "generator output matches committed golden")
