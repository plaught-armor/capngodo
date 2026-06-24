# Changelog

All notable changes to capngodo are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow
[SemVer](https://semver.org/).

## [Unreleased]

## [0.2.0] — 2026-06-24

### Added

- **Lazy reader iteration** — for every `List(struct)` field the codegen now
  emits `iter_<field>()` alongside the eager `get_<field>()`. It returns a
  `CapnReader.StructListIter` that yields **one reused element `Reader`** per
  step (`for ph in person.iter_phones(): …`), so an iterate-and-read loop
  allocates a single element reader instead of N + the `Array`. The yielded
  reader is a transient view (read fields out, don't retain). Backed by the new
  `StructReader.fill_list(ptr_index, out)` runtime primitive. The eager
  `get_<field>() -> Array[Reader]` is unchanged for random-access / retain.
- **Lazy builder iteration** — symmetric `init_<field>_iter(n)` returns a
  `CapnBuilder.StructListBuilderIter` that yields one reused element `Builder`
  per step (`for ph in person.init_phones_iter(2): ph.set_…`), avoiding the
  per-element `Builder` + `Array`.
- **Robustness fuzz suite** — a valid-roundtrip property test (random
  AddressBook data → build → serialize packed/unpacked → read, eager + lazy,
  ~28k asserts) and a malformed-input fuzz (800 hostile buffers: random /
  byte-flipped / truncated / hand-crafted-adversarial, opened packed +
  unpacked and fully traversed) proving the decoder never crashes, hangs, or
  OOMs on untrusted bytes.

### Changed

- **Cross-file type resolution is now optimistic.** A field of an imported type
  resolves to that file's umbrella class (`Common.Point` →
  `CommonCapnp.Point.Reader`) even when the imported file is **not** in the same
  generation request — GDScript `class_name`s are global, so the reference is
  live as long as you generated that file in any run. A file not in the request
  emits a one-shot warning; capnp's built-in `c++.capnp` is skipped. Previously
  an imported-but-not-requested type degraded to an unresolved stub, forcing
  `capnp compile a b` everything together.
- **Decode ~3.2× faster, build ~22% faster** (plus the lazy paths above). Pure
  internal work — public API and wire output unchanged. Decode: collapsed
  per-dereference allocations (pointer-decode + reader scratch), flattened the
  pointer-follow call chain, and inlined the Text/Data/`get_list` hot paths.
  Build: alloc-free pointer writes (no per-pointer scratch `PackedByteArray`)
  and a single bulk `append_array` for Text/Data bodies instead of a per-byte
  loop.

### Tests

- 104 → 166 GUT tests (added the two fuzz suites, lazy reader/builder coverage,
  and a single-file cross-file resolution test).

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
