# Changelog

All notable changes to capngodo are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow
[SemVer](https://semver.org/).

## [0.1.0] — unreleased

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
  primitives, `Text`/`Data`, enums, nested structs, lists, unions and groups,
  and field defaults.
- **Reserved-name sanitization** — generated identifiers that collide with Godot
  built-ins or GDScript keywords are mangled (`enum Color` → `Color_`, field
  `class` → `get_class_`).
- **Tooling**: `capnpc-gdscript` shim (POSIX + Windows `.cmd`), a shimless
  cross-platform generate path, `tools/build_capnp.sh`, `tools/run_tests.sh`.
- **Tests**: 51 GUT tests / 422 assertions, including round-trips and
  bidirectional interop verified against the reference `capnp` implementation.

### Known gaps

Tracked in [`docs/DEFERRED.md`](docs/DEFERRED.md): generics (`Brand`
resolution), capability/RPC, cross-file imports, typed `Array[T]` list returns,
`Data` field defaults, Windows verification on a real host.
