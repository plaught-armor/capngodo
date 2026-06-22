extends GutTest

## Reads the real CodeGeneratorRequest that `capnp compile -o-` produced for
## samples/addressbook.capnp, and verifies the meta-schema reader extracts the
## schema graph: structs, fields, slot types, a nested enum, and a union.
## Fixture: tests/fixtures/addressbook.cgr.bin (committed; regenerate with capnp).


var _cgr: CapnReader.StructReader = null


func before_all() -> void:
	var f: FileAccess = FileAccess.open("res://tests/fixtures/addressbook.cgr.bin", FileAccess.READ)
	assert_not_null(f, "addressbook.cgr.bin present")
	if f == null:
		return
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	_cgr = CapnSchema.open_request(bytes)
	assert_not_null(_cgr, "CodeGeneratorRequest opened")


func _find_node(simple_name: String) -> CapnReader.StructReader:
	var nodes: CapnReader.ListReader = CapnSchema.cgr_nodes(_cgr)
	for i: int in nodes.size():
		var n: CapnReader.StructReader = nodes.get_struct(i)
		if CapnSchema.node_unqualified_name(n) == simple_name:
			return n
	return null


func _find_field(node: CapnReader.StructReader, name: String) -> CapnReader.StructReader:
	var fields: CapnReader.ListReader = CapnSchema.node_struct_fields(node)
	for i: int in fields.size():
		var fld: CapnReader.StructReader = fields.get_struct(i)
		if CapnSchema.field_name(fld) == name:
			return fld
	return null


func _find_node_by_id(id: int) -> CapnReader.StructReader:
	var nodes: CapnReader.ListReader = CapnSchema.cgr_nodes(_cgr)
	for i: int in nodes.size():
		var n: CapnReader.StructReader = nodes.get_struct(i)
		if CapnSchema.node_id(n) == id:
			return n
	return null


func test_requested_file_is_addressbook() -> void:
	var reqs: CapnReader.ListReader = CapnSchema.cgr_requested_files(_cgr)
	assert_gt(reqs.size(), 0, "has a requested file")
	assert_string_contains(CapnSchema.req_file_name(reqs.get_struct(0)), "addressbook.capnp")


func test_person_struct_and_field_types() -> void:
	var person: CapnReader.StructReader = _find_node("Person")
	assert_not_null(person, "found Person node")
	if person == null:
		return
	assert_eq(CapnSchema.node_which(person), CapnSchema.NodeWhich.STRUCT, "Person is a struct")

	var id_field: CapnReader.StructReader = _find_field(person, "id")
	assert_not_null(id_field, "Person.id exists")
	assert_eq(CapnSchema.field_which(id_field), CapnSchema.FieldWhich.SLOT, "id is a slot")
	assert_eq(CapnSchema.type_which(CapnSchema.field_slot_type(id_field)), CapnSchema.TypeWhich.UINT32, "id : UInt32")

	var name_field: CapnReader.StructReader = _find_field(person, "name")
	assert_eq(CapnSchema.type_which(CapnSchema.field_slot_type(name_field)), CapnSchema.TypeWhich.TEXT, "name : Text")

	var phones_field: CapnReader.StructReader = _find_field(person, "phones")
	var phones_type: CapnReader.StructReader = CapnSchema.field_slot_type(phones_field)
	assert_eq(CapnSchema.type_which(phones_type), CapnSchema.TypeWhich.LIST, "phones : List")
	# Element type of the list is a struct (PhoneNumber).
	var elem: CapnReader.StructReader = CapnSchema.type_list_element(phones_type)
	assert_eq(CapnSchema.type_which(elem), CapnSchema.TypeWhich.STRUCT, "phones element : struct")


func test_person_employment_union() -> void:
	# An anonymous `union` is a GROUP field whose group-type node carries the
	# discriminant + the union member fields (this is the path M5 codegen walks).
	var person: CapnReader.StructReader = _find_node("Person")
	if person == null:
		return
	var employment: CapnReader.StructReader = _find_field(person, "employment")
	assert_not_null(employment, "Person.employment exists")
	assert_eq(CapnSchema.field_which(employment), CapnSchema.FieldWhich.GROUP, "employment is a group")

	var group: CapnReader.StructReader = _find_node_by_id(CapnSchema.field_group_type_id(employment))
	assert_not_null(group, "resolved the group's type node")
	if group == null:
		return
	assert_gt(CapnSchema.node_struct_discriminant_count(group), 0, "group carries a union")

	var employer: CapnReader.StructReader = _find_field(group, "employer")
	assert_not_null(employer, "employer field exists in the group")
	assert_true(CapnSchema.field_in_union(employer), "employer is a union member")
	assert_eq(CapnSchema.type_which(CapnSchema.field_slot_type(employer)), CapnSchema.TypeWhich.TEXT, "employer : Text")
	# A non-union struct field reports no discriminant.
	assert_false(CapnSchema.field_in_union(_find_field(person, "id")), "id is not in a union")


func test_phone_number_type_enum() -> void:
	var type_enum: CapnReader.StructReader = _find_node("Type")
	assert_not_null(type_enum, "found PhoneNumber.Type enum node")
	if type_enum == null:
		return
	assert_eq(CapnSchema.node_which(type_enum), CapnSchema.NodeWhich.ENUM, "Type is an enum")
	var enumerants: CapnReader.ListReader = CapnSchema.node_enum_enumerants(type_enum)
	assert_eq(enumerants.size(), 3, "3 enumerants")
	assert_eq(CapnSchema.enumerant_name(enumerants.get_struct(0)), "mobile")
	assert_eq(CapnSchema.enumerant_name(enumerants.get_struct(1)), "home")
	assert_eq(CapnSchema.enumerant_name(enumerants.get_struct(2)), "work")


func test_address_book_struct() -> void:
	var ab: CapnReader.StructReader = _find_node("AddressBook")
	assert_not_null(ab, "found AddressBook node")
	if ab == null:
		return
	var people: CapnReader.StructReader = _find_field(ab, "people")
	assert_not_null(people, "AddressBook.people exists")
	assert_eq(CapnSchema.type_which(CapnSchema.field_slot_type(people)), CapnSchema.TypeWhich.LIST, "people : List")
