class_name CapnCodegen
extends RefCounted
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
	var is_top: bool # directly nested under the file node (gets read_/new_ entries)


	func _init(p_id: int, p_flat: String, p_node: CapnReader.StructReader, p_is_top: bool) -> void:
		id = p_id
		flat = p_flat
		node = p_node
		is_top = p_is_top


## One concrete instantiation of a generic struct to emit (CG1b). `subst` maps a
## generic parameter index -> its bound Type reader; `subst_scope` is the generic
## node id those parameters belong to. POD record (D1).
class MonoInst extends RefCounted:
	var gen_node: CapnReader.StructReader
	var mono_name: String
	var subst: Dictionary[int, CapnReader.StructReader]
	var subst_scope: int


	func _init(p_node: CapnReader.StructReader, p_name: String, p_subst: Dictionary[int, CapnReader.StructReader], p_scope: int) -> void:
		gen_node = p_node
		mono_name = p_name
		subst = p_subst
		subst_scope = p_scope

## Brand-signature -> monomorphic class name, for the file currently being
## emitted (CG1b). Set/reset by _emit_umbrella, populated by
## _collect_instantiations before the struct loop, read by _struct_flat when a
## branded struct field resolves to its mono class. Emit-scoped scratch: safe
## because generate_files emits files strictly sequentially with no await on the
## emit path (same pattern as _f32_scratch). Mono classes are per-file — two
## files each using Box(Text) emit their own Box_Text.
static var _mono_by_sig: Dictionary[String, String] = { }

## Inherit-mono key -> class name (CG1d). A nested struct that inherits its
## enclosing generic's parameters (`Outer(T) { struct Inner { value :T } }`)
## needs a per-instantiation mono (`Outer(Text)` → `Outer_Inner_Text`) whose name
## can't be derived from the field's own brand (an INHERIT scope carries no
## bindings — they come from the enclosing subst). Keyed by inner node id + the
## enclosing subst signature so `Outer(Text).Inner` ≠ `Outer(Int).Inner`. Reset
## alongside _mono_by_sig.
static var _inherit_mono_by_key: Dictionary[String, String] = { }


static func generate_files(cgr: CapnReader.StructReader) -> Dictionary[String, String]:
	var nodes_by_id: Dictionary[int, CapnReader.StructReader] = _index_nodes(cgr)
	var out: Dictionary[String, String] = { }
	var reqs: CapnReader.ListReader = CapnSchema.cgr_requested_files(cgr)
	# The set of files we actually emit. Only these are cross-file-referenceable
	# (CG7): an imported type from a file we DON'T generate has no umbrella class
	# to point at, so it stays unresolved rather than referencing a phantom class.
	var requested_ids: Dictionary[int, bool] = { }
	for i: int in reqs.size():
		requested_ids[CapnSchema.req_file_id(reqs.get_struct(i))] = true
	for i: int in reqs.size():
		var rf: CapnReader.StructReader = reqs.get_struct(i)
		var fname: String = CapnSchema.req_file_name(rf)
		var file_node: CapnReader.StructReader = nodes_by_id.get(CapnSchema.req_file_id(rf))
		if file_node == null:
			push_error("[CapnCodegen] requested file node %d not found" % CapnSchema.req_file_id(rf))
			continue
		out[fname + ".gd"] = _emit_umbrella(fname, file_node, nodes_by_id, requested_ids)
	return out

# --- node collection -----------------------------------------------------


static func _index_nodes(cgr: CapnReader.StructReader) -> Dictionary[int, CapnReader.StructReader]:
	var by_id: Dictionary[int, CapnReader.StructReader] = { }
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
	var used: Dictionary[String, bool] = { }
	_walk(file_node, "", by_id, result, flat_by_id, used)
	return result


static func _walk(node: CapnReader.StructReader, prefix: String, by_id: Dictionary[int, CapnReader.StructReader], result: Array[CodegenEntry], flat_by_id: Dictionary[int, String], used: Dictionary[String, bool]) -> void:
	var nested: CapnReader.ListReader = CapnSchema.node_nested_nodes(node)
	for i: int in nested.size():
		var nn: CapnReader.StructReader = nested.get_struct(i)
		var name: String = CapnSchema.nested_name(nn)
		var id: int = CapnSchema.nested_id(nn)
		var flat: String = _uniquify(_safe_type((prefix + "_" + name) if not prefix.is_empty() else name), used)
		var child: CapnReader.StructReader = by_id.get(id)
		if child == null:
			continue
		used[flat] = true
		flat_by_id[id] = flat
		result.append(CodegenEntry.new(id, flat, child, prefix.is_empty()))
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


## Qualify cross-file type names into flat_by_id: for every OTHER file in the
## request, run the same flatten pass and record its node ids as
## "<OtherUmbrella>.<flat>" — so a field of an imported type resolves to that
## file's generated umbrella class. Local names already in flat_by_id win. Only
## requested files are qualified: an imported type from a file we don't generate
## has no umbrella to point at, so it stays unresolved (and `capnp`'s built-in
## c++.capnp annotations — never requested — are skipped, avoiding a bogus
## "C++Capnp" reference). Request all your files together: `capnp compile a b`.
static func _add_cross_file_names(current_file_id: int, by_id: Dictionary[int, CapnReader.StructReader], flat_by_id: Dictionary[int, String], requested_ids: Dictionary[int, bool]) -> void:
	for fid: int in requested_ids:
		if fid == current_file_id:
			continue
		var fnode: CapnReader.StructReader = by_id.get(fid)
		if fnode == null:
			continue
		var other: Dictionary[int, String] = { }
		_collect(fnode, by_id, other)
		var umbrella: String = _umbrella_class(CapnSchema.node_display_name(fnode))
		for id: int in other:
			if not flat_by_id.has(id):
				flat_by_id[id] = "%s.%s" % [umbrella, other[id]]

# --- emission ------------------------------------------------------------


static func _emit_umbrella(fname: String, file_node: CapnReader.StructReader, by_id: Dictionary[int, CapnReader.StructReader], requested_ids: Dictionary[int, bool]) -> String:
	var flat_by_id: Dictionary[int, String] = { }
	var types: Array[CodegenEntry] = _collect(file_node, by_id, flat_by_id)
	# Cross-file refs (CG7): a field of an imported type resolves to that file's
	# umbrella class. Local names (already in flat_by_id) win; everything else
	# from the other requested files becomes a qualified "Umbrella.Flat".
	_add_cross_file_names(CapnSchema.node_id(file_node), by_id, flat_by_id, requested_ids)

	# Generics monomorphization (CG1b): find every concrete instantiation
	# (Box(Text), Box(Inner), …) and register its signature -> mono class name
	# BEFORE emitting fields, so a branded struct field resolves to its mono class
	# (Box(Text) -> Box_Text.Reader). The erased generic (CG1a) still emits as the
	# unbound floor; mono classes are additive.
	_mono_by_sig = { }
	_inherit_mono_by_key = { }
	var used_names: Dictionary[String, bool] = { }
	for id: int in flat_by_id:
		used_names[flat_by_id[id]] = true
	var monos: Array[MonoInst] = _collect_instantiations(types, by_id, flat_by_id, used_names)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("class_name %s extends RefCounted" % _umbrella_class(fname))
	lines.append("")
	lines.append("## GENERATED from %s by capnpc-gdscript — do not edit." % fname)
	lines.append("")

	# Enums first (class-scoped), then schema-level consts, then struct classes.
	for entry: CodegenEntry in types:
		if CapnSchema.node_which(entry.node) == CapnSchema.NodeWhich.ENUM:
			_emit_enum(lines, entry)
	for entry: CodegenEntry in types:
		if CapnSchema.node_which(entry.node) == CapnSchema.NodeWhich.CONST:
			_emit_const(lines, entry, flat_by_id)
	for entry: CodegenEntry in types:
		if CapnSchema.node_which(entry.node) == CapnSchema.NodeWhich.STRUCT:
			_emit_struct(lines, entry, flat_by_id, by_id)

	# Monomorphic classes (CG1b): each instantiation re-emits the generic struct
	# with its parameter slot(s) typed to the bound type. A synthetic entry carries
	# the mono name; subst/subst_scope drive the param substitution in _emit_struct.
	for m: MonoInst in monos:
		var ent: CodegenEntry = CodegenEntry.new(CapnSchema.node_id(m.gen_node), m.mono_name, m.gen_node, false)
		_emit_struct(lines, ent, flat_by_id, by_id, m.subst, m.subst_scope)

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


