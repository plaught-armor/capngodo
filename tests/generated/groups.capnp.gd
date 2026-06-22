class_name GroupsCapnp extends RefCounted

## GENERATED from groups.capnp by capnpc-gdscript — do not edit.

class Entity extends RefCounted:
	const DATA_WORDS: int = 4
	const PTR_WORDS: int = 2
	enum StateMode { IDLE, MOVING }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_name() -> String:
			return _r.get_text(0, "")

		func get_transform_pos_x() -> float:
			return _r.get_f32(0, 0)

		func get_transform_pos_y() -> float:
			return _r.get_f32(4, 0)

		func get_physics_mass() -> float:
			return _r.get_f32(8, 0)

		func get_physics_velocity_dx() -> float:
			return _r.get_f32(12, 0)

		func get_physics_velocity_dy() -> float:
			return _r.get_f32(16, 0)

		func get_physics_label() -> String:
			return _r.get_text(1, "")

		func get_state_hp() -> int:
			return _r.get_i32(20, 0)

		func state_mode_which() -> int:
			return _r.get_u16(24, 0)

		func is_state_mode_idle() -> bool:
			return _r.get_u16(24, 0) == 0

		func is_state_mode_moving() -> bool:
			return _r.get_u16(24, 0) == 1

		func get_state_mode_moving() -> float:
			return _r.get_f32(28, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_name(value: String) -> void:
			_b.set_text(0, value)

		func set_transform_pos_x(value: float) -> void:
			_b.set_f32(0, value, 0)

		func set_transform_pos_y(value: float) -> void:
			_b.set_f32(4, value, 0)

		func set_physics_mass(value: float) -> void:
			_b.set_f32(8, value, 0)

		func set_physics_velocity_dx(value: float) -> void:
			_b.set_f32(12, value, 0)

		func set_physics_velocity_dy(value: float) -> void:
			_b.set_f32(16, value, 0)

		func set_physics_label(value: String) -> void:
			_b.set_text(1, value)

		func set_state_hp(value: int) -> void:
			_b.set_i32(20, value, 0)

		func set_state_mode_idle() -> void:
			_b.set_u16(24, 0, 0)

		func set_state_mode_moving(value: float) -> void:
			_b.set_u16(24, 1, 0)
			_b.set_f32(28, value, 0)

class Outer extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 0
	enum Which { EMPTY, BOX }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func which() -> int:
			return _r.get_u16(0, 0)

		func is_empty() -> bool:
			return _r.get_u16(0, 0) == 0

		func is_box() -> bool:
			return _r.get_u16(0, 0) == 1

		func get_box_w() -> int:
			return _r.get_i32(4, 0)

		func get_box_h() -> int:
			return _r.get_i32(8, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_empty() -> void:
			_b.set_u16(0, 0, 0)

		# TODO: named group 'box' is a union arm — set outer which() manually

		func set_box_w(value: int) -> void:
			_b.set_i32(4, value, 0)

		func set_box_h(value: int) -> void:
			_b.set_i32(8, value, 0)


static func read_entity(bytes: PackedByteArray, packed: bool = false) -> Entity.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Entity.Reader.wrap(msg.get_root())

static func new_entity() -> Entity.Builder:
	return Entity.Builder.wrap(CapnBuilder.new_message(Entity.DATA_WORDS, Entity.PTR_WORDS))

static func read_outer(bytes: PackedByteArray, packed: bool = false) -> Outer.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Outer.Reader.wrap(msg.get_root())

static func new_outer() -> Outer.Builder:
	return Outer.Builder.wrap(CapnBuilder.new_message(Outer.DATA_WORDS, Outer.PTR_WORDS))
