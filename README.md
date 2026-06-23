# capngodo

[![tests](https://github.com/plaught-armor/capngodo/actions/workflows/tests.yml/badge.svg)](https://github.com/plaught-armor/capngodo/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A [Cap'n Proto](https://capnproto.org/) serializer/deserializer **and schema
code generator** for Godot 4.6+ / GDScript. Inspired by
[godobuf](https://github.com/oniksan/godobuf) (the same idea, for Protobuf).

Two ways to use it:

1. **Runtime codec** — read and write Cap'n Proto messages from GDScript with no
   external tools. You supply the struct layout (field offsets). Fully standalone.
2. **Generated typed classes** — run `capnp compile -o gdscript myschema.capnp`
   for typed `Reader`/`Builder` classes (`get_name()`, `set_id()`, …). Needs the
   `capnp` binary **at generation time only** — generated code + the runtime ship
   without it.

Verified bidirectionally against the reference Cap'n Proto implementation: the
generated readers decode real `capnp`-encoded messages, and the generated
builders produce bytes that `capnp decode` reads back correctly.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [Examples](#examples)
- [Type mapping](#type-mapping)
- [Codegen workflow](#codegen-workflow)
- [API reference](#api-reference)
  - [Runtime: reading](#runtime-reading)
  - [Runtime: writing](#runtime-writing)
  - [Generated classes](#generated-classes-api)
- [Default values](#default-values)
- [Errors & limits](#errors--limits)
- [Testing](#testing)
- [Project layout](#project-layout)
- [Roadmap](#roadmap)
- [Credits](#credits)

## Features

**Supported**

- Wire codec: structs, lists (all 8 element sizes), `Text`, `Data`, packed
  encoding, single + multi-segment messages, far + double-far pointers,
  default-value XOR, traversal + pointer-depth limits.
- Schema codegen: typed `Reader`/`Builder` classes for structs, enums, nested
  types, lists (including `List(List(T))`), struct-level + group unions, named
  groups, field + `Data` defaults, schema `const` declarations, and interface
  (capability) fields (decode to cap-table index; serialization-only).
- Typed returns: list getters return `Array[T]` (`Array[X.Reader]`,
  `Array[String]`, `Array[int]`, …); enum fields return the generated enum.
- Cross-file type references — a field of an imported type resolves to that
  file's generated umbrella class (request all files together).
- Generics: type-erased accessors for parameter / `AnyPointer` fields
  (`Box(T)` → `Box`), plus monomorphized typed classes for concrete
  instantiations (`Box(Text)` → `Box_Text` with `get_value() -> String`).
- Reserved-name sanitization (a schema `enum Color` / field `class` won't clash
  with Godot built-ins / GDScript keywords).
- `capnpc-gdscript` plugin so `capnp compile -o gdscript` works directly, plus an
  in-editor dock panel (capnp status, install, in-process generate).

**Not yet** (tracked in [`docs/DEFERRED.md`](docs/DEFERRED.md))

- RPC / live capabilities (serialization-only by design). Some deferred generic
  sub-cases (nested-generic inner emission, `inherit` scopes, generic
  enums/interfaces), `List(AnyPointer)`, and real-Windows codegen verification.

There is no RPC layer (by design — like godobuf, this is serialization only).
Capability pointers decode to a table index so cap-bearing messages don't crash.

## Requirements

- **Godot 4.6+** — runtime + codegen.
- **GUT** (`addons/gut`) — only to run the test suite (vendored in this repo).
- **`capnp`** — only to *generate* typed classes. Install a release
  (`apt-get install capnproto`, `brew install capnp`, or the prebuilt Windows
  zip — see [capnproto.org/install](https://capnproto.org/install.html)) or build
  from source (`tools/build_capnp.sh`).

## Install

Copy `addons/capngodo/` into your project's `addons/` directory and enable the
plugin in Project Settings (or just use the `class_name` globals directly — the
runtime needs no plugin activation).

The **distributable is `addons/capngodo/` only**. `addons/gut/` is vendored here
solely to run tests — a dev dependency, excluded when packaging the addon.

## Quick start

### Generated classes (recommended)

After `capnp compile -o gdscript addressbook.capnp` (see
[Codegen workflow](#codegen-workflow)):

```gdscript
# Build
var ab: AddressbookCapnp.AddressBook.Builder = AddressbookCapnp.new_address_book()
var people: Array = ab.init_people(1)
var alice: AddressbookCapnp.Person.Builder = people[0]
alice.set_id(123)
alice.set_name("Alice")
var phones: Array = alice.init_phones(1)
var phone: AddressbookCapnp.Person_PhoneNumber.Builder = phones[0]
phone.set_number("555-1212")
phone.set_type(AddressbookCapnp.Person_PhoneNumber_Type.MOBILE)
alice.set_employment_employer("Acme")            # union member
var bytes: PackedByteArray = ab.to_bytes()

# Read
var r: AddressbookCapnp.AddressBook.Reader = AddressbookCapnp.read_address_book(bytes)
var read_people: Array = r.get_people()
for i: int in read_people.size():
    var p: AddressbookCapnp.Person.Reader = read_people[i]
    print(p.get_id(), p.get_name())
    if p.is_employment_employer():
        print("works at ", p.get_employment_employer())
```

### Runtime codec (no capnp)

Read/write directly when you know the struct layout (field offsets):

```gdscript
# Read
var msg: CapnReader.Message = CapnReader.open(bytes, false)   # false = not packed
var root: CapnReader.StructReader = msg.get_root()
var id: int = root.get_u32(0, 0)                  # data offset 0, default 0
var name: String = root.get_text(0)               # pointer field 0
var items: CapnReader.ListReader = root.get_list(1)
for i: int in items.size():
    var item: CapnReader.StructReader = items.get_struct(i)

# Write
var b: CapnBuilder.StructBuilder = CapnBuilder.new_message(1, 2)  # data_words=1, ptr_words=2
b.set_u32(0, 42, 0)                               # offset, value, default
b.set_text(0, "hello")                            # pointer field 0
var out: PackedByteArray = CapnBuilder.to_bytes(b, false)
```

Offsets come from your schema — run `capnp compile -ocapnp` to see them, or just
use the generated classes, which bake them in.

## Examples

Three runnable demos under [`examples/`](examples/) — each pairs a `.capnp`
schema, its generated `.gd`, a `demo.tscn` you can open and run, and a static
pure API that doubles as an integration smoke test in `tests/integration/`:

- [`save_load/`](examples/save_load/) — **save/load**: a `GameState` (player,
  level, hp, position, inventory) serialized to bytes, written to `user://`, and
  read back. `SaveLoadDemo.save_game(path, dict)` / `load_game(path)`.
- [`network_packet/`](examples/network_packet/) — **multiplayer packets**: a
  `Packet` header plus a struct-level union body (chat / move / spawn),
  serialized to compact **packed** bytes and decoded by dispatching on the union
  discriminant. `NetworkPacketDemo.encode_*()` / `decode(wire)`.
- [`config/`](examples/config/) — **settings with defaults**: a `Settings` blob
  where unset fields read back their **schema defaults**, plus an enum-typed
  field (`Quality`). `ConfigDemo.save_settings(overrides)` / `load_settings(bytes)`.

## Type mapping

How each Cap'n Proto type maps to GDScript and the codec methods. `off` =
byte offset in the data section; `bit` = bit offset; `ptr` = pointer-section
index; `def` = default value (XOR mask for scalars).

| Cap'n Proto | GDScript | Reader method | Builder method |
|---|---|---|---|
| `Void` | — | (none) | (none) |
| `Bool` | `bool` | `get_bool(bit, def)` | `set_bool(bit, v, def)` |
| `Int8/16/32/64` | `int` | `get_i8/i16/i32/i64(off, def)` | `set_i8/i16/i32/i64(off, v, def)` |
| `UInt8/16/32/64` | `int` | `get_u8/u16/u32/u64(off, def)` | `set_u8/u16/u32/u64(off, v, def)` |
| `Float32/64` | `float` | `get_f32/f64(off, def_bits)` | `set_f32/f64(off, v, def_bits)` |
| `Text` | `String` | `get_text(ptr, def)` | `set_text(ptr, s)` |
| `Data` | `PackedByteArray` | `get_data(ptr, def)` | `set_data(ptr, bytes)` |
| `enum` | `int` | `get_u16(off, def)` | `set_u16(off, v, def)` |
| struct | `StructReader` | `get_struct(ptr)` | `init_struct(ptr, dw, pw)` |
| `List(T)` | `ListReader` | `get_list(ptr)` | `init_list` / `init_composite_list` |
| interface (capability) | `int` (table index) | `get_cap_index(ptr)` | — (no RPC) |

`UInt64` values ≥ 2^63 come back as a negative `int` (GDScript `int` is signed
64-bit) — the bit pattern is exact. `Float*` defaults are passed as their IEEE
bit pattern (`def_bits`), not the float value.

## Codegen workflow

> **Why is `capnp` required to generate?** It parses the schema and — crucially —
> **computes the field offsets**. Cap'n Proto's official guidance is explicit:
> *"Do not implement your own schema parser. The schema language is more
> complicated than it looks, and the algorithm to determine offsets of fields is
> subtle"* ([otherlang](https://capnproto.org/otherlang.html)). A re-implemented
> layout algorithm risks diverging from `capnp` → wire-incompatible output. So
> capngodo follows the recommended path: `capnp` is the frontend; we are the
> code-generator plugin. It's a **build-time tool only** — generated `.gd` and
> the runtime ship without it. (This is why we can't be fully self-contained like
> godobuf: Protobuf has no field offsets to compute; Cap'n Proto's whole design
> is fixed offsets.)

### 1. Get `capnp`

Install a release ([capnproto.org/install](https://capnproto.org/install.html)):

- **Debian/Ubuntu**: `sudo apt-get install capnproto`
- **macOS**: `brew install capnp`
- **Windows**: download the prebuilt zip from
  [capnproto.org](https://capnproto.org/install.html#installation-windows) and put
  `capnp.exe` on your `PATH`.
- **From the release tarball** (any Unix): `curl -O
  https://capnproto.org/capnproto-c++-1.4.0.tar.gz && tar zxf … && ./configure &&
  make -j && sudo make install`.

Or build the local checkout (no sudo) — prints the binary path:

```sh
export CAPNPROTO_SRC=/path/to/capnproto      # a Cap'n Proto source checkout
CAPNP="$(tools/build_capnp.sh)"
```

Tested with capnp 2.0-dev; 0.10+ / 1.x should also work (the `schema.capnp`
meta-format the codegen reads is stable across these).

### 2. Configure the plugin shim

```sh
chmod +x tools/*.sh tools/capnpc-gdscript    # if exec bits didn't survive transfer
export CAPNGODO_GODOT=/path/to/godot          # a Godot 4.6+ binary
export CAPNGODO_PROJECT=/path/to/capngodo     # this repo
export PATH="$CAPNGODO_PROJECT/tools:$PATH"   # puts capnpc-gdscript on PATH
```

### 3. Generate

```sh
"$CAPNP" compile -o gdscript myschema.capnp
# -> myschema.capnp.gd

# If the schema imports another (e.g. addressbook.capnp imports c++.capnp),
# add the include path so capnp can resolve it:
"$CAPNP" compile -I "$CAPNPROTO_SRC/c++/src" -o gdscript addressbook.capnp
```

`capnp` resolves `-o gdscript` to the `capnpc-gdscript` shim on your `PATH`,
pipes it the compiled schema, and the shim runs the headless Godot plugin
(`addons/capngodo/codegen/plugin_main.gd`), which writes the `.gd` file.

### Any platform (shimless)

The shim is just a convenience. This two-step works identically on **Linux,
macOS, and Windows** with no shell-script dependency — `capnp` writes the
request to a file, then you run the plugin directly:

```sh
# 1. capnp emits the CodeGeneratorRequest to a file
capnp compile -o- myschema.capnp > request.bin

# 2. run the plugin: args are <output-dir> <request-file>
godot --headless --quiet --path /path/to/capngodo \
    --script res://addons/capngodo/codegen/plugin_main.gd \
    -- . request.bin
```

On Windows use `godot.exe` and a Windows path; otherwise the commands are the
same. A Windows shim (`tools/capnpc-gdscript.cmd`) is also provided for the
`-o gdscript` form, but `capnp` may not spawn a `.cmd` plugin on all setups — if
`-o gdscript` fails on Windows, use this shimless method.

## API reference

### Runtime: reading

`CapnReader` (static entry points):

| Method | Returns |
|---|---|
| `CapnReader.open(bytes: PackedByteArray, packed: bool, limits: CapnLimits = null)` | `Message` (null on malformed framing) |
| `CapnReader.from_segments(segs: CapnSegments, limits: CapnLimits = null)` | `Message` (already-parsed segments, no framing) |

`CapnReader.Message`:

| Method | Returns |
|---|---|
| `get_root()` | `StructReader` (the root struct) |

`CapnReader.StructReader` — primitive getters take `(byte_off, default)`; pointer
getters take a `ptr_index`. A field beyond the struct's stored size returns the
default (forward/backward schema compatibility).

| Method | Returns |
|---|---|
| `get_u8/u16/u32/u64(off, def)` | `int` |
| `get_i8/i16/i32/i64(off, def)` | `int` |
| `get_f32/f64(off, def_bits)` | `float` |
| `get_bool(bit_off, def)` | `bool` |
| `get_text(ptr, def = "")` | `String` |
| `get_data(ptr, def = PackedByteArray())` | `PackedByteArray` |
| `get_struct(ptr)` | `StructReader` (empty reader if null) |
| `get_list(ptr)` | `ListReader` |
| `get_cap_index(ptr)` | `int` (capability table index, or -1) |
| `has_ptr(ptr)` | `bool` (false for a null pointer field) |

`CapnReader.ListReader` — element getters take an index `i`:

| Method | Returns |
|---|---|
| `size()` | `int` |
| `get_u8/u16/u32/u64(i)`, `get_i8/i16/i32/i64(i)` | `int` |
| `get_f32/f64(i)` | `float` |
| `get_bool(i)` | `bool` |
| `get_struct(i)` | `StructReader` (composite list, or upgraded primitive) |
| `get_struct_ptr(i)` | `StructReader` (List of struct *pointers*) |
| `get_list(i)` | `ListReader` (List of List) |
| `get_text/get_data(i, def)` | `String` / `PackedByteArray` |
| `to_text()` / `to_data()` | `String` / `PackedByteArray` (a byte list as Text/Data) |

### Runtime: writing

`CapnBuilder` (static entry points):

| Method | Returns |
|---|---|
| `CapnBuilder.new_message(data_words, ptr_words, cap_words = 0)` | `StructBuilder` (the root) |
| `CapnBuilder.to_bytes(root: StructBuilder, packed: bool = false)` | `PackedByteArray` |

`cap_words > 0` caps each segment, forcing multi-segment output (double-far
pointers); the default `0` keeps everything in one segment.

`CapnBuilder.StructBuilder` — setters take `(byte_off, value, default)`; `init_*`
allocate child objects and return their builder.

| Method | Returns |
|---|---|
| `set_u8/u16/u32/u64(off, v, def = 0)` | — |
| `set_i8/i16/i32/i64(off, v, def = 0)` | — |
| `set_f32/f64(off, v, def_bits = 0)` | — |
| `set_bool(bit_off, v, def = false)` | — |
| `set_text(ptr, s)` / `set_data(ptr, bytes)` | — |
| `init_struct(ptr, dw, pw)` | `StructBuilder` |
| `init_list(ptr, code: CapnPointer.ElemSize, count)` | `ListBuilder` |
| `init_composite_list(ptr, count, dw, pw)` | `ListBuilder` (struct list) |
| `to_bytes(packed = false)` | `PackedByteArray` |

`CapnBuilder.ListBuilder` — element setters take `(i, value)`:

| Method | Returns |
|---|---|
| `size()` | `int` |
| `set_u8/.../i64(i, v)`, `set_f32/f64(i, v)`, `set_bool(i, v)` | — |
| `set_text/set_data(i, …)` | — |
| `init_struct(i)` | `StructBuilder` (composite list element) |
| `init_struct_ptr(i, dw, pw)` | `StructBuilder` (List of struct pointers) |

`CapnPointer.ElemSize` values for `init_list`: `VOID, BIT, BYTE, TWO_BYTES,
FOUR_BYTES, EIGHT_BYTES, POINTER, COMPOSITE`.

### Generated classes API

For each schema struct `Foo`, the umbrella class exposes `Foo` with constants
`DATA_WORDS` / `PTR_WORDS` and two inner classes. Field offsets are baked in, so
you call by name — no offsets.

`Foo.Reader` (via `Foo.Reader.wrap(struct_reader)` or a top-level `read_*`):

| Pattern | Meaning |
|---|---|
| `get_<field>()` | scalar / Text / Data / enum (int) / nested `Reader` |
| `get_<field>() -> Array` | a list (elements are the typed `Reader`) |

`Foo.Builder` (via `new_*` or `Foo.Builder.wrap(struct_builder)`):

| Pattern | Meaning |
|---|---|
| `set_<field>(value)` | scalar / Text / Data / enum |
| `init_<field>() -> <Child>.Builder` | nested struct |
| `init_<field>(n) -> Array` | composite (struct) list → element `Builder`s |
| `init_<field>(n) -> CapnBuilder.ListBuilder` | primitive / Text list (set elements via the ListBuilder) |
| `to_bytes(packed = false)` | serialize |

Top-level (per root struct): `new_<root>() -> Root.Builder`,
`read_<root>(bytes, packed = false) -> Root.Reader`.

Enums → class-scoped `enum <Name> { MEMBER, … }`. Unions/groups →
`<group>_which() -> int`, `is_<group>_<member>() -> bool`,
`get_<group>_<member>()`, `set_<group>_<member>(value)` (void members:
`set_<group>_<member>()` with no value).

Generics → the erased `Box` (type-erased `get_<f>_struct/list/text/data()`) plus
a fully-typed `Box_Text` / `Box_Inner` / … per concrete instantiation
(`get_value() -> String`); a branded field resolves to the mono class. Imported
types resolve to the other file's umbrella class
(`Common.Point` → `CommonCapnp.Point.Reader`).

## Default values

Cap'n Proto stores scalars XOR'd with their schema default, so a default-valued
field is all-zero on the wire (and packs well). The codec handles this: pass the
field's default to the getter/setter (the generated code does this for you). A
field set to its own default encodes to wire zero; an unset field reads back as
its default. Pointer-field (Text/Data/struct/list) defaults: a null pointer
reads back as the declared default.

## Errors & limits

Readers are lazy views over untrusted bytes. On a malformed pointer,
out-of-bounds target, or a blown limit, a getter returns the default / an empty
reader and calls `push_error` (set `Message.had_error` is also set). Limits are
configurable via `CapnLimits` (traversal-word ceiling + pointer depth, defaults
~64 MiB / depth 64) passed to `CapnReader.open`.

## Testing

```sh
CAPNGODO_GODOT=/path/to/godot tools/run_tests.sh
```

On Windows (no `sh`), run the underlying command directly:

```bat
godot.exe --headless --path . --import
godot.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Runs the full GUT suite headless. Integration tests decode the real Cap'n Proto
`testdata/` fixtures and round-trip the generated readers/builders.

For **bidirectional interop** against the reference implementation (the method
[recommended by Cap'n Proto](https://capnproto.org/otherlang.html) — `capnp`
encode/decode), run:

```sh
CAPNGODO_GODOT=/path/to/godot CAPNP=/path/to/capnp tools/run_interop.sh
```

It builds a message with capngodo and checks `capnp decode` reads it, then has
`capnp encode` produce a message and checks capngodo reads it back. Both the GUT
suite and the interop test run on every push via GitHub Actions.

## Project layout

```
addons/capngodo/
  runtime/    wire codec (CapnReader, CapnBuilder, CapnPointer, CapnSegments,
              CapnFraming, CapnPacked, CapnTextData, CapnLimits, CapnTarget)
  meta/       CapnSchema — reads capnp's CodeGeneratorRequest
  codegen/    CapnCodegen + the headless plugin entry
tools/        capnpc-gdscript shim, build_capnp.sh, run_tests.sh
tests/        GUT unit + integration tests, fixtures, committed goldens
docs/         DEFERRED.md (tracked TODOs)
```

## Roadmap

Tracked work and known gaps live in [`docs/DEFERRED.md`](docs/DEFERRED.md). The
big features (generics, cross-file refs, interface fields, typed returns) have
landed; remaining items are RPC (out of scope by design) and the deferred
generic sub-cases above.

## Credits

- [Cap'n Proto](https://capnproto.org/) by Kenton Varda — wire format + schema language.
- [godobuf](https://github.com/oniksan/godobuf) — the model for a pure-GDScript schema compiler.