## Emit a class-scoped GDScript const for a schema `const` node. Handles scalar
## / bool / float / Text / enum values; Data (C1 — Packed* can't be const),
## struct, list, and pointer consts emit a TODO (rare; would need a static var
## or a value builder).
static func _emit_const(lines: PackedStringArray, entry: CodegenEntry, flat_by_id: Dictionary[int, String]) -> void:
	var t: CapnReader.StructReader = CapnSchema.const_type(entry.node)
	var tw: CapnSchema.TypeWhich = CapnSchema.type_which(t)
	var name: String = _safe_enum_member(_snake(entry.flat).to_upper())
	var lit: String = _const_literal(CapnSchema.const_value(entry.node), tw)
	if lit.is_empty():
		lines.append("# TODO: const '%s' of type %d (unsupported value kind)" % [name, tw])
		lines.append("")
		return
	lines.append("const %s: %s = %s" % [name, _const_type_str(tw), lit])
	lines.append("")


## GDScript type for a const of TypeWhich `tw` (enum is int-typed at const
## scope — int at the wire, no `as`-cast complications in a constant expr).
static func _const_type_str(tw: CapnSchema.TypeWhich) -> String:
	if tw == CapnSchema.TypeWhich.BOOL:
		return "bool"
	elif tw == CapnSchema.TypeWhich.FLOAT32 or tw == CapnSchema.TypeWhich.FLOAT64:
		return "float"
	elif tw == CapnSchema.TypeWhich.TEXT:
		return "String"
	return "int"


## The GDScript literal for a const Value (the actual value — unlike a field
## default, no XOR/bit-pattern form). "" for kinds we don't emit.
static func _const_literal(v: CapnReader.StructReader, tw: CapnSchema.TypeWhich) -> String:
	if tw == CapnSchema.TypeWhich.BOOL:
		return "true" if CapnSchema.value_bool(v) else "false"
	elif tw == CapnSchema.TypeWhich.INT8:
		return str(CapnSchema.value_i8(v))
	elif tw == CapnSchema.TypeWhich.INT16:
		return str(CapnSchema.value_i16(v))
	elif tw == CapnSchema.TypeWhich.INT32:
		return str(CapnSchema.value_i32(v))
	elif tw == CapnSchema.TypeWhich.INT64:
		return str(CapnSchema.value_i64(v))
	elif tw == CapnSchema.TypeWhich.UINT8:
		return str(CapnSchema.value_u8(v))
	elif tw == CapnSchema.TypeWhich.UINT16:
		return str(CapnSchema.value_u16(v))
	elif tw == CapnSchema.TypeWhich.UINT32:
		return str(CapnSchema.value_u32(v))
	elif tw == CapnSchema.TypeWhich.UINT64:
		return str(CapnSchema.value_u64(v))
	elif tw == CapnSchema.TypeWhich.ENUM:
		# UInt64 > 2^63-1 reads back negative (Godot int is signed, no unsigned
		# 64-bit Variant) — a wire-wide limitation, not specific to consts.
		return str(CapnSchema.value_enum(v))
	elif tw == CapnSchema.TypeWhich.FLOAT32:
		return _float_literal(CapnSchema.value_f32(v), false)
	elif tw == CapnSchema.TypeWhich.FLOAT64:
		return _float_literal(CapnSchema.value_f64(v), true)
	elif tw == CapnSchema.TypeWhich.TEXT:
		return _gd_string(CapnSchema.value_text(v))
	return ""


## A valid GDScript float literal. str() emits the bare value but renders the
## non-finite values as "inf"/"nan" — not parseable identifiers — so map those
## to INF / -INF / NAN. Caveat: str() gives ~14 significant digits, so a
## math-derived Float64 const can differ from the schema at the ULP level
## (acceptable for the typical designer-tuned constant; `is_f64` is reserved for
## a future higher-precision path). GDScript's % formatter has no %g.
static func _float_literal(x: float, _is_f64: bool) -> String:
	if is_nan(x):
		return "NAN"
	if is_inf(x):
		return "INF" if x > 0.0 else "-INF"
	return str(x)


static func _emit_struct(lines: PackedStringArray, entry: CodegenEntry, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], subst: Dictionary[int, CapnReader.StructReader] = { }, subst_scope: int = 0) -> void:
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
		var gf: CapnReader.StructReader = fields.get_struct(i)
		var ov: CapnReader.StructReader = _param_override(gf, subst, subst_scope)
		if ov != null:
			# Generic parameter slot (CG1b): emit a typed getter from the bound type
			# instead of the erased AnyPointer accessors.
			_emit_slot_getter(lines, _safe_member(_snake(CapnSchema.field_name(gf))), gf, flat_by_id, ov)
		else:
			_emit_field_getter(lines, gf, flat_by_id, by_id, struct_disc, subst, subst_scope)
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
		var sf: CapnReader.StructReader = fields.get_struct(i)
		var ov: CapnReader.StructReader = _param_override(sf, subst, subst_scope)
		if ov != null:
			# Generic parameter slot (CG1b): typed setter from the bound type.
			_emit_slot_setter(lines, _safe_member(_snake(CapnSchema.field_name(sf))), sf, flat_by_id, -1, 0, -1, 0, ov)
		else:
			_emit_field_setter(lines, sf, flat_by_id, by_id, struct_disc, subst, subst_scope)
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
		var full: String = ("%s_%s" % [prefix, fname]) if not prefix.is_empty() else fname
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
	var by_disc: Dictionary[int, String] = { }
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		if CapnSchema.field_in_union(m):
			by_disc[CapnSchema.field_discriminant_value(m)] = _safe_enum_member(_snake(CapnSchema.field_name(m)).to_upper())
	var ordered: PackedStringArray = PackedStringArray()
	for d: int in CapnSchema.node_struct_discriminant_count(gnode):
		ordered.append(by_disc.get(d, "RESERVED_%d" % d))
	lines.append(TAB + "enum %s { %s }" % [_safe_type(_pascal(name_snake)), ", ".join(ordered)])


## subst/subst_scope (CG1d): when this struct is a generic mono, a param slot
## nested inside one of its groups resolves to the bound type — threaded down to
## every group leaf so group-nested params emit typed, not erased. (Top-level
## param slots never reach here: _emit_struct applies _param_override and emits
## them directly; this fn handles only the non-param fields it recurses into.)
static func _emit_field_getter(lines: PackedStringArray, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], struct_disc: int, subst: Dictionary[int, CapnReader.StructReader] = { }, subst_scope: int = 0) -> void:
	var fname: String = _safe_member(_snake(CapnSchema.field_name(f)))
	# Any struct-level union arm — slot, named group, or union group — gets an
	# outer is_<name>() selector first.
	var is_struct_arm: bool = struct_disc >= 0 and CapnSchema.field_in_union(f)
	var gnode: CapnReader.StructReader = _union_node(f, by_id)
	if gnode != null:
		if is_struct_arm:
			_emit_is_arm(lines, fname, struct_disc, CapnSchema.field_discriminant_value(f))
		_emit_union_getters(lines, fname, gnode, flat_by_id, by_id, subst, subst_scope)
		return
	if CapnSchema.field_which(f) == CapnSchema.FieldWhich.GROUP:
		var named: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(f))
		if named == null:
			lines.append("")
			lines.append(TAB + TAB + "# TODO: named group '%s' (unresolved cross-file type)" % fname)
			return
		if is_struct_arm:
			_emit_is_arm(lines, fname, struct_disc, CapnSchema.field_discriminant_value(f))
		_emit_named_group_getters(lines, fname, named, flat_by_id, by_id, subst, subst_scope)
		return
	if is_struct_arm:
		_emit_is_arm(lines, fname, struct_disc, CapnSchema.field_discriminant_value(f))
	_emit_slot_getter(lines, fname, f, flat_by_id, null, _inherit_flat(f, subst, subst_scope))


