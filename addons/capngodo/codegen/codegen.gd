class_name CapnCodegen extends RefCounted

## Generates GDScript reader classes from a CodeGeneratorRequest (read via
## CapnSchema). One umbrella class per .capnp file, with every struct/enum
## flattened into an inner class / class-scoped enum — this sidesteps the
## cross-file class_name cycle problem (the same reason CapnReader is one file).
##
## Covered: readers + builders for struct/enum nodes; primitive / Text / Data /
## enum / nested-struct / List fields; struct-level and group unions; field
## defaults; named (non-union) groups (flattened to get_<group>_<field>());
## type-erased generic-parameter and AnyPointer fields. Remaining gaps tracked
## in docs/DEFERRED.md (generics monomorphization, interface fields, Data
## defaults, cross-file refs). Static-fn system (D9).
##
## generate_files(cgr) -> { "<file>.capnp.gd": "<source>" } for each requested file.

const TAB: String = "\t"


## A schema node to emit, with its flattened GDScript name (Person.PhoneNumber
## -> "Person_PhoneNumber"). POD record (D1).
class CodegenEntry extends RefCounted:
	var id: int
	var flat: String
	var node: CapnReader.StructReader
	var is_top: bool  # directly nested under the file node (gets read_/new_ entries)

	func _init(p_id: int, p_flat: String, p_node: CapnReader.StructReader, p_is_top: bool) -> void:
		id = p_id
		flat = p_flat
		node = p_node
		is_top = p_is_top


static func generate_files(cgr: CapnReader.StructReader) -> Dictionary[String, String]:
	var nodes_by_id: Dictionary[int, CapnReader.StructReader] = _index_nodes(cgr)
	var out: Dictionary[String, String] = {}
	var reqs: CapnReader.ListReader = CapnSchema.cgr_requested_files(cgr)
	for i: int in reqs.size():
		var rf: CapnReader.StructReader = reqs.get_struct(i)
		var fname: String = CapnSchema.req_file_name(rf)
		var file_node: CapnReader.StructReader = nodes_by_id.get(CapnSchema.req_file_id(rf))
		if file_node == null:
			push_error("[CapnCodegen] requested file node %d not found" % CapnSchema.req_file_id(rf))
			continue
		out[fname + ".gd"] = _emit_umbrella(fname, file_node, nodes_by_id)
	return out


# --- node collection -----------------------------------------------------

static func _index_nodes(cgr: CapnReader.StructReader) -> Dictionary[int, CapnReader.StructReader]:
	var by_id: Dictionary[int, CapnReader.StructReader] = {}
	var nodes: CapnReader.ListReader = CapnSchema.cgr_nodes(cgr)
	for i: int in nodes.size():
		var n: CapnReader.StructReader = nodes.get_struct(i)
		by_id[CapnSchema.node_id(n)] = n
	return by_id


## Walk the file's nested-node tree, building flat names (Person.PhoneNumber ->
## "Person_PhoneNumber"). Returns an ordered Array[CodegenEntry] and fills
## flat_by_id (node id -> flat name) for cross-references.
static func _collect(file_node: CapnReader.StructReader, by_id: Dictionary[int, CapnReader.StructReader], flat_by_id: Dictionary[int, String]) -> Array[CodegenEntry]:
	var result: Array[CodegenEntry] = []
	var used: Dictionary[String, bool] = {}
	_walk(file_node, "", by_id, result, flat_by_id, used)
	return result


static func _walk(node: CapnReader.StructReader, prefix: String, by_id: Dictionary[int, CapnReader.StructReader], result: Array[CodegenEntry], flat_by_id: Dictionary[int, String], used: Dictionary[String, bool]) -> void:
	var nested: CapnReader.ListReader = CapnSchema.node_nested_nodes(node)
	for i: int in nested.size():
		var nn: CapnReader.StructReader = nested.get_struct(i)
		var name: String = CapnSchema.nested_name(nn)
		var id: int = CapnSchema.nested_id(nn)
		var flat: String = _uniquify(_safe_type((prefix + "_" + name) if prefix != "" else name), used)
		var child: CapnReader.StructReader = by_id.get(id)
		if child == null:
			continue
		used[flat] = true
		flat_by_id[id] = flat
		result.append(CodegenEntry.new(id, flat, child, prefix == ""))
		_walk(child, flat, by_id, result, flat_by_id, used)


## Disambiguate a name that already exists (post-mangle or legitimate clash) by
## suffixing _2, _3, … so two schema types never produce the same GDScript class.
static func _uniquify(flat: String, used: Dictionary[String, bool]) -> String:
	if not used.has(flat):
		return flat
	var n: int = 2
	while used.has("%s_%d" % [flat, n]):
		n += 1
	push_warning("[CapnCodegen] generated name '%s' collides; renamed to '%s_%d'" % [flat, flat, n])
	return "%s_%d" % [flat, n]


# --- emission ------------------------------------------------------------

static func _emit_umbrella(fname: String, file_node: CapnReader.StructReader, by_id: Dictionary[int, CapnReader.StructReader]) -> String:
	var flat_by_id: Dictionary[int, String] = {}
	var types: Array[CodegenEntry] = _collect(file_node, by_id, flat_by_id)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("class_name %s extends RefCounted" % _umbrella_class(fname))
	lines.append("")
	lines.append("## GENERATED from %s by capnpc-gdscript — do not edit." % fname)
	lines.append("")

	# Enums first (class-scoped), then struct inner classes.
	for entry: CodegenEntry in types:
		if CapnSchema.node_which(entry.node) == CapnSchema.NodeWhich.ENUM:
			_emit_enum(lines, entry)
	for entry: CodegenEntry in types:
		if CapnSchema.node_which(entry.node) == CapnSchema.NodeWhich.STRUCT:
			_emit_struct(lines, entry, flat_by_id, by_id)

	# Top-level read_<name>() / new_<name>() entry per top-level struct.
	for entry: CodegenEntry in types:
		if CapnSchema.node_which(entry.node) == CapnSchema.NodeWhich.STRUCT and entry.is_top:
			var sname: String = _snake(entry.flat)
			lines.append("")
			lines.append("static func read_%s(bytes: PackedByteArray, packed: bool = false) -> %s.Reader:" % [sname, entry.flat])
			lines.append(TAB + "var msg: CapnReader.Message = CapnReader.open(bytes, packed)")
			lines.append(TAB + "return %s.Reader.wrap(msg.get_root())" % entry.flat)
			lines.append("")
			lines.append("static func new_%s() -> %s.Builder:" % [sname, entry.flat])
			lines.append(TAB + "return %s.Builder.wrap(CapnBuilder.new_message(%s.DATA_WORDS, %s.PTR_WORDS))" % [entry.flat, entry.flat, entry.flat])
	return "\n".join(lines) + "\n"


