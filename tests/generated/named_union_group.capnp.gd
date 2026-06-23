class_name NamedUnionGroupCapnp extends RefCounted

## GENERATED from named_union_group.capnp by capnpc-gdscript — do not edit.

class Command extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 2
	enum Body { CHAT, MOVE, QUIT }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_id() -> int:
			return self.get_u32(0, 0)

		func body_which() -> int:
			return self.get_u16(4, 0)

		func is_body_chat() -> bool:
			return self.get_u16(4, 0) == 0

		func get_body_chat_sender() -> String:
			return self.get_text(0, "")

		func get_body_chat_text() -> String:
			return self.get_text(1, "")

		func is_body_move() -> bool:
			return self.get_u16(4, 0) == 1

		func get_body_move_dx() -> int:
			return self.get_i32(8, 0)

		func get_body_move_dy() -> int:
			return self.get_i32(12, 0)

		func is_body_quit() -> bool:
			return self.get_u16(4, 0) == 2

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_id(value: int) -> void:
			self.set_u32(0, value, 0)

		func set_body_chat_sender(value: String) -> void:
			self.set_u16(4, 0, 0)
			self.set_text(0, value)

		func set_body_chat_text(value: String) -> void:
			self.set_u16(4, 0, 0)
			self.set_text(1, value)

		func set_body_move_dx(value: int) -> void:
			self.set_u16(4, 1, 0)
			self.set_i32(8, value, 0)

		func set_body_move_dy(value: int) -> void:
			self.set_u16(4, 1, 0)
			self.set_i32(12, value, 0)

		func set_body_quit() -> void:
			self.set_u16(4, 2, 0)


static func read_command(bytes: PackedByteArray, packed: bool = false) -> Command.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Command.Reader = Command.Reader.new()
	msg.fill_root(r)
	return r

static func new_command() -> Command.Builder:
	return Command.Builder.wrap(CapnBuilder.new_message(Command.DATA_WORDS, Command.PTR_WORDS))
