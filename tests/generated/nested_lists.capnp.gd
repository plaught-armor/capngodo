class_name NestedListsCapnp extends RefCounted

## GENERATED from nested_lists.capnp by capnpc-gdscript — do not edit.

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

class Nested extends RefCounted:
	const DATA_WORDS: int = 0
	const PTR_WORDS: int = 4

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_matrix() -> Array[CapnReader.ListReader]:
			var lr: CapnReader.ListReader = _r.get_list(0)
			var out: Array[CapnReader.ListReader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_list(i)
			return out

		func get_rows() -> Array[CapnReader.ListReader]:
			var lr: CapnReader.ListReader = _r.get_list(1)
			var out: Array[CapnReader.ListReader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_list(i)
			return out

		func get_cells() -> Array[CapnReader.ListReader]:
			var lr: CapnReader.ListReader = _r.get_list(2)
			var out: Array[CapnReader.ListReader] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_list(i)
			return out

		func get_handles() -> Array[int]:
			var lr: CapnReader.ListReader = _r.get_list(3)
			var out: Array[int] = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = lr.get_cap_index(i)
			return out

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func init_matrix(n: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(0, CapnPointer.ElemSize.POINTER, n)

		func init_rows(n: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(1, CapnPointer.ElemSize.POINTER, n)

		func init_cells(n: int) -> CapnBuilder.ListBuilder:
			return _b.init_list(2, CapnPointer.ElemSize.POINTER, n)

		# init 'handles' omitted: List(interface) is read-only (capability)


static func read_cell(bytes: PackedByteArray, packed: bool = false) -> Cell.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Cell.Reader.wrap(msg.get_root())

static func new_cell() -> Cell.Builder:
	return Cell.Builder.wrap(CapnBuilder.new_message(Cell.DATA_WORDS, Cell.PTR_WORDS))

static func read_nested(bytes: PackedByteArray, packed: bool = false) -> Nested.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Nested.Reader.wrap(msg.get_root())

static func new_nested() -> Nested.Builder:
	return Nested.Builder.wrap(CapnBuilder.new_message(Nested.DATA_WORDS, Nested.PTR_WORDS))