static func _emit_enum(lines: PackedStringArray, entry: CodegenEntry) -> void:
	var enumerants: CapnReader.ListReader = CapnSchema.node_enum_enumerants(entry.node)
	var members: PackedStringArray = PackedStringArray()
	for i: int in enumerants.size():
		members.append(_safe_enum_member(_snake(CapnSchema.enumerant_name(enumerants.get_struct(i))).to_upper()))
	lines.append("enum %s { %s }" % [entry.flat, ", ".join(members)])
	lines.append("")


static func _emit_struct(lines: PackedStringArray, entry: CodegenEntry, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader]) -> void:
	var node: CapnReader.StructReader = entry.node
	var flat: String = entry.flat
	var fields: CapnReader.ListReader = CapnSchema.node_struct_fields(node)

	# Struct-level union (the struct itself carries a discriminant).
	var struct_disc: int = _disc_byte(node) if CapnSchema.node_struct_discriminant_count(node) > 0 else -1

	lines.append("class %s extends RefCounted:" % flat)
	lines.append(TAB + "const DATA_WORDS: int = %d" % CapnSchema.node_struct_data_words(node))
	lines.append(TAB + "const PTR_WORDS: int = %d" % CapnSchema.node_struct_pointer_count(node))

	# Struct-level union -> a `Which` enum; each (possibly group-nested) union ->
	# its own enum named after the flattened accessor prefix (state.mode union ->
	# enum StateMode, matching state_mode_which()).
	if struct_disc >= 0:
		_emit_union_enum(lines, "which", node)
	_emit_field_union_enums(lines, "", fields, by_id)
	lines.append("")

	# Reader.
	lines.append(TAB + "class Reader extends RefCounted:")
	lines.append(TAB + TAB + "var _r: CapnReader.StructReader")
	lines.append("")
	lines.append(TAB + TAB + "static func wrap(r: CapnReader.StructReader) -> Reader:")
	lines.append(TAB + TAB + TAB + "var o: Reader = Reader.new()")
	lines.append(TAB + TAB + TAB + "o._r = r")
	lines.append(TAB + TAB + TAB + "return o")
	if struct_disc >= 0:
		lines.append("")
		lines.append(TAB + TAB + "func which() -> int:")
		lines.append(TAB + TAB + TAB + "return _r.get_u16(%d, 0)" % struct_disc)
	for i: int in fields.size():
		_emit_field_getter(lines, fields.get_struct(i), flat_by_id, by_id, struct_disc)
	lines.append("")

	# Builder.
	lines.append(TAB + "class Builder extends RefCounted:")
	lines.append(TAB + TAB + "var _b: CapnBuilder.StructBuilder")
	lines.append("")
	lines.append(TAB + TAB + "static func wrap(b: CapnBuilder.StructBuilder) -> Builder:")
	lines.append(TAB + TAB + TAB + "var o: Builder = Builder.new()")
	lines.append(TAB + TAB + TAB + "o._b = b")
	lines.append(TAB + TAB + TAB + "return o")
	lines.append("")
	lines.append(TAB + TAB + "func to_bytes(packed: bool = false) -> PackedByteArray:")
	lines.append(TAB + TAB + TAB + "return CapnBuilder.to_bytes(_b, packed)")
	for i: int in fields.size():
		_emit_field_setter(lines, fields.get_struct(i), flat_by_id, by_id, struct_disc)
	lines.append("")


## Returns the group's type node if `f` is a union group (discriminantCount > 0),
## else null. Named (non-discriminated) groups and plain slots return null.
static func _union_node(f: CapnReader.StructReader, by_id: Dictionary[int, CapnReader.StructReader]) -> CapnReader.StructReader:
	if CapnSchema.field_which(f) != CapnSchema.FieldWhich.GROUP:
		return null
	var gnode: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(f))
	if gnode == null or CapnSchema.node_struct_discriminant_count(gnode) == 0:
		return null
	return gnode


## Emit a `Which`-style enum for every union reachable through `fields`,
## including unions nested inside named groups. The enum name tracks the
## flattened accessor prefix (path joined by "_", pascal-cased in
## _emit_union_enum) so `state.mode` -> enum StateMode matches state_mode_which().
static func _emit_field_union_enums(lines: PackedStringArray, prefix: String, fields: CapnReader.ListReader, by_id: Dictionary[int, CapnReader.StructReader]) -> void:
	for i: int in fields.size():
		var gf: CapnReader.StructReader = fields.get_struct(i)
		var fname: String = _snake(CapnSchema.field_name(gf))
		var full: String = ("%s_%s" % [prefix, fname]) if prefix != "" else fname
		var un: CapnReader.StructReader = _union_node(gf, by_id)
		if un != null:
			_emit_union_enum(lines, full, un)
		elif CapnSchema.field_which(gf) == CapnSchema.FieldWhich.GROUP:
			var sub: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(gf))
			if sub != null:
				_emit_field_union_enums(lines, full, CapnSchema.node_struct_fields(sub), by_id)


