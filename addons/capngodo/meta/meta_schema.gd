class_name CapnSchema extends RefCounted

## Typed accessors over a CodeGeneratorRequest message (capnp/schema.capnp),
## the input a `capnp compile -o-` plugin receives on stdin. Hand-written
## "generated-style" code that bootstraps the codegen plugin: it lets the plugin
## read the compiled schema (nodes, fields, types) using the runtime CapnReader.
##
## Offsets are lifted from capnp's generated schema.capnp.h (byte = element index
## x type size; bool offsets are bit positions). Static-fn system (D9): every
## accessor takes a CapnReader.StructReader and returns a primitive / String /
## child reader. One-way dependency on CapnReader, so no class_name cycle.
##
## Enum discriminant values follow union *declaration order* in schema.capnp
## (source: capnproto/c++/src/capnp/schema.capnp). Input is TRUSTED: capnp's own
## compiler output. The *_which() casts assume the discriminant is in range; an
## upstream schema that adds a new variant would need a new enum member here.
##
## Note: Field.slot's hadExplicitDefault bit (byte 16) and Field.group's typeId
## (u64 byte 16) intentionally share bytes — the which() discriminant at byte 8
## selects which is live. Gate variant accessors on which() before reading.

# Widened limits for schema input: schemas nest deeply (groups, annotations) and
# can be large, so we go past the 64MiW / depth-64 runtime defaults.
const CGR_TRAVERSAL_WORDS: int = 1 << 28
const CGR_DEPTH: int = 256

# Node.which() — byte 12 (u16). Order: schema.capnp Node union.
enum NodeWhich { FILE, STRUCT, ENUM, INTERFACE, CONST, ANNOTATION }

# Field.which() — byte 8 (u16).
enum FieldWhich { SLOT, GROUP }

# Type.which() / Value.which() — byte 0 (u16). Shared declaration order.
enum TypeWhich {
	VOID, BOOL, INT8, INT16, INT32, INT64,
	UINT8, UINT16, UINT32, UINT64, FLOAT32, FLOAT64,
	TEXT, DATA, LIST, ENUM, STRUCT, INTERFACE, ANY_POINTER,
}

# --- CodeGeneratorRequest (pointer section) ---
const CGR_PTR_NODES: int = 0
const CGR_PTR_REQUESTED_FILES: int = 1
const CGR_PTR_CAPNP_VERSION: int = 2

# --- Node ---
const NODE_OFF_ID: int = 0            # u64
const NODE_OFF_PREFIX_LEN: int = 8    # u32
const NODE_OFF_WHICH: int = 12        # u16
const NODE_OFF_SCOPE_ID: int = 16     # u64
const NODE_BIT_IS_GENERIC: int = 288  # bool
const NODE_PTR_DISPLAY_NAME: int = 0
const NODE_PTR_NESTED_NODES: int = 1
const NODE_PTR_PARAMETERS: int = 5
# Node.struct group (shares Node's data/ptr section)
const STRUCT_OFF_DATA_WORDS: int = 14         # u16
const STRUCT_OFF_DISCRIMINANT_OFFSET: int = 32 # u32
const STRUCT_OFF_POINTER_COUNT: int = 24       # u16
const STRUCT_OFF_DISCRIMINANT_COUNT: int = 30  # u16
const STRUCT_PTR_FIELDS: int = 3
# Node.enum group
const ENUM_PTR_ENUMERANTS: int = 3
# Node.const group
const CONST_PTR_TYPE: int = 3
const CONST_PTR_VALUE: int = 4

# --- Node.NestedNode ---
const NESTED_OFF_ID: int = 0  # u64
const NESTED_PTR_NAME: int = 0

# --- Field ---
const FIELD_OFF_CODE_ORDER: int = 0        # u16
const FIELD_OFF_DISCRIMINANT_VALUE: int = 2 # u16, default 0xffff
const FIELD_OFF_WHICH: int = 8             # u16
const FIELD_PTR_NAME: int = 0
const FIELD_NO_DISCRIMINANT: int = 0xffff
# Field.slot group
const SLOT_OFF_OFFSET: int = 4             # u32
const SLOT_BIT_HAD_DEFAULT: int = 128      # bool
const SLOT_PTR_TYPE: int = 2
const SLOT_PTR_DEFAULT_VALUE: int = 3
# Field.group group
const GROUP_OFF_TYPE_ID: int = 16          # u64

