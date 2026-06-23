class_name InteropCapnp extends RefCounted

## GENERATED from interop.capnp by capnpc-gdscript — do not edit.

enum Kind { ALPHA, BETA }

class Child extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_note() -> String:
			return self.get_text(0, "")

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

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_id() -> int:
			return self.get_u32(0, 0)

		func get_name() -> String:
			return self.get_text(0, "")

		func get_tags() -> Array[String]:
			var lr: CapnReader.ListReader = self.get_list(1)
			var out: Array[String] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_text(i)
			return out

		func get_scores() -> PackedInt32Array:
			return self.get_list(2).to_int32_array()

		func get_child() -> Child.Reader:
			var r: Child.Reader = Child.Reader.new()
			self.fill_struct(3, r)
			return r

		func get_kind() -> Kind:
			return self.get_u16(4, 0) as Kind

		func status_which() -> int:
			return self.get_u16(6, 0)

		func is_status_active() -> bool:
			return self.get_u16(6, 0) == 0

		func is_status_banned() -> bool:
			return self.get_u16(6, 0) == 1

		func get_status_banned() -> String:
			return self.get_text(4, "")

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

		func set_scores(value: PackedInt32Array) -> void:
			var lb: CapnBuilder.ListBuilder = _b.init_list(2, CapnPointer.ElemSize.FOUR_BYTES, value.size())
			lb.set_int32_array(value)

		func init_child() -> Child.Builder:
			return Child.Builder.wrap(_b.init_struct(3, Child.DATA_WORDS, Child.PTR_WORDS))

		func set_kind(value: Kind) -> void:
			_b.set_u16(4, value, 0)

		func set_status_active() -> void:
			_b.set_u16(6, 0, 0)

		func set_status_banned(value: String) -> void:
			_b.set_u16(6, 1, 0)
			_b.set_text(4, value)


static func read_child(bytes: PackedByteArray, packed: bool = false) -> Child.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Child.Reader = Child.Reader.new()
	msg.fill_root(r)
	return r

static func new_child() -> Child.Builder:
	return Child.Builder.wrap(CapnBuilder.new_message(Child.DATA_WORDS, Child.PTR_WORDS))

static func read_root(bytes: PackedByteArray, packed: bool = false) -> Root.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Root.Reader = Root.Reader.new()
	msg.fill_root(r)
	return r

static func new_root() -> Root.Builder:
	return Root.Builder.wrap(CapnBuilder.new_message(Root.DATA_WORDS, Root.PTR_WORDS))
