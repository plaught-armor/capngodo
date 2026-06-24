# Deferred work

Genuinely open items only. The completed milestones (the wire codec, schema
codegen, generics, unions, cross-file refs, interface fields, typed + packed
list returns, the decode/build perf inlining + lazy iterator APIs, and the
robustness fuzzing) are recorded in the [CHANGELOG](../CHANGELOG.md) and git
history, not here. Nothing below is a known-wrong result on a tested path — these
are bounded edges, cosmetics, and won't-fix-here items. Priority: P1 (fix before
a real release) → P3 (nice-to-have / measure-first).

## Open

| id | pri | item | notes |
|---|---|---|---|
| CG1d-residual | P3 | **Deeper inherit-field monomorphization** | A generic `inherit`-scope field monomorphizes for a *direct top-level slot* (`Outer(T) { struct Inner { value :T } }` → `Outer_Inner_Text`); a **group-nested or deeper-chained** inherit field degrades to the erased floor (raw `get_<f>_struct/list/text/data()`, no wrong output). Schema/test: `generic_inherit.capnp`. |
| CG11-residual | P3 | **Triple-discriminant union group** | A group arm whose union is *itself* a struct-level union arm needs three discriminant writes per leaf; `_emit_slot_setter` carries two, so the **builder** side degrades to a loud `# TODO` (the reader still emits getters; no wrong output). Schema/test: `named_union_group.capnp`. |
| RT3 | P3 | **`CapnWireWords.read_u64` naming** | Returns a possibly-negative bit pattern; consider `read_u64_bits` to surface that. No callers today. |
| ES1 | P3 | **Per-element / struct-upgrade element-size validation** | The bulk primitive getters (`to_int32_array`, `to_int64_array`, `to_float32_array`, `to_float64_array`, `to_byte_array`) now reject a wire element size that disagrees with the schema (`had_error` + empty). The **per-element** getters (`get_u16(i)` in a `List(UInt16)` loop, etc.) and the legal `List(primitive) → List(struct)` **upgrade** path still trust the wire stride, so a mismatched/hostile wire yields *wrong data* there — **memory-safe** (Godot `decode_*`/`slice` clamp + error, never crash/OOM; verified) but not flagged. capnp validates this via `checkElementSize`/`expectedElementSize` (`layout.c++`). To close: thread the schema's expected element size through the per-element accessors and decide whether to support the primitive→struct upgrade. |
| PK6 | 🚫 | **Windows codegen verification** | `tools/capnpc-gdscript.cmd` + the shimless 2-step are documented but untested on a real Windows host (developed on Linux). The plugin itself (`plugin_main.gd`) is cross-platform. Open Q for a Windows contributor: does `capnp` spawn a `.cmd` plugin via `-o gdscript`? If not, the shimless 2-step is the fallback. |

## Bigger bets (not scheduled)

- **GDExtension** — the remaining 10–100× decode/encode lever (kills per-element
  Variant dispatch + GDScript call overhead). The pure-GDScript hot paths are now
  inlined and measured to their floor (decode 31→9.8 ms, build 18→14 ms across
  this cycle), so this native step is the only large lever left — at the cost of
  a native build and pure-GDScript portability.
- **Interop expansion** — broaden the bidirectional `capnp`-tool cross-check
  (more types / edge cases) for deeper spec-compliance confidence.

## Refuted — do not reland without new evidence

Measured slower (or wrong); kept so they aren't re-attempted:

- **RT1** — packed-codec pre-sized index-cursor writes (`out[i] = b`): slower than
  the batched `append_array` of a per-word `content` array. GDScript per-element
  Variant set loses to the C++ bulk copy; the per-word alloc isn't the bottleneck.
- **RT2** — lazy `_buf()` segment cache in `Message` behind a bool guard: added a
  per-call branch for no win (the 3-hop is a cheap CoW ref-share).
- **RT8** — eager segment-buffer field on the reader: ~40% faster on a *pure
  scalar-read* path but a wash-to-loss on the text-heavy AddressBook bench
  (per-reader `PackedByteArray` init not amortized). Conditional — would need a
  scalar-heavy bench to justify honestly; not unconditional.
- **RT6** — String-construction micro-opts: `String` build is **~1.5%** of decode,
  not the cost. `get_string_from_ascii` is slower (extra copy); a per-Message
  intern cache is +4–5% (must build the String to key it); `StringName` is +57%
  and semantically wrong (Text is arbitrary UTF-8, not an identifier). No
  ranged-`utf8` API exists, so the sub-range `slice` is forced and negligible.
- **D7 condition-tables for small int dispatch** — a `Dictionary.get(code)` lookup
  is ~7% *slower* than the flat if-chain for the 8-way `ElemSize` dispatch (int
  hash + Variant box/unbox > a few compares); `match` is ~2×. Keep flat if-chains
  on the hot paths.
- **Generated-output lint/format conformance** — intentionally NOT done.
  `*.capnp.gd` is machine output, excluded from the gd-check gate (vendored
  `addons/gut` is too). Conforming would need a formatter reimplementation inside
  codegen, a worse enum-naming scheme (`PersonPhoneNumberType` vs the readable
  flattened `Person_PhoneNumber_Type`), and a stale-golden regen — all
  disproportionate for machine output.

## Accepted as-is (documented, not bugs)

- Empty-`PackedByteArray`-on-error ambiguity in `pack`/`unpack` (only ambiguous
  when input is legitimately empty; errors also `push_error`).
- Unchecked enum casts (`x as NodeWhich`, …) in the meta-reader — input is trusted
  `capnp` output; would only drift on an upstream schema-version bump.
- Non-canonical builder output (cross-segment always uses double-far; orphaned
  bytes when a union member is re-set) — spec-valid, just not minimal.
- Lazy `iter_*()` / `init_*_iter()` yield a **reused view** valid only for the
  current loop step — by design (the alloc-free path); the eager `get_*()` /
  `init_*()` `Array` forms remain for random access / retention.