## Emit is_<name>() -> bool for a struct-level union arm: true when the struct's
## discriminant (at byte `struct_disc`) equals this arm's value.
static func _emit_is_arm(lines: PackedStringArray, fname: String, struct_disc: int, disc_val: int) -> void:
	lines.append("")
	lines.append(TAB + TAB + "func is_%s() -> bool:" % fname)
	lines.append(TAB + TAB + TAB + "return _r.get_u16(%d, 0) == %d" % [struct_disc, disc_val])


## Emit a get_<suffix>() reader for a slot field. Void fields produce nothing.
## type_override (CG1b): when non-null, emit the accessor with this Type instead
## of the field's declared type (a generic parameter slot bound to a concrete
## type). The wire offset still comes from `f` (param fields are pointer slots).
## flat_override (CG1d): when non-empty, a STRUCT field resolves to this class name
## instead of its brand-derived name — used for an inherit-branded field whose mono
## name comes from the enclosing instantiation, not its own (erased) brand.
static func _emit_slot_getter(lines: PackedStringArray, suffix: String, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String], type_override: CapnReader.StructReader = null, flat_override: String = "") -> void:
	var t: CapnReader.StructReader = type_override if type_override != null else CapnSchema.field_slot_type(f)
	var off: int = CapnSchema.field_slot_offset(f)
	var tw: CapnSchema.TypeWhich = CapnSchema.type_which(t)
	if tw == CapnSchema.TypeWhich.VOID:
		return
	if tw == CapnSchema.TypeWhich.STRUCT and not flat_override.is_empty():
		lines.append("")
		lines.append(TAB + TAB + "func get_%s() -> %s.Reader:" % [suffix, flat_override])
		lines.append(TAB + TAB + TAB + "return %s.Reader.wrap(_r.get_struct(%d))" % [flat_override, off])
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
## subst/subst_scope (CG1d): a union arm that is a generic param slot resolves to
## the bound type.
## A group arm (CG11) is flattened past its is_<arm>() selector: a named-group arm
## gets get_<arm>_<field>(); a union-group arm gets a nested <arm>_which() + is_/
## get_ — all sharing the parent layout, so reads need no discriminant threading.
static func _emit_union_getters(lines: PackedStringArray, gsnake: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], subst: Dictionary[int, CapnReader.StructReader] = { }, subst_scope: int = 0) -> void:
	var disc: int = _disc_byte(gnode)
	lines.append("")
	lines.append(TAB + TAB + "func %s_which() -> int:" % gsnake)
	lines.append(TAB + TAB + TAB + "return _r.get_u16(%d, 0)" % disc)
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		var mfull: String = "%s_%s" % [gsnake, _safe_member(_snake(CapnSchema.field_name(m)))]
		lines.append("")
		lines.append(TAB + TAB + "func is_%s() -> bool:" % mfull)
		lines.append(TAB + TAB + TAB + "return _r.get_u16(%d, 0) == %d" % [disc, CapnSchema.field_discriminant_value(m)])
		if CapnSchema.field_which(m) == CapnSchema.FieldWhich.SLOT:
			_emit_slot_getter(lines, mfull, m, flat_by_id, _param_override(m, subst, subst_scope))
			continue
		# CG11: group arm of this union. is_<arm>() above selects it; flatten the
		# group's fields (or its nested union) the same way a struct-level group arm
		# does — the layout is shared, so reads carry no discriminant.
		var un: CapnReader.StructReader = _union_node(m, by_id)
		if un != null:
			_emit_union_getters(lines, mfull, un, flat_by_id, by_id, subst, subst_scope)
		else:
			var sub: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(m))
			if sub == null:
				lines.append("")
				lines.append(TAB + TAB + "# TODO: group arm '%s' (unresolved cross-file type)" % mfull)
			else:
				_emit_named_group_getters(lines, mfull, sub, flat_by_id, by_id, subst, subst_scope)


## Named (non-discriminated) group reader: a group is a sub-namespace whose
## fields share the parent's data/pointer layout, so flatten them into
## get_<group>_<field>() accessors. Recurses for nested named groups and
## delegates to _emit_union_getters for a union nested inside the group.
static func _emit_named_group_getters(lines: PackedStringArray, prefix: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], subst: Dictionary[int, CapnReader.StructReader] = { }, subst_scope: int = 0) -> void:
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		var full: String = "%s_%s" % [prefix, _safe_member(_snake(CapnSchema.field_name(m)))]
		var un: CapnReader.StructReader = _union_node(m, by_id)
		if un != null:
			_emit_union_getters(lines, full, un, flat_by_id, by_id, subst, subst_scope)
		elif CapnSchema.field_which(m) == CapnSchema.FieldWhich.GROUP:
			var sub: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(m))
			if sub == null:
				lines.append("")
				lines.append(TAB + TAB + "# TODO: nested group '%s' (unresolved cross-file type)" % full)
				continue
			_emit_named_group_getters(lines, full, sub, flat_by_id, by_id, subst, subst_scope)
		else:
			_emit_slot_getter(lines, full, m, flat_by_id, _param_override(m, subst, subst_scope))


static func _emit_list_getter(lines: PackedStringArray, fname: String, off: int, elem: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> void:
	var ew: CapnSchema.TypeWhich = CapnSchema.type_which(elem)
	if ew == CapnSchema.TypeWhich.ANY_POINTER:
		# List(AnyPointer): elements are erased — each may be a struct, list, text,
		# data, or capability, so there's no single typed Array shape. Return the
		# raw outer ListReader; the caller materializes element i with the matching
		# per-element accessor — lr.get_struct_ptr(i) / get_list(i) / get_text(i) /
		# get_data(i) / get_cap_index(i) (CG10b). capnp admits this only via
		# List(AnyList) — a literal List(AnyPointer) is rejected by the compiler.
		lines.append("")
		lines.append(TAB + TAB + "func get_%s() -> CapnReader.ListReader:" % fname)
		lines.append(TAB + TAB + TAB + "return _r.get_list(%d)" % off)
		return
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
	if ew == CapnSchema.TypeWhich.LIST:
		# List(List(T)): each element is a lazy inner list reader; the caller reads
		# its elements with typed getters (or recurses for deeper nesting) (CG10).
		return "Array[CapnReader.ListReader]"
	if ew == CapnSchema.TypeWhich.INTERFACE:
		return "Array[int]" # capability cap-table indices (CG10)
	if ew == CapnSchema.TypeWhich.VOID:
		return "Array" # List(Void): length-only, elements are null (AnyPointer handled in _emit_list_getter, CG10b)
	if ew == CapnSchema.TypeWhich.STRUCT:
		var flat: String = _struct_flat(elem, flat_by_id)
		return ("Array[%s.Reader]" % flat) if not flat.is_empty() else "Array"
	return "Array[%s]" % _return_type(ew, elem, flat_by_id)

# --- setters (Builder) ---------------------------------------------------


## subst/subst_scope (CG1d): mirror of _emit_field_getter — a param slot nested
## in one of a generic mono's groups resolves to its bound type.
static func _emit_field_setter(lines: PackedStringArray, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], struct_disc: int, subst: Dictionary[int, CapnReader.StructReader] = { }, subst_scope: int = 0) -> void:
	var fname: String = _safe_member(_snake(CapnSchema.field_name(f)))
	var gnode: CapnReader.StructReader = _union_node(f, by_id)
	if gnode != null:
		# A union group that is itself an arm of a struct-level union (CG4):
		# thread the OUTER discriminant in so selecting an inner arm also selects
		# this group on the outer union. Otherwise the inner setters alone leave
		# the outer which() at its zero default.
		if struct_disc >= 0 and CapnSchema.field_in_union(f):
			_emit_union_setters(lines, fname, gnode, flat_by_id, by_id, struct_disc, CapnSchema.field_discriminant_value(f), subst, subst_scope)
		else:
			_emit_union_setters(lines, fname, gnode, flat_by_id, by_id, -1, 0, subst, subst_scope)
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
			_emit_named_group_setters(lines, fname, named, flat_by_id, by_id, struct_disc, CapnSchema.field_discriminant_value(f), subst, subst_scope)
		else:
			_emit_named_group_setters(lines, fname, named, flat_by_id, by_id, -1, 0, subst, subst_scope)
		return
	# A struct-level union member's setter also writes the discriminant.
	var flat_override: String = _inherit_flat(f, subst, subst_scope)
	if struct_disc >= 0 and CapnSchema.field_in_union(f):
		_emit_slot_setter(lines, fname, f, flat_by_id, struct_disc, CapnSchema.field_discriminant_value(f), -1, 0, null, flat_override)
	else:
		_emit_slot_setter(lines, fname, f, flat_by_id, -1, 0, -1, 0, null, flat_override)