## enum <Name> { MEMBER0, MEMBER1, ... } in discriminant-value order. Members
## are the union fields of gnode (those with a discriminant), so this works for
## both group unions (all fields) and struct-level unions (mixed with plain
## fields).
static func _emit_union_enum(lines: PackedStringArray, name_snake: String, gnode: CapnReader.StructReader) -> void:
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	var by_disc: Dictionary[int, String] = {}
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		if CapnSchema.field_in_union(m):
			by_disc[CapnSchema.field_discriminant_value(m)] = _safe_enum_member(_snake(CapnSchema.field_name(m)).to_upper())
	var ordered: PackedStringArray = PackedStringArray()
	for d: int in CapnSchema.node_struct_discriminant_count(gnode):
		ordered.append(by_disc.get(d, "RESERVED_%d" % d))
	lines.append(TAB + "enum %s { %s }" % [_safe_type(_pascal(name_snake)), ", ".join(ordered)])


static func _emit_field_getter(lines: PackedStringArray, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], struct_disc: int) -> void:
	var fname: String = _safe_member(_snake(CapnSchema.field_name(f)))
	# Any struct-level union arm — slot, named group, or union group — gets an
	# outer is_<name>() selector first.
	var is_struct_arm: bool = struct_disc >= 0 and CapnSchema.field_in_union(f)
	var gnode: CapnReader.StructReader = _union_node(f, by_id)
	if gnode != null:
		if is_struct_arm:
			_emit_is_arm(lines, fname, struct_disc, CapnSchema.field_discriminant_value(f))
		_emit_union_getters(lines, fname, gnode, flat_by_id)
		return
	if CapnSchema.field_which(f) == CapnSchema.FieldWhich.GROUP:
		var named: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(f))
		if named == null:
			lines.append("")
			lines.append(TAB + TAB + "# TODO: named group '%s' (unresolved cross-file type)" % fname)
			return
		if is_struct_arm:
			_emit_is_arm(lines, fname, struct_disc, CapnSchema.field_discriminant_value(f))
		_emit_named_group_getters(lines, fname, named, flat_by_id, by_id)
		return
	if is_struct_arm:
		_emit_is_arm(lines, fname, struct_disc, CapnSchema.field_discriminant_value(f))
	_emit_slot_getter(lines, fname, f, flat_by_id)


## Emit is_<name>() -> bool for a struct-level union arm: true when the struct's
## discriminant (at byte `struct_disc`) equals this arm's value.
static func _emit_is_arm(lines: PackedStringArray, fname: String, struct_disc: int, disc_val: int) -> void:
	lines.append("")
	lines.append(TAB + TAB + "func is_%s() -> bool:" % fname)
	lines.append(TAB + TAB + TAB + "return _r.get_u16(%d, 0) == %d" % [struct_disc, disc_val])


## Emit a get_<suffix>() reader for a slot field. Void fields produce nothing.
static func _emit_slot_getter(lines: PackedStringArray, suffix: String, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> void:
	var t: CapnReader.StructReader = CapnSchema.field_slot_type(f)
	var off: int = CapnSchema.field_slot_offset(f)
	var tw: CapnSchema.TypeWhich = CapnSchema.type_which(t)
	if tw == CapnSchema.TypeWhich.VOID:
		return
	if tw == CapnSchema.TypeWhich.LIST:
		_emit_list_getter(lines, suffix, off, CapnSchema.type_list_element(t), flat_by_id)
		return
	# A generic type-parameter field (and an explicit `:AnyPointer`) is a plain
	# pointer slot on the wire — type-erased. Expose the four pointer
	# interpretations; the caller picks the one matching the concrete binding.
	if tw == CapnSchema.TypeWhich.ANY_POINTER:
		_emit_anyptr_getter(lines, suffix, off)
		return
	lines.append("")
	lines.append(TAB + TAB + "func get_%s() -> %s:" % [suffix, _return_type(tw, t, flat_by_id)])
	lines.append(TAB + TAB + TAB + "return %s" % _scalar_expr("_r", tw, t, off, flat_by_id, _default_for(f, tw)))


## Type-erased reader accessors for an AnyPointer / generic-parameter slot.
## has_<f>() reports presence; get_<f>_struct/list/text/data() interpret the
## same pointer as each pointer kind (the wire stores no element type, so the
## caller resolves it from the concrete binding it knows statically).
static func _emit_anyptr_getter(lines: PackedStringArray, suffix: String, off: int) -> void:
	lines.append("")
	lines.append(TAB + TAB + "func has_%s() -> bool:" % suffix)
	lines.append(TAB + TAB + TAB + "return _r.has_ptr(%d)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func get_%s_struct() -> CapnReader.StructReader:" % suffix)
	lines.append(TAB + TAB + TAB + "return _r.get_struct(%d)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func get_%s_list() -> CapnReader.ListReader:" % suffix)
	lines.append(TAB + TAB + TAB + "return _r.get_list(%d)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func get_%s_text() -> String:" % suffix)
	lines.append(TAB + TAB + TAB + "return _r.get_text(%d, \"\")" % off)
	lines.append("")
	lines.append(TAB + TAB + "func get_%s_data() -> PackedByteArray:" % suffix)
	lines.append(TAB + TAB + TAB + "return _r.get_data(%d)" % off)


## Union (group) reader: <group>_which() + per-member is_/get_ accessors.
static func _emit_union_getters(lines: PackedStringArray, gsnake: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> void:
	var disc: int = _disc_byte(gnode)
	lines.append("")
	lines.append(TAB + TAB + "func %s_which() -> int:" % gsnake)
	lines.append(TAB + TAB + TAB + "return _r.get_u16(%d, 0)" % disc)
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		var mname: String = _safe_member(_snake(CapnSchema.field_name(m)))
		lines.append("")
		lines.append(TAB + TAB + "func is_%s_%s() -> bool:" % [gsnake, mname])
		lines.append(TAB + TAB + TAB + "return _r.get_u16(%d, 0) == %d" % [disc, CapnSchema.field_discriminant_value(m)])
		if CapnSchema.field_which(m) == CapnSchema.FieldWhich.SLOT:
			_emit_slot_getter(lines, "%s_%s" % [gsnake, mname], m, flat_by_id)


## Named (non-discriminated) group reader: a group is a sub-namespace whose
## fields share the parent's data/pointer layout, so flatten them into
## get_<group>_<field>() accessors. Recurses for nested named groups and
## delegates to _emit_union_getters for a union nested inside the group.
static func _emit_named_group_getters(lines: PackedStringArray, prefix: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader]) -> void:
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		var full: String = "%s_%s" % [prefix, _safe_member(_snake(CapnSchema.field_name(m)))]
		var un: CapnReader.StructReader = _union_node(m, by_id)
		if un != null:
			_emit_union_getters(lines, full, un, flat_by_id)
		elif CapnSchema.field_which(m) == CapnSchema.FieldWhich.GROUP:
			var sub: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(m))
			if sub == null:
				lines.append("")
				lines.append(TAB + TAB + "# TODO: nested group '%s' (unresolved cross-file type)" % full)
				continue
			_emit_named_group_getters(lines, full, sub, flat_by_id, by_id)
		else:
			_emit_slot_getter(lines, full, m, flat_by_id)


