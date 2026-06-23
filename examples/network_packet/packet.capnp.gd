class_name PacketCapnp extends RefCounted

## GENERATED from packet.capnp by capnpc-gdscript — do not edit.

class Vec2 extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 0

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_x() -> float:
			return _r.get_f32(0, 0)

		func get_y() -> float:
			return _r.get_f32(4, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_x(value: float) -> void:
			_b.set_f32(0, value, 0)

		func set_y(value: float) -> void:
			_b.set_f32(4, value, 0)

class MoveBody extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_pos() -> Vec2.Reader:
			return Vec2.Reader.wrap(_r.get_struct(0))

		func get_vel() -> Vec2.Reader:
			return Vec2.Reader.wrap(_r.get_struct(1))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_pos() -> Vec2.Builder:
			return Vec2.Builder.wrap(_b.init_struct(0, Vec2.DATA_WORDS, Vec2.PTR_WORDS))

		func init_vel() -> Vec2.Builder:
			return Vec2.Builder.wrap(_b.init_struct(1, Vec2.DATA_WORDS, Vec2.PTR_WORDS))

class SpawnBody extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_entity_id() -> int:
			return _r.get_u32(0, 0)

		func get_pos() -> Vec2.Reader:
			return Vec2.Reader.wrap(_r.get_struct(0))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_entity_id(value: int) -> void:
			_b.set_u32(0, value, 0)

		func init_pos() -> Vec2.Builder:
			return Vec2.Builder.wrap(_b.init_struct(0, Vec2.DATA_WORDS, Vec2.PTR_WORDS))

class Packet extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 1
	enum Body { CHAT, MOVE, SPAWN }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_seq() -> int:
			return _r.get_u32(0, 0)

		func get_sender_id() -> int:
			return _r.get_u32(4, 0)

		func body_which() -> int:
			return _r.get_u16(8, 0)

		func is_body_chat() -> bool:
			return _r.get_u16(8, 0) == 0

		func get_body_chat() -> String:
			return _r.get_text(0, "")

		func is_body_move() -> bool:
			return _r.get_u16(8, 0) == 1

		func get_body_move() -> MoveBody.Reader:
			return MoveBody.Reader.wrap(_r.get_struct(0))

		func is_body_spawn() -> bool:
			return _r.get_u16(8, 0) == 2

		func get_body_spawn() -> SpawnBody.Reader:
			return SpawnBody.Reader.wrap(_r.get_struct(0))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_seq(value: int) -> void:
			_b.set_u32(0, value, 0)

		func set_sender_id(value: int) -> void:
			_b.set_u32(4, value, 0)

		func set_body_chat(value: String) -> void:
			_b.set_u16(8, 0, 0)
			_b.set_text(0, value)

		func init_body_move() -> MoveBody.Builder:
			_b.set_u16(8, 1, 0)
			return MoveBody.Builder.wrap(_b.init_struct(0, MoveBody.DATA_WORDS, MoveBody.PTR_WORDS))

		func init_body_spawn() -> SpawnBody.Builder:
			_b.set_u16(8, 2, 0)
			return SpawnBody.Builder.wrap(_b.init_struct(0, SpawnBody.DATA_WORDS, SpawnBody.PTR_WORDS))


static func read_vec2(bytes: PackedByteArray, packed: bool = false) -> Vec2.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Vec2.Reader.wrap(msg.get_root())

static func new_vec2() -> Vec2.Builder:
	return Vec2.Builder.wrap(CapnBuilder.new_message(Vec2.DATA_WORDS, Vec2.PTR_WORDS))

static func read_move_body(bytes: PackedByteArray, packed: bool = false) -> MoveBody.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return MoveBody.Reader.wrap(msg.get_root())

static func new_move_body() -> MoveBody.Builder:
	return MoveBody.Builder.wrap(CapnBuilder.new_message(MoveBody.DATA_WORDS, MoveBody.PTR_WORDS))

static func read_spawn_body(bytes: PackedByteArray, packed: bool = false) -> SpawnBody.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return SpawnBody.Reader.wrap(msg.get_root())

static func new_spawn_body() -> SpawnBody.Builder:
	return SpawnBody.Builder.wrap(CapnBuilder.new_message(SpawnBody.DATA_WORDS, SpawnBody.PTR_WORDS))

static func read_packet(bytes: PackedByteArray, packed: bool = false) -> Packet.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Packet.Reader.wrap(msg.get_root())

static func new_packet() -> Packet.Builder:
	return Packet.Builder.wrap(CapnBuilder.new_message(Packet.DATA_WORDS, Packet.PTR_WORDS))
