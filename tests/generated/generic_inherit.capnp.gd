class_name GenericInheritCapnp extends RefCounted

## GENERATED from generic_inherit.capnp by capnpc-gdscript — do not edit.

class Outer extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_inner() -> Outer_Inner.Reader:
			var r: Outer_Inner.Reader = Outer_Inner.Reader.new()
			self.fill_struct(0, r)
			return r

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_inner() -> Outer_Inner.Builder:
			return Outer_Inner.Builder.wrap(_b.init_struct(0, Outer_Inner.DATA_WORDS, Outer_Inner.PTR_WORDS))

class Outer_Inner extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func has_value() -> bool:
			return self.has_ptr(0)

		func get_value_struct() -> CapnReader.StructReader:
			return self.get_struct(0)

		func get_value_list() -> CapnReader.ListReader:
			return self.get_list(0)

		func get_value_text() -> String:
			return self.get_text(0, "")

		func get_value_data() -> PackedByteArray:
			return self.get_data(0)

		func get_label() -> String:
			return self.get_text(1, "")

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_value_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			return _b.init_struct(0, data_words, ptr_words)

		func init_value_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(0, elem_size, count)

		func init_value_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			return _b.init_composite_list(0, count, data_words, ptr_words)

		func set_value_text(value: String) -> void:
			_b.set_text(0, value)

		func set_value_data(value: PackedByteArray) -> void:
			_b.set_data(0, value)

		func set_label(value: String) -> void:
			_b.set_text(1, value)

class Use extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_o() -> Outer_Text.Reader:
			var r: Outer_Text.Reader = Outer_Text.Reader.new()
			self.fill_struct(0, r)
			return r

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_o() -> Outer_Text.Builder:
			return Outer_Text.Builder.wrap(_b.init_struct(0, Outer_Text.DATA_WORDS, Outer_Text.PTR_WORDS))

class Outer_Text extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_inner() -> Outer_Inner_Text.Reader:
			var r: Outer_Inner_Text.Reader = Outer_Inner_Text.Reader.new()
			self.fill_struct(0, r)
			return r

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_inner() -> Outer_Inner_Text.Builder:
			return Outer_Inner_Text.Builder.wrap(_b.init_struct(0, Outer_Inner_Text.DATA_WORDS, Outer_Inner_Text.PTR_WORDS))

class Outer_Inner_Text extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_value() -> String:
			return self.get_text(0, "")

		func get_label() -> String:
			return self.get_text(1, "")

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_value(value: String) -> void:
			_b.set_text(0, value)

		func set_label(value: String) -> void:
			_b.set_text(1, value)


static func read_outer(bytes: PackedByteArray, packed: bool = false) -> Outer.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Outer.Reader = Outer.Reader.new()
	msg.fill_root(r)
	return r

static func new_outer() -> Outer.Builder:
	return Outer.Builder.wrap(CapnBuilder.new_message(Outer.DATA_WORDS, Outer.PTR_WORDS))

static func read_use(bytes: PackedByteArray, packed: bool = false) -> Use.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Use.Reader = Use.Reader.new()
	msg.fill_root(r)
	return r

static func new_use() -> Use.Builder:
	return Use.Builder.wrap(CapnBuilder.new_message(Use.DATA_WORDS, Use.PTR_WORDS))