static func _emit_list_getter(lines: PackedStringArray, fname: String, off: int, elem: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> void:
	var ew: CapnSchema.TypeWhich = CapnSchema.type_which(elem)
	# Type the returned container by element kind for autocomplete at the call
	# site. Indexed writes into a typed Array carry the element type directly —
	# no C3 .assign() needed.
	var arr: String = _list_container_type(ew, elem, flat_by_id)
	lines.append("")
	lines.append(TAB + TAB + "func get_%s() -> %s:" % [fname, arr])
	lines.append(TAB + TAB + TAB + "var lr: CapnReader.ListReader = _r.get_list(%d)" % off)
	lines.append(TAB + TAB + TAB + "var out: %s = []" % arr)
	lines.append(TAB + TAB + TAB + "out.resize(lr.size())")
	lines.append(TAB + TAB + TAB + "for i: int in lr.size():")
	lines.append(TAB + TAB + TAB + TAB + "out[i] = %s" % _list_elem_expr(ew, elem, flat_by_id))
	lines.append(TAB + TAB + TAB + "return out")


## The typed container type for a list getter — "Array[<T>]", or plain "Array"
## when the element type is erased/unresolved (AnyPointer, list-of-list,
## interface, void, or a cross-file struct not yet in flat_by_id). Checks
## _flat_of directly for structs rather than reading _return_type's sentinel.
static func _list_container_type(ew: CapnSchema.TypeWhich, elem: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	if ew == CapnSchema.TypeWhich.ANY_POINTER or ew == CapnSchema.TypeWhich.LIST or ew == CapnSchema.TypeWhich.INTERFACE or ew == CapnSchema.TypeWhich.VOID:
		return "Array"
	if ew == CapnSchema.TypeWhich.STRUCT:
		var flat: String = _flat_of(elem, flat_by_id)
		return ("Array[%s.Reader]" % flat) if flat != "" else "Array"
	return "Array[%s]" % _return_type(ew, elem, flat_by_id)


# --- setters (Builder) ---------------------------------------------------

static func _emit_field_setter(lines: PackedStringArray, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], struct_disc: int) -> void:
	var fname: String = _safe_member(_snake(CapnSchema.field_name(f)))
	var gnode: CapnReader.StructReader = _union_node(f, by_id)
	if gnode != null:
		# A union group that is itself an arm of a struct-level union (CG4):
		# thread the OUTER discriminant in so selecting an inner arm also selects
		# this group on the outer union. Otherwise the inner setters alone leave
		# the outer which() at its zero default.
		if struct_disc >= 0 and CapnSchema.field_in_union(f):
			_emit_union_setters(lines, fname, gnode, flat_by_id, struct_disc, CapnSchema.field_discriminant_value(f))
		else:
			_emit_union_setters(lines, fname, gnode, flat_by_id)
		return
	if CapnSchema.field_which(f) == CapnSchema.FieldWhich.GROUP:
		var named: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(f))
		if named == null:
			lines.append("")
			lines.append(TAB + TAB + "# TODO: named group '%s' (unresolved cross-file type)" % fname)
			return
		# A named group that is itself a struct-level union arm (CG4): thread the
		# OUTER discriminant into every flattened leaf setter so selecting any
		# leaf also selects this group on the outer union.
		if struct_disc >= 0 and CapnSchema.field_in_union(f):
			_emit_named_group_setters(lines, fname, named, flat_by_id, by_id, struct_disc, CapnSchema.field_discriminant_value(f))
		else:
			_emit_named_group_setters(lines, fname, named, flat_by_id, by_id)
		return
	# A struct-level union member's setter also writes the discriminant.
	if struct_disc >= 0 and CapnSchema.field_in_union(f):
		_emit_slot_setter(lines, fname, f, flat_by_id, struct_disc, CapnSchema.field_discriminant_value(f))
	else:
		_emit_slot_setter(lines, fname, f, flat_by_id, -1, 0)


## Emit a setter (set_/init_) for a slot field. When disc_off >= 0 the field is
## a union member, so the setter writes the discriminant first.
static func _emit_slot_setter(lines: PackedStringArray, suffix: String, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String], disc_off: int, disc_val: int, outer_disc_off: int = -1, outer_disc_val: int = 0) -> void:
	var t: CapnReader.StructReader = CapnSchema.field_slot_type(f)
	var off: int = CapnSchema.field_slot_offset(f)
	var tw: CapnSchema.TypeWhich = CapnSchema.type_which(t)
	# disc_line may carry up to two discriminant writes: the OUTER struct-level
	# union arm (CG4) and this group's INNER arm, joined by "\n" (no trailing
	# newline). Callers append it as one block; "\n".join(lines) splits it.
	var disc_writes: PackedStringArray = PackedStringArray()
	if outer_disc_off >= 0:
		disc_writes.append(TAB + TAB + TAB + "_b.set_u16(%d, %d, 0)" % [outer_disc_off, outer_disc_val])
	if disc_off >= 0:
		disc_writes.append(TAB + TAB + TAB + "_b.set_u16(%d, %d, 0)" % [disc_off, disc_val])
	var disc_line: String = "\n".join(disc_writes)

	if tw == CapnSchema.TypeWhich.VOID:
		# A void union member's setter just selects the discriminant.
		if disc_off >= 0:
			lines.append("")
			lines.append(TAB + TAB + "func set_%s() -> void:" % suffix)
			lines.append(disc_line)
		return
	if tw == CapnSchema.TypeWhich.LIST:
		_emit_list_setter(lines, suffix, off, CapnSchema.type_list_element(t), flat_by_id, disc_line)
		return
	if tw == CapnSchema.TypeWhich.STRUCT:
		var child: String = _flat_of(t, flat_by_id)
		if child == "":
			lines.append("")
			lines.append(TAB + TAB + "# TODO(M6): init '%s' (unresolved cross-file struct)" % suffix)
			return
		lines.append("")
		lines.append(TAB + TAB + "func init_%s() -> %s.Builder:" % [suffix, child])
		if disc_line != "":
			lines.append(disc_line)
		lines.append(TAB + TAB + TAB + "return %s.Builder.wrap(_b.init_struct(%d, %s.DATA_WORDS, %s.PTR_WORDS))" % [child, off, child, child])
		return
	if tw == CapnSchema.TypeWhich.ANY_POINTER:
		_emit_anyptr_setter(lines, suffix, off, disc_line)
		return
	lines.append("")
	lines.append(TAB + TAB + "func set_%s(value: %s) -> void:" % [suffix, _return_type(tw, t, flat_by_id)])
	if disc_line != "":
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + _scalar_set("_b", tw, off, _default_for(f, tw)))


