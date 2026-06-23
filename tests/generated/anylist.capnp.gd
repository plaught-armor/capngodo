class_name AnylistCapnp extends RefCounted

## GENERATED from anylist.capnp by capnpc-gdscript — do not edit.

class Bag extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_rows() -> CapnReader.ListReader:
			return _r.get_list(0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_rows(n: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(0, CapnPointer.ElemSize.POINTER, n)


static func read_bag(bytes: PackedByteArray, packed: bool = false) -> Bag.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Bag.Reader.wrap(msg.get_root())

static func new_bag() -> Bag.Builder:
	return Bag.Builder.wrap(CapnBuilder.new_message(Bag.DATA_WORDS, Bag.PTR_WORDS))
