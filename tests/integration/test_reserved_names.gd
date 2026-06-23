extends GutTest
## Reserved-name sanitization (CG2): a schema using names that collide with
## Godot built-ins / GDScript keywords (enum Color, struct Node, field `class`)
## must generate valid, usable code. The generator appends "_" to collisions:
## Color -> Color_, Node -> Node_, class -> class_ (get_class_/set_class_).
## Uses the generated ReservedCapnp (from tests/golden/reserved.capnp).

func test_reserved_type_and_field_names_round_trip() -> void:
	var h: ReservedCapnp.Holder.Builder = ReservedCapnp.new_holder()
	var n: ReservedCapnp.Node_.Builder = h.init_child()
	n.set_value(42)
	n.set_class_("keyword-named field") # field 'class' -> get_/set_class_
	n.set_instance_id_(7) # field 'instanceId' -> Object getter shadow avoided
	n.set_color(ReservedCapnp.Color_.GREEN) # enum Color -> Color_
	n.set_kind(ReservedCapnp.Math.PI_) # enum member 'pi' -> PI_

	var r: ReservedCapnp.Holder.Reader = ReservedCapnp.read_holder(h.to_bytes())
	var rn: ReservedCapnp.Node_.Reader = r.get_child()
	assert_eq(rn.get_value(), 42, "value")
	assert_eq(rn.get_class_(), "keyword-named field", "field 'class' -> get_class_")
	assert_eq(rn.get_instance_id_(), 7, "field 'instanceId' -> get_instance_id_")
	assert_eq(rn.get_color(), ReservedCapnp.Color_.GREEN, "enum Color -> Color_")
	assert_eq(rn.get_kind(), ReservedCapnp.Math.PI_, "enum member 'pi' -> PI_")
	# Sanity: the real Object.get_instance_id() is NOT shadowed — it returns the
	# object's own id (nonzero, and not our field's value 7).
	assert_ne(rn.get_instance_id(), 0, "Object.get_instance_id intact")
	assert_ne(rn.get_instance_id(), 7, "real instance id != the shadowed field")


func test_mangled_enum_values() -> void:
	assert_eq(ReservedCapnp.Color_.RED, 0)
	assert_eq(ReservedCapnp.Color_.GREEN, 1)
	assert_eq(ReservedCapnp.Color_.BLUE, 2)
	# 'e' is not reserved, stays; pi/tau are GDScript constants -> mangled.
	assert_eq(ReservedCapnp.Math.PI_, 0)
	assert_eq(ReservedCapnp.Math.TAU_, 1)
	assert_eq(ReservedCapnp.Math.E, 2)
