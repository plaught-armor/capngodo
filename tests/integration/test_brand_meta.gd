extends GutTest
## CG1b step 1: the meta_schema Brand / anyPointer.parameter accessors, verified
## against a real capnp CGR (tests/fixtures/generic.cgr.bin, from generic.capnp:
## Box(T){value,label}; Container{boxedText:Box(Text); boxedStruct:Box(Inner);
## boxedList:Box(List(Int32))}). Confirms every wire offset in docs/CG1B_PLAN.md.

func _cgr() -> CapnReader.StructReader:
	var f: FileAccess = FileAccess.open("res://tests/fixtures/generic.cgr.bin", FileAccess.READ)
	assert_not_null(f, "generic.cgr.bin present")
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return CapnSchema.open_request(b)


func _find_node(cgr: CapnReader.StructReader, uname: String) -> CapnReader.StructReader:
	var nodes: CapnReader.ListReader = CapnSchema.cgr_nodes(cgr)
	for i: int in nodes.size():
		var n: CapnReader.StructReader = nodes.get_struct(i)
		if CapnSchema.node_unqualified_name(n) == uname:
			return n
	return null


func _field(node: CapnReader.StructReader, fname: String) -> CapnReader.StructReader:
	var fields: CapnReader.ListReader = CapnSchema.node_struct_fields(node)
	for i: int in fields.size():
		var f: CapnReader.StructReader = fields.get_struct(i)
		if CapnSchema.field_name(f) == fname:
			return f
	return null


func test_brand_binding_resolves_to_text() -> void:
	var cgr: CapnReader.StructReader = _cgr()
	var container: CapnReader.StructReader = _find_node(cgr, "Container")
	assert_not_null(container, "found Container node")
	var t: CapnReader.StructReader = CapnSchema.field_slot_type(_field(container, "boxedText"))
	assert_eq(CapnSchema.type_which(t), CapnSchema.TypeWhich.STRUCT, "boxedText is a struct (Box)")

	var scopes: CapnReader.ListReader = CapnSchema.brand_scopes(CapnSchema.type_brand(t))
	assert_true(scopes.size() >= 1, "brand carries a scope")
	var scope: CapnReader.StructReader = scopes.get_struct(0)
	assert_eq(CapnSchema.scope_which(scope), CapnSchema.BrandScopeWhich.BIND, "scope binds")
	var binds: CapnReader.ListReader = CapnSchema.scope_bind(scope)
	assert_eq(binds.size(), 1, "one binding (T)")
	var binding: CapnReader.StructReader = binds.get_struct(0)
	assert_eq(CapnSchema.binding_which(binding), CapnSchema.BindingWhich.TYPE, "binding is a type")
	assert_eq(CapnSchema.type_which(CapnSchema.binding_type(binding)), CapnSchema.TypeWhich.TEXT, "T bound to Text")


func test_brand_binding_resolves_to_struct() -> void:
	var cgr: CapnReader.StructReader = _cgr()
	var container: CapnReader.StructReader = _find_node(cgr, "Container")
	var t: CapnReader.StructReader = CapnSchema.field_slot_type(_field(container, "boxedStruct"))
	var binding: CapnReader.StructReader = CapnSchema.scope_bind(CapnSchema.brand_scopes(CapnSchema.type_brand(t)).get_struct(0)).get_struct(0)
	var bound: CapnReader.StructReader = CapnSchema.binding_type(binding)
	assert_eq(CapnSchema.type_which(bound), CapnSchema.TypeWhich.STRUCT, "T bound to a struct")
	assert_eq(CapnSchema.type_id(bound), CapnSchema.node_id(_find_node(cgr, "Inner")), "bound to Inner")


func test_parameter_field_references_box_param() -> void:
	var cgr: CapnReader.StructReader = _cgr()
	var box: CapnReader.StructReader = _find_node(cgr, "Box")
	var t: CapnReader.StructReader = CapnSchema.field_slot_type(_field(box, "value"))
	assert_eq(CapnSchema.type_which(t), CapnSchema.TypeWhich.ANY_POINTER, "value is anyPointer")
	assert_eq(CapnSchema.type_anyptr_which(t), CapnSchema.AnyPtrWhich.PARAMETER, "it's a type parameter")
	assert_eq(CapnSchema.anyptr_param_scope_id(t), CapnSchema.node_id(box), "scope = Box's id")
	assert_eq(CapnSchema.anyptr_param_index(t), 0, "param index 0 (T)")
