class_name CapabilityCapnp extends RefCounted

## GENERATED from capability.capnp by capnpc-gdscript — do not edit.

class Session extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_id() -> int:
			return _r.get_u32(0, 0)

		func get_greeter() -> int:
			return _r.get_cap_index(0)

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

		# capability 'greeter' is read-only (serialization only, no RPC)

class Event extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1
	enum Which { NONE, HANDLER, COUNT }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func which() -> int:
			return _r.get_u16(0, 0)

		func is_none() -> bool:
			return _r.get_u16(0, 0) == 0

		func is_handler() -> bool:
			return _r.get_u16(0, 0) == 1

		func get_handler() -> int:
			return _r.get_cap_index(0)

		func is_count() -> bool:
			return _r.get_u16(0, 0) == 2

		func get_count() -> int:
			return _r.get_u16(2, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_none() -> void:
			_b.set_u16(0, 0, 0)

		func set_handler() -> void:  # selects this arm; the capability stays unset (no RPC)
			_b.set_u16(0, 1, 0)

		func set_count(value: int) -> void:
			_b.set_u16(0, 2, 0)
			_b.set_u16(2, value, 0)


static func read_session(bytes: PackedByteArray, packed: bool = false) -> Session.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Session.Reader.wrap(msg.get_root())

static func new_session() -> Session.Builder:
	return Session.Builder.wrap(CapnBuilder.new_message(Session.DATA_WORDS, Session.PTR_WORDS))

static func read_event(bytes: PackedByteArray, packed: bool = false) -> Event.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Event.Reader.wrap(msg.get_root())

static func new_event() -> Event.Builder:
	return Event.Builder.wrap(CapnBuilder.new_message(Event.DATA_WORDS, Event.PTR_WORDS))
