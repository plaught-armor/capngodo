class_name AnylistCapnp extends RefCounted

## GENERATED from anylist.capnp by capnpc-gdscript — do not edit.

class Bag extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 1

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_rows() -> CapnReader.ListReader:
			return self.get_list(0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_rows(n: int) -> CapnBuilder.ListBuilder:
			return self.init_list(0, CapnPointer.ElemSize.POINTER, n)


static func read_bag(bytes: PackedByteArray, packed: bool = false) -> Bag.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Bag.Reader = Bag.Reader.new()
	msg.fill_root(r)
	return r

static func new_bag() -> Bag.Builder:
	return Bag.Builder.wrap(CapnBuilder.new_message(Bag.DATA_WORDS, Bag.PTR_WORDS))
