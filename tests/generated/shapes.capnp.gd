class_name ShapesCapnp extends RefCounted

## GENERATED from shapes.capnp by capnpc-gdscript — do not edit.

class Line extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 3

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_start() -> CommonCapnp.Point.Reader:
			return CommonCapnp.Point.Reader.wrap(_r.get_struct(0))

		func get_end() -> CommonCapnp.Point.Reader:
			return CommonCapnp.Point.Reader.wrap(_r.get_struct(1))

		func get_label() -> String:
			return _r.get_text(2, "")

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_start() -> CommonCapnp.Point.Builder:
			return CommonCapnp.Point.Builder.wrap(_b.init_struct(0, CommonCapnp.Point.DATA_WORDS, CommonCapnp.Point.PTR_WORDS))

		func init_end() -> CommonCapnp.Point.Builder:
			return CommonCapnp.Point.Builder.wrap(_b.init_struct(1, CommonCapnp.Point.DATA_WORDS, CommonCapnp.Point.PTR_WORDS))

		func set_label(value: String) -> void:
			_b.set_text(2, value)


static func read_line(bytes: PackedByteArray, packed: bool = false) -> Line.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Line.Reader.wrap(msg.get_root())

static func new_line() -> Line.Builder:
	return Line.Builder.wrap(CapnBuilder.new_message(Line.DATA_WORDS, Line.PTR_WORDS))
