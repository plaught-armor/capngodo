extends GutTest
## CG11 — a *group* arm inside a *named* union. Distinct from CG3/CG4, which
## cover a group arm of the anonymous struct-level union. Here `Command.body` is
## a named union whose `chat` / `move` arms are groups and `quit` is a void slot
## arm. Each group leaf flattens to get_/set_body_<arm>_<field>(), and every leaf
## setter writes `body`'s discriminant so selecting any leaf selects the arm.
## Uses the generated NamedUnionGroupCapnp (from tests/golden/named_union_group.capnp).

func test_group_arm_round_trips_and_selects_the_arm() -> void:
	var c: NamedUnionGroupCapnp.Command.Builder = NamedUnionGroupCapnp.new_command()
	c.set_id(7)
	c.set_body_chat_sender("alice")
	c.set_body_chat_text("hi")

	var r: NamedUnionGroupCapnp.Command.Reader = NamedUnionGroupCapnp.read_command(c.to_bytes())
	assert_eq(r.get_id(), 7, "scalar field outside the union")
	assert_eq(r.body_which(), NamedUnionGroupCapnp.Command.Body.CHAT, "discriminant = chat")
	assert_true(r.is_body_chat(), "chat arm selected")
	assert_false(r.is_body_move(), "move arm not selected")
	assert_eq(r.get_body_chat_sender(), "alice", "group leaf: sender")
	assert_eq(r.get_body_chat_text(), "hi", "group leaf: text")


func test_setting_a_second_group_arm_reselects() -> void:
	# A leaf setter on a different arm rewrites the discriminant — selecting move
	# after chat must flip body_which() and read back the move fields.
	var c: NamedUnionGroupCapnp.Command.Builder = NamedUnionGroupCapnp.new_command()
	c.set_body_chat_sender("ignored")
	c.set_body_move_dx(3)
	c.set_body_move_dy(-4)

	var r: NamedUnionGroupCapnp.Command.Reader = NamedUnionGroupCapnp.read_command(c.to_bytes())
	assert_eq(r.body_which(), NamedUnionGroupCapnp.Command.Body.MOVE, "last arm set wins")
	assert_true(r.is_body_move(), "move arm selected")
	assert_eq(r.get_body_move_dx(), 3, "group leaf: dx")
	assert_eq(r.get_body_move_dy(), -4, "group leaf: dy")


func test_void_slot_arm_selects_without_payload() -> void:
	var c: NamedUnionGroupCapnp.Command.Builder = NamedUnionGroupCapnp.new_command()
	c.set_body_quit()

	var r: NamedUnionGroupCapnp.Command.Reader = NamedUnionGroupCapnp.read_command(c.to_bytes())
	assert_eq(r.body_which(), NamedUnionGroupCapnp.Command.Body.QUIT, "discriminant = quit")
	assert_true(r.is_body_quit(), "quit arm selected")
	assert_false(r.is_body_chat(), "chat arm not selected")


func test_codegen_matches_committed_golden() -> void:
	# Generator output for the CG11 schema must equal the committed reader, or the
	# named-union group-arm emission drifted.
	var f: FileAccess = FileAccess.open("res://tests/fixtures/named_union_group.cgr.bin", FileAccess.READ)
	assert_not_null(f, "fixture present")
	if f == null:
		return
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var cgr: CapnReader.StructReader = CapnSchema.open_request(bytes)
	var files: Dictionary = CapnCodegen.generate_files(cgr)
	assert_true(files.has("named_union_group.capnp.gd"), "generated the umbrella file")

	var g: FileAccess = FileAccess.open("res://tests/generated/named_union_group.capnp.gd", FileAccess.READ)
	assert_not_null(g, "committed golden present")
	if g == null:
		return
	var committed: String = g.get_as_text()
	g.close()
	assert_eq(files["named_union_group.capnp.gd"], committed, "generator output matches committed golden")
