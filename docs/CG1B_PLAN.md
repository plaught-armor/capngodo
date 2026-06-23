# CG1b — Generics monomorphization (design + discovery)

CG1a (done) type-erases generic-parameter fields: `Box(T)` → a single `Box`
class whose `value` field exposes `get_value_struct/list/text/data()`. CG1b adds
fully-typed per-instantiation classes on top: `Box(Text)` → `Box_Text` with
`get_value() -> String`. CG1a stays the fallback for unbound / AnyPointer-bound
uses.

This file is the scoping discovery so the build is a focused effort, not
archaeology. Offsets lifted from `capnproto/c++/src/capnp/schema.capnp.h`.

## Status

- **Step 1 — meta_schema Brand accessors: DONE** (commit `8ee8652`). All the
  accessors below exist and are verified against `tests/fixtures/generic.cgr.bin`
  by `tests/integration/test_brand_meta.gd`. Every wire offset is confirmed.
- **Step 2 — the monomorphizer: TODO.** Detailed below. This is the remaining
  work; nothing in the codegen emits monomorphic classes yet.

## Wire offsets (for meta_schema accessors)

**Type** (the `brand` lives on the struct/enum/interface variants):
- `struct/enum/interface.brand` → pointer index **0**
- `anyPointer` sub-discriminant `which` → byte **8** (u16): `UNCONSTRAINED=0`, `PARAMETER=1`, `IMPLICIT_METHOD_PARAMETER=2`
- `anyPointer.parameter.scopeId` → byte **16** (u64)
- `anyPointer.parameter.parameterIndex` → byte **10** (u16)

**Brand:** `scopes` → pointer index **0** (List(Scope))

**Brand.Scope:**
- `scopeId` → byte **0** (u64)
- `which` → byte **8** (u16): `BIND=0`, `INHERIT=1`
- `bind` → pointer index **0** (List(Binding))

**Brand.Binding:**
- `which` → byte **0** (u16): `UNBOUND=0`, `TYPE=1`
- `type` → pointer index **0** (Type)

meta_schema additions (~12 accessors): `type_brand`, `type_anyptr_which`,
`anyptr_param_scope_id`, `anyptr_param_index`, `brand_scopes`, `scope_id`,
`scope_which`, `scope_bind`, `binding_which`, `binding_type`, plus
`enum BrandScopeWhich { BIND, INHERIT }` and `enum BindingWhich { UNBOUND, TYPE }`
and `enum AnyPtrWhich { UNCONSTRAINED, PARAMETER, IMPLICIT_METHOD_PARAMETER }`.

## Step 2 — concrete implementation plan

All in `addons/capngodo/codegen/codegen.gd`. CG1a's erased emit stays; mono
classes are additive. Build + test in the 2a → 2b → 2c order below.

### The shared context (do this first)

The two new maps travel with `flat_by_id` through the whole field-emit chain.
Rather than thread two more params through ~10 functions, add ONE bundle and
pass it where `flat_by_id` already goes:

```
class EmitCtx extends RefCounted:        # POD (D1)
    var flat_by_id: Dictionary[int, String]      # node id -> local/qualified flat
    var mono_by_sig: Dictionary[String, String]  # brand signature -> mono class name
    var subst: Dictionary[int, CapnReader.StructReader] = {}  # param index -> bound Type (current mono emit)
    var subst_scope: int = 0                      # the generic node id `subst` is for (0 = none)
```

Minimal-churn alternative if the EmitCtx rename is too broad in one pass: keep
`flat_by_id` as-is and add `mono_by_sig` + `subst`/`subst_scope` as parallel
params with defaults (`= {}` / `= null` / `= 0`) on the same functions. Either
way the touch list is: `_emit_struct`, `_emit_field_getter`, `_emit_field_setter`,
`_emit_slot_getter`, `_emit_slot_setter`, `_scalar_expr`, `_return_type`,
`_list_elem_expr`, `_list_container_type`, `_flat_of`/a new `_struct_flat`.

### Brand signature + naming