# --- Type ---
const TYPE_OFF_WHICH: int = 0              # u16
const TYPE_OFF_TYPE_ID: int = 8            # u64 (enum/struct/interface variants)
const TYPE_LIST_PTR_ELEMENT: int = 0       # Type.list.elementType
const TYPE_PTR_BRAND: int = 0              # Type.{struct,enum,interface}.brand (ptr 0)
# Type.anyPointer sub-union (gate on type_which() == ANY_POINTER first).
const ANYPTR_OFF_WHICH: int = 8           # u16 — Type.anyPointer.which()
const ANYPTR_PARAM_OFF_SCOPE: int = 16    # u64 — anyPointer.parameter.scopeId
const ANYPTR_PARAM_OFF_INDEX: int = 10    # u16 — anyPointer.parameter.parameterIndex

# Type.anyPointer.which() — byte 8 (u16).
enum AnyPtrWhich { UNCONSTRAINED, PARAMETER, IMPLICIT_METHOD_PARAMETER }

# --- Brand (generic parameter bindings) ---
const BRAND_PTR_SCOPES: int = 0           # List(Brand.Scope)
const SCOPE_OFF_ID: int = 0               # u64 — Brand.Scope.scopeId
const SCOPE_OFF_WHICH: int = 8            # u16 — Brand.Scope.which()
const SCOPE_PTR_BIND: int = 0             # List(Brand.Binding)
const BINDING_OFF_WHICH: int = 0          # u16 — Brand.Binding.which()
const BINDING_PTR_TYPE: int = 0           # Brand.Binding.type (a Type)

# Brand.Scope.which() — byte 8 (u16).
enum BrandScopeWhich { BIND, INHERIT }
# Brand.Binding.which() — byte 0 (u16).
enum BindingWhich { UNBOUND, TYPE }

# --- Value (union; gate reads on value_which) ---
const VALUE_OFF_WHICH: int = 0             # u16
const VALUE_BIT_BOOL: int = 16             # bool at bit 16 (byte 2)
const VALUE_OFF_8: int = 2                 # int8/uint8
const VALUE_OFF_16: int = 2                # int16/uint16/enum
const VALUE_OFF_32: int = 4                # int32/uint32/float32
const VALUE_OFF_64: int = 8                # int64/uint64/float64
const VALUE_PTR: int = 0                   # text/data

# --- Enumerant ---
const ENUMERANT_OFF_CODE_ORDER: int = 0    # u16
const ENUMERANT_PTR_NAME: int = 0

# --- CodeGeneratorRequest.RequestedFile ---
const REQFILE_OFF_ID: int = 0              # u64
const REQFILE_PTR_FILENAME: int = 0


# --- CodeGeneratorRequest ----------------------------------------------

## Returns the CodeGeneratorRequest root, or null on malformed input — the
## caller must null-check before using any accessor below.
static func open_request(bytes: PackedByteArray, packed: bool = false) -> CapnReader.StructReader:
	var limits: CapnLimits = CapnLimits.new(CGR_TRAVERSAL_WORDS, CGR_DEPTH)
	var msg: CapnReader.Message = CapnReader.open(bytes, packed, limits)
	if msg == null:
		return null
	return msg.get_root()


static func cgr_nodes(cgr: CapnReader.StructReader) -> CapnReader.ListReader:
	return cgr.get_list(CGR_PTR_NODES)


static func cgr_requested_files(cgr: CapnReader.StructReader) -> CapnReader.ListReader:
	return cgr.get_list(CGR_PTR_REQUESTED_FILES)


# --- Node --------------------------------------------------------------

static func node_id(n: CapnReader.StructReader) -> int:
	return n.get_u64(NODE_OFF_ID, 0)


static func node_display_name(n: CapnReader.StructReader) -> String:
	return n.get_text(NODE_PTR_DISPLAY_NAME)


## Unqualified (simple) name = displayName with the qualifying prefix stripped:
## the file path for a top-level node, file path + parent scopes for a nested
## one. e.g. "addressbook.capnp:Person.PhoneNumber" -> "PhoneNumber".
static func node_unqualified_name(n: CapnReader.StructReader) -> String:
	var full: String = node_display_name(n)
	var prefix_len: int = n.get_u32(NODE_OFF_PREFIX_LEN, 0)
	if prefix_len > 0 and prefix_len <= full.length():
		return full.substr(prefix_len)
	return full


static func node_which(n: CapnReader.StructReader) -> NodeWhich:
	return n.get_u16(NODE_OFF_WHICH, 0) as NodeWhich


static func node_scope_id(n: CapnReader.StructReader) -> int:
	return n.get_u64(NODE_OFF_SCOPE_ID, 0)


static func node_nested_nodes(n: CapnReader.StructReader) -> CapnReader.ListReader:
	return n.get_list(NODE_PTR_NESTED_NODES)


static func node_is_generic(n: CapnReader.StructReader) -> bool:
	return n.get_bool(NODE_BIT_IS_GENERIC, false)


