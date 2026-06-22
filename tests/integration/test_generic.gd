extends GutTest

## Generics (CG1a): a type parameter is a plain pointer on the wire, so a
## parameter-typed field gets type-erased accessors — get_<f>_struct/list/text/
## data() on the reader, init_<f>_struct/list/composite_list + set_<f>_text/data
## on the builder. The caller resolves the concrete kind from the binding it
## knows statically. An explicit `:AnyPointer` field is the same shape.
## Uses the generated GenericCapnp (from tests/golden/generic.capnp):
##   Box(T) { value @0 :T; label @1 :Text; }
##   Container { boxedText :Box(Text); boxedStruct :Box(Inner);
##               boxedList :Box(List(Int32)); raw :AnyPointer; }


func test_erased_text_param_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var bt: GenericCapnp.Box.Builder = c.init_boxed_text()
	bt.set_value_text("hello")          # T = Text -> erased text setter
	bt.set_label("greeting")            # concrete field alongside the parameter

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	var rbt: GenericCapnp.Box.Reader = r.get_boxed_text()
	assert_true(rbt.has_value(), "value pointer present")
	assert_eq(rbt.get_value_text(), "hello", "erased text param")
	assert_eq(rbt.get_label(), "greeting", "concrete label intact")


func test_erased_struct_param_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var bs: GenericCapnp.Box.Builder = c.init_boxed_struct()
	# T = Inner: allocate the pointee raw, then wrap in the concrete Builder.
	var inner: GenericCapnp.Inner.Builder = GenericCapnp.Inner.Builder.wrap(
		bs.init_value_struct(GenericCapnp.Inner.DATA_WORDS, GenericCapnp.Inner.PTR_WORDS)
	)
	inner.set_n(99)
	bs.set_label("struct-box")

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	var rbs: GenericCapnp.Box.Reader = r.get_boxed_struct()
	assert_eq(rbs.get_label(), "struct-box", "label intact")
	var rinner: GenericCapnp.Inner.Reader = GenericCapnp.Inner.Reader.wrap(rbs.get_value_struct())
	assert_eq(rinner.get_n(), 99, "erased struct param field")


func test_erased_list_param_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var bl: GenericCapnp.Box.Builder = c.init_boxed_list()
	# T = List(Int32): erased list init, fill via the raw ListBuilder.
	var lb: CapnBuilder.ListBuilder = bl.init_value_list(CapnPointer.ElemSize.FOUR_BYTES, 3)
	lb.set_i32(0, 10)
	lb.set_i32(1, 20)
	lb.set_i32(2, 30)

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	var lr: CapnReader.ListReader = r.get_boxed_list().get_value_list()
	assert_eq(lr.size(), 3, "list length")
	assert_eq(lr.get_i32(0), 10, "elem 0")
	assert_eq(lr.get_i32(1), 20, "elem 1")
	assert_eq(lr.get_i32(2), 30, "elem 2")


func test_explicit_anypointer_data_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var payload: PackedByteArray = [0xDE, 0xAD, 0xBE, 0xEF]
	c.set_raw_data(payload)             # AnyPointer written as a Data payload

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	assert_true(r.has_raw(), "raw pointer present")
	assert_eq(r.get_raw_data(), payload, "erased AnyPointer data")


func test_anypointer_union_arm_writes_discriminant() -> void:
	# An AnyPointer field inside a struct-level union: each erased setter must
	# select the outer discriminant before writing the pointer.
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	c.set_opt_ptr_text("chosen")

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	assert_eq(r.which(), GenericCapnp.Container_.Which.OPT_PTR, "optPtr arm selected")
	assert_true(r.is_opt_ptr(), "is_opt_ptr")
	assert_false(r.is_opt_num(), "not opt_num")
	assert_eq(r.get_opt_ptr_text(), "chosen", "erased text in union arm")


func test_anypointer_union_sibling_arm() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	c.set_opt_num(42)

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	assert_eq(r.which(), GenericCapnp.Container_.Which.OPT_NUM, "optNum arm selected")
	assert_true(r.is_opt_num(), "is_opt_num")
	assert_eq(r.get_opt_num(), 42, "sibling scalar arm")


func test_unset_param_reports_absent() -> void:
	# A freshly-built Container sets no pointers -> every erased getter is empty.
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	assert_false(r.has_raw(), "raw absent when unset")
	assert_false(r.get_boxed_text().has_value(), "box value absent when unset")
	assert_eq(r.get_raw_text(), "", "absent text reads empty")
	assert_eq(r.get_raw_data(), PackedByteArray(), "absent data reads empty")