## Emit a setter (set_/init_) for a slot field. When disc_off >= 0 the field is
## a union member, so the setter writes the discriminant first.
## type_override (CG1b): see _emit_slot_getter — a generic parameter slot bound to
## a concrete type emits a typed setter; offset still from `f`.
## flat_override (CG1d): see _emit_slot_getter — a STRUCT field resolves to this
## class name (an inherit-branded field's enclosing-instantiation mono).
static func _emit_slot_setter(lines: PackedStringArray, suffix: String, f: CapnReader.StructReader, flat_by_id: Dictionary[int, String], disc_off: int, disc_val: int, outer_disc_off: int = -1, outer_disc_val: int = 0, type_override: CapnReader.StructReader = null, flat_override: String = "") -> void:
	var t: CapnReader.StructReader = type_override if type_override != null else CapnSchema.field_slot_type(f)
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
		var child: String = flat_override if not flat_override.is_empty() else _struct_flat(t, flat_by_id)
		if child.is_empty():
			lines.append("")
			lines.append(TAB + TAB + "# TODO(M6): init '%s' (unresolved cross-file struct)" % suffix)
			return
		lines.append("")
		lines.append(TAB + TAB + "func init_%s() -> %s.Builder:" % [suffix, child])
		if not disc_line.is_empty():
			lines.append(disc_line)
		lines.append(TAB + TAB + TAB + "return %s.Builder.wrap(_b.init_struct(%d, %s.DATA_WORDS, %s.PTR_WORDS))" % [child, off, child, child])
		return
	if tw == CapnSchema.TypeWhich.ANY_POINTER:
		_emit_anyptr_setter(lines, suffix, off, disc_line)
		return
	if tw == CapnSchema.TypeWhich.INTERFACE:
		# Capability field: no RPC layer to inject a cap. As a union arm it still
		# needs a selector that writes the discriminant(s) (so the arm is
		# reachable); the cap itself stays unset. A plain field gets no setter.
		if not disc_line.is_empty():
			lines.append("")
			lines.append(TAB + TAB + "func set_%s() -> void:  # selects this arm; the capability stays unset (no RPC)" % suffix)
			lines.append(disc_line)
		else:
			lines.append("")
			lines.append(TAB + TAB + "# capability '%s' is read-only (serialization only, no RPC)" % suffix)
		return
	lines.append("")
	lines.append(TAB + TAB + "func set_%s(value: %s) -> void:" % [suffix, _return_type(tw, t, flat_by_id)])
	if not disc_line.is_empty():
		lines.append(disc_line)
	# Text/Data writes carry no XOR default (set_text/set_data ignore `def`), so
	# skip computing the default literal for them — value_text/value_data +
	# _gd_string/_data_literal would otherwise allocate a string the setter discards
	# (CQ4).
	var def: String = "" if (tw == CapnSchema.TypeWhich.TEXT or tw == CapnSchema.TypeWhich.DATA) else _default_for(f, tw)
	lines.append(TAB + TAB + TAB + _scalar_set("_b", tw, off, def))


## Type-erased builder accessors for an AnyPointer / generic-parameter slot.
## Mirrors _emit_anyptr_getter: init_<f>_struct allocates the pointee and returns
## the RAW StructBuilder (the caller wraps it in the concrete type's Builder);
## init_<f>_list/composite_list return a ListBuilder used directly; set_<f>_text/
## data write a pointer payload. Each entry point writes the slot, so each writes
## the union discriminant first when the field is a union member.
static func _emit_anyptr_setter(lines: PackedStringArray, suffix: String, off: int, disc_line: String) -> void:
	lines.append("")
	lines.append(TAB + TAB + "func init_%s_struct(data_words: int, ptr_words: int) -> CapnBuilder.StructBuilder:" % suffix)
	if not disc_line.is_empty():
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_struct(%d, data_words, ptr_words)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func init_%s_list(elem_size: CapnPointer.ElemSize, count: int) -> CapnBuilder.ListBuilder:" % suffix)
	if not disc_line.is_empty():
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_list(%d, elem_size, count)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func init_%s_composite_list(count: int, data_words: int, ptr_words: int) -> CapnBuilder.ListBuilder:" % suffix)
	if not disc_line.is_empty():
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_composite_list(%d, count, data_words, ptr_words)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func set_%s_text(value: String) -> void:" % suffix)
	if not disc_line.is_empty():
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "_b.set_text(%d, value)" % off)
	lines.append("")
	lines.append(TAB + TAB + "func set_%s_data(value: PackedByteArray) -> void:" % suffix)
	if not disc_line.is_empty():
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "_b.set_data(%d, value)" % off)


