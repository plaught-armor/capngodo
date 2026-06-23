extends SceneTree

## capnpc-gdscript plugin entry. `capnp compile -o<shim>` pipes a serialized
## CodeGeneratorRequest to this process's stdin; we parse it (CapnSchema),
## generate GDScript (CapnCodegen), and write each file to the output dir.
##
## User args (after `--`), both supplied by the shell shim:
##   args[0] = output dir (capnp's CWD, which Godot's --path would mask)
##   args[1] = path to the CodeGeneratorRequest (shim spools stdin here, since
##             Godot's FileAccess cannot open /dev/stdin)
## Exit code is non-zero on failure so capnp reports it.


func _initialize() -> void:
	# SceneTree.quit(code) sets the process exit code so capnp sees failures.
	quit(_run())


func _run() -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("[capnpc-gdscript] expected <out_dir> <request_file> args")
		return 1
	var out_dir: String = args[0]
	var req_path: String = args[1]

	var rf: FileAccess = FileAccess.open(req_path, FileAccess.READ)
	if rf == null:
		push_error("[capnpc-gdscript] cannot open request file %s" % req_path)
		return 1
	var data: PackedByteArray = rf.get_buffer(rf.get_length())
	rf.close()
	if data.is_empty():
		push_error("[capnpc-gdscript] empty CodeGeneratorRequest")
		return 1

	var cgr: CapnReader.StructReader = CapnSchema.open_request(data)
	if cgr == null:
		push_error("[capnpc-gdscript] failed to parse CodeGeneratorRequest")
		return 1

	var files: Dictionary[String, String] = CapnCodegen.generate_files(cgr)
	if files.is_empty():
		push_error("[capnpc-gdscript] no output generated")
		return 1

	for fname: String in files:
		var path: String = out_dir.path_join(fname)
		# requestedFile.filename may carry subdirs; create them first.
		var dir: String = path.get_base_dir()
		if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if w == null:
			push_error("[capnpc-gdscript] cannot write %s (err %d)" % [path, FileAccess.get_open_error()])
			return 1
		w.store_string(files[fname])
		w.close()
		# Progress to stderr — stdout is reserved (capnp plugin convention).
		printerr("capnpc-gdscript: wrote %s" % path)
	return 0
