extends GutTest
## Lazy reader API: StructReader.fill_list (reused ListReader) + StructListIter
## (reused element reader). Parity with the eager get_list / Array path, plus the
## view-lifetime contract (the yielded reader repositions each step).

const WORD_BYTES: int = 8


func _root(bb: CapnBuilder.StructBuilder) -> CapnReader.StructReader:
	return CapnReader.open(CapnBuilder.to_bytes(bb, false), false).get_root()

# --- fill_list parity ----------------------------------------------------


func test_fill_list_matches_get_list_primitive() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = bb.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 3)
	lb.set_i32(0, 7)
	lb.set_i32(1, 8)
	lb.set_i32(2, 9)
	var root: CapnReader.StructReader = _root(bb)
	var eager: CapnReader.ListReader = root.get_list(0)
	var reused: CapnReader.ListReader = CapnReader.ListReader.new()
	root.fill_list(0, reused)
	assert_eq(reused.size(), eager.size(), "count parity")
	for i: int in eager.size():
		assert_eq(reused.get_i32(i), eager.get_i32(i), "elem %d" % i)


func test_fill_list_matches_get_list_composite() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = bb.init_composite_list(0, 2, 1, 0)
	lb.init_struct(0).set_u32(0, 100, 0)
	lb.init_struct(1).set_u32(0, 200, 0)
	var root: CapnReader.StructReader = _root(bb)
	var reused: CapnReader.ListReader = CapnReader.ListReader.new()
	root.fill_list(0, reused)
	assert_eq(reused.size(), 2)
	assert_eq(reused.get_struct(0).get_u32(0, 0), 100)
	assert_eq(reused.get_struct(1).get_u32(0, 0), 200)


func test_fill_list_reuse_across_lists_resets() -> void:
	# A reused ListReader filled with a 3-list then a null pointer must report 0,
	# not leak the prior length/stride.
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 2)
	var lb: CapnBuilder.ListBuilder = bb.init_list(0, CapnPointer.ElemSize.FOUR_BYTES, 3)
	lb.set_i32(0, 1)
	lb.set_i32(1, 2)
	lb.set_i32(2, 3)
	# ptr 1 left null
	var root: CapnReader.StructReader = _root(bb)
	var reused: CapnReader.ListReader = CapnReader.ListReader.new()
	root.fill_list(0, reused)
	assert_eq(reused.size(), 3)
	root.fill_list(1, reused) # null pointer
	assert_eq(reused.size(), 0, "reset on null, no stale length")

# --- StructListIter ------------------------------------------------------


func test_iter_matches_eager_composite() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = bb.init_composite_list(0, 3, 1, 0)
	lb.init_struct(0).set_u32(0, 11, 0)
	lb.init_struct(1).set_u32(0, 22, 0)
	lb.init_struct(2).set_u32(0, 33, 0)
	var root: CapnReader.StructReader = _root(bb)
	var lr: CapnReader.ListReader = root.get_list(0)
	var elem: CapnReader.StructReader = CapnReader.StructReader.new()
	var got: Array[int] = []
	for e: CapnReader.StructReader in CapnReader.StructListIter.new(lr, elem):
		got.append(e.get_u32(0, 0))
	assert_eq(got, [11, 22, 33] as Array[int], "lazy iteration values")


func test_iter_empty_list_yields_nothing() -> void:
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	bb.init_composite_list(0, 0, 1, 0)
	var root: CapnReader.StructReader = _root(bb)
	var elem: CapnReader.StructReader = CapnReader.StructReader.new()
	var count: int = 0
	for e: CapnReader.StructReader in CapnReader.StructListIter.new(root.get_list(0), elem):
		count += 1
	assert_eq(count, 0, "empty list -> no iterations")


func test_iter_yields_reused_view() -> void:
	# Contract: the yielded reader repositions each step (it is one reused object).
	var bb: CapnBuilder.StructBuilder = CapnBuilder.new_message(0, 1)
	var lb: CapnBuilder.ListBuilder = bb.init_composite_list(0, 2, 1, 0)
	lb.init_struct(0).set_u32(0, 1, 0)
	lb.init_struct(1).set_u32(0, 2, 0)
	var root: CapnReader.StructReader = _root(bb)
	var elem: CapnReader.StructReader = CapnReader.StructReader.new()
	var seen: Array = []
	for e: CapnReader.StructReader in CapnReader.StructListIter.new(root.get_list(0), elem):
		seen.append(e) # retaining the view (the documented footgun)
	# All retained refs are the SAME object, now positioned at the last element.
	assert_same(seen[0], seen[1], "iterator reuses one reader object")
	assert_eq((seen[0] as CapnReader.StructReader).get_u32(0, 0), 2, "stale view = last element")
