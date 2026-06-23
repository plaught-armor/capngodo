class_name GenericCapnp extends RefCounted

## GENERATED from generic.capnp by capnpc-gdscript — do not edit.

class Inner extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 0

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_n() -> int:
			return self.get_i32(0, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_n(value: int) -> void:
			_b.set_i32(0, value, 0)

class Box extends RefCounted:
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

class Container_ extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 5
	enum Which { OPT_PTR, OPT_NUM }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o
		func which() -> int:
			return self.get_u16(0, 0)

		func get_boxed_text() -> Box_Text.Reader:
			var r: Box_Text.Reader = Box_Text.Reader.new()
			self.fill_struct(0, r)
			return r

		func get_boxed_struct() -> Box_Inner.Reader:
			var r: Box_Inner.Reader = Box_Inner.Reader.new()
			self.fill_struct(1, r)
			return r

		func get_boxed_list() -> Box_List_Int32.Reader:
			var r: Box_List_Int32.Reader = Box_List_Int32.Reader.new()
			self.fill_struct(2, r)
			return r

		func has_raw() -> bool:
			return self.has_ptr(3)

		func get_raw_struct() -> CapnReader.StructReader:
			return self.get_struct(3)

		func get_raw_list() -> CapnReader.ListReader:
			return self.get_list(3)

		func get_raw_text() -> String:
			return self.get_text(3, "")

		func get_raw_data() -> PackedByteArray:
			return self.get_data(3)

		func is_opt_ptr() -> bool:
			return self.get_u16(0, 0) == 0

		func has_opt_ptr() -> bool:
			return self.has_ptr(4)

		func get_opt_ptr_struct() -> CapnReader.StructReader:
			return self.get_struct(4)

		func get_opt_ptr_list() -> CapnReader.ListReader:
			return self.get_list(4)

		func get_opt_ptr_text() -> String:
			return self.get_text(4, "")

		func get_opt_ptr_data() -> PackedByteArray:
			return self.get_data(4)

		func is_opt_num() -> bool:
			return self.get_u16(0, 0) == 1

		func get_opt_num() -> int:
			return self.get_i32(4, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_boxed_text() -> Box_Text.Builder:
			return Box_Text.Builder.wrap(_b.init_struct(0, Box_Text.DATA_WORDS, Box_Text.PTR_WORDS))

		func init_boxed_struct() -> Box_Inner.Builder:
			return Box_Inner.Builder.wrap(_b.init_struct(1, Box_Inner.DATA_WORDS, Box_Inner.PTR_WORDS))

		func init_boxed_list() -> Box_List_Int32.Builder:
			return Box_List_Int32.Builder.wrap(_b.init_struct(2, Box_List_Int32.DATA_WORDS, Box_List_Int32.PTR_WORDS))

		func init_raw_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			return _b.init_struct(3, data_words, ptr_words)

		func init_raw_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(3, elem_size, count)

		func init_raw_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			return _b.init_composite_list(3, count, data_words, ptr_words)

		func set_raw_text(value: String) -> void:
			_b.set_text(3, value)

		func set_raw_data(value: PackedByteArray) -> void:
			_b.set_data(3, value)

		func init_opt_ptr_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			_b.set_u16(0, 0, 0)
			return _b.init_struct(4, data_words, ptr_words)

		func init_opt_ptr_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			_b.set_u16(0, 0, 0)
			return _b.init_list(4, elem_size, count)

		func init_opt_ptr_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			_b.set_u16(0, 0, 0)
			return _b.init_composite_list(4, count, data_words, ptr_words)

		func set_opt_ptr_text(value: String) -> void:
			_b.set_u16(0, 0, 0)
			_b.set_text(4, value)

		func set_opt_ptr_data(value: PackedByteArray) -> void:
			_b.set_u16(0, 0, 0)
			_b.set_data(4, value)

		func set_opt_num(value: int) -> void:
			_b.set_u16(0, 1, 0)
			_b.set_i32(4, value, 0)

class Box_Text extends RefCounted:
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

class Box_Inner extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_value() -> Inner.Reader:
			var r: Inner.Reader = Inner.Reader.new()
			self.fill_struct(0, r)
			return r

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

		func init_value() -> Inner.Builder:
			return Inner.Builder.wrap(_b.init_struct(0, Inner.DATA_WORDS, Inner.PTR_WORDS))

		func set_label(value: String) -> void:
			_b.set_text(1, value)

class Box_List_Int32 extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_value() -> PackedInt32Array:
			return self.get_list(0).to_int32_array()

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

		func set_value(value: PackedInt32Array) -> void:
			var lb: CapnBuilder.ListBuilder = _b.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, value.size())
			lb.set_int32_array(value)

		func set_label(value: String) -> void:
			_b.set_text(1, value)


static func read_inner(bytes: PackedByteArray, packed: bool = false) -> Inner.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Inner.Reader = Inner.Reader.new()
	msg.fill_root(r)
	return r

static func new_inner() -> Inner.Builder:
	return Inner.Builder.wrap(CapnBuilder.new_message(Inner.DATA_WORDS, Inner.PTR_WORDS))

static func read_box(bytes: PackedByteArray, packed: bool = false) -> Box.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Box.Reader = Box.Reader.new()
	msg.fill_root(r)
	return r

static func new_box() -> Box.Builder:
	return Box.Builder.wrap(CapnBuilder.new_message(Box.DATA_WORDS, Box.PTR_WORDS))

static func read_container_(bytes: PackedByteArray, packed: bool = false) -> Container_.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Container_.Reader = Container_.Reader.new()
	msg.fill_root(r)
	return r

static func new_container_() -> Container_.Builder:
	return Container_.Builder.wrap(CapnBuilder.new_message(Container_.DATA_WORDS, Container_.PTR_WORDS))