## Type-erased builder accessors for an AnyPointer / generic-parameter slot.
## Mirrors _emit_anyptr_getter: init_<f>_struct allocates the pointee and returns
## the RAW StructBuilder (the caller wraps it in the concrete type's Builder);
## init_<f>_list/composite_list return a ListBuilder used directly; set_<f>_text/
## data write a pointer payload. Each entry point writes the slot, so each writes
## the union discriminant first when the field is a union member.
static func _emit_anyptr_setter(lines: PackedStringArray, suffix: String, off: int, disc_line: String) -> void:
	lines.append("")
	lines.append(TAB + TAB + "func init_%s_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:" % suffix)
	if disc_line != "":
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_struct(%d, data_words, ptr_words)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func init_%s_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:" % suffix)
	if disc_line != "":
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_list(%d, elem_size, count)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func init_%s_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:" % suffix)
	if disc_line != "":
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_composite_list(%d, count, data_words, ptr_words)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func set_%s_text(value: String) -> void:" % suffix)
	if disc_line != "":
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "_b.set_text(%d, value)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func set_%s_data(value: PackedByteArray) -> void:" % suffix)
	if disc_line != "":
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "_b.set_data(%d, value)" % off)


static func _emit_list_setter(lines: PackedStringArray, fname: String, off: int, elem: CapnReader.StructReader, flat_by_id: Dictionary[int, String], disc_line: String = "") -> void:
	var ew: CapnSchema.TypeWhich = CapnSchema.type_which(elem)
	lines.append("")
	if ew == CapnSchema.TypeWhich.STRUCT:
		var child: String = _flat_of(elem, flat_by_id)
		if child == "":
			lines.append(TAB + TAB + "# TODO(M6): init '%s' (unresolved cross-file struct list)" % fname)
			return
		# Composite list -> typed Array of element Builders.
		var arr: String = "Array[%s.Builder]" % child
		lines.append(TAB + TAB + "func init_%s(n: int) -> %s:" % [fname, arr])
		if disc_line != "":
			lines.append(disc_line)
		lines.append(TAB + TAB + TAB + "var lb: CapnBuilder.ListBuilder = _b.init_composite_list(%d, n, %s.DATA_WORDS, %s.PTR_WORDS)" % [off, child, child])
		lines.append(TAB + TAB + TAB + "var out: %s = []" % arr)
		lines.append(TAB + TAB + TAB + "out.resize(n)")
		lines.append(TAB + TAB + TAB + "for i: int in n:")
		lines.append(TAB + TAB + TAB + TAB + "out[i] = %s.Builder.wrap(lb.init_struct(i))" % child)
		lines.append(TAB + TAB + TAB + "return out")
		return
	# Primitive / Text / Data list -> a raw ListBuilder; caller sets elements
	# via lb.set_<kind>(i, value).
	lines.append(TAB + TAB + "func init_%s(n: int) -> CapnBuilder.ListBuilder:" % fname)
	if disc_line != "":
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_list(%d, %s, n)" % [off, _elem_size_token(ew)])


## Union (group) builder: per-member set_/init_ that writes the discriminant.
## When the group is itself a struct-level union arm, outer_disc_off/val are
## threaded to each member setter so it also selects this group on the outer
## union (CG4).
static func _emit_union_setters(lines: PackedStringArray, gsnake: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String], outer_disc_off: int = -1, outer_disc_val: int = 0) -> void:
	var disc: int = _disc_byte(gnode)
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		if CapnSchema.field_which(m) != CapnSchema.FieldWhich.SLOT:
			lines.append("")
			lines.append(TAB + TAB + "# TODO(M6): nested group union member '%s'" % _snake(CapnSchema.field_name(m)))
			continue
		_emit_slot_setter(lines, "%s_%s" % [gsnake, _safe_member(_snake(CapnSchema.field_name(m)))], m, flat_by_id, disc, CapnSchema.field_discriminant_value(m), outer_disc_off, outer_disc_val)


## Named (non-discriminated) group builder: mirror of _emit_named_group_getters.
## Flattens to set_<group>_<field>()/init_<group>_<field>(); recurses for nested
## named groups; delegates to _emit_union_setters for a union nested in the group.
## When the group is itself a struct-level union arm, outer_disc_off/val thread
## down to every leaf setter so selecting any leaf selects this arm (CG4).
static func _emit_named_group_setters(lines: PackedStringArray, prefix: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], outer_disc_off: int = -1, outer_disc_val: int = 0) -> void:
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		var full: String = "%s_%s" % [prefix, _safe_member(_snake(CapnSchema.field_name(m)))]
		var un: CapnReader.StructReader = _union_node(m, by_id)
		if un != null:
			_emit_union_setters(lines, full, un, flat_by_id, outer_disc_off, outer_disc_val)
		elif CapnSchema.field_which(m) == CapnSchema.FieldWhich.GROUP:
			var sub: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(m))
			if sub == null:
				lines.append("")
				lines.append(TAB + TAB + "# TODO: nested group '%s' (unresolved cross-file type)" % full)
				continue
			_emit_named_group_setters(lines, full, sub, flat_by_id, by_id, outer_disc_off, outer_disc_val)
		else:
			_emit_slot_setter(lines, full, m, flat_by_id, -1, 0, outer_disc_off, outer_disc_val)


