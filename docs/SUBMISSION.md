# Getting capngodo listed / discoverable

Concrete steps + ready-to-use artifacts for listing capngodo on
[capnproto.org/otherlang.html](https://capnproto.org/otherlang.html) and the
Godot Asset Library. The page lists author-maintained, unreviewed
implementations — there is no formal "official SDK" status; being listed makes
capngodo the de-facto GDScript/Godot implementation (it'd be the first).

## Pre-flight checklist

- [ ] Repo is **public** (a private repo can't be listed).
- [ ] `LICENSE` present (MIT — committed).
- [ ] CI passing (the `tests` workflow runs the GUT suite).
- [ ] A tagged release (e.g. `v0.1.0`) + GitHub release notes (see `CHANGELOG.md`).
- [ ] README states what's supported / not (done).

## 1. Cap'n Proto: otherlang.html

The page is generated from `doc/otherlang.md` in
[`capnproto/capnproto`](https://github.com/capnproto/capnproto). Open a PR adding
one line under the **`##### Serialization only`** heading (alphabetical by
language — between "D" and "Java"... place near "GDScript"):

```markdown
* [GDScript (Godot)](https://github.com/plaught-armor/capngodo) by [@plaught-armor](https://github.com/plaught-armor)
```

We belong under *Serialization only* (no RPC). We already satisfy their two
stated expectations: we did **not** write our own schema parser (we use the
`capnp` compiler + a `capnpc-gdscript` plugin, exactly as recommended), and we
**test via `capnp` encode/decode** interop.

## 2. Announce on GitHub Discussions

The Cap'n Proto mailing list **has moved to GitHub Discussions** (pinned notice
on the repo), so that's the live community hub. Post in the **🙌 Show and tell**
category at
[capnproto/capnproto/discussions](https://github.com/capnproto/capnproto/discussions)
(the legacy [Google Group](https://groups.google.com/group/capnproto) still
exists but is deprecated). Draft:

> **Title:** capngodo — Cap'n Proto serialization + codegen for Godot/GDScript
>
> Hi all,
>
> I've written capngodo, a pure-GDScript Cap'n Proto implementation for the
> Godot game engine (4.6+): https://github.com/plaught-armor/capngodo
>
> It's serialization-only (no RPC). Per the otherlang guidance it does NOT
> implement its own schema parser — it ships a `capnpc-gdscript` compiler plugin
> driven by `capnp compile`, plus a standalone runtime wire codec. The full wire
> format is covered (structs, all list types, packed, multi-segment + far
> pointers, default-XOR), with codegen for structs/enums/unions/groups/defaults.
>
> It's verified bidirectionally against the reference implementation: generated
> readers decode real `capnp`-encoded messages, and generated builders produce
> bytes `capnp decode` reads back. 51 tests against the standard `testdata/`
> fixtures + interop.
>
> I'd like to add it under "Serialization only" on the Other Languages page
> (PR incoming). Feedback welcome — thanks!

## 3. Godot Asset Library

Submit at <https://godotengine.org/asset-library/asset/edit> (requires a Godot
account). This is where Godot developers discover addons. Package the
**`addons/capngodo/` directory only** (exclude `addons/gut`, `tests/`, the dev
tooling). Fill in: name, category (Tools/Scripts), Godot version, repo URL,
license (MIT), a short description + the README highlights.