## Generic parameters (List(Node.Parameter)) — empty for non-generic nodes.
static func node_parameters(n: CapnReader.StructReader) -> CapnReader.ListReader:
	return n.get_list(NODE_PTR_PARAMETERS)


# Node.const group: type + value (gate on node_which() == CONST).
static func const_type(n: CapnReader.StructReader) -> CapnReader.StructReader:
	return n.get_struct(CONST_PTR_TYPE)


static func const_value(n: CapnReader.StructReader) -> CapnReader.StructReader:
	return n.get_struct(CONST_PTR_VALUE)


static func node_struct_data_words(n: CapnReader.StructReader) -> int:
	return n.get_u16(STRUCT_OFF_DATA_WORDS, 0)


static func node_struct_pointer_count(n: CapnReader.StructReader) -> int:
	return n.get_u16(STRUCT_OFF_POINTER_COUNT, 0)


static func node_struct_discriminant_count(n: CapnReader.StructReader) -> int:
	return n.get_u16(STRUCT_OFF_DISCRIMINANT_COUNT, 0)


static func node_struct_discriminant_offset(n: CapnReader.StructReader) -> int:
	return n.get_u32(STRUCT_OFF_DISCRIMINANT_OFFSET, 0)


static func node_struct_fields(n: CapnReader.StructReader) -> CapnReader.ListReader:
	return n.get_list(STRUCT_PTR_FIELDS)


static func node_enum_enumerants(n: CapnReader.StructReader) -> CapnReader.ListReader:
	return n.get_list(ENUM_PTR_ENUMERANTS)


# --- Node.NestedNode ---------------------------------------------------

static func nested_id(nn: CapnReader.StructReader) -> int:
	return nn.get_u64(NESTED_OFF_ID, 0)


static func nested_name(nn: CapnReader.StructReader) -> String:
	return nn.get_text(NESTED_PTR_NAME)


# --- Field -------------------------------------------------------------

static func field_name(f: CapnReader.StructReader) -> String:
	return f.get_text(FIELD_PTR_NAME)


static func field_which(f: CapnReader.StructReader) -> FieldWhich:
	return f.get_u16(FIELD_OFF_WHICH, 0) as FieldWhich


static func field_code_order(f: CapnReader.StructReader) -> int:
	return f.get_u16(FIELD_OFF_CODE_ORDER, 0)


static func field_discriminant_value(f: CapnReader.StructReader) -> int:
	return f.get_u16(FIELD_OFF_DISCRIMINANT_VALUE, FIELD_NO_DISCRIMINANT)


static func field_in_union(f: CapnReader.StructReader) -> bool:
	return field_discriminant_value(f) != FIELD_NO_DISCRIMINANT


static func field_slot_offset(f: CapnReader.StructReader) -> int:
	return f.get_u32(SLOT_OFF_OFFSET, 0)


static func field_slot_type(f: CapnReader.StructReader) -> CapnReader.StructReader:
	return f.get_struct(SLOT_PTR_TYPE)


static func field_slot_default(f: CapnReader.StructReader) -> CapnReader.StructReader:
	return f.get_struct(SLOT_PTR_DEFAULT_VALUE)


static func field_slot_had_default(f: CapnReader.StructReader) -> bool:
	return f.get_bool(SLOT_BIT_HAD_DEFAULT, false)


static func field_group_type_id(f: CapnReader.StructReader) -> int:
	return f.get_u64(GROUP_OFF_TYPE_ID, 0)


# --- Type --------------------------------------------------------------

static func type_which(t: CapnReader.StructReader) -> TypeWhich:
	return t.get_u16(TYPE_OFF_WHICH, 0) as TypeWhich


## Referenced node id. Defined ONLY for the ENUM/STRUCT/INTERFACE variants
## (byte 8 is union-shared); gate on type_which() first. Fails loud on misuse.
static func type_id(t: CapnReader.StructReader) -> int:
	var w: TypeWhich = type_which(t)
	if w != TypeWhich.ENUM and w != TypeWhich.STRUCT and w != TypeWhich.INTERFACE:
		push_error("[CapnSchema] type_id() on Type.%s — undefined" % TypeWhich.keys()[w])
	return t.get_u64(TYPE_OFF_TYPE_ID, 0)


## Element type of a List. Defined ONLY for the LIST variant — gate on
## type_which() == LIST before calling.
static func type_list_element(t: CapnReader.StructReader) -> CapnReader.StructReader:
	return t.get_struct(TYPE_LIST_PTR_ELEMENT)


## The generic Brand on a STRUCT/ENUM/INTERFACE type (parameter bindings).
## Shares ptr 0 with Type.list.elementType — gate on type_which() first.
static func type_brand(t: CapnReader.StructReader) -> CapnReader.StructReader:
	return t.get_struct(TYPE_PTR_BRAND)


