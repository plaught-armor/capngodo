extends GutTest

## List(Void) (CG8): a void list carries only a length. The builder must use
## ElemSize.VOID (not the pointer fallback) so the count round-trips and the
## sibling pointer field is undisturbed. Uses the generated VoidlistCapnp.


func test_void_list_length_round_trips() -> void:
	var p: VoidlistCapnp.Pings.Builder = VoidlistCapnp.new_pings()
	var _lb: CapnBuilder.ListBuilder = p.init_voids(3)  # void elements: nothing to set
	p.set_label("ok")

	var r: VoidlistCapnp.Pings.Reader = VoidlistCapnp.read_pings(p.to_bytes())
	var voids: Array = r.get_voids()
	assert_eq(voids.size(), 3, "void list length round-trips")
	assert_eq(r.get_label(), "ok", "sibling pointer field intact")


func test_empty_void_list() -> void:
	var p: VoidlistCapnp.Pings.Builder = VoidlistCapnp.new_pings()
	p.init_voids(0)
	var r: VoidlistCapnp.Pings.Reader = VoidlistCapnp.read_pings(p.to_bytes())
	assert_eq(r.get_voids().size(), 0, "zero-length void list")
