class_name NestedListsCapnp extends RefCounted

## GENERATED from nested_lists.capnp by capnpc-gdscript — do not edit.

class Cell extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 0

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_v() -> int:
			return self.get_i32(0, 0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_v(value: int) -> void:
			self.set_i32(0, value, 0)

class Nested extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 4

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_matrix() -> Array[CapnReader.ListReader]:
			var lr: CapnReader.ListReader = self.get_list(0)
			var out: Array[CapnReader.ListReader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_list(i)
			return out

		func get_rows() -> Array[CapnReader.ListReader]:
			var lr: CapnReader.ListReader = self.get_list(1)
			var out: Array[CapnReader.ListReader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_list(i)
			return out

		func get_cells() -> Array[CapnReader.ListReader]:
			var lr: CapnReader.ListReader = self.get_list(2)
			var out: Array[CapnReader.ListReader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_list(i)
			return out

		func get_handles() -> Array[int]:
			var lr: CapnReader.ListReader = self.get_list(3)
			var out: Array[int] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_cap_index(i)
			return out

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func init_matrix(n: int) -> CapnBuilder.ListBuilder:
			return self.init_list(0, CapnPointer.ElemSize.POINTER, n)

		func init_rows(n: int) -> CapnBuilder.ListBuilder:
			return self.init_list(1, CapnPointer.ElemSize.POINTER, n)

		func init_cells(n: int) -> CapnBuilder.ListBuilder:
			return self.init_list(2, CapnPointer.ElemSize.POINTER, n)

		# init 'handles' omitted: List(interface) is read-only (capability)


static func read_cell(bytes: PackedByteArray, packed: bool = false) -> Cell.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Cell.Reader = Cell.Reader.new()
	msg.fill_root(r)
	return r

static func new_cell() -> Cell.Builder:
	return Cell.Builder.wrap(CapnBuilder.new_message(Cell.DATA_WORDS, Cell.PTR_WORDS))

static func read_nested(bytes: PackedByteArray, packed: bool = false) -> Nested.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: Nested.Reader = Nested.Reader.new()
	msg.fill_root(r)
	return r

static func new_nested() -> Nested.Builder:
	return Nested.Builder.wrap(CapnBuilder.new_message(Nested.DATA_WORDS, Nested.PTR_WORDS))
