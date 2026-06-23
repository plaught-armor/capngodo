class_name ReservedCapnp extends RefCounted

## GENERATED from reserved.capnp by capnpc-gdscript — do not edit.

enum Color_ { RED, GREEN, BLUE }

enum Math { PI_, TAU_, E }

class Node_ extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_value() -> int:
			return self.get_i32(0, 0)

		func get_class_() -> String:
			return self.get_text(0, "")

		func get_color() -> Color_:
			return self.get_u16(4, 0) as Color_

		func get_instance_id_() -> int:
			return self.get_i32(8, 0)

		func get_kind() -> Math:
			return self.get_u16(6, 0) as Math

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_value(value: int) -> void:
			self.set_i32(0, value, 0)

		func set_class_(value: String) -> void:
			self.set_text(0, value)

		func set_color(value: Color_) -> void:
			self.set_u16(4, value, 0)

		func set_instance_id_(value: int) -> void:
			self.set_i32(8, value, 0)

		func set_kind(value: Math) -> void:
			self.set_u16(6, value, 0)

class Holder extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_child() -> Node_.Reader:
			var r: Node_.Reader = Node_.Reader.new()
			self.fill_struct(0, r)
			return r

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_child() -> Node_.Builder:
			var b: Node_.Builder = Node_.Builder.new()
			self.fill_struct(0, Node_.DATA_WORDS, Node_.PTR_WORDS, b)
			return b


static func read_node_(bytes: PackedByteArray, packed: bool = false) -> Node_.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Node_.Reader = Node_.Reader.new()
	msg.fill_root(r)
	return r

static func new_node_() -> Node_.Builder:
	return Node_.Builder.wrap(CapnBuilder.new_message(Node_.DATA_WORDS, Node_.PTR_WORDS))

static func read_holder(bytes: PackedByteArray, packed: bool = false) -> Holder.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Holder.Reader = Holder.Reader.new()
	msg.fill_root(r)
	return r

static func new_holder() -> Holder.Builder:
	return Holder.Builder.wrap(CapnBuilder.new_message(Holder.DATA_WORDS, Holder.PTR_WORDS))