`_brand_signature(type) -> String`: canonical key for dedup. `"<typeId>|<arg>|<arg>…"`
where each arg is the bound type rendered: struct/enum → its node id (stable);
TEXT → "T", scalar → its TypeWhich, LIST → "L(" + elem-sig + ")". Use ids (not
flat names) so it's request-order-independent.

`_mono_name(gen_flat, brand) -> String`: human name `Box_Text`, `Map_Text_Int32`.
Arg rendering: struct/enum → that type's flat (basename), scalar/text → capnp
kind name (`Text`, `Int32`). `_safe_type` + uniquify against `used`.

### 2a — Substitution-aware field emit (no new classes yet)

1. Add `type_override` to `_emit_slot_getter`/`_emit_slot_setter`:
   `var t = type_override if type_override != null else field_slot_type(f)`. Offset
   still from `f` (param fields are pointer slots). Default null = unchanged.
2. In `_emit_field_getter`/`_emit_field_setter`, before dispatch: if `subst_scope != 0`
   and the field type is `anyPointer` with `type_anyptr_which == PARAMETER` and
   `anyptr_param_scope_id == subst_scope` → `type_override = subst[anyptr_param_index]`.
   Pass it down. Non-param fields: override stays null.
3. Verify: emitting `Box` with a subst `{0: <Text type>}` produces `get_value() ->
   String` instead of the erased `get_value_struct/...`. (Unit-test the emit on a
   hand-built subst before wiring collection.)

### 2b — Resolve branded struct field refs to mono names

`_struct_flat(type, ctx) -> String`: if `type_brand(type)` has bindings AND
`_brand_signature(type)` is in `ctx.mono_by_sig` → return that mono name; else
fall back to `_flat_of(type, ctx.flat_by_id)`. Swap `_flat_of` → `_struct_flat`
in the STRUCT arms of `_scalar_expr`, `_return_type`, `_emit_slot_setter`
(init_struct), `_list_elem_expr`, `_list_container_type`. So a field
`boxedText :Box(Text)` emits `Box_Text.Reader.wrap(...)`.

### 2c — Collect, dedup, emit

`_collect_instantiations(types, by_id, ctx) -> Array[MonoInst]`:
walk every struct field of every collected type; for a field whose type is a
struct with a brand carrying concrete bindings, compute its signature; if new,
register `ctx.mono_by_sig[sig] = mono_name` and queue a `MonoInst {gen_node,
mono_name, subst}` (subst built from the brand's `scopes[scopeId==gen_id].bind[]`).
Then in `_emit_umbrella`, after the normal struct loop, emit each MonoInst via
`_emit_struct` with its subst/subst_scope set (reuses the whole struct emitter,
param fields substituted). MonoInst classes go at umbrella scope next to the
erased `Box`.

Resolution order: collect BEFORE emitting fields (so `mono_by_sig` is populated
when getters resolve `Box(Text)` → `Box_Text`). Emit erased generic + mono
classes both; the erased one is the fallback for unbound use.

### Deferred within CG1b (land 2a–2c first, then iterate)

- Nested-generic bindings (`Box(Box(Text))`): the inner instantiation must also
  be collected + named, and the signature/naming recursion handles it. Add after
  the flat case works.
- `inherit` scopes (`Outer(T).Inner`): a `BrandScopeWhich.INHERIT` scope passes
  params through from the enclosing brand. Resolve against the outer subst.
- Generic enums / interface params.

## Hazards / test matrix

Extend `tests/golden/generic.capnp` + add a monomorphization test covering:

- Single instantiation: `Box(Text)`, `Box(SomeStruct)`, `Box(Int32)`.
- Multiple instantiations of one generic: `Box(Text)` + `Box(Int32)` → two classes.
- Nested generic: `Box(Box(Text))`, `Map(Text, List(Int32))`.
- `inherit` scope: generic struct with a nested type using the outer param
  (schema.capnp's own `Outer(T).Inner` example).
- Unbound / AnyPointer-bound use → must still fall back to CG1a's erased class.
- Generic enum/interface params.
- Cross-file generic instantiation (interacts with CG7).

## Boundary

Keep CG1a as the floor — never remove the erased class; monomorphic classes are
additive. A generic never used with concrete args emits only the erased form.
