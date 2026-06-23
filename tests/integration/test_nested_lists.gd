extends GutTest

## CG10 — nested + pointer-element lists. A List(List(T)) outer is a pointer list
## whose elements point to inner lists. The reader exposes each element as a lazy
## CapnReader.ListReader (read inner elements with typed getters); the builder
## hands back the outer ListBuilder so the caller fills inner lists via
## init_list_at / init_composite_list_at. List(interface) decodes to cap-table
## indices (serialization-only — no setter). Uses the generated NestedListsCapnp.


func test_nested_primitive_list_round_trips() -> void:
	var nb: NestedListsCapnp.Nested.Builder = NestedListsCapnp.new_nested()
	var m: CapnBuilder.ListBuilder = nb.init_matrix(2)
	var r0: CapnBuilder.ListBuilder = m.init_list_at(0, CapnPointer.ElemSize.FOUR_BYTES, 3)
	r0.set_i32(0, 1)
	r0.set_i32(1, 2)
	r0.set_i32(2, 3)
	var r1: CapnBuilder.ListBuilder = m.init_list_at(1, CapnPointer.ElemSize.FOUR_BYTES, 2)
	r1.set_i32(0, 4)
	r1.set_i32(1, 5)

	var r: NestedListsCapnp.Nested.Reader = NestedListsCapnp.read_nested(nb.to_bytes())
	var mat: Array[CapnReader.ListReader] = r.get_matrix()
	assert_eq(mat.size(), 2, "outer matrix length")
	assert_eq(mat[0].size(), 3, "row 0 length")
	assert_eq(mat[0].get_i32(0), 1, "matrix[0][0]")
	assert_eq(mat[0].get_i32(2), 3, "matrix[0][2]")
	assert_eq(mat[1].size(), 2, "row 1 length")
	assert_eq(mat[1].get_i32(1), 5, "matrix[1][1]")


func test_nested_text_list_round_trips() -> void:
	var nb: NestedListsCapnp.Nested.Builder = NestedListsCapnp.new_nested()
	var rows: CapnBuilder.ListBuilder = nb.init_rows(2)
	var t0: CapnBuilder.ListBuilder = rows.init_list_at(0, CapnPointer.ElemSize.POINTER, 2)
	t0.set_text(0, "alpha")
	t0.set_text(1, "beta")
	var t1: CapnBuilder.ListBuilder = rows.init_list_at(1, CapnPointer.ElemSize.POINTER, 1)
	t1.set_text(0, "gamma")

	var r: NestedListsCapnp.Nested.Reader = NestedListsCapnp.read_nested(nb.to_bytes())
	var rd: Array[CapnReader.ListReader] = r.get_rows()
	assert_eq(rd.size(), 2, "outer rows length")
	assert_eq(rd[0].get_text(0), "alpha", "rows[0][0]")
	assert_eq(rd[0].get_text(1), "beta", "rows[0][1]")
	assert_eq(rd[1].get_text(0), "gamma", "rows[1][0]")


func test_nested_struct_list_round_trips() -> void:
	var nb: NestedListsCapnp.Nested.Builder = NestedListsCapnp.new_nested()
	var cells: CapnBuilder.ListBuilder = nb.init_cells(2)
	var c0: CapnBuilder.ListBuilder = cells.init_composite_list_at(
		0, 1, NestedListsCapnp.Cell.DATA_WORDS, NestedListsCapnp.Cell.PTR_WORDS
	)
	NestedListsCapnp.Cell.Builder.wrap(c0.init_struct(0)).set_v(10)
	var c1: CapnBuilder.ListBuilder = cells.init_composite_list_at(
		1, 2, NestedListsCapnp.Cell.DATA_WORDS, NestedListsCapnp.Cell.PTR_WORDS
	)
	NestedListsCapnp.Cell.Builder.wrap(c1.init_struct(0)).set_v(20)
	NestedListsCapnp.Cell.Builder.wrap(c1.init_struct(1)).set_v(30)

	var r: NestedListsCapnp.Nested.Reader = NestedListsCapnp.read_nested(nb.to_bytes())
	var cd: Array[CapnReader.ListReader] = r.get_cells()
	assert_eq(cd.size(), 2, "outer cells length")
	assert_eq(cd[0].size(), 1, "cells[0] length")
	assert_eq(NestedListsCapnp.Cell.Reader.wrap(cd[0].get_struct(0)).get_v(), 10, "cells[0][0].v")
	assert_eq(cd[1].size(), 2, "cells[1] length")
	assert_eq(NestedListsCapnp.Cell.Reader.wrap(cd[1].get_struct(1)).get_v(), 30, "cells[1][1].v")


func test_empty_nested_list() -> void:
	var nb: NestedListsCapnp.Nested.Builder = NestedListsCapnp.new_nested()
	nb.init_matrix(0)
	var r: NestedListsCapnp.Nested.Reader = NestedListsCapnp.read_nested(nb.to_bytes())
	assert_eq(r.get_matrix().size(), 0, "zero-length outer list")


func test_interface_list_unset_is_empty_and_typed() -> void:
	# List(interface) has no setter (serialization-only); an unset list reads as an
	# empty Array[int]. The cap-index path itself is exercised by the wire reader.
	var nb: NestedListsCapnp.Nested.Builder = NestedListsCapnp.new_nested()
	var r: NestedListsCapnp.Nested.Reader = NestedListsCapnp.read_nested(nb.to_bytes())
	var handles: Array[int] = r.get_handles()
	assert_eq(handles.size(), 0, "unset capability list is empty")


func test_interface_list_decodes_cap_indices() -> void:
	# No builder-side cap setter (serialization-only), so hand-poke self-contained
	# cap pointers into the handles pointer list to actually exercise the
	# ListReader.get_cap_index decode path on a populated list.
	var nb: NestedListsCapnp.Nested.Builder = NestedListsCapnp.new_nested()
	var lb: CapnBuilder.ListBuilder = nb.init_list(3, CapnPointer.ElemSize.POINTER, 2)
	lb.arena._put(lb.seg_id, lb.first_elem_word + 0, CapnPointer.encode_cap(0))
	lb.arena._put(lb.seg_id, lb.first_elem_word + 1, CapnPointer.encode_cap(7))

	var r: NestedListsCapnp.Nested.Reader = NestedListsCapnp.read_nested(nb.to_bytes())
	var handles: Array[int] = r.get_handles()
	assert_eq(handles.size(), 2, "two capability entries")
	assert_eq(handles[0], 0, "handles[0] cap index")
	assert_eq(handles[1], 7, "handles[1] cap index")
