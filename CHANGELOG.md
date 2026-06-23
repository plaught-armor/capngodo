# Changelog

All notable changes to capngodo are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow
[SemVer](https://semver.org/).

## [0.1.0] — 2026-06-22

First release. Pure-GDScript Cap'n Proto serialization + schema codegen for
Godot 4.6+.

### Added

- **Runtime wire codec** (standalone, no dependencies): structs, lists (all 8
  element sizes), `Text`, `Data`, packed encoding, single + multi-segment
  messages, far + double-far pointers, default-value XOR, traversal and
  pointer-depth limits.
- **Schema codegen** via the `capnpc-gdscript` compiler plugin
  (`capnp compile -o gdscript`): typed `Reader`/`Builder` classes with
  `get_*` / `set_*` / `init_*` / `to_bytes` / `new_*` / `read_*`. Covers
  primitives, `Text`/`Data`, enums, nested structs, lists, struct-level and
  group unions, named groups, field + `Data` defaults, schema `const`
  declarations, and interface (capability) fields (decode to cap-table index;
  serialization-only).
- **Typed returns** — list getters return `Array[T]` (`Array[X.Reader]`,
  `Array[String]`, `Array[int]`, …); enum-typed fields return the generated enum
  (int at the wire, enum at the API boundary).
- **Cross-file type references** — a field of an imported type resolves to that
  file's generated umbrella class (`Common.Point` → `CommonCapnp.Point.Reader`);
  request all files together (`capnp compile a b`).
- **Generics** — type-erased accessors for parameter / `AnyPointer` fields
  (`Box(T)` → `Box`), plus monomorphized typed classes for concrete
  instantiations (`Box(Text)` → `Box_Text` with `get_value() -> String`); the
  erased form is the unbound fallback.
- **Nested + pointer-element lists** — `List(List(T))` (lazy inner readers,
  `init_list_at` / `init_composite_list_at` builders) and `List(interface)` →
  cap-table indices.
- **Reserved-name sanitization** — generated identifiers that collide with Godot
  built-ins or GDScript keywords are mangled (`enum Color` → `Color_`, field
  `class` → `get_class_`).
- **Editor plugin** — dock panel: capnp status, one-click install, and an
  in-process schema → out-dir generate (no CLI/PATH/env needed).
- **Tooling**: `capnpc-gdscript` shim (POSIX + Windows `.cmd`), a shimless
  cross-platform generate path, `tools/build_capnp.sh`, `tools/run_tests.sh`.
- **Tests**: 104 GUT tests / 604 assertions, including round-trips and
  bidirectional interop verified against the reference `capnp` implementation.

### Known gaps

Tracked in [`docs/DEFERRED.md`](docs/DEFERRED.md): RPC / live capabilities
(serialization-only by design), deferred generic sub-cases (nested-generic inner
emission, `inherit` scopes, generic enums/interfaces — CG1c), `List(AnyPointer)`
(CG10b), and Windows codegen verification on a real host (PK6).
