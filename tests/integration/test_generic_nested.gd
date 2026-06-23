extends GutTest

## CG1c — nested-generic monomorphization. Box(Box(Text)) emits a typed outer
## (Box_Box_Text) whose value resolves to the typed inner (Box_Text), itself with
## get_value() -> String. The collector recurses into brand bindings so the inner
## instantiation registers and names distinctly (Box_Box_Text vs Box_Box_Cell).
## Uses the generated GenericNestedCapnp (tests/golden/generic_nested.capnp):
##   Box(T) { value @0 :T }
##   Holder { bb :Box(Box(Text)); bbc :Box(Box(Cell)) }   Cell { v @0 :Int32 }


func test_nested_text_two_levels_round_trip() -> void:
	var h: GenericNestedCapnp.Holder.Builder = GenericNestedCapnp.new_holder()
	var outer: GenericNestedCapnp.Box_Box_Text.Builder = h.init_bb()
	var inner: GenericNestedCapnp.Box_Text.Builder = outer.init_value()
	inner.set_value("deep")             # typed String at the innermost level

	var r: GenericNestedCapnp.Holder.Reader = GenericNestedCapnp.read_holder(h.to_bytes())
	var rb: GenericNestedCapnp.Box_Box_Text.Reader = r.get_bb()
	var ri: GenericNestedCapnp.Box_Text.Reader = rb.get_value()
	assert_eq(ri.get_value(), "deep", "Box(Box(Text)) -> typed String two levels down")


func test_nested_struct_three_levels_round_trip() -> void:
	var h: GenericNestedCapnp.Holder.Builder = GenericNestedCapnp.new_holder()
	var outer: GenericNestedCapnp.Box_Box_Cell.Builder = h.init_bbc()
	var mid: GenericNestedCapnp.Box_Cell.Builder = outer.init_value()
	var cell: GenericNestedCapnp.Cell.Builder = mid.init_value()
	cell.set_v(7)

	var r: GenericNestedCapnp.Holder.Reader = GenericNestedCapnp.read_holder(h.to_bytes())
	var got: GenericNestedCapnp.Cell.Reader = r.get_bbc().get_value().get_value()
	assert_eq(got.get_v(), 7, "Box(Box(Cell)) -> typed Cell three levels down")


func test_erased_box_floor_still_present() -> void:
	# The unbound generic Box stays emitted with the type-erased accessors (CG1a),
	# reachable via the top-level new_box()/read_box() regardless of the mono layer.
	var b: GenericNestedCapnp.Box.Builder = GenericNestedCapnp.new_box()
	b.set_value_text("erased")
	var r: GenericNestedCapnp.Box.Reader = GenericNestedCapnp.read_box(b.to_bytes())
	assert_eq(r.get_value_text(), "erased", "erased Box floor intact")
