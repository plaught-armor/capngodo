extends GutTest
## CG1d — a generic bound to an interface (capability) type. Interfaces are
## pointer types, so capnp accepts them as generic args; the CG1b/CG1c param
## substitution drives the INTERFACE accessor arms. Box(Handle) -> Box_Handle
## with get_value() -> int (cap-table index, -1 absent) and no value setter
## (serialization-only). Uses generated GenericIfaceCapnp (generic_iface.capnp):
##   Box(T) { value @0 :T }   Use { h :Box(Handle) }   interface Handle {}

func test_interface_param_typed_to_cap_index() -> void:
	# No cap setter (serialization-only), so an unset capability reads -1.
	var u: GenericIfaceCapnp.Use.Builder = GenericIfaceCapnp.new_use()
	var hb: GenericIfaceCapnp.Box_Handle.Builder = u.init_h()
	assert_not_null(hb, "Box(Handle) instantiates to Box_Handle.Builder")

	var r: GenericIfaceCapnp.Use.Reader = GenericIfaceCapnp.read_use(u.to_bytes())
	assert_eq(r.get_h().get_value(), -1, "unset capability param reads -1")


func test_interface_param_decodes_poked_cap_index() -> void:
	# Hand-poke a self-contained cap pointer into the Box_Handle value slot (ptr 0)
	# to exercise the get_cap_index decode the typed accessor wraps.
	var u: GenericIfaceCapnp.Use.Builder = GenericIfaceCapnp.new_use()
	var hb: GenericIfaceCapnp.Box_Handle.Builder = u.init_h()
	# The generated Builder IS a StructBuilder now (wrapper-collapse), so poke the
	# capability pointer directly on it (capabilities have no typed setter).
	var sb: CapnBuilder.StructBuilder = hb
	sb.arena._put(sb.seg_id, sb.ptr_word + 0, CapnPointer.encode_cap(5))

	var r: GenericIfaceCapnp.Use.Reader = GenericIfaceCapnp.read_use(u.to_bytes())
	assert_eq(r.get_h().get_value(), 5, "typed interface param decodes cap-table index")