## Type.anyPointer sub-discriminant — gate on type_which() == ANY_POINTER.
static func type_anyptr_which(t: CapnReader.StructReader) -> AnyPtrWhich:
	return t.get_u16(ANYPTR_OFF_WHICH, 0) as AnyPtrWhich


## anyPointer.parameter.scopeId — the generic type whose parameter is referenced.
## Gate on type_anyptr_which() == PARAMETER.
static func anyptr_param_scope_id(t: CapnReader.StructReader) -> int:
	return t.get_u64(ANYPTR_PARAM_OFF_SCOPE, 0)


## anyPointer.parameter.parameterIndex — index within that type's param list.
static func anyptr_param_index(t: CapnReader.StructReader) -> int:
	return t.get_u16(ANYPTR_PARAM_OFF_INDEX, 0)


# --- Brand -------------------------------------------------------------

static func brand_scopes(b: CapnReader.StructReader) -> CapnReader.ListReader:
	return b.get_list(BRAND_PTR_SCOPES)


static func scope_id(s: CapnReader.StructReader) -> int:
	return s.get_u64(SCOPE_OFF_ID, 0)


static func scope_which(s: CapnReader.StructReader) -> BrandScopeWhich:
	return s.get_u16(SCOPE_OFF_WHICH, 0) as BrandScopeWhich


## List(Brand.Binding) — gate on scope_which() == BIND.
static func scope_bind(s: CapnReader.StructReader) -> CapnReader.ListReader:
	return s.get_list(SCOPE_PTR_BIND)


static func binding_which(b: CapnReader.StructReader) -> BindingWhich:
	return b.get_u16(BINDING_OFF_WHICH, 0) as BindingWhich


## The bound Type — gate on binding_which() == TYPE.
static func binding_type(b: CapnReader.StructReader) -> CapnReader.StructReader:
	return b.get_struct(BINDING_PTR_TYPE)


# --- Enumerant ---------------------------------------------------------

static func enumerant_name(e: CapnReader.StructReader) -> String:
	return e.get_text(ENUMERANT_PTR_NAME)


static func enumerant_code_order(e: CapnReader.StructReader) -> int:
	return e.get_u16(ENUMERANT_OFF_CODE_ORDER, 0)


# --- RequestedFile -----------------------------------------------------

static func req_file_id(rf: CapnReader.StructReader) -> int:
	return rf.get_u64(REQFILE_OFF_ID, 0)


static func req_file_name(rf: CapnReader.StructReader) -> String:
	return rf.get_text(REQFILE_PTR_FILENAME)


# --- Value (field defaults / const values) -----------------------------
# Gate each read on value_which(); reading the wrong variant is undefined.

static func value_which(v: CapnReader.StructReader) -> TypeWhich:
	return v.get_u16(VALUE_OFF_WHICH, 0) as TypeWhich


static func value_bool(v: CapnReader.StructReader) -> bool:
	return v.get_bool(VALUE_BIT_BOOL, false)


static func value_i8(v: CapnReader.StructReader) -> int:
	return v.get_i8(VALUE_OFF_8, 0)


static func value_i16(v: CapnReader.StructReader) -> int:
	return v.get_i16(VALUE_OFF_16, 0)


static func value_i32(v: CapnReader.StructReader) -> int:
	return v.get_i32(VALUE_OFF_32, 0)


static func value_i64(v: CapnReader.StructReader) -> int:
	return v.get_i64(VALUE_OFF_64, 0)


static func value_u8(v: CapnReader.StructReader) -> int:
	return v.get_u8(VALUE_OFF_8, 0)


static func value_u16(v: CapnReader.StructReader) -> int:
	return v.get_u16(VALUE_OFF_16, 0)


static func value_u32(v: CapnReader.StructReader) -> int:
	return v.get_u32(VALUE_OFF_32, 0)


static func value_u64(v: CapnReader.StructReader) -> int:
	return v.get_u64(VALUE_OFF_64, 0)


static func value_f32(v: CapnReader.StructReader) -> float:
	return v.get_f32(VALUE_OFF_32, 0)


static func value_f64(v: CapnReader.StructReader) -> float:
	return v.get_f64(VALUE_OFF_64, 0)


static func value_enum(v: CapnReader.StructReader) -> int:
	return v.get_u16(VALUE_OFF_16, 0)


static func value_text(v: CapnReader.StructReader) -> String:
	return v.get_text(VALUE_PTR)


static func value_data(v: CapnReader.StructReader) -> PackedByteArray:
	return v.get_data(VALUE_PTR)
