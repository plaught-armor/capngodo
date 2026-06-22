# capngodo

A [Cap'n Proto](https://capnproto.org/) serializer/deserializer **and schema
code generator** for Godot 4.6+ / GDScript. Inspired by
[godobuf](https://github.com/oniksan/godobuf) (the same idea, for Protobuf).

Two ways to use it:

1. **Runtime codec** — read and write Cap'n Proto messages from GDScript with no
   external tools. You supply the struct layout (field offsets). Fully standalone.
2. **Generated typed classes** — run `capnp compile -o gdscript myschema.capnp`
   to get typed `Reader`/`Builder` classes (`get_name()`, `set_id()`, …). Needs
   the `capnp` binary **at generation time only** — generated code + the runtime
   ship without it.

Verified bidirectionally against the reference Cap'n Proto implementation: the
generated readers decode real `capnp`-encoded messages, and the generated
builders produce bytes that `capnp decode` reads back correctly.

## Status

| Area | State |
|---|---|
| Wire codec: structs, lists (all element sizes), text/data, packed, multi-segment + far/double-far pointers, default-XOR, traversal/depth limits | ✅ |
| Reader codegen: primitives, text/data, enums, nested structs, lists | ✅ |
| Builder codegen: `set_*`/`init_*`/`to_bytes`, composite lists | ✅ |
| Unions & groups, field defaults | ✅ |
| Generics, capability/RPC, cross-file imports | ⏳ see [`docs/DEFERRED.md`](docs/DEFERRED.md) |

There is no RPC layer (by design — like godobuf, this is serialization only).
Capability pointers decode to a table index so cap-bearing messages don't crash.

## Requirements

- **Godot 4.6+** — runtime + codegen.
- **GUT** (`addons/gut`) — only to run the test suite.
- **`capnp`** — only to *generate* typed classes from `.capnp` schemas. Build it
  from source (`tools/build_capnp.sh`) or install a package (`pacman -S
  capnproto`, `apt install capnproto`, `brew install capnp`).

## Install

Copy `addons/capngodo/` into your project's `addons/` directory and enable the
plugin in Project Settings (or just use the `class_name` globals directly — the
runtime needs no plugin activation).

The **distributable is `addons/capngodo/` only**. `addons/gut/` is vendored in
this repo solely to run the test suite — it is a dev dependency and should be
excluded when packaging the addon for release.

## Runtime codec (no capnp needed)

Read a message whose layout you know:

```gdscript
var msg := CapnReader.open(bytes, false)        # false = not packed
var root := msg.get_root()                       # StructReader
var id := root.get_u32(0, 0)                      # data offset 0, default 0
var name := root.get_text(0)                      # pointer field 0
var items := root.get_list(1)                     # pointer field 1 -> ListReader
for i in items.size():
    var item := items.get_struct(i)               # composite-list element
```

Write one:

```gdscript
var b := CapnBuilder.new_message(1, 2)            # data_words=1, ptr_words=2
b.set_u32(0, 42, 0)                               # offset, value, default
b.set_text(0, "hello")                            # pointer field 0
var child := b.init_struct(1, 1, 0)               # ptr field 1, child dw=1 pw=0
child.set_u32(0, 7, 0)
var bytes := CapnBuilder.to_bytes(b, false)       # false = not packed
```

The offsets come from your schema (run `capnp compile -ocapnp` to see them, or
use the generated classes below, which bake them in).

## Generated typed classes (recommended)

### 1. Get `capnp`

```sh
# Build from a Cap'n Proto source checkout (no sudo):
export CAPNPROTO_SRC=/path/to/capnproto
CAPNP="$(tools/build_capnp.sh)"        # prints the built binary path
# ...or just install a package and use `capnp` directly.
```

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
(`addons/capngodo/codegen/plugin_main.gd`) which writes the `.gd` file.

### 4. Use the generated class

For `samples/addressbook.capnp`, the generated `AddressbookCapnp` gives you:

```gdscript
# Build
var ab := AddressbookCapnp.new_address_book()
var people := ab.init_people(1)
people[0].set_id(123)
people[0].set_name("Alice")
var phones := people[0].init_phones(1)
phones[0].set_number("555-1212")
phones[0].set_type(AddressbookCapnp.Person_PhoneNumber_Type.MOBILE)
people[0].set_employment_employer("Acme")       # union member
var bytes := ab.to_bytes()

# Read
var r := AddressbookCapnp.read_address_book(bytes)
for p in r.get_people():
    print(p.get_id(), p.get_name())
    if p.is_employment_employer():
        print("works at ", p.get_employment_employer())
```

Generated API per struct: `Reader.get_<field>()`, `Builder.set_<field>()` /
`init_<field>()` / `to_bytes()`, top-level `new_<root>()` / `read_<root>()`.
Unions get `<group>_which()`, `is_<group>_<member>()`, `get_/set_<group>_<member>()`.

## Testing

```sh
CAPNGODO_GODOT=/path/to/godot tools/run_tests.sh
```

Runs the full GUT suite headless (unit + integration). Integration tests decode
the real Cap'n Proto `testdata/` fixtures and the committed generated readers.

## Layout

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

## Credits

- [Cap'n Proto](https://capnproto.org/) by Kenton Varda — wire format + schema language.
- [godobuf](https://github.com/oniksan/godobuf) — the model for a pure-GDScript schema compiler.