static func _disc_byte(gnode: CapnReader.StructReader) -> int:
	# discriminantOffset is in 16-bit units (the discriminant is a u16).
	return CapnSchema.node_struct_discriminant_offset(gnode) * 2


# Variant builtin type names (not in ClassDB) + GDScript keywords. ClassDB
# covers every engine class (Node, Resource, ...) dynamically.
const _VARIANT_TYPES: PackedStringArray = [
	"bool", "int", "float", "String", "StringName", "NodePath", "RID",
	"Object", "Callable", "Signal", "Dictionary", "Array", "Variant", "Nil", "void",
	"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
	"Rect2", "Rect2i", "Transform2D", "Transform3D", "Plane", "Quaternion",
	"AABB", "Basis", "Projection", "Color",
	"PackedByteArray", "PackedInt32Array", "PackedInt64Array", "PackedFloat32Array",
	"PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
	"PackedVector3Array", "PackedVector4Array", "PackedColorArray",
]
const _GD_KEYWORDS: PackedStringArray = [
	"if", "elif", "else", "for", "while", "match", "when", "break", "continue",
	"pass", "return", "class", "class_name", "extends", "is", "as", "self",
	"super", "signal", "func", "static", "const", "enum", "var", "breakpoint",
	"preload", "await", "yield", "assert", "void", "and", "or", "not", "in",
	"true", "false", "null", "PI", "TAU", "INF", "NAN",
]
# Object getter stems a field would shadow via get_<stem>() — Readers/Builders
# extend RefCounted (Object), so only Object's own getters matter (NOT Node's
# get_name/get_path/get_owner). "class" is also a keyword, covered separately.
const _RESERVED_MEMBERS: PackedStringArray = [
	"script", "meta", "instance_id", "method_list", "property_list",
	"signal_list", "incoming_connections", "indexed",
]


## True if `name` would collide with a Godot type or GDScript keyword as a
## generated class/enum identifier.
static func _is_reserved_type(name: String) -> bool:
	return ClassDB.class_exists(name) or _VARIANT_TYPES.has(name) or _GD_KEYWORDS.has(name)


## A collision-safe type identifier (trailing "_" on reserved names).
static func _safe_type(name: String) -> String:
	return (name + "_") if _is_reserved_type(name) else name


## A collision-safe field stem for get_<stem>()/set_<stem>() — avoids GDScript
## keywords and Object methods we'd otherwise shadow.
static func _safe_member(stem: String) -> String:
	if _GD_KEYWORDS.has(stem) or _RESERVED_MEMBERS.has(stem):
		return stem + "_"
	return stem


## A collision-safe enum member (UPPERCASE) — avoids GDScript's uppercase
## built-in constants (PI/TAU/INF/NAN, and TRUE/FALSE/NULL via the keyword list).
static func _safe_enum_member(upper: String) -> String:
	return (upper + "_") if _GD_KEYWORDS.has(upper) else upper


static func _pascal(snake: String) -> String:
	# Upper-case the first letter of each "_"-part, preserving the rest as-is
	# (no Godot capitalize() — it re-splits camelCase and lowercases tails).
	var parts: PackedStringArray = snake.split("_", false)
	var out: String = ""
	for p: String in parts:
		if p.is_empty():
			continue
		out += p.substr(0, 1).to_upper() + p.substr(1)
	return out


static func _scalar_set(recv: String, tw: CapnSchema.TypeWhich, off: int, def: String) -> String:
	if tw == CapnSchema.TypeWhich.BOOL:
		return "%s.set_bool(%d, value, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.INT8:
		return "%s.set_i8(%d, value, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.INT16:
		return "%s.set_i16(%d, value, %s)" % [recv, off * 2, def]
	elif tw == CapnSchema.TypeWhich.INT32:
		return "%s.set_i32(%d, value, %s)" % [recv, off * 4, def]
	elif tw == CapnSchema.TypeWhich.INT64:
		return "%s.set_i64(%d, value, %s)" % [recv, off * 8, def]
	elif tw == CapnSchema.TypeWhich.UINT8:
		return "%s.set_u8(%d, value, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.UINT16:
		return "%s.set_u16(%d, value, %s)" % [recv, off * 2, def]
	elif tw == CapnSchema.TypeWhich.UINT32:
		return "%s.set_u32(%d, value, %s)" % [recv, off * 4, def]
	elif tw == CapnSchema.TypeWhich.UINT64:
		return "%s.set_u64(%d, value, %s)" % [recv, off * 8, def]
	elif tw == CapnSchema.TypeWhich.FLOAT32:
		return "%s.set_f32(%d, value, %s)" % [recv, off * 4, def]
	elif tw == CapnSchema.TypeWhich.FLOAT64:
		return "%s.set_f64(%d, value, %s)" % [recv, off * 8, def]
	elif tw == CapnSchema.TypeWhich.ENUM:
		return "%s.set_u16(%d, value, %s)" % [recv, off * 2, def]
	elif tw == CapnSchema.TypeWhich.TEXT:
		return "%s.set_text(%d, value)" % [recv, off]
	elif tw == CapnSchema.TypeWhich.DATA:
		return "%s.set_data(%d, value)" % [recv, off]
	return "pass  # TODO(M6): set type %d" % tw


