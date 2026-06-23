extends GutTest
## Generics. Two layers over the generated GenericCapnp (tests/golden/generic.capnp):
##   Box(T) { value @0 :T; label @1 :Text; }
##   Container { boxedText :Box(Text); boxedStruct :Box(Inner);
##               boxedList :Box(List(Int32)); raw :AnyPointer; union { optPtr; optNum } }
##
## CG1a (erased floor): the generic Box itself is a plain pointer on the wire, so
## its parameter field gets type-erased accessors — get_value_struct/list/text/
## data() / init_value_*/set_value_text|data(). Reached via the top-level
## new_box()/read_box(); the unbound fallback. An explicit `:AnyPointer` field
## (Container.raw) is the same shape.
##
## CG1b (monomorphized): a concrete instantiation resolves to a fully-typed class
## — Box(Text) -> Box_Text with get_value()->String, Box(Inner) -> Box_Inner with
## get_value()->Inner.Reader, Box(List(Int32)) -> Box_List_Int32 with
## get_value()->Array[int]. Container's branded fields return the mono types.

# --- CG1a: erased floor (top-level Box) ----------------------------------

func test_erased_box_text_round_trips() -> void:
	var b: GenericCapnp.Box.Builder = GenericCapnp.new_box()
	b.set_value_text("hello") # T erased -> text setter
	b.set_label("greeting")

	var r: GenericCapnp.Box.Reader = GenericCapnp.read_box(b.to_bytes())
	assert_true(r.has_value(), "value pointer present")
	assert_eq(r.get_value_text(), "hello", "erased text param")
	assert_eq(r.get_label(), "greeting", "concrete label intact")


func test_erased_box_struct_round_trips() -> void:
	var b: GenericCapnp.Box.Builder = GenericCapnp.new_box()
	var inner: GenericCapnp.Inner.Builder = GenericCapnp.Inner.Builder.wrap(
		b.init_value_struct(GenericCapnp.Inner.DATA_WORDS, GenericCapnp.Inner.PTR_WORDS),
	)
	inner.set_n(99)

	var r: GenericCapnp.Box.Reader = GenericCapnp.read_box(b.to_bytes())
	var rinner: GenericCapnp.Inner.Reader = GenericCapnp.Inner.Reader.wrap(r.get_value_struct())
	assert_eq(rinner.get_n(), 99, "erased struct param field")


func test_erased_box_list_round_trips() -> void:
	var b: GenericCapnp.Box.Builder = GenericCapnp.new_box()
	var lb: CapnBuilder.ListBuilder = b.init_value_list(CapnPointer.ElemSize.FOUR_BYTES, 3)
	lb.set_i32(0, 10)
	lb.set_i32(1, 20)
	lb.set_i32(2, 30)

	var r: GenericCapnp.Box.Reader = GenericCapnp.read_box(b.to_bytes())
	var lr: CapnReader.ListReader = r.get_value_list()
	assert_eq(lr.size(), 3, "list length")
	assert_eq(lr.get_i32(2), 30, "elem 2")

# --- CG1b: monomorphic typed instantiations (via Container) ---------------


func test_mono_box_text_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var bt: GenericCapnp.Box_Text.Builder = c.init_boxed_text()
	bt.set_value("hello") # typed String setter, not erased
	bt.set_label("greeting")

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	var rbt: GenericCapnp.Box_Text.Reader = r.get_boxed_text()
	assert_eq(rbt.get_value(), "hello", "typed text param -> String")
	assert_eq(rbt.get_label(), "greeting", "concrete label intact")


func test_mono_box_struct_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var bs: GenericCapnp.Box_Inner.Builder = c.init_boxed_struct()
	bs.init_value().set_n(99) # typed Inner.Builder, no raw data/ptr words
	bs.set_label("struct-box")

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	var rbs: GenericCapnp.Box_Inner.Reader = r.get_boxed_struct()
	assert_eq(rbs.get_label(), "struct-box", "label intact")
	assert_eq(rbs.get_value().get_n(), 99, "typed struct param -> Inner.Reader")


func test_mono_box_list_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var bl: GenericCapnp.Box_List_Int32.Builder = c.init_boxed_list()
	bl.set_value(PackedInt32Array([10, 20, 30]))

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	var vals: PackedInt32Array = r.get_boxed_list().get_value()
	assert_eq(vals, PackedInt32Array([10, 20, 30]), "typed list param -> PackedInt32Array")


func test_mono_box_text_unset_reads_empty() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	assert_eq(r.get_boxed_text().get_value(), "", "absent typed param reads empty")

# --- AnyPointer (explicit, unconstrained) — stays erased ------------------


func test_explicit_anypointer_data_round_trips() -> void:
	var c: GenericCapnp.Container_.Builder = GenericCapnp.new_container_()
	var payload: PackedByteArray = [0xDE, 0xAD, 0xBE, 0xEF]
	c.set_raw_data(payload)

	var r: GenericCapnp.Container_.Reader = GenericCapnp.read_container_(c.to_bytes())
	assert_true(r.has_raw(), "raw pointer present")
	assert_eq(r.get_raw_data(), payload, "erased AnyPointer data")


func test_anypointer_union_arm_writes_discriminant() -> void:
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
