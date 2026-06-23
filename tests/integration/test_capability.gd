extends GutTest
## Interface (capability) field types (CG6): a capability field decodes to its
## cap-table index (-1 when absent); there is no RPC layer and no setter. Uses
## the generated CapabilityCapnp (from tests/golden/capability.capnp).

func test_capability_field_absent_reads_minus_one() -> void:
	# Our builder writes no capability (serialization only), so the cap pointer
	# is absent and get_greeter() returns -1 — while the sibling scalar field is
	# unaffected (proves the capability accessor doesn't disturb layout).
	var s: CapabilityCapnp.Session.Builder = CapabilityCapnp.new_session()
	s.set_id(5)

	var r: CapabilityCapnp.Session.Reader = CapabilityCapnp.read_session(s.to_bytes())
	assert_eq(r.get_id(), 5, "scalar field intact")
	assert_eq(r.get_greeter(), -1, "absent capability -> -1")


func test_capability_union_arm_is_selectable() -> void:
	# The cap arm has a no-arg selector that writes the discriminant; the cap
	# itself stays unset (get_handler() -> -1).
	var e: CapabilityCapnp.Event.Builder = CapabilityCapnp.new_event()
	e.set_handler()

	var r: CapabilityCapnp.Event.Reader = CapabilityCapnp.read_event(e.to_bytes())
	assert_eq(r.which(), CapabilityCapnp.Event.Which.HANDLER, "handler arm selected")
	assert_true(r.is_handler(), "is_handler")
	assert_eq(r.get_handler(), -1, "cap stays unset")


func test_capability_union_sibling_arm() -> void:
	var e: CapabilityCapnp.Event.Builder = CapabilityCapnp.new_event()
	e.set_count(7)

	var r: CapabilityCapnp.Event.Reader = CapabilityCapnp.read_event(e.to_bytes())
	assert_eq(r.which(), CapabilityCapnp.Event.Which.COUNT, "count arm selected")
	assert_eq(r.get_count(), 7, "count value")