## The default literal for a slot field: the XOR mask for numerics/enum (a value
## or 0), the IEEE bit pattern for floats, "true"/"false" for bool, a quoted
## string for Text, or the zero default when the field has no explicit default.
static func _default_for(f: CapnReader.StructReader, tw: CapnSchema.TypeWhich) -> String:
	if not CapnSchema.field_slot_had_default(f):
		if tw == CapnSchema.TypeWhich.BOOL:
			return "false"
		elif tw == CapnSchema.TypeWhich.TEXT:
			return "\"\""
		elif tw == CapnSchema.TypeWhich.DATA:
			return "PackedByteArray()"
		return "0"
	var dv: CapnReader.StructReader = CapnSchema.field_slot_default(f)
	if tw == CapnSchema.TypeWhich.BOOL:
		return "true" if CapnSchema.value_bool(dv) else "false"
	elif tw == CapnSchema.TypeWhich.INT8:
		return str(CapnSchema.value_i8(dv))
	elif tw == CapnSchema.TypeWhich.INT16:
		return str(CapnSchema.value_i16(dv))
	elif tw == CapnSchema.TypeWhich.INT32:
		return str(CapnSchema.value_i32(dv))
	elif tw == CapnSchema.TypeWhich.INT64:
		return str(CapnSchema.value_i64(dv))
	elif tw == CapnSchema.TypeWhich.UINT8:
		return str(CapnSchema.value_u8(dv))
	elif tw == CapnSchema.TypeWhich.UINT16:
		return str(CapnSchema.value_u16(dv))
	elif tw == CapnSchema.TypeWhich.UINT32:
		return str(CapnSchema.value_u32(dv))
	elif tw == CapnSchema.TypeWhich.UINT64:
		return str(CapnSchema.value_u64(dv))
	elif tw == CapnSchema.TypeWhich.ENUM:
		return str(CapnSchema.value_enum(dv))
	elif tw == CapnSchema.TypeWhich.FLOAT32:
		return str(_f32_bits(CapnSchema.value_f32(dv)))
	elif tw == CapnSchema.TypeWhich.FLOAT64:
		return str(_f64_bits(CapnSchema.value_f64(dv)))
	elif tw == CapnSchema.TypeWhich.TEXT:
		return _gd_string(CapnSchema.value_text(dv))
	elif tw == CapnSchema.TypeWhich.DATA:
		return _data_literal(CapnSchema.value_data(dv))
	return "0"


static var _f32_scratch: PackedByteArray = _make_scratch(4)
static var _f64_scratch: PackedByteArray = _make_scratch(8)


static func _make_scratch(n: int) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(n)
	return b


static func _f32_bits(value: float) -> int:
	_f32_scratch.encode_float(0, value)
	return _f32_scratch.decode_u32(0)


static func _f64_bits(value: float) -> int:
	_f64_scratch.encode_double(0, value)
	return _f64_scratch.decode_u64(0)


## A GDScript double-quoted string literal for `s` (escapes backslash, quote,
## and the control chars that would otherwise break the literal).
static func _gd_string(s: String) -> String:
	var e: String = s.replace("\\", "\\\\").replace("\"", "\\\"")
	e = e.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
	return "\"" + e + "\""


