extends GutTest
## Nested union in a struct-level union (CG4): a union-group that is itself an
## arm of the struct-level union. The inner-arm setters must also write the
## OUTER discriminant, or the message reads back as a different outer arm.
## Uses the generated NestedUnionCapnp (from tests/golden/nested_union.capnp):
##   Msg { id; union { none; payload :union{text,num}; count } }

func test_nested_union_text_arm_sets_outer_discriminant() -> void:
	var m: NestedUnionCapnp.Msg.Builder = NestedUnionCapnp.new_msg()
	m.set_id(7)
	m.set_payload_text("hi")

	var r: NestedUnionCapnp.Msg.Reader = NestedUnionCapnp.read_msg(m.to_bytes())
	assert_eq(r.get_id(), 7, "id outside the union intact")
	assert_eq(r.which(), NestedUnionCapnp.Msg.Which.PAYLOAD, "outer arm = PAYLOAD")
	assert_true(r.is_payload(), "is_payload (outer)")
	assert_false(r.is_none(), "not none")
	assert_eq(r.payload_which(), NestedUnionCapnp.Msg.Payload.TEXT, "inner arm = TEXT")
	assert_true(r.is_payload_text(), "is_payload_text (inner)")
	assert_eq(r.get_payload_text(), "hi", "inner text value")


func test_nested_union_num_arm() -> void:
	var m: NestedUnionCapnp.Msg.Builder = NestedUnionCapnp.new_msg()
	m.set_payload_num(-5)

	var r: NestedUnionCapnp.Msg.Reader = NestedUnionCapnp.read_msg(m.to_bytes())
	assert_eq(r.which(), NestedUnionCapnp.Msg.Which.PAYLOAD, "outer arm = PAYLOAD")
	assert_eq(r.payload_which(), NestedUnionCapnp.Msg.Payload.NUM, "inner arm = NUM")
	assert_eq(r.get_payload_num(), -5, "inner num value")


func test_plain_slot_arm_alongside_union_group() -> void:
	var m: NestedUnionCapnp.Msg.Builder = NestedUnionCapnp.new_msg()
	m.set_count(42)

	var r: NestedUnionCapnp.Msg.Reader = NestedUnionCapnp.read_msg(m.to_bytes())
	assert_eq(r.which(), NestedUnionCapnp.Msg.Which.COUNT, "outer arm = COUNT")
	assert_true(r.is_count(), "is_count")
	assert_false(r.is_payload(), "not payload")
	assert_eq(r.get_count(), 42, "count value")


func test_void_outer_arm() -> void:
	var m: NestedUnionCapnp.Msg.Builder = NestedUnionCapnp.new_msg()
	m.set_none()

	var r: NestedUnionCapnp.Msg.Reader = NestedUnionCapnp.read_msg(m.to_bytes())
	assert_eq(r.which(), NestedUnionCapnp.Msg.Which.NONE, "outer arm = NONE")
	assert_true(r.is_none(), "is_none")


func test_void_inner_arm_writes_both_discriminants() -> void:
	# A void inner arm carries no value, but still must select BOTH the outer
	# (PAYLOAD) and inner (RESET) discriminants.
	var m: NestedUnionCapnp.Msg.Builder = NestedUnionCapnp.new_msg()
	m.set_payload_reset()

	var r: NestedUnionCapnp.Msg.Reader = NestedUnionCapnp.read_msg(m.to_bytes())
	assert_eq(r.which(), NestedUnionCapnp.Msg.Which.PAYLOAD, "outer = PAYLOAD")
	assert_true(r.is_payload(), "is_payload")
	assert_eq(r.payload_which(), NestedUnionCapnp.Msg.Payload.RESET, "inner = RESET")
	assert_true(r.is_payload_reset(), "is_payload_reset")


func test_field_outside_union_independent_of_arm() -> void:
	# Setting id (outside the union) after the union arm must not disturb either
	# discriminant.
	var m: NestedUnionCapnp.Msg.Builder = NestedUnionCapnp.new_msg()
	m.set_payload_text("x")
	m.set_id(42)

	var r: NestedUnionCapnp.Msg.Reader = NestedUnionCapnp.read_msg(m.to_bytes())
	assert_eq(r.which(), NestedUnionCapnp.Msg.Which.PAYLOAD, "arm intact after set_id")
	assert_eq(r.get_payload_text(), "x", "inner value intact")
	assert_eq(r.get_id(), 42, "id stored")


func test_last_write_wins_across_outer_arms() -> void:
	# Selecting count after payload must flip the outer discriminant back.
	var m: NestedUnionCapnp.Msg.Builder = NestedUnionCapnp.new_msg()
	m.set_payload_num(99)
	m.set_count(3)

	var r: NestedUnionCapnp.Msg.Reader = NestedUnionCapnp.read_msg(m.to_bytes())
	assert_eq(r.which(), NestedUnionCapnp.Msg.Which.COUNT, "outer arm flipped to COUNT")
	assert_eq(r.get_count(), 3, "count value")