static func _emit_list_setter(lines: PackedStringArray, fname: String, off: int, elem: CapnReader.StructReader, flat_by_id: Dictionary[int, String], disc_line: String = "") -> void:
	var ew: CapnSchema.TypeWhich = CapnSchema.type_which(elem)
	lines.append("")
	if ew == CapnSchema.TypeWhich.INTERFACE:
		# Capability list: serialization-only, no RPC layer to write caps (CG6/CG10).
		lines.append(TAB + TAB + "# init '%s' omitted: List(interface) is read-only (capability)" % fname)
		return
	if ew == CapnSchema.TypeWhich.ANY_POINTER:
		# List(AnyPointer): erased pointer elements. Allocate the outer pointer
		# list and hand back its raw ListBuilder; the caller fills each element via
		# the per-element entry points — init_struct_ptr(i, dw, pw) / init_list_at(
		# i, code, n) / init_composite_list_at(i, n, dw, pw) / set_text(i, s) /
		# set_data(i, bytes) (CG10b). Mirrors the getter's raw-ListReader return.
		lines.append(TAB + TAB + "func init_%s(n: int) -> CapnBuilder.ListBuilder:" % fname)
		if not disc_line.is_empty():
			lines.append(disc_line)
		lines.append(TAB + TAB + TAB + "return _b.init_list(%d, CapnPointer.ElemSize.POINTER, n)" % off)
		return
	if ew == CapnSchema.TypeWhich.STRUCT:
		var child: String = _flat_of(elem, flat_by_id)
		if child.is_empty():
			lines.append(TAB + TAB + "# TODO(M6): init '%s' (unresolved cross-file struct list)" % fname)
			return
		# Composite list -> typed Array of element Builders.
		var arr: String = "Array[%s.Builder]" % child
		lines.append(TAB + TAB + "func init_%s(n: int) -> %s:" % [fname, arr])
		if not disc_line.is_empty():
			lines.append(disc_line)
		lines.append(TAB + TAB + TAB + "var lb: CapnBuilder.ListBuilder = _b.init_composite_list(%d, n, %s.DATA_WORDS, %s.PTR_WORDS)" % [off, child, child])
		lines.append(TAB + TAB + TAB + "var out: %s = []" % arr)
		lines.append(TAB + TAB + TAB + "out.resize(n)")
		lines.append(TAB + TAB + TAB + "for i: int in n:")
		lines.append(TAB + TAB + TAB + TAB + "out[i] = %s.Builder.wrap(lb.init_struct(i))" % child)
		lines.append(TAB + TAB + TAB + "return out")
		return
	# Primitive / Text / Data list -> a raw ListBuilder; caller sets elements
	# via lb.set_<kind>(i, value). A List(List(T)) outer also lands here:
	# _elem_size_token(LIST) is POINTER, so this allocates the outer pointer list
	# and the caller fills each element via lb.init_list_at / init_composite_list_at
	# (CG10).
	lines.append(TAB + TAB + "func init_%s(n: int) -> CapnBuilder.ListBuilder:" % fname)
	if not disc_line.is_empty():
		lines.append(disc_line)
	lines.append(TAB + TAB + TAB + "return _b.init_list(%d, %s, n)" % [off, _elem_size_token(ew)])


## Union (group) builder: per-member set_/init_ that writes the discriminant.
## When the group is itself a struct-level union arm, outer_disc_off/val are
## threaded to each member setter so it also selects this group on the outer
## union (CG4).
## A group arm (CG11) flattens like a slot arm, but its leaf setters carry this
## union's discriminant as their OUTER write (selecting any leaf selects the arm).
## Bounded: a group arm whose union is itself a struct-level arm (outer_disc_off
## >= 0) would need three discriminant writes per leaf — beyond the two
## _emit_slot_setter carries — so it degrades to a loud TODO (reader still works).
static func _emit_union_setters(lines: PackedStringArray, gsnake: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], outer_disc_off: int = -1, outer_disc_val: int = 0, subst: Dictionary[int, CapnReader.StructReader] = { }, subst_scope: int = 0) -> void:
	var disc: int = _disc_byte(gnode)
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		var mfull: String = "%s_%s" % [gsnake, _safe_member(_snake(CapnSchema.field_name(m)))]
		if CapnSchema.field_which(m) == CapnSchema.FieldWhich.SLOT:
			_emit_slot_setter(lines, mfull, m, flat_by_id, disc, CapnSchema.field_discriminant_value(m), outer_disc_off, outer_disc_val, _param_override(m, subst, subst_scope))
			continue
		# CG11: group arm. Its leaves must select this arm — write this union's
		# discriminant. A third (struct-level) discriminant can't be carried, so
		# bound to the case where this union is not itself a struct-level arm.
		if outer_disc_off >= 0:
			lines.append("")
			lines.append(TAB + TAB + "# TODO(M6): group arm '%s' under a struct-level union (3-level discriminant)" % mfull)
			continue
		var un: CapnReader.StructReader = _union_node(m, by_id)
		if un != null:
			_emit_union_setters(lines, mfull, un, flat_by_id, by_id, disc, CapnSchema.field_discriminant_value(m), subst, subst_scope)
		else:
			var sub: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(m))
			if sub == null:
				lines.append("")
				lines.append(TAB + TAB + "# TODO: group arm '%s' (unresolved cross-file type)" % mfull)
			else:
				_emit_named_group_setters(lines, mfull, sub, flat_by_id, by_id, disc, CapnSchema.field_discriminant_value(m), subst, subst_scope)


## Named (non-discriminated) group builder: mirror of _emit_named_group_getters.
## Flattens to set_<group>_<field>()/init_<group>_<field>(); recurses for nested
## named groups; delegates to _emit_union_setters for a union nested in the group.
## When the group is itself a struct-level union arm, outer_disc_off/val thread
## down to every leaf setter so selecting any leaf selects this arm (CG4).
static func _emit_named_group_setters(lines: PackedStringArray, prefix: String, gnode: CapnReader.StructReader, flat_by_id: Dictionary[int, String], by_id: Dictionary[int, CapnReader.StructReader], outer_disc_off: int = -1, outer_disc_val: int = 0, subst: Dictionary[int, CapnReader.StructReader] = { }, subst_scope: int = 0) -> void:
	var members: CapnReader.ListReader = CapnSchema.node_struct_fields(gnode)
	for i: int in members.size():
		var m: CapnReader.StructReader = members.get_struct(i)
		var full: String = "%s_%s" % [prefix, _safe_member(_snake(CapnSchema.field_name(m)))]
		var un: CapnReader.StructReader = _union_node(m, by_id)
		if un != null:
			_emit_union_setters(lines, full, un, flat_by_id, by_id, outer_disc_off, outer_disc_val, subst, subst_scope)
		elif CapnSchema.field_which(m) == CapnSchema.FieldWhich.GROUP:
			var sub: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(m))
			if sub == null:
				lines.append("")
				lines.append(TAB + TAB + "# TODO: nested group '%s' (unresolved cross-file type)" % full)
				continue
			_emit_named_group_setters(lines, full, sub, flat_by_id, by_id, outer_disc_off, outer_disc_val, subst, subst_scope)
		else:
			_emit_slot_setter(lines, full, m, flat_by_id, -1, 0, outer_disc_off, outer_disc_val, _param_override(m, subst, subst_scope))


static func _disc_byte(gnode: CapnReader.StructReader) -> int:
	# discriminantOffset is in 16-bit units (the discriminant is a u16).
	return CapnSchema.node_struct_discriminant_offset(gnode) * 2

