class_name GenericNestedCapnp extends RefCounted

## GENERATED from generic_nested.capnp by capnpc-gdscript — do not edit.

class Cell extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 0

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_v() -> int:
			return _r.get_i32(0, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_v(value: int) -> void:
			_b.set_i32(0, value, 0)

class Box extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func has_value() -> bool:
			return _r.has_ptr(0)

		func get_value_struct() -> CapnReader.StructReader:
			return _r.get_struct(0)

		func get_value_list() -> CapnReader.ListReader:
			return _r.get_list(0)

		func get_value_text() -> String:
			return _r.get_text(0, "")

		func get_value_data() -> PackedByteArray:
			return _r.get_data(0)

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

class Holder extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_bb() -> Box_Box_Text.Reader:
			return Box_Box_Text.Reader.wrap(_r.get_struct(0))

		func get_bbc() -> Box_Box_Cell.Reader:
			return Box_Box_Cell.Reader.wrap(_r.get_struct(1))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_bb() -> Box_Box_Text.Builder:
			return Box_Box_Text.Builder.wrap(_b.init_struct(0, Box_Box_Text.DATA_WORDS, Box_Box_Text.PTR_WORDS))

		func init_bbc() -> Box_Box_Cell.Builder:
			return Box_Box_Cell.Builder.wrap(_b.init_struct(1, Box_Box_Cell.DATA_WORDS, Box_Box_Cell.PTR_WORDS))

class Box_Text extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_value() -> String:
			return _r.get_text(0, "")

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

class Box_Box_Text extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_value() -> Box_Text.Reader:
			return Box_Text.Reader.wrap(_r.get_struct(0))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_value() -> Box_Text.Builder:
			return Box_Text.Builder.wrap(_b.init_struct(0, Box_Text.DATA_WORDS, Box_Text.PTR_WORDS))

class Box_Cell extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_value() -> Cell.Reader:
			return Cell.Reader.wrap(_r.get_struct(0))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_value() -> Cell.Builder:
			return Cell.Builder.wrap(_b.init_struct(0, Cell.DATA_WORDS, Cell.PTR_WORDS))

class Box_Box_Cell extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_value() -> Box_Cell.Reader:
			return Box_Cell.Reader.wrap(_r.get_struct(0))

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_value() -> Box_Cell.Builder:
			return Box_Cell.Builder.wrap(_b.init_struct(0, Box_Cell.DATA_WORDS, Box_Cell.PTR_WORDS))


static func read_cell(bytes: PackedByteArray, packed: bool = false) -> Cell.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Cell.Reader.wrap(msg.get_root())

static func new_cell() -> Cell.Builder:
	return Cell.Builder.wrap(CapnBuilder.new_message(Cell.DATA_WORDS, Cell.PTR_WORDS))

static func read_box(bytes: PackedByteArray, packed: bool = false) -> Box.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Box.Reader.wrap(msg.get_root())

static func new_box() -> Box.Builder:
	return Box.Builder.wrap(CapnBuilder.new_message(Box.DATA_WORDS, Box.PTR_WORDS))

static func read_holder(bytes: PackedByteArray, packed: bool = false) -> Holder.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Holder.Reader.wrap(msg.get_root())

static func new_holder() -> Holder.Builder:
	return Holder.Builder.wrap(CapnBuilder.new_message(Holder.DATA_WORDS, Holder.PTR_WORDS))
