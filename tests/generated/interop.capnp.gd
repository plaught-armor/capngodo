class_name InteropCapnp extends RefCounted

## GENERATED from interop.capnp by capnpc-gdscript — do not edit.

enum Kind { ALPHA, BETA }

class Child extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_note() -> String:
			return _r.get_text(0, "")

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_note(value: String) -> void:
			_b.set_text(0, value)

class Root extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 5
	enum Status { ACTIVE, BANNED }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_id() -> int:
			return _r.get_u32(0, 0)

		func get_name() -> String:
			return _r.get_text(0, "")

		func get_tags() -> Array:
			var lr: CapnReader.ListReader = _r.get_list(1)
			var out: Array = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_text(i)
			return out

		func get_scores() -> Array:
			var lr: CapnReader.ListReader = _r.get_list(2)
			var out: Array = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_i32(i)
			return out

		func get_child() -> Child.Reader:
			return Child.Reader.wrap(_r.get_struct(3))

		func get_kind() -> int:
			return _r.get_u16(4, 0)

		func status_which() -> int:
			return _r.get_u16(6, 0)

		func is_status_active() -> bool:
			return _r.get_u16(6, 0) == 0

		func is_status_banned() -> bool:
			return _r.get_u16(6, 0) == 1

		func get_status_banned() -> String:
			return _r.get_text(4, "")

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

		func set_name(value: String) -> void:
			_b.set_text(0, value)

		func init_tags(n: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(1, CapnPointer.ElemSize.POINTER, n)

		func init_scores(n: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(2, CapnPointer.ElemSize.FOUR_BYTES, n)

		func init_child() -> Child.Builder:
			return Child.Builder.wrap(_b.init_struct(3, Child.DATA_WORDS, Child.PTR_WORDS))

		func set_kind(value: int) -> void:
			_b.set_u16(4, value, 0)

		func set_status_active() -> void:
			_b.set_u16(6, 0, 0)

		func set_status_banned(value: String) -> void:
			_b.set_u16(6, 1, 0)
			_b.set_text(4, value)


static func read_child(bytes: PackedByteArray, packed: bool = false) -> Child.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Child.Reader.wrap(msg.get_root())

static func new_child() -> Child.Builder:
	return Child.Builder.wrap(CapnBuilder.new_message(Child.DATA_WORDS, Child.PTR_WORDS))

static func read_root(bytes: PackedByteArray, packed: bool = false) -> Root.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Root.Reader.wrap(msg.get_root())

static func new_root() -> Root.Builder:
	return Root.Builder.wrap(CapnBuilder.new_message(Root.DATA_WORDS, Root.PTR_WORDS))
