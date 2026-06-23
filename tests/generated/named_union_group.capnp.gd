class_name NamedUnionGroupCapnp extends RefCounted

## GENERATED from named_union_group.capnp by capnpc-gdscript — do not edit.

class Command extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 2
	enum Body { CHAT, MOVE, QUIT }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_id() -> int:
			return _r.get_u32(0, 0)

		func body_which() -> int:
			return _r.get_u16(4, 0)

		func is_body_chat() -> bool:
			return _r.get_u16(4, 0) == 0

		func get_body_chat_sender() -> String:
			return _r.get_text(0, "")

		func get_body_chat_text() -> String:
			return _r.get_text(1, "")

		func is_body_move() -> bool:
			return _r.get_u16(4, 0) == 1

		func get_body_move_dx() -> int:
			return _r.get_i32(8, 0)

		func get_body_move_dy() -> int:
			return _r.get_i32(12, 0)

		func is_body_quit() -> bool:
			return _r.get_u16(4, 0) == 2

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_id(value: int) -> void:
			_b.set_u32(0, value, 0)

		func set_body_chat_sender(value: String) -> void:
			_b.set_u16(4, 0, 0)
			_b.set_text(0, value)

		func set_body_chat_text(value: String) -> void:
			_b.set_u16(4, 0, 0)
			_b.set_text(1, value)

		func set_body_move_dx(value: int) -> void:
			_b.set_u16(4, 1, 0)
			_b.set_i32(8, value, 0)

		func set_body_move_dy(value: int) -> void:
			_b.set_u16(4, 1, 0)
			_b.set_i32(12, value, 0)

		func set_body_quit() -> void:
			_b.set_u16(4, 2, 0)


static func read_command(bytes: PackedByteArray, packed: bool = false) -> Command.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Command.Reader.wrap(msg.get_root())

static func new_command() -> Command.Builder:
	return Command.Builder.wrap(CapnBuilder.new_message(Command.DATA_WORDS, Command.PTR_WORDS))
