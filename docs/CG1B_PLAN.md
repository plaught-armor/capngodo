# CG1b — Generics monomorphization (design + discovery)

CG1a (done) type-erases generic-parameter fields: `Box(T)` → a single `Box`
class whose `value` field exposes `get_value_struct/list/text/data()`. CG1b adds
fully-typed per-instantiation classes on top: `Box(Text)` → `Box_Text` with
`get_value() -> String`. CG1a stays the fallback for unbound / AnyPointer-bound
uses.

This file is the scoping discovery so the build is a focused effort, not
archaeology. Offsets lifted from `capnproto/c++/src/capnp/schema.capnp.h`.

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

## The four passes (codegen)

1. **Collect instantiations.** Walk every struct field's type. A field whose
   type is `struct/enum/interface` with a `brand` carrying concrete bindings is
   an instantiation: `(typeId, binding-tuple)`. Recurse into the bindings
   (a binding's type may itself be a branded instantiation — `Box(Map(Text,Int))`).

2. **Resolve a binding context.** For an instantiation, build a map
   `(scopeId, parameterIndex) -> resolved Type` from the brand's `scopes[].bind[]`.
   `inherit` scopes pass the parameter through to the enclosing context. The
   generic node's own `parameters` list (Node.parameters, ptr 5 — already in
   meta_schema as `node_parameters`) gives the parameter names/arity.

3. **Emit a concrete class per instantiation.** Clone the generic struct's
   emission but, wherever a field's type is `anyPointer.parameter` matching
   `(scopeId, index)`, substitute the resolved type from the binding context.
   Nested types of the generic that reference the params get their own
   monomorphic emission threaded with the same context. Name = `<Flat>_<Arg…>`
   (e.g. `Box_Text`, `Map_Text_Int32`); sanitize + uniquify like flat names.

4. **Dedup + register.** Two fields with the same `(typeId, binding-tuple)`
   share one emitted class. Register each instantiation's name in `flat_by_id`-style
   so field accessors reference `Box_Text.Reader` instead of the erased `Box`.

## Hazards / test matrix

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
