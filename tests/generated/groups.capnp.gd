class_name GroupsCapnp extends RefCounted

## GENERATED from groups.capnp by capnpc-gdscript — do not edit.

class Entity extends RefCounted:
	const DATA_WORDS: int = 4
	const PTR_WORDS: int = 2
	enum StateMode { IDLE, MOVING }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_name() -> String:
			return self.get_text(0, "")

		func get_transform_pos_x() -> float:
			return self.get_f32(0, 0)

		func get_transform_pos_y() -> float:
			return self.get_f32(4, 0)

		func get_physics_mass() -> float:
			return self.get_f32(8, 0)

		func get_physics_velocity_dx() -> float:
			return self.get_f32(12, 0)

		func get_physics_velocity_dy() -> float:
			return self.get_f32(16, 0)

		func get_physics_label() -> String:
			return self.get_text(1, "")

		func get_state_hp() -> int:
			return self.get_i32(20, 0)

		func state_mode_which() -> int:
			return self.get_u16(24, 0)

		func is_state_mode_idle() -> bool:
			return self.get_u16(24, 0) == 0

		func is_state_mode_moving() -> bool:
			return self.get_u16(24, 0) == 1

		func get_state_mode_moving() -> float:
			return self.get_f32(28, 0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_name(value: String) -> void:
			self.set_text(0, value)

		func set_transform_pos_x(value: float) -> void:
			self.set_f32(0, value, 0)

		func set_transform_pos_y(value: float) -> void:
			self.set_f32(4, value, 0)

		func set_physics_mass(value: float) -> void:
			self.set_f32(8, value, 0)

		func set_physics_velocity_dx(value: float) -> void:
			self.set_f32(12, value, 0)

		func set_physics_velocity_dy(value: float) -> void:
			self.set_f32(16, value, 0)

		func set_physics_label(value: String) -> void:
			self.set_text(1, value)

		func set_state_hp(value: int) -> void:
			self.set_i32(20, value, 0)

		func set_state_mode_idle() -> void:
			self.set_u16(24, 0, 0)

		func set_state_mode_moving(value: float) -> void:
			self.set_u16(24, 1, 0)
			self.set_f32(28, value, 0)

class Outer extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 0
	enum Which { EMPTY, BOX }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o
		func which() -> int:
			return self.get_u16(0, 0)

		func is_empty() -> bool:
			return self.get_u16(0, 0) == 0

		func is_box() -> bool:
			return self.get_u16(0, 0) == 1

		func get_box_w() -> int:
			return self.get_i32(4, 0)

		func get_box_h() -> int:
			return self.get_i32(8, 0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_empty() -> void:
			self.set_u16(0, 0, 0)

		func set_box_w(value: int) -> void:
			self.set_u16(0, 1, 0)
			self.set_i32(4, value, 0)

		func set_box_h(value: int) -> void:
			self.set_u16(0, 1, 0)
			self.set_i32(8, value, 0)


static func read_entity(bytes: PackedByteArray, packed: bool = false) -> Entity.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Entity.Reader = Entity.Reader.new()
	msg.fill_root(r)
	return r

static func new_entity() -> Entity.Builder:
	return Entity.Builder.wrap(CapnBuilder.new_message(Entity.DATA_WORDS, Entity.PTR_WORDS))

static func read_outer(bytes: PackedByteArray, packed: bool = false) -> Outer.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Outer.Reader = Outer.Reader.new()
	msg.fill_root(r)
	return r

static func new_outer() -> Outer.Builder:
	return Outer.Builder.wrap(CapnBuilder.new_message(Outer.DATA_WORDS, Outer.PTR_WORDS))
