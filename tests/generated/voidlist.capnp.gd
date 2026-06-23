class_name VoidlistCapnp extends RefCounted

## GENERATED from voidlist.capnp by capnpc-gdscript — do not edit.

class Pings extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 2

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_voids() -> Array:
			var lr: CapnReader.ListReader = self.get_list(0)
			var out: Array = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = null
			return out

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

		func init_voids(n: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(0, CapnPointer.ElemSize.VOID, n)

		func set_label(value: String) -> void:
			_b.set_text(1, value)


static func read_pings(bytes: PackedByteArray, packed: bool = false) -> Pings.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Pings.Reader = Pings.Reader.new()
	msg.fill_root(r)
	return r

static func new_pings() -> Pings.Builder:
	return Pings.Builder.wrap(CapnBuilder.new_message(Pings.DATA_WORDS, Pings.PTR_WORDS))