# Variant builtin type names (not in ClassDB) + GDScript keywords. ClassDB
# covers every engine class (Node, Resource, ...) dynamically. Dictionaries (not
# PackedStringArray) for O(1) `.has()` — these are membership sets, queried per
# emitted identifier, never iterated (P8).
static var _VARIANT_TYPES: Dictionary[String, bool] = {
	"bool": true,
	"int": true,
	"float": true,
	"String": true,
	"StringName": true,
	"NodePath": true,
	"RID": true,
	"Object": true,
	"Callable": true,
	"Signal": true,
	"Dictionary": true,
	"Array": true,
	"Variant": true,
	"Nil": true,
	"void": true,
	"Vector2": true,
	"Vector2i": true,
	"Vector3": true,
	"Vector3i": true,
	"Vector4": true,
	"Vector4i": true,
	"Rect2": true,
	"Rect2i": true,
	"Transform2D": true,
	"Transform3D": true,
	"Plane": true,
	"Quaternion": true,
	"AABB": true,
	"Basis": true,
	"Projection": true,
	"Color": true,
	"PackedByteArray": true,
	"PackedInt32Array": true,
	"PackedInt64Array": true,
	"PackedFloat32Array": true,
	"PackedFloat64Array": true,
	"PackedStringArray": true,
	"PackedVector2Array": true,
	"PackedVector3Array": true,
	"PackedVector4Array": true,
	"PackedColorArray": true,
}
static var _GD_KEYWORDS: Dictionary[String, bool] = {
	"if": true,
	"elif": true,
	"else": true,
	"for": true,
	"while": true,
	"match": true,
	"when": true,
	"break": true,
	"continue": true,
	"pass": true,
	"return": true,
	"class": true,
	"class_name": true,
	"extends": true,
	"is": true,
	"as": true,
	"self": true,
	"super": true,
	"signal": true,
	"func": true,
	"static": true,
	"const": true,
	"enum": true,
	"var": true,
	"breakpoint": true,
	"preload": true,
	"await": true,
	"yield": true,
	"assert": true,
	"void": true,
	"and": true,
	"or": true,
	"not": true,
	"in": true,
	"true": true,
	"false": true,
	"null": true,
	"PI": true,
	"TAU": true,
	"INF": true,
	"NAN": true,
}
# Object getter stems a field would shadow via get_<stem>() — Readers/Builders
# extend RefCounted (Object), so only Object's own getters matter (NOT Node's
# get_name/get_path/get_owner). "class" is also a keyword, covered separately.
static var _RESERVED_MEMBERS: Dictionary[String, bool] = {
	"script": true,
	"meta": true,
	"instance_id": true,
	"method_list": true,
	"property_list": true,
	"signal_list": true,
	"incoming_connections": true,
	"indexed": true,
}


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
	if ew == CapnSchema.TypeWhich.VOID:
		return "CapnPointer.ElemSize.VOID" # List(Void): count only, zero width
	elif ew == CapnSchema.TypeWhich.BOOL:
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
		if eflat.is_empty():
			return "%s.get_u16(%d, %s)" % [recv, off * 2, def]
		return "%s.get_u16(%d, %s) as %s" % [recv, off * 2, def, eflat]
	elif tw == CapnSchema.TypeWhich.TEXT:
		return "%s.get_text(%d, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.DATA:
		return "%s.get_data(%d, %s)" % [recv, off, def]
	elif tw == CapnSchema.TypeWhich.STRUCT:
		var flat: String = _struct_flat(t, flat_by_id)
		if flat.is_empty():
			return "null  # TODO(M6): unresolved cross-file struct"
		return "%s.Reader.wrap(%s.get_struct(%d))" % [flat, recv, off]
	elif tw == CapnSchema.TypeWhich.INTERFACE:
		# Capability field: no RPC layer, so decode to the cap-table index
		# (-1 when absent). Read-only — there's no setter (see _emit_slot_setter).
		return "%s.get_cap_index(%d)" % [recv, off]
	return "null  # TODO(M6): type %d" % tw


