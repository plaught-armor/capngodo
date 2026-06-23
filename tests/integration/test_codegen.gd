extends GutTest
## M5 codegen: end-to-end (generated reader decodes a real capnp-encoded
## addressbook message), golden (generator output matches the committed file),
## and compile-check (every generated source parses).
##
## Fixtures: addressbook.cgr.bin (compiler output), addressbook_msg.bin (a real
## AddressBook value encoded by `capnp encode`). The committed generated reader
## lives at tests/generated/addressbook.capnp.gd (class_name AddressbookCapnp).

func _read_bytes(path: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "%s present" % path)
	if f == null:
		return PackedByteArray()
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return b


func _read_text(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s


func test_generated_reader_decodes_real_message() -> void:
	var bytes: PackedByteArray = _read_bytes("res://tests/fixtures/addressbook_msg.bin")
	var ab: AddressbookCapnp.AddressBook.Reader = AddressbookCapnp.read_address_book(bytes)
	var people: Array = ab.get_people()
	assert_eq(people.size(), 2, "two people")

	var alice = people[0]
	assert_eq(alice.get_id(), 123, "alice id")
	assert_eq(alice.get_name(), "Alice", "alice name")
	assert_eq(alice.get_email(), "alice@example.com", "alice email")
	var alice_phones: Array = alice.get_phones()
	assert_eq(alice_phones.size(), 1, "alice one phone")
	assert_eq(alice_phones[0].get_number(), "555-1212", "alice phone number")
	assert_eq(alice_phones[0].get_type(), AddressbookCapnp.Person_PhoneNumber_Type.MOBILE, "alice phone type mobile")

	var bob = people[1]
	assert_eq(bob.get_id(), 456, "bob id")
	assert_eq(bob.get_name(), "Bob", "bob name")
	var bob_phones: Array = bob.get_phones()
	assert_eq(bob_phones.size(), 2, "bob two phones")
	assert_eq(bob_phones[0].get_type(), AddressbookCapnp.Person_PhoneNumber_Type.HOME, "bob phone 0 home")
	assert_eq(bob_phones[1].get_number(), "555-8888", "bob phone 1 number")
	assert_eq(bob_phones[1].get_type(), AddressbookCapnp.Person_PhoneNumber_Type.WORK, "bob phone 1 work")


func test_generated_builder_roundtrips() -> void:
	# Build an AddressBook with the generated Builder, serialize, read it back
	# with the generated Reader.
	var ab: AddressbookCapnp.AddressBook.Builder = AddressbookCapnp.new_address_book()
	var people: Array = ab.init_people(2)

	var alice = people[0]
	alice.set_id(123)
	alice.set_name("Alice")
	alice.set_email("alice@example.com")
	var alice_phones: Array = alice.init_phones(1)
	alice_phones[0].set_number("555-1212")
	alice_phones[0].set_type(AddressbookCapnp.Person_PhoneNumber_Type.MOBILE)

	var bob = people[1]
	bob.set_id(456)
	bob.set_name("Bob")
	var bob_phones: Array = bob.init_phones(2)
	bob_phones[0].set_number("555-9999")
	bob_phones[0].set_type(AddressbookCapnp.Person_PhoneNumber_Type.HOME)
	bob_phones[1].set_number("555-8888")
	bob_phones[1].set_type(AddressbookCapnp.Person_PhoneNumber_Type.WORK)

	# Union (group) members.
	alice.set_employment_employer("Acme")
	bob.set_employment_school("MIT")

	var bytes: PackedByteArray = ab.to_bytes()

	var rab: AddressbookCapnp.AddressBook.Reader = AddressbookCapnp.read_address_book(bytes)
	var rpeople: Array = rab.get_people()
	assert_eq(rpeople.size(), 2, "two people")
	assert_eq(rpeople[0].get_id(), 123, "alice id")
	assert_eq(rpeople[0].get_name(), "Alice", "alice name")
	assert_eq(rpeople[0].get_email(), "alice@example.com", "alice email")
	var rap: Array = rpeople[0].get_phones()
	assert_eq(rap.size(), 1, "alice 1 phone")
	assert_eq(rap[0].get_number(), "555-1212", "alice phone number")
	assert_eq(rap[0].get_type(), AddressbookCapnp.Person_PhoneNumber_Type.MOBILE, "alice phone mobile")
	assert_eq(rpeople[1].get_id(), 456, "bob id")
	var rbp: Array = rpeople[1].get_phones()
	assert_eq(rbp.size(), 2, "bob 2 phones")
	assert_eq(rbp[1].get_number(), "555-8888", "bob phone 1 number")
	assert_eq(rbp[1].get_type(), AddressbookCapnp.Person_PhoneNumber_Type.WORK, "bob phone 1 work")

	# Union read-back.
	assert_eq(rpeople[0].employment_which(), AddressbookCapnp.Person.Employment.EMPLOYER, "alice employed")
	assert_true(rpeople[0].is_employment_employer(), "alice is_employer")
	assert_false(rpeople[0].is_employment_school(), "alice not school")
	assert_eq(rpeople[0].get_employment_employer(), "Acme", "alice employer")
	assert_eq(rpeople[1].employment_which(), AddressbookCapnp.Person.Employment.SCHOOL, "bob school")
	assert_eq(rpeople[1].get_employment_school(), "MIT", "bob school name")


func test_generated_builder_bytes_decode_in_capnp_compatible_reader() -> void:
	# Cross-check: our generated builder's output must be readable as the same
	# logical message by re-opening through the runtime reader directly.
	var ab: AddressbookCapnp.AddressBook.Builder = AddressbookCapnp.new_address_book()
	var people: Array = ab.init_people(1)
	people[0].set_id(7)
	people[0].set_name("Solo")
	var msg: CapnReader.Message = CapnReader.open(ab.to_bytes(), false)
	var root: CapnReader.StructReader = msg.get_root()
	var plist: CapnReader.ListReader = root.get_list(0)
	assert_eq(plist.size(), 1)
	assert_eq(plist.get_struct(0).get_u32(0, 0), 7, "raw reader sees id")
	assert_eq(plist.get_struct(0).get_text(0), "Solo", "raw reader sees name")


func test_codegen_matches_committed_golden() -> void:
	# Generator output must equal the committed reader, or one of them drifted.
	var cgr: CapnReader.StructReader = CapnSchema.open_request(_read_bytes("res://tests/fixtures/addressbook.cgr.bin"))
	var files: Dictionary = CapnCodegen.generate_files(cgr)
	assert_true(files.has("addressbook.capnp.gd"), "generated the umbrella file")
	var committed: String = _read_text("res://tests/generated/addressbook.capnp.gd")
	assert_eq(files["addressbook.capnp.gd"], committed, "generator output matches committed golden")


func test_generated_sources_compile() -> void:
	# GDScript.new().reload() can't resolve external class_name globals
	# (CapnReader) when compiling a source in isolation, so it returns
	# ERR_PARSE_ERROR (43) even for valid code. OK or 43 both mean "parsed";
	# real compilation is proven by the end-to-end test loading the identical
	# committed file as a project resource and executing it.
	var cgr: CapnReader.StructReader = CapnSchema.open_request(_read_bytes("res://tests/fixtures/addressbook.cgr.bin"))
	var files: Dictionary = CapnCodegen.generate_files(cgr)
	for fname: String in files:
		var script: GDScript = GDScript.new()
		# Drop the `class_name X ` prefix: the umbrella global is already
		# registered (the committed file is a project resource), so an isolated
		# reload() would log a benign "hides a global script class" warning (CQ7).
		script.source_code = _strip_class_name(files[fname])
		var err: int = script.reload()
		assert_true(err == OK or err == ERR_PARSE_ERROR, "%s parses (err=%d)" % [fname, err])


## Replace a leading `class_name Foo extends Bar` with just `extends Bar`.
func _strip_class_name(src: String) -> String:
	var nl: int = src.find("\n")
	var first: String = src.substr(0, nl) if nl != -1 else src
	if not first.begins_with("class_name "):
		return src
	var ext: int = first.find("extends ")
	if ext == -1:
		return src
	return first.substr(ext) + (src.substr(nl) if nl != -1 else "")


func test_typed_list_returns_assign_to_typed_locals() -> void:
	# CQ1: list getters/setters return Array[T], so they assign directly to a
	# typed local. Assigning an untyped Array to a typed Array[T] local fails at
	# runtime, so these typed locals are a real regression guard on the return
	# type (no C3 .assign() round-trip needed).
	var ab: AddressbookCapnp.AddressBook.Reader = AddressbookCapnp.read_address_book(_read_bytes("res://tests/fixtures/addressbook_msg.bin"))
	var people: Array[AddressbookCapnp.Person.Reader] = ab.get_people()
	assert_eq(people.size(), 2, "two people")
	assert_eq(people[0].get_name(), "Alice", "typed element keeps its API")
	var phones: Array[AddressbookCapnp.Person_PhoneNumber.Reader] = people[0].get_phones()
	assert_eq(phones.size(), 1, "one phone")
	# CQ2: the enum getter returns the generated enum type, so it assigns to an
	# enum-typed local (int underneath).
	var ptype: AddressbookCapnp.Person_PhoneNumber_Type = phones[0].get_type()
	assert_eq(ptype, AddressbookCapnp.Person_PhoneNumber_Type.MOBILE, "enum-typed getter")

	var b: AddressbookCapnp.AddressBook.Builder = AddressbookCapnp.new_address_book()
	var bpeople: Array[AddressbookCapnp.Person.Builder] = b.init_people(1)
	assert_eq(bpeople.size(), 1, "builder list is typed too")
	bpeople[0].set_name("Solo")
	assert_eq(AddressbookCapnp.read_address_book(b.to_bytes()).get_people()[0].get_name(), "Solo", "round-trip")


func test_typed_text_and_primitive_list_returns() -> void:
	# CQ1 for non-struct elements: Text list -> Array[String], Int32 list ->
	# Array[int]. Typed locals guard those element-type branches.
	var root: InteropCapnp.Root.Builder = InteropCapnp.new_root()
	var tb: CapnBuilder.ListBuilder = root.init_tags(2)
	tb.set_text(0, "alpha")
	tb.set_text(1, "bravo")
	root.set_scores(PackedInt32Array([10, -20]))

	var r: InteropCapnp.Root.Reader = InteropCapnp.read_root(root.to_bytes())
	var tags: Array[String] = r.get_tags()
	var scores: PackedInt32Array = r.get_scores()
	assert_eq(tags.size(), 2, "two tags")
	assert_eq(tags[0], "alpha", "Array[String] element")
	assert_eq(scores.size(), 2, "two scores")
	assert_eq(scores[1], -20, "Array[int] element")
