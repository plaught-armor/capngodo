extends SceneTree
## Interop driver for tools/run_interop.sh. Two modes (args after `--`):
##   build  <file>   write a canonical Root message (via the generated builder)
##   verify <file>   read a Root message and assert its fields; exit 1 on mismatch
## Together with `capnp decode` / `capnp encode` this proves bidirectional
## compatibility with the reference Cap'n Proto implementation.

const ID: int = 123456
const NAME: String = "Alice"
const TAGS: PackedStringArray = ["alpha", "bravo", "charlie"]
const SCORES: PackedInt32Array = [10, -20, 30]
const NOTE: String = "child note"
const BANNED: String = "spam"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <build|verify> <file>")
		quit(2)
		return
	var mode: String = args[0]
	var path: String = args[1]
	if mode == "build":
		quit(_build(path))
	elif mode == "verify":
		quit(_verify(path))
	else:
		push_error("unknown mode '%s'" % mode)
		quit(2)


func _build(path: String) -> int:
	var root: InteropCapnp.Root.Builder = InteropCapnp.new_root()
	root.set_id(ID)
	root.set_name(NAME)
	var tags: CapnBuilder.ListBuilder = root.init_tags(TAGS.size())
	for i: int in TAGS.size():
		tags.set_text(i, TAGS[i])
	root.set_scores(SCORES)
	var child: InteropCapnp.Child.Builder = root.init_child()
	child.set_note(NOTE)
	root.set_kind(InteropCapnp.Kind.BETA)
	root.set_status_banned(BANNED)

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % path)
		return 1
	f.store_buffer(root.to_bytes())
	f.close()
	return 0


func _verify(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot read %s" % path)
		return 1
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	var r: InteropCapnp.Root.Reader = InteropCapnp.read_root(bytes)
	var ok: bool = true
	ok = _check(r.get_id() == ID, "id") and ok
	ok = _check(r.get_name() == NAME, "name") and ok
	var tags: Array = r.get_tags()
	ok = _check(tags.size() == TAGS.size() and tags[0] == TAGS[0] and tags[2] == TAGS[2], "tags") and ok
	var scores: Array = r.get_scores()
	ok = _check(scores.size() == SCORES.size() and scores[1] == SCORES[1], "scores") and ok
	ok = _check(r.get_child().get_note() == NOTE, "child.note") and ok
	ok = _check(r.get_kind() == InteropCapnp.Kind.BETA, "kind") and ok
	ok = _check(r.is_status_banned() and r.get_status_banned() == BANNED, "status.banned") and ok
	if ok:
		print("interop verify: OK")
	return 0 if ok else 1


func _check(cond: bool, label: String) -> bool:
	if not cond:
		push_error("interop verify FAILED: %s" % label)
	return cond
