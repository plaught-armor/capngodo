class_name GenericIfaceCapnp extends RefCounted

## GENERATED from generic_iface.capnp by capnpc-gdscript — do not edit.

class Box extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

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

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_value_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:
			return self.init_struct(0, data_words, ptr_words)

		func init_value_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:
			return self.init_list(0, elem_size, count)

		func init_value_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:
			return self.init_composite_list(0, count, data_words, ptr_words)

		func set_value_text(value: String) -> void:
			self.set_text(0, value)

		func set_value_data(value: PackedByteArray) -> void:
			self.set_data(0, value)

class Use extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_h() -> Box_Handle.Reader:
			var r: Box_Handle.Reader = Box_Handle.Reader.new()
			self.fill_struct(0, r)
			return r

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_h() -> Box_Handle.Builder:
			var b: Box_Handle.Builder = Box_Handle.Builder.new()
			self.fill_struct(0, Box_Handle.DATA_WORDS, Box_Handle.PTR_WORDS, b)
			return b

class Box_Handle extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_value() -> int:
			return self.get_cap_index(0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		# capability 'value' is read-only (serialization only, no RPC)


static func read_box(bytes: PackedByteArray, packed: bool = false) -> Box.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Box.Reader = Box.Reader.new()
	msg.fill_root(r)
	return r

static func new_box() -> Box.Builder:
	return Box.Builder.wrap(CapnBuilder.new_message(Box.DATA_WORDS, Box.PTR_WORDS))

static func read_use(bytes: PackedByteArray, packed: bool = false) -> Use.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Use.Reader = Use.Reader.new()
	msg.fill_root(r)
	return r

static func new_use() -> Use.Builder:
	return Use.Builder.wrap(CapnBuilder.new_message(Use.DATA_WORDS, Use.PTR_WORDS))
