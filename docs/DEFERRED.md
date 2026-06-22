# Deferred work

Items consciously deferred during M1–M6, collected from the per-section reviews
so they aren't lost. Grouped by area; priority is P1 (should fix before a real
release) → P3 (nice-to-have / measure-first). Nothing here is a known-wrong
result on the tested paths — these are gaps, edges, and polish.

## Codegen features (biggest gaps)

| id | pri | item | notes |
|---|---|---|---|
| CG1a | ✅ | **Generics — type-erased** | Done. A type parameter is a plain pointer on the wire, so a parameter-typed field (and an explicit `:AnyPointer`) emits type-erased accessors: reader `has_<f>()` + `get_<f>_struct/list/text/data()`; builder `init_<f>_struct/list/composite_list()` + `set_<f>_text/data()`. Generic structs themselves get normal classes (`Box(T)` → `Box`); brand bindings ignored — the caller resolves the concrete kind from the binding it knows statically. Union-arm AnyPointer setters write the outer discriminant. Bidirectional interop-verified. Schema: `tests/golden/generic.capnp`; test: `tests/integration/test_generic.gd`. Also covers the AnyPointer half of CG6. |
| CG1b | P1 | **Generics — monomorphized** (`Brand` resolution) | Layer fully-typed per-instantiation classes on top of CG1a's erased base: resolve `Brand.Scope`/`Binding` from the CGR and emit a concrete class per binding tuple (`Box(Text)` → `Box_Text` with `get_value() -> String`). Recursive (bindings thread into nested generic types) and combinatorial. Largest remaining feature; CG1a is the unbound floor it falls back to. |
| CG2 | ✅ | **Reserved-name sanitization** | Done. Type names (class/enum) colliding with a Godot type (`ClassDB.class_exists` + Variant types) or GDScript keyword get a trailing `_` (`Color`→`Color_`, `Node`→`Node_`); field stems colliding with keywords or Object getters (`class`/`script`/`meta`) too (`get_class_`). Cross-refs stay consistent via `flat_by_id`. Interop-verified (capnp decode reads the original names). Test: `tests/integration/test_reserved_names.gd`. |
| CG3 | P2 | **Named (non-union) groups** | A `:group { ... }` with no discriminant emits only a `# TODO(M6): named group 'X'` comment — no accessors. Need flattened `get_<group>_<field>()` recursion. |
| CG4 | P2 | **Nested union in a struct-level union** | A union-group that is itself an arm of a struct-level union: member setters don't write the OUTER `which()`. Guarded with an inline `# TODO` in generated output; reader side is correct. |
| CG5 | P2 | **Data field defaults** | `Data` field with `hadExplicitDefault` drops the authored bytes (returns empty). Need to emit a `PackedByteArray([...])` literal or a boot-loaded const. (Numeric/bool/enum/float/Text defaults ARE done.) |
| CG6 | P2 | **Interface field types** | AnyPointer fields now handled by CG1a (type-erased accessors). Interface/capability fields still emit no-op stubs (`null` getter, `pass` setter) — they decode to a table index at runtime but codegen has no accessor yet. |
| CG7 | P3 | **Cross-file type references** | Multi-file schemas (`import`/`using`) — a field of an imported type isn't in the current file's `flat_by_id`; `_flat_of` returns "" → valid-but-`null`/`Variant` stub + `push_error`. Need a cross-file name map. |

## Codegen quality / typing

| id | pri | item | notes |
|---|---|---|---|
| CQ1 | P2 | **Typed `Array[T]` list returns** | Generated list getters/setters use untyped `Array` (elements are `Variant`), so call sites lose autocomplete/typing (forces untyped test locals, H1). Emit `Array[X.Reader]` + `assign()` (C3). |
| CQ2 | P3 | **Enum-typed returns (D10a)** | Enum getters return `int`, not the generated enum type. Could emit `-> <Enum>` for autocomplete (still int underneath). |
| CQ3 | P3 | **`_pascal` ALLCAPS / `_snake` acronym runs** | `_snake("HTTPServer")` → `httpserver` (not `http_server`); `_pascal` lowercases tails. Fine for capnp's lowerCamelCase convention, edge for ALLCAPS names. |
| CQ4 | P3 | **`_scalar_set` TEXT/DATA computes unused `def`** | `_default_for` runs for text/data setters but the literal is unused (text/data don't XOR on write). Short-circuit. |
| CQ5 | P3 | **Typed containers (H10b)** | `_index_nodes`/`_collect` and threaded `by_id`/`flat_by_id` params are plain `Dictionary`/`Array` despite carrying known shapes. Type the signatures. |
| CQ6 | P3 | **Struct-level union untested** | Codegen supports struct-level unions (`which()` + `is_*`) but only group-unions are covered by tests. Add a struct-level-union test schema. |
| CQ7 | P3 | **Golden compile-check warning** | `test_generated_sources_compile` reload()s a source whose `class_name` is already registered → benign `"hides a global script class"` log. Strip `class_name` before the isolated compile, or accept the noise. |

## Runtime perf (measure-first — DOD inline checklist)

| id | pri | item | notes |
|---|---|---|---|
| RT1 | P3 | **Packed codec hot-loop allocs** | `wire_packed` builds output via per-word `append`; pre-size + indexed writes if profiling shows it. |
| RT2 | P3 | **Reader `_buf()` 3-hop** | `msg.segments.segments[seg_id]` per primitive read; cache the buffer ref in the reader if hot. |
| RT3 | P3 | **`read_u64` naming** | `CapnWireWords.read_u64` returns a possibly-negative bit pattern; consider `read_u64_bits` to surface that. No callers today. |

## Packaging (the rest of M7)

| id | pri | item | notes |
|---|---|---|---|
| PK1 | ✅ | **`tools/build_capnp.sh`** | Done. Builds `capnp` from a checkout (cmake/ninja, no sudo); prints the binary path. |
| PK2 | ✅ | **README** | Done. Install, the `capnp compile -o gdscript` workflow, env vars, runtime-codec usage. Workflow verified verbatim. |
| PK3 | ✅ | **GUT CI script** | Done — `tools/run_tests.sh` (import + GUT headless, propagates exit code). |
| PK4 | P3 | **Editor plugin panel** | `plugin.gd` is a stub; optional in-editor "compile .capnp" UI (like godobuf). |
| PK5 | ✅ | **Repo folder rename** | Done — repo is `capngodo`. |
| PK6 | P2 | **Verify Windows codegen on real Windows** | `tools/capnpc-gdscript.cmd` + the shimless 2-step are documented but UNTESTED on a real Windows host (developed on Linux). The plugin itself (`plugin_main.gd`) is cross-platform. Open Q: does capnp spawn a `.cmd` plugin via `-o gdscript` on Windows? If not, the shimless 2-step is the fallback. |

## Accepted as-is (documented, not bugs)

- Empty-`PackedByteArray`-on-error ambiguity in `xor_bytes`/`pack`/`unpack` (only ambiguous when input is legitimately empty; errors also `push_error`).
- Unchecked enum casts (`x as NodeWhich`, etc.) in the meta-reader — input is trusted capnp output; would only drift on an upstream schema version bump.
- Non-canonical builder output (cross-segment uses double-far always; orphaned bytes when a union member is re-set) — spec-valid, just not minimal.
