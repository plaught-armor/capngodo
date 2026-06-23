class_name GenericGroupCapnp extends RefCounted

## GENERATED from generic_group.capnp by capnpc-gdscript — do not edit.

class Box extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func has_holder_value() -> bool:
			return _r.has_ptr(0)

		func get_holder_value_struct() -> CapnReader.StructReader:
			return _r.get_struct(0)

		func get_holder_value_list() -> CapnReader.ListReader:
			return _r.get_list(0)

		func get_holder_value_text() -> String:
			return _r.get_text(0, "")

		func get_holder_value_data() -> PackedByteArray:
			return _r.get_data(0)

		func get_holder_label() -> String:
			return _r.get_text(1, "")

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_holder_value_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			return _b.init_struct(0, data_words, ptr_words)

		func init_holder_value_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(0, elem_size, count)

		func init_holder_value_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			return _b.init_composite_list(0, count, data_words, ptr_words)

		func set_holder_value_text(value: String) -> void:
			_b.set_text(0, value)

		func set_holder_value_data(value: PackedByteArray) -> void:
			_b.set_data(0, value)

		func set_holder_label(value: String) -> void:
			_b.set_text(1, value)

class Tagged extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1
	enum Body { ITEM, COUNT }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func body_which() -> int:
			return _r.get_u16(0, 0)

		func is_body_item() -> bool:
			return _r.get_u16(0, 0) == 0

		func has_body_item() -> bool:
			return _r.has_ptr(0)

		func get_body_item_struct() -> CapnReader.StructReader:
			return _r.get_struct(0)

		func get_body_item_list() -> CapnReader.ListReader:
			return _r.get_list(0)

		func get_body_item_text() -> String:
			return _r.get_text(0, "")

		func get_body_item_data() -> PackedByteArray:
			return _r.get_data(0)

		func is_body_count() -> bool:
			return _r.get_u16(0, 0) == 1

		func get_body_count() -> int:
			return _r.get_i32(4, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_body_item_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			_b.set_u16(0, 0, 0)
			return _b.init_struct(0, data_words, ptr_words)

		func init_body_item_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			_b.set_u16(0, 0, 0)
			return _b.init_list(0, elem_size, count)

		func init_body_item_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			_b.set_u16(0, 0, 0)
			return _b.init_composite_list(0, count, data_words, ptr_words)

		func set_body_item_text(value: String) -> void:
			_b.set_u16(0, 0, 0)
			_b.set_text(0, value)

		func set_body_item_data(value: PackedByteArray) -> void:
			_b.set_u16(0, 0, 0)
			_b.set_data(0, value)

		func set_body_count(value: int) -> void:
			_b.set_u16(0, 1, 0)
			_b.set_i32(4, value, 0)

class Holder extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_inner_boxed() -> Box_Text.Reader:
			return Box_Text.Reader.wrap(_r.get_struct(0))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_inner_boxed() -> Box_Text.Builder:
			return Box_Text.Builder.wrap(_b.init_struct(0, Box_Text.DATA_WORDS, Box_Text.PTR_WORDS))

class Use extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_box_text() -> Box_Text.Reader:
			return Box_Text.Reader.wrap(_r.get_struct(0))

		func get_tagged_text() -> Tagged_Text.Reader:
			return Tagged_Text.Reader.wrap(_r.get_struct(1))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_box_text() -> Box_Text.Builder:
			return Box_Text.Builder.wrap(_b.init_struct(0, Box_Text.DATA_WORDS, Box_Text.PTR_WORDS))

		func init_tagged_text() -> Tagged_Text.Builder:
			return Tagged_Text.Builder.wrap(_b.init_struct(1, Tagged_Text.DATA_WORDS, Tagged_Text.PTR_WORDS))

class Box_Text extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_holder_value() -> String:
			return _r.get_text(0, "")

		func get_holder_label() -> String:
			return _r.get_text(1, "")

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_holder_value(value: String) -> void:
			_b.set_text(0, value)

		func set_holder_label(value: String) -> void:
			_b.set_text(1, value)

class Tagged_Text extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1
	enum Body { ITEM, COUNT }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func body_which() -> int:
			return _r.get_u16(0, 0)

		func is_body_item() -> bool:
			return _r.get_u16(0, 0) == 0

		func get_body_item() -> String:
			return _r.get_text(0, "")

		func is_body_count() -> bool:
			return _r.get_u16(0, 0) == 1

		func get_body_count() -> int:
			return _r.get_i32(4, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_body_item(value: String) -> void:
			_b.set_u16(0, 0, 0)
			_b.set_text(0, value)

		func set_body_count(value: int) -> void:
			_b.set_u16(0, 1, 0)
			_b.set_i32(4, value, 0)


static func read_box(bytes: PackedByteArray, packed: bool = false) -> Box.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Box.Reader.wrap(msg.get_root())

static func new_box() -> Box.Builder:
	return Box.Builder.wrap(CapnBuilder.new_message(Box.DATA_WORDS, Box.PTR_WORDS))

static func read_tagged(bytes: PackedByteArray, packed: bool = false) -> Tagged.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Tagged.Reader.wrap(msg.get_root())

static func new_tagged() -> Tagged.Builder:
	return Tagged.Builder.wrap(CapnBuilder.new_message(Tagged.DATA_WORDS, Tagged.PTR_WORDS))

static func read_holder(bytes: PackedByteArray, packed: bool = false) -> Holder.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Holder.Reader.wrap(msg.get_root())

static func new_holder() -> Holder.Builder:
	return Holder.Builder.wrap(CapnBuilder.new_message(Holder.DATA_WORDS, Holder.PTR_WORDS))

static func read_use(bytes: PackedByteArray, packed: bool = false) -> Use.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Use.Reader.wrap(msg.get_root())

static func new_use() -> Use.Builder:
	return Use.Builder.wrap(CapnBuilder.new_message(Use.DATA_WORDS, Use.PTR_WORDS))
