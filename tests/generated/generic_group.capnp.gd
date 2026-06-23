class_name GenericGroupCapnp extends RefCounted

## GENERATED from generic_group.capnp by capnpc-gdscript — do not edit.

class Box extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func has_holder_value() -> bool:
			return self.has_ptr(0)

		func get_holder_value_struct() -> CapnReader.StructReader:
			return self.get_struct(0)

		func get_holder_value_list() -> CapnReader.ListReader:
			return self.get_list(0)

		func get_holder_value_text() -> String:
			return self.get_text(0, "")

		func get_holder_value_data() -> PackedByteArray:
			return self.get_data(0)

		func get_holder_label() -> String:
			return self.get_text(1, "")

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_holder_value_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			return self.init_struct(0, data_words, ptr_words)

		func init_holder_value_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			return self.init_list(0, elem_size, count)

		func init_holder_value_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			return self.init_composite_list(0, count, data_words, ptr_words)

		func set_holder_value_text(value: String) -> void:
			self.set_text(0, value)

		func set_holder_value_data(value: PackedByteArray) -> void:
			self.set_data(0, value)

		func set_holder_label(value: String) -> void:
			self.set_text(1, value)

class Tagged extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1
	enum Body { ITEM, COUNT }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func body_which() -> int:
			return self.get_u16(0, 0)

		func is_body_item() -> bool:
			return self.get_u16(0, 0) == 0

		func has_body_item() -> bool:
			return self.has_ptr(0)

		func get_body_item_struct() -> CapnReader.StructReader:
			return self.get_struct(0)

		func get_body_item_list() -> CapnReader.ListReader:
			return self.get_list(0)

		func get_body_item_text() -> String:
			return self.get_text(0, "")

		func get_body_item_data() -> PackedByteArray:
			return self.get_data(0)

		func is_body_count() -> bool:
			return self.get_u16(0, 0) == 1

		func get_body_count() -> int:
			return self.get_i32(4, 0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_body_item_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			self.set_u16(0, 0, 0)
			return self.init_struct(0, data_words, ptr_words)

		func init_body_item_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			self.set_u16(0, 0, 0)
			return self.init_list(0, elem_size, count)

		func init_body_item_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			self.set_u16(0, 0, 0)
			return self.init_composite_list(0, count, data_words, ptr_words)

		func set_body_item_text(value: String) -> void:
			self.set_u16(0, 0, 0)
			self.set_text(0, value)

		func set_body_item_data(value: PackedByteArray) -> void:
			self.set_u16(0, 0, 0)
			self.set_data(0, value)

		func set_body_count(value: int) -> void:
			self.set_u16(0, 1, 0)
			self.set_i32(4, value, 0)

class Holder extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_inner_boxed() -> Box_Text.Reader:
			var r: Box_Text.Reader = Box_Text.Reader.new()
			self.fill_struct(0, r)
			return r

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_inner_boxed() -> Box_Text.Builder:
			var b: Box_Text.Builder = Box_Text.Builder.new()
			self.fill_struct(0, Box_Text.DATA_WORDS, Box_Text.PTR_WORDS, b)
			return b

class Use extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_box_text() -> Box_Text.Reader:
			var r: Box_Text.Reader = Box_Text.Reader.new()
			self.fill_struct(0, r)
			return r

		func get_tagged_text() -> Tagged_Text.Reader:
			var r: Tagged_Text.Reader = Tagged_Text.Reader.new()
			self.fill_struct(1, r)
			return r

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_box_text() -> Box_Text.Builder:
			var b: Box_Text.Builder = Box_Text.Builder.new()
			self.fill_struct(0, Box_Text.DATA_WORDS, Box_Text.PTR_WORDS, b)
			return b

		func init_tagged_text() -> Tagged_Text.Builder:
			var b: Tagged_Text.Builder = Tagged_Text.Builder.new()
			self.fill_struct(1, Tagged_Text.DATA_WORDS, Tagged_Text.PTR_WORDS, b)
			return b

class Box_Text extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_holder_value() -> String:
			return self.get_text(0, "")

		func get_holder_label() -> String:
			return self.get_text(1, "")

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_holder_value(value: String) -> void:
			self.set_text(0, value)

		func set_holder_label(value: String) -> void:
			self.set_text(1, value)

class Tagged_Text extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1
	enum Body { ITEM, COUNT }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func body_which() -> int:
			return self.get_u16(0, 0)

		func is_body_item() -> bool:
			return self.get_u16(0, 0) == 0

		func get_body_item() -> String:
			return self.get_text(0, "")

		func is_body_count() -> bool:
			return self.get_u16(0, 0) == 1

		func get_body_count() -> int:
			return self.get_i32(4, 0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_body_item(value: String) -> void:
			self.set_u16(0, 0, 0)
			self.set_text(0, value)

		func set_body_count(value: int) -> void:
			self.set_u16(0, 1, 0)
			self.set_i32(4, value, 0)


static func read_box(bytes: PackedByteArray, packed: bool = false) -> Box.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Box.Reader = Box.Reader.new()
	msg.fill_root(r)
	return r

static func new_box() -> Box.Builder:
	return Box.Builder.wrap(CapnBuilder.new_message(Box.DATA_WORDS, Box.PTR_WORDS))

static func read_tagged(bytes: PackedByteArray, packed: bool = false) -> Tagged.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Tagged.Reader = Tagged.Reader.new()
	msg.fill_root(r)
	return r

static func new_tagged() -> Tagged.Builder:
	return Tagged.Builder.wrap(CapnBuilder.new_message(Tagged.DATA_WORDS, Tagged.PTR_WORDS))

static func read_holder(bytes: PackedByteArray, packed: bool = false) -> Holder.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Holder.Reader = Holder.Reader.new()
	msg.fill_root(r)
	return r

static func new_holder() -> Holder.Builder:
	return Holder.Builder.wrap(CapnBuilder.new_message(Holder.DATA_WORDS, Holder.PTR_WORDS))

static func read_use(bytes: PackedByteArray, packed: bool = false) -> Use.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Use.Reader = Use.Reader.new()
	msg.fill_root(r)
	return r

static func new_use() -> Use.Builder:
	return Use.Builder.wrap(CapnBuilder.new_message(Use.DATA_WORDS, Use.PTR_WORDS))