## A GDScript PackedByteArray literal for `bytes` (a Data field's authored
## default). The constructor form is required in expression position — there is
## no typed annotation to coerce a bare `[...]`, and a `const` PackedByteArray is
## broken (engine bug C1). Empty -> PackedByteArray().
static func _data_literal(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return "PackedByteArray()"
	var parts: PackedStringArray = PackedStringArray()
	parts.resize(bytes.size())
	for i: int in bytes.size():
		parts[i] = str(bytes[i])
	return "PackedByteArray([%s])" % ", ".join(parts)


## TypeWhich -> CapnPointer.ElemSize token for a non-composite list.
static func _elem_size_token(ew: CapnSchema.TypeWhich) -> String:
	if ew == CapnSchema.TypeWhich.BOOL:
		return "CapnPointer.ElemSize.BIT"
	elif ew == CapnSchema.TypeWhich.INT8 or ew == CapnSchema.TypeWhich.UINT8:
		return "CapnPointer.ElemSize.BYTE"
	elif ew == CapnSchema.TypeWhich.INT16 or ew == CapnSchema.TypeWhich.UINT16 or ew == CapnSchema.TypeWhich.ENUM:
		return "CapnPointer.ElemSize.TWO_BYTES"
	elif ew == CapnSchema.TypeWhich.INT32 or ew == CapnSchema.TypeWhich.UINT32 or ew == CapnSchema.TypeWhich.FLOAT32:
		return "CapnPointer.ElemSize.FOUR_BYTES"
	elif ew == CapnSchema.TypeWhich.INT64 or ew == CapnSchema.TypeWhich.UINT64 or ew == CapnSchema.TypeWhich.FLOAT64:
		return "CapnPointer.ElemSize.EIGHT_BYTES"
	# Text / Data (pointer elements).
	return "CapnPointer.ElemSize.POINTER"


# --- type -> expression mapping ------------------------------------------

static func _scalar_expr(recv: String, tw: CapnSchema.TypeWhich, t: CapnReader.StructReader, off: int, flat_by_id: Dictionary[int, String], def: String) -> String:
	if tw == CapnSchema.TypeWhich.BOOL:
		return "%s.get_bool(%d, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.INT8:
		return "%s.get_i8(%d, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.INT16:
		return "%s.get_i16(%d, %s)" % [recv, off * 2, def]
	elif tw == CapnSchema.TypeWhich.INT32:
		return "%s.get_i32(%d, %s)" % [recv, off * 4, def]
	elif tw == CapnSchema.TypeWhich.INT64:
		return "%s.get_i64(%d, %s)" % [recv, off * 8, def]
	elif tw == CapnSchema.TypeWhich.UINT8:
		return "%s.get_u8(%d, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.UINT16:
		return "%s.get_u16(%d, %s)" % [recv, off * 2, def]
	elif tw == CapnSchema.TypeWhich.UINT32:
		return "%s.get_u32(%d, %s)" % [recv, off * 4, def]
	elif tw == CapnSchema.TypeWhich.UINT64:
		return "%s.get_u64(%d, %s)" % [recv, off * 8, def]
	elif tw == CapnSchema.TypeWhich.FLOAT32:
		return "%s.get_f32(%d, %s)" % [recv, off * 4, def]
	elif tw == CapnSchema.TypeWhich.FLOAT64:
		return "%s.get_f64(%d, %s)" % [recv, off * 8, def]
	elif tw == CapnSchema.TypeWhich.ENUM:
		var eflat: String = _flat_of(t, flat_by_id)
		if eflat == "":
			return "%s.get_u16(%d, %s)" % [recv, off * 2, def]
		return "%s.get_u16(%d, %s) as %s" % [recv, off * 2, def, eflat]
	elif tw == CapnSchema.TypeWhich.TEXT:
		return "%s.get_text(%d, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.DATA:
		return "%s.get_data(%d, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.STRUCT:
		var flat: String = _flat_of(t, flat_by_id)
		if flat == "":
			return "null  # TODO(M6): unresolved cross-file struct"
		return "%s.Reader.wrap(%s.get_struct(%d))" % [flat, recv, off]
	return "null  # TODO(M6): type %d" % tw


static func _list_elem_expr(ew: CapnSchema.TypeWhich, elem: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	if ew == CapnSchema.TypeWhich.STRUCT:
		var flat: String = _flat_of(elem, flat_by_id)
		if flat == "":
			return "null  # TODO(M6): unresolved cross-file struct"
		return "%s.Reader.wrap(lr.get_struct(i))" % flat
	elif ew == CapnSchema.TypeWhich.TEXT:
		return "lr.get_text(i)"
	elif ew == CapnSchema.TypeWhich.DATA:
		return "lr.get_data(i)"
	elif ew == CapnSchema.TypeWhich.BOOL:
		return "lr.get_bool(i)"
	elif ew == CapnSchema.TypeWhich.INT8:
		return "lr.get_i8(i)"
	elif ew == CapnSchema.TypeWhich.INT16:
		return "lr.get_i16(i)"
	elif ew == CapnSchema.TypeWhich.INT32:
		return "lr.get_i32(i)"
	elif ew == CapnSchema.TypeWhich.INT64:
		return "lr.get_i64(i)"
	elif ew == CapnSchema.TypeWhich.UINT8:
		return "lr.get_u8(i)"
	elif ew == CapnSchema.TypeWhich.UINT16:
		return "lr.get_u16(i)"
	elif ew == CapnSchema.TypeWhich.ENUM:
		# Match the Array[<Enum>] container type emitted by _list_container_type.
		var eflat: String = _flat_of(elem, flat_by_id)
		return ("lr.get_u16(i) as %s" % eflat) if eflat != "" else "lr.get_u16(i)"
	elif ew == CapnSchema.TypeWhich.UINT32:
		return "lr.get_u32(i)"
	elif ew == CapnSchema.TypeWhich.UINT64:
		return "lr.get_u64(i)"
	elif ew == CapnSchema.TypeWhich.FLOAT32:
		return "lr.get_f32(i)"
	elif ew == CapnSchema.TypeWhich.FLOAT64:
		return "lr.get_f64(i)"
	return "null  # TODO(M6): list elem type %d" % ew


static func _return_type(tw: CapnSchema.TypeWhich, t: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	if tw == CapnSchema.TypeWhich.BOOL:
		return "bool"
	elif tw == CapnSchema.TypeWhich.FLOAT32 or tw == CapnSchema.TypeWhich.FLOAT64:
		return "float"
	elif tw == CapnSchema.TypeWhich.TEXT:
		return "String"
	elif tw == CapnSchema.TypeWhich.DATA:
		return "PackedByteArray"
	elif tw == CapnSchema.TypeWhich.STRUCT:
		var flat: String = _flat_of(t, flat_by_id)
		return ("%s.Reader" % flat) if flat != "" else "Variant"
	elif tw == CapnSchema.TypeWhich.ENUM:
		# Enum at the API boundary (D10a): return the generated enum type for
		# autocomplete; int underneath. Cross-file enum (unresolved) -> int.
		var flat: String = _flat_of(t, flat_by_id)
		return flat if flat != "" else "int"
	# int8..uint64 -> int
	return "int"


## Flattened GDScript name for a struct/enum type, or "" if unresolved (a
## cross-file ref, unsupported until M6). Callers must keep generated syntax
## valid when this returns "".
static func _flat_of(type_reader: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	var id: int = CapnSchema.type_id(type_reader)
	if not flat_by_id.has(id):
		push_error("[CapnCodegen] unresolved type id %d (cross-file refs land in M6)" % id)
		return ""
	return flat_by_id[id]


# --- naming helpers ------------------------------------------------------

static func _umbrella_class(fname: String) -> String:
	# "path/addressbook.capnp" -> "AddressbookCapnp"
	var base: String = fname.get_file().trim_suffix(".capnp")
	var parts: PackedStringArray = base.replace("-", "_").split("_", false)
	var out: String = ""
	for p: String in parts:
		out += p.capitalize() if p.length() > 1 else p.to_upper()
	return out + "Capnp"


## camelCase / PascalCase -> snake_case. Splits on a lower->upper boundary
## ("phoneNumber" -> "phone_number") AND at the end of a capital run that starts
## a new word ("HTTPServer" -> "http_server", "parseHTTPRequest" ->
## "parse_http_request") — so acronym runs don't collapse into one token.
## Like Python's inflection.underscore, the last capital of a run starts the new
## word ("APIv2" -> "ap_iv2") — not a bug: capnp identifiers are camelCase, so a
## lowercase word always begins with its own Pascal-cased capital. capnp names
## can't contain "_", so the leading-strip is just defensive.
static func _snake(s: String) -> String:
	var out: String = ""
	var n: int = s.length()
	for i: int in n:
		var ch: String = s[i]
		var low: String = ch.to_lower()
		var is_upper: bool = ch != low
		if is_upper and i > 0 and not out.ends_with("_"):
			var prev_upper: bool = s[i - 1] != s[i - 1].to_lower()
			var next_lower: bool = i + 1 < n and _is_lower_letter(s[i + 1])
			# lower/digit -> Upper, or acronym-end (Upper run -> lowercase word).
			if not prev_upper or next_lower:
				out += "_"
		out += low
	while out.begins_with("_"):
		out = out.substr(1)
	return out


## True if `ch` is a lowercase cased letter (not a digit or symbol).
static func _is_lower_letter(ch: String) -> bool:
	return ch == ch.to_lower() and ch != ch.to_upper()
