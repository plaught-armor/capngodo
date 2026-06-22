class_name CommonCapnp extends RefCounted

## GENERATED from common.capnp by capnpc-gdscript — do not edit.

class Point extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 0

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_x() -> int:
			return _r.get_i32(0, 0)

		func get_y() -> int:
			return _r.get_i32(4, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_x(value: int) -> void:
			_b.set_i32(0, value, 0)

		func set_y(value: int) -> void:
			_b.set_i32(4, value, 0)


static func read_point(bytes: PackedByteArray, packed: bool = false) -> Point.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Point.Reader.wrap(msg.get_root())

static func new_point() -> Point.Builder:
	return Point.Builder.wrap(CapnBuilder.new_message(Point.DATA_WORDS, Point.PTR_WORDS))
