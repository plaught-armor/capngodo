class_name NestedUnionCapnp extends RefCounted

## GENERATED from nested_union.capnp by capnpc-gdscript — do not edit.

class Msg extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 1
	enum Which { NONE, PAYLOAD, COUNT }
	enum Payload { TEXT, NUM, RESET }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func which() -> int:
			return _r.get_u16(4, 0)

		func get_id() -> int:
			return _r.get_u32(0, 0)

		func is_none() -> bool:
			return _r.get_u16(4, 0) == 0

		func is_payload() -> bool:
			return _r.get_u16(4, 0) == 1

		func payload_which() -> int:
			return _r.get_u16(6, 0)

		func is_payload_text() -> bool:
			return _r.get_u16(6, 0) == 0

		func get_payload_text() -> String:
			return _r.get_text(0, "")

		func is_payload_num() -> bool:
			return _r.get_u16(6, 0) == 1

		func get_payload_num() -> int:
			return _r.get_i32(8, 0)

		func is_payload_reset() -> bool:
			return _r.get_u16(6, 0) == 2

		func is_count() -> bool:
			return _r.get_u16(4, 0) == 2

		func get_count() -> int:
			return _r.get_u16(6, 0)

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

		func set_none() -> void:
			_b.set_u16(4, 0, 0)

		func set_payload_text(value: String) -> void:
			_b.set_u16(4, 1, 0)
			_b.set_u16(6, 0, 0)
			_b.set_text(0, value)

		func set_payload_num(value: int) -> void:
			_b.set_u16(4, 1, 0)
			_b.set_u16(6, 1, 0)
			_b.set_i32(8, value, 0)

		func set_payload_reset() -> void:
			_b.set_u16(4, 1, 0)
			_b.set_u16(6, 2, 0)

		func set_count(value: int) -> void:
			_b.set_u16(4, 2, 0)
			_b.set_u16(6, value, 0)


static func read_msg(bytes: PackedByteArray, packed: bool = false) -> Msg.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Msg.Reader.wrap(msg.get_root())

static func new_msg() -> Msg.Builder:
	return Msg.Builder.wrap(CapnBuilder.new_message(Msg.DATA_WORDS, Msg.PTR_WORDS))