static func _list_elem_expr(ew: CapnSchema.TypeWhich, elem: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	if ew == CapnSchema.TypeWhich.VOID:
		return "null" # List(Void) carries only a length; elements have no value
	if ew == CapnSchema.TypeWhich.LIST:
		return "lr.get_list(i)" # List(List(T)): lazy inner list reader (CG10)
	if ew == CapnSchema.TypeWhich.INTERFACE:
		return "lr.get_cap_index(i)" # List(interface): cap-table index, -1 absent (CG10)
	if ew == CapnSchema.TypeWhich.STRUCT:
		var flat: String = _struct_flat(elem, flat_by_id)
		if flat.is_empty():
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
		return ("lr.get_u16(i) as %s" % eflat) if not eflat.is_empty() else "lr.get_u16(i)"
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
		var flat: String = _struct_flat(t, flat_by_id)
		return ("%s.Reader" % flat) if not flat.is_empty() else "Variant"
	elif tw == CapnSchema.TypeWhich.ENUM:
		# Enum at the API boundary (D10a): return the generated enum type for
		# autocomplete; int underneath. Cross-file enum (unresolved) -> int.
		var flat: String = _flat_of(t, flat_by_id)
		return flat if not flat.is_empty() else "int"
	elif tw == CapnSchema.TypeWhich.INTERFACE:
		return "int" # cap-table index
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


## Flattened name for a STRUCT type, resolving a concrete generic instantiation to
## its monomorphic class (CG1b). Box(Text) -> "Box_Text" when that instantiation
## was collected; otherwise falls back to the erased generic / plain struct name.
## Gate the caller on type_which == STRUCT (reads the brand).
static func _struct_flat(t: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	var sig: String = _brand_signature(t)
	if _mono_by_sig.has(sig):
		return _mono_by_sig[sig]
	return _flat_of(t, flat_by_id)

# --- generics monomorphization (CG1b) ------------------------------------


## The bound Type for `f` when it is a generic parameter slot of the generic
## currently being monomorphized, else null. A param slot is an AnyPointer whose
## anyPointer.which == PARAMETER and whose scopeId matches subst_scope; the bound
## type is subst[parameterIndex] (null when that parameter is left unbound).
## subst is READ-ONLY here and in every emitter that threads it — never mutated —
## so the `subst = {}` shared-default-literal in those signatures (engine bug C2)
## is safe; subst_scope == 0 (the non-generic default) also short-circuits below.
static func _param_override(f: CapnReader.StructReader, subst: Dictionary[int, CapnReader.StructReader], subst_scope: int) -> CapnReader.StructReader:
	if subst_scope == 0:
		return null
	if CapnSchema.field_which(f) != CapnSchema.FieldWhich.SLOT:
		return null
	var t: CapnReader.StructReader = CapnSchema.field_slot_type(f)
	if CapnSchema.type_which(t) != CapnSchema.TypeWhich.ANY_POINTER:
		return null
	if CapnSchema.type_anyptr_which(t) != CapnSchema.AnyPtrWhich.PARAMETER:
		return null
	if CapnSchema.anyptr_param_scope_id(t) != subst_scope:
		return null
	return subst.get(CapnSchema.anyptr_param_index(t))

## Max generic-nesting depth the collector recurses (Box(Box(Box(…))) — bound the
## recursion per NASA rule 2). Real schemas nest a handful deep at most.
const _MAX_GENERIC_DEPTH: int = 16


## Walk every collected struct's slot field; for each field whose type (or, for a
## list field, element type) is a concrete generic instantiation, register it and
## recurse into its brand bindings — Box(Box(Text)) registers Box_Text then
## Box_Box_Text; a List(Box(Text)) field registers Box_Text (its getter then
## resolves the element to Box_Text.Reader via _struct_flat). Dedup by signature
## so two fields of Box(Text) share one Box_Text. Group fields are walked
## recursively (CG1d), so a Box(Text)-typed slot nested inside a named/union group
## registers its mono too — the leaf getter would otherwise resolve to the erased
## floor. Still deferred (see docs/CG1B_PLAN.md): inherit scopes (Outer(T).Inner),
## generic enums/interfaces, cross-file mono dedup.
static func _collect_instantiations(types: Array[CodegenEntry], by_id: Dictionary[int, CapnReader.StructReader], flat_by_id: Dictionary[int, String], used_names: Dictionary[String, bool]) -> Array[MonoInst]:
	var insts: Array[MonoInst] = []
	var seen: Dictionary[String, bool] = { }
	for entry: CodegenEntry in types:
		if CapnSchema.node_which(entry.node) != CapnSchema.NodeWhich.STRUCT:
			continue
		_collect_field_insts(CapnSchema.node_struct_fields(entry.node), by_id, flat_by_id, insts, seen, used_names, 0)
	return insts


## Walk a field list, registering the instantiation behind every slot's type and
## recursing into group fields (CG1d). `depth` bounds the group recursion (NASA
## rule 2); group nesting is finite + acyclic, the cap is a backstop.
static func _collect_field_insts(fields: CapnReader.ListReader, by_id: Dictionary[int, CapnReader.StructReader], flat_by_id: Dictionary[int, String], insts: Array[MonoInst], seen: Dictionary[String, bool], used_names: Dictionary[String, bool], depth: int) -> void:
	if depth >= _MAX_GENERIC_DEPTH:
		return
	for i: int in fields.size():
		var f: CapnReader.StructReader = fields.get_struct(i)
		if CapnSchema.field_which(f) == CapnSchema.FieldWhich.SLOT:
			_register_inst(CapnSchema.field_slot_type(f), by_id, flat_by_id, insts, seen, used_names, 0)
		elif CapnSchema.field_which(f) == CapnSchema.FieldWhich.GROUP:
			var g: CapnReader.StructReader = by_id.get(CapnSchema.field_group_type_id(f))
			if g != null:
				_collect_field_insts(CapnSchema.node_struct_fields(g), by_id, flat_by_id, insts, seen, used_names, depth + 1)


## Register the instantiation for type `t` if it is a concrete generic struct, and
## recurse into its brand bindings (inner generics) + list elements. Inner monos
## are registered before the outer so the dedup map is fully populated before
## emit; emit order is forward-ref-safe regardless.
static func _register_inst(t: CapnReader.StructReader, by_id: Dictionary[int, CapnReader.StructReader], flat_by_id: Dictionary[int, String], insts: Array[MonoInst], seen: Dictionary[String, bool], used_names: Dictionary[String, bool], depth: int) -> void:
	if depth >= _MAX_GENERIC_DEPTH:
		push_error("[CapnCodegen] generic nesting exceeds %d — not monomorphizing deeper" % _MAX_GENERIC_DEPTH)
		return
	var tw: CapnSchema.TypeWhich = CapnSchema.type_which(t)
	if tw == CapnSchema.TypeWhich.LIST:
		_register_inst(CapnSchema.type_list_element(t), by_id, flat_by_id, insts, seen, used_names, depth + 1)
		return
	if tw != CapnSchema.TypeWhich.STRUCT:
		return
	if not _is_concrete_generic(t):
		return
	# Only monomorphize generics we actually emit. A generic defined in an
	# unrequested file has no local class to extend the layout from, so its field
	# stays unresolved (erased) rather than emitting a broken mono.
	if not flat_by_id.has(CapnSchema.type_id(t)):
		return
	var sig: String = _brand_signature(t)
	if seen.has(sig):
		return
	seen[sig] = true
	var gen_id: int = CapnSchema.type_id(t)
	var gen_node: CapnReader.StructReader = by_id.get(gen_id)
	if gen_node == null:
		return
	var subst: Dictionary[int, CapnReader.StructReader] = _build_subst(t, gen_id)
	for idx: int in subst:
		_register_inst(subst[idx], by_id, flat_by_id, insts, seen, used_names, depth + 1)
	var mono_name: String = _uniquify(_mono_name(flat_by_id[gen_id], t, flat_by_id), used_names)
	used_names[mono_name] = true
	_mono_by_sig[sig] = mono_name
	insts.append(MonoInst.new(gen_node, mono_name, subst, gen_id))
	# A nested struct of this generic that inherits its parameters (INHERIT brand)
	# needs its own per-instantiation mono so the inherited param resolves (CG1d).
	_register_inherit_monos(gen_node, gen_id, subst, by_id, flat_by_id, insts, used_names, 0)


## Register a mono for every nested struct of `gen_node` whose field type carries
## an INHERIT brand scope for `gen_id` — i.e. it inherits the enclosing generic's
## parameters (`Outer(T).Inner` referenced by `inner :Inner`). The inner mono
## reuses the enclosing `subst` (the inner struct's param slots scope to `gen_id`,
## so _param_override types them when _emit_struct re-emits the inner node with
## this subst). depth bounds the walk (NASA rule 2); only direct top-level slot
## fields are handled — a group-nested or deeper-chained inherit field degrades to
## the erased floor (no wrong output).
static func _register_inherit_monos(gen_node: CapnReader.StructReader, gen_id: int, subst: Dictionary[int, CapnReader.StructReader], by_id: Dictionary[int, CapnReader.StructReader], flat_by_id: Dictionary[int, String], insts: Array[MonoInst], used_names: Dictionary[String, bool], depth: int) -> void:
	if depth >= _MAX_GENERIC_DEPTH:
		push_error("[CapnCodegen] inherit-mono nesting exceeds %d — not monomorphizing deeper" % _MAX_GENERIC_DEPTH)
		return
	var fields: CapnReader.ListReader = CapnSchema.node_struct_fields(gen_node)
	for i: int in fields.size():
		var f: CapnReader.StructReader = fields.get_struct(i)
		if CapnSchema.field_which(f) != CapnSchema.FieldWhich.SLOT:
			continue
		var t: CapnReader.StructReader = CapnSchema.field_slot_type(f)
		if not _inherits_scope(t, gen_id):
			continue
		var inner_id: int = CapnSchema.type_id(t)
		# A self-reference (inner_id == gen_id) is the generic itself, not a nested
		# inheriting struct — it resolves through _mono_by_sig (or the erased floor),
		# never a separate inherit mono. Skip to avoid a split-brain duplicate class.
		if inner_id == gen_id:
			continue
		var inner_node: CapnReader.StructReader = by_id.get(inner_id)
		if inner_node == null or not flat_by_id.has(inner_id):
			continue
		var key: String = _inherit_key(inner_id, subst)
		if _inherit_mono_by_key.has(key):
			continue
		var name: String = _uniquify(_mono_name_from_subst(flat_by_id[inner_id], subst, flat_by_id), used_names)
		used_names[name] = true
		_inherit_mono_by_key[key] = name
		insts.append(MonoInst.new(inner_node, name, subst, gen_id))
		# The inner mono may itself reference further inherit structs of the same
		# generic — register those too (still scoped to gen_id).
		_register_inherit_monos(inner_node, gen_id, subst, by_id, flat_by_id, insts, used_names, depth + 1)


## True when STRUCT type `t` carries an INHERIT brand scope for `sid` (it inherits
## the parameters of the generic whose node id is `sid`).
static func _inherits_scope(t: CapnReader.StructReader, sid: int) -> bool:
	if CapnSchema.type_which(t) != CapnSchema.TypeWhich.STRUCT:
		return false
	var scopes: CapnReader.ListReader = CapnSchema.brand_scopes(CapnSchema.type_brand(t))
	for i: int in scopes.size():
		var s: CapnReader.StructReader = scopes.get_struct(i)
		if CapnSchema.scope_id(s) == sid and CapnSchema.scope_which(s) == CapnSchema.BrandScopeWhich.INHERIT:
			return true
	return false


## Dedup/lookup key for an inherit mono: inner node id + the enclosing subst's
## bound-type signatures (index order). Distinguishes Outer(Text).Inner from
## Outer(Int).Inner, which share the same inner node id but differ in subst.
static func _inherit_key(inner_id: int, subst: Dictionary[int, CapnReader.StructReader]) -> String:
	var s: String = str(inner_id)
	var idxs: Array[int] = []
	idxs.assign(subst.keys())
	idxs.sort()
	for k: int in idxs:
		s += "#" + _sig_of_type(subst[k])
	return s


## Human mono name for an inherit instantiation: "<InnerFlat>_<Arg>…" using the
## enclosing subst's bound types (Outer_Inner + Text -> Outer_Inner_Text).
static func _mono_name_from_subst(inner_flat: String, subst: Dictionary[int, CapnReader.StructReader], flat_by_id: Dictionary[int, String]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(_basename(inner_flat))
	var idxs: Array[int] = []
	idxs.assign(subst.keys())
	idxs.sort()
	for k: int in idxs:
		parts.append(_arg_name_of_type(subst[k], flat_by_id))
	return _safe_type("_".join(parts))


## The inherit-mono class name for slot field `f` in a `subst`/`subst_scope`
## context, or "" when `f` is not an inherit-branded struct field (CG1d). Read at
## emit time by the slot getter/setter to resolve the field to its mono.
static func _inherit_flat(f: CapnReader.StructReader, subst: Dictionary[int, CapnReader.StructReader], subst_scope: int) -> String:
	if subst_scope == 0:
		return ""
	if CapnSchema.field_which(f) != CapnSchema.FieldWhich.SLOT:
		return ""
	var t: CapnReader.StructReader = CapnSchema.field_slot_type(f)
	if not _inherits_scope(t, subst_scope):
		return ""
	return _inherit_mono_by_key.get(_inherit_key(CapnSchema.type_id(t), subst), "")


## True when STRUCT type `t` carries a brand that binds at least one of its own
## parameters to a concrete type (vs all-unbound -> falls back to the erased
## generic). Reads the BIND scope whose scopeId == t's node id.
static func _is_concrete_generic(t: CapnReader.StructReader) -> bool:
	var scope: CapnReader.StructReader = _find_bind_scope(t)
	if scope == null:
		return false
	var binds: CapnReader.ListReader = CapnSchema.scope_bind(scope)
	for i: int in binds.size():
		if CapnSchema.binding_which(binds.get_struct(i)) == CapnSchema.BindingWhich.TYPE:
			return true
	return false


## The Brand.Scope (which == BIND) binding `t`'s own parameters, or null.
static func _find_bind_scope(t: CapnReader.StructReader) -> CapnReader.StructReader:
	var gen_id: int = CapnSchema.type_id(t)
	var scopes: CapnReader.ListReader = CapnSchema.brand_scopes(CapnSchema.type_brand(t))
	for i: int in scopes.size():
		var s: CapnReader.StructReader = scopes.get_struct(i)
		if CapnSchema.scope_id(s) == gen_id and CapnSchema.scope_which(s) == CapnSchema.BrandScopeWhich.BIND:
			return s
	return null


## parameterIndex -> bound Type reader for the concrete bindings of `t`.
static func _build_subst(t: CapnReader.StructReader, gen_id: int) -> Dictionary[int, CapnReader.StructReader]:
	var out: Dictionary[int, CapnReader.StructReader] = { }
	var scope: CapnReader.StructReader = _find_bind_scope(t)
	if scope == null:
		return out
	var binds: CapnReader.ListReader = CapnSchema.scope_bind(scope)
	for i: int in binds.size():
		var b: CapnReader.StructReader = binds.get_struct(i)
		if CapnSchema.binding_which(b) == CapnSchema.BindingWhich.TYPE:
			out[i] = CapnSchema.binding_type(b)
	return out


## Canonical dedup key for an instantiation: "<genId>|<arg>|<arg>…" using node
## ids (request-order-independent). Unbound params render "U". A plain struct (no
## bindings) yields just "<id>", which never matches a mono entry.
static func _brand_signature(t: CapnReader.StructReader) -> String:
	var s: String = str(CapnSchema.type_id(t))
	var scope: CapnReader.StructReader = _find_bind_scope(t)
	if scope == null:
		return s
	var binds: CapnReader.ListReader = CapnSchema.scope_bind(scope)
	for i: int in binds.size():
		s += "|" + _sig_of_binding(binds.get_struct(i))
	return s


static func _sig_of_binding(b: CapnReader.StructReader) -> String:
	if CapnSchema.binding_which(b) != CapnSchema.BindingWhich.TYPE:
		return "U"
	return _sig_of_type(CapnSchema.binding_type(b))


## Signature fragment for a bound type. Struct -> "n(<brand-sig>)" (the brand is
## expanded recursively so Box(Box(Text)) and Box(Box(Int32)) get distinct keys);
## enum/interface -> "n<id>"; list -> "L(<elem>)"; scalar/text/etc -> "s<which>".
## (capnp forbids scalar generic args, so the scalar arm only renders LIST element
## types, never a bound parameter.)
static func _sig_of_type(t: CapnReader.StructReader) -> String:
	var tw: CapnSchema.TypeWhich = CapnSchema.type_which(t)
	if tw == CapnSchema.TypeWhich.STRUCT:
		return "n(" + _brand_signature(t) + ")"
	if tw == CapnSchema.TypeWhich.ENUM or tw == CapnSchema.TypeWhich.INTERFACE:
		return "n" + str(CapnSchema.type_id(t))
	if tw == CapnSchema.TypeWhich.LIST:
		return "L(" + _sig_of_type(CapnSchema.type_list_element(t)) + ")"
	return "s" + str(tw)


## Human mono name: "<GenFlat>_<Arg>_<Arg>…" (Box_Text, Map_Text_Int32). Struct/
## enum args use the bound type's flat basename; scalars use the capnp kind name.
static func _mono_name(gen_flat: String, t: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(_basename(gen_flat))
	var scope: CapnReader.StructReader = _find_bind_scope(t)
	if scope != null:
		var binds: CapnReader.ListReader = CapnSchema.scope_bind(scope)
		for i: int in binds.size():
			parts.append(_mono_arg_name(binds.get_struct(i), flat_by_id))
	return _safe_type("_".join(parts))


static func _mono_arg_name(b: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	if CapnSchema.binding_which(b) != CapnSchema.BindingWhich.TYPE:
		return "Any"
	return _arg_name_of_type(CapnSchema.binding_type(b), flat_by_id)


static func _arg_name_of_type(t: CapnReader.StructReader, flat_by_id: Dictionary[int, String]) -> String:
	var tw: CapnSchema.TypeWhich = CapnSchema.type_which(t)
	if tw == CapnSchema.TypeWhich.STRUCT:
		var flat: String = flat_by_id.get(CapnSchema.type_id(t), "")
		var base: String = _basename(flat) if not flat.is_empty() else "Struct"
		# A generic arg that is itself an instantiation appends its own args, so
		# Box(Box(Text)) -> Box_Box_Text (distinct from Box(Box(Int32))).
		var scope: CapnReader.StructReader = _find_bind_scope(t)
		if scope != null:
			var binds: CapnReader.ListReader = CapnSchema.scope_bind(scope)
			for i: int in binds.size():
				base += "_" + _mono_arg_name(binds.get_struct(i), flat_by_id)
		return base
	if tw == CapnSchema.TypeWhich.ENUM or tw == CapnSchema.TypeWhich.INTERFACE:
		var flat: String = flat_by_id.get(CapnSchema.type_id(t), "")
		return _basename(flat) if not flat.is_empty() else _capnp_kind_name(tw)
	if tw == CapnSchema.TypeWhich.LIST:
		return "List_" + _arg_name_of_type(CapnSchema.type_list_element(t), flat_by_id)
	return _capnp_kind_name(tw)


## Last "."-segment of a (possibly cross-file-qualified) flat name:
## "CommonCapnp.Point" -> "Point", "Box" -> "Box".
static func _basename(flat: String) -> String:
	return flat.get_slice(".", flat.get_slice_count(".") - 1)


static func _capnp_kind_name(tw: CapnSchema.TypeWhich) -> String:
	if tw == CapnSchema.TypeWhich.VOID:
		return "Void"
	elif tw == CapnSchema.TypeWhich.BOOL:
		return "Bool"
	elif tw == CapnSchema.TypeWhich.INT8:
		return "Int8"
	elif tw == CapnSchema.TypeWhich.INT16:
		return "Int16"
	elif tw == CapnSchema.TypeWhich.INT32:
		return "Int32"
	elif tw == CapnSchema.TypeWhich.INT64:
		return "Int64"
	elif tw == CapnSchema.TypeWhich.UINT8:
		return "UInt8"
	elif tw == CapnSchema.TypeWhich.UINT16:
		return "UInt16"
	elif tw == CapnSchema.TypeWhich.UINT32:
		return "UInt32"
	elif tw == CapnSchema.TypeWhich.UINT64:
		return "UInt64"
	elif tw == CapnSchema.TypeWhich.FLOAT32:
		return "Float32"
	elif tw == CapnSchema.TypeWhich.FLOAT64:
		return "Float64"
	elif tw == CapnSchema.TypeWhich.TEXT:
		return "Text"
	elif tw == CapnSchema.TypeWhich.DATA:
		return "Data"
	return "Any"

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
