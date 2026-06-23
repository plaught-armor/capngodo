extends GutTest
## Named (non-union) groups (CG3): a group with no discriminant is a sub-
## namespace whose fields share the parent's layout. Codegen flattens them to
## get_<group>_<field>() / set_<group>_<field>(). Uses the generated GroupsCapnp
## (from tests/golden/groups.capnp):
##   Entity { name; transform :group{posX,posY}; physics :group{mass,
##            velocity :group{dx,dy}, label}; state :group{hp, mode :union{...}} }

func test_scalar_group_round_trips() -> void:
	var e: GroupsCapnp.Entity.Builder = GroupsCapnp.new_entity()
	e.set_name("hero")
	e.set_transform_pos_x(1.5)
	e.set_transform_pos_y(-2.5)

	var r: GroupsCapnp.Entity.Reader = GroupsCapnp.read_entity(e.to_bytes())
	assert_eq(r.get_name(), "hero", "name")
	assert_almost_eq(r.get_transform_pos_x(), 1.5, 0.0001, "transform.posX")
	assert_almost_eq(r.get_transform_pos_y(), -2.5, 0.0001, "transform.posY")


func test_nested_group_and_pointer_field_round_trip() -> void:
	var e: GroupsCapnp.Entity.Builder = GroupsCapnp.new_entity()
	e.set_physics_mass(10.0)
	e.set_physics_velocity_dx(3.0)
	e.set_physics_velocity_dy(4.0)
	e.set_physics_label("rigid")

	var r: GroupsCapnp.Entity.Reader = GroupsCapnp.read_entity(e.to_bytes())
	assert_almost_eq(r.get_physics_mass(), 10.0, 0.0001, "physics.mass")
	assert_almost_eq(r.get_physics_velocity_dx(), 3.0, 0.0001, "physics.velocity.dx (nested group)")
	assert_almost_eq(r.get_physics_velocity_dy(), 4.0, 0.0001, "physics.velocity.dy (nested group)")
	assert_eq(r.get_physics_label(), "rigid", "physics.label (pointer in group)")


func test_union_nested_in_group_round_trips() -> void:
	var e: GroupsCapnp.Entity.Builder = GroupsCapnp.new_entity()
	e.set_state_hp(42)
	e.set_state_mode_moving(5.5)

	var r: GroupsCapnp.Entity.Reader = GroupsCapnp.read_entity(e.to_bytes())
	assert_eq(r.get_state_hp(), 42, "state.hp")
	assert_eq(r.state_mode_which(), GroupsCapnp.Entity.StateMode.MOVING, "state.mode discriminant")
	assert_true(r.is_state_mode_moving(), "is moving")
	assert_false(r.is_state_mode_idle(), "not idle")
	assert_almost_eq(r.get_state_mode_moving(), 5.5, 0.0001, "state.mode.moving value")


func test_group_fields_are_independent() -> void:
	# Group fields share the parent layout but occupy distinct offsets — setting
	# one must not disturb a sibling group's field.
	var e: GroupsCapnp.Entity.Builder = GroupsCapnp.new_entity()
	e.set_transform_pos_x(7.0)
	e.set_state_hp(99)
	e.set_state_mode_idle()

	var r: GroupsCapnp.Entity.Reader = GroupsCapnp.read_entity(e.to_bytes())
	assert_almost_eq(r.get_transform_pos_x(), 7.0, 0.0001, "transform.posX intact")
	assert_eq(r.get_state_hp(), 99, "state.hp intact")
	assert_true(r.is_state_mode_idle(), "idle arm selected")
	# Untouched group field reads its zero default.
	assert_almost_eq(r.get_physics_mass(), 0.0, 0.0001, "untouched physics.mass zero")


func _read_bytes(path: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "%s present" % path)
	if f == null:
		return PackedByteArray()
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return b


func test_named_group_as_union_arm_reads() -> void:
	# A named group that is a struct-level union arm: the reader emits is_box()
	# + flattened get_box_w/h(). The box setters can't select the outer
	# discriminant (documented gap), so the message is authored by reference
	# capnp (`capnp encode '(box=(w=3,h=4))'`) — doubles as reverse interop.
	var r: GroupsCapnp.Outer.Reader = GroupsCapnp.read_outer(_read_bytes("res://tests/fixtures/outer_box.bin"))
	assert_eq(r.which(), GroupsCapnp.Outer.Which.BOX, "box arm selected")
	assert_true(r.is_box(), "is_box")
	assert_false(r.is_empty(), "not empty")
	assert_eq(r.get_box_w(), 3, "box.w flattened getter")
	assert_eq(r.get_box_h(), 4, "box.h flattened getter")


func test_named_group_union_void_arm_reads() -> void:
	var r: GroupsCapnp.Outer.Reader = GroupsCapnp.read_outer(_read_bytes("res://tests/fixtures/outer_empty.bin"))
	assert_eq(r.which(), GroupsCapnp.Outer.Which.EMPTY, "empty arm selected")
	assert_true(r.is_empty(), "is_empty")
	assert_false(r.is_box(), "not box")


func test_named_group_as_union_arm_builds() -> void:
	# CG4 closed the setter gap: the box leaf setters now write the outer
	# discriminant, so a built box arm round-trips without manual disc poking.
	var o: GroupsCapnp.Outer.Builder = GroupsCapnp.new_outer()
	o.set_box_w(8)
	o.set_box_h(5)

	var r: GroupsCapnp.Outer.Reader = GroupsCapnp.read_outer(o.to_bytes())
	assert_eq(r.which(), GroupsCapnp.Outer.Which.BOX, "box arm selected by leaf setter")
	assert_true(r.is_box(), "is_box")
	assert_eq(r.get_box_w(), 8, "box.w")
	assert_eq(r.get_box_h(), 5, "box.h")
