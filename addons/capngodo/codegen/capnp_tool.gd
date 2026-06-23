class_name CapnTool
extends RefCounted
## In-editor / in-process codegen glue: resolve the `capnp` compiler, run it to
## dump a CodeGeneratorRequest, and feed that to CapnCodegen — all without the
## CLI shim or a headless-Godot subprocess (the editor IS Godot). Static-fn
## system (D9). The CLI shim (tools/capnpc-gdscript + plugin_main.gd) stays the
## path for `capnp compile -o gdscript` outside the editor.
##
## Why a temp file instead of capturing stdout: OS.execute decodes child stdout
## as a UTF-8 String, which corrupts the binary CodeGeneratorRequest. So we run
## `capnp compile -o-` through a shell that redirects stdout to a temp file and
## read the bytes back.
##
## Shell args are quoted (_quote), so paths must still come from trusted local
## sources (ProjectSettings / the editor file dialog), not the network. The
## POSIX quoting is the standard single-quote idiom; the Windows cmd.exe path is
## written but UNTESTED (PK6) and won't survive `%`/`&`/`^` in a schema path.

## ProjectSettings key holding the user-resolved capnp path (set by the
## installer or the "Browse" button in the editor dock).
const SETTING_KEY: String = "capngodo/capnp_path"


## The per-user cache dir capngodo downloads the capnp binary into.
static func cache_dir() -> String:
	return OS.get_cache_dir().path_join("capngodo")


## The default cached binary path for this platform (where the installer writes).
static func cached_binary_path() -> String:
	var name: String = "capnp.exe" if OS.get_name() == "Windows" else "capnp"
	return cache_dir().path_join(name)


## Resolve a usable `capnp` invocation, in priority order:
##   1. the ProjectSettings path (installer / Browse), if it exists,
##   2. the cached download, if present,
##   3. "capnp" on PATH, if `capnp --version` succeeds,
## or "" when none is found. Callers treat "" as "offer to install".
static func resolve_capnp() -> String:
	var configured: String = ProjectSettings.get_setting(SETTING_KEY, "")
	if not configured.is_empty():
		if FileAccess.file_exists(configured):
			return configured
		push_warning("[CapnTool] %s = '%s' but that file is missing; falling back" % [SETTING_KEY, configured])
	var cached: String = cached_binary_path()
	if FileAccess.file_exists(cached):
		return cached
	if _runs_ok("capnp"):
		return "capnp"
	return ""


## True if `<bin> --version` exits 0 — used to probe PATH.
static func _runs_ok(bin: String) -> bool:
	var out: Array = []
	return OS.execute(bin, ["--version"], out, true) == 0


## Run `capnp compile -o- <schema>` and return the raw CodeGeneratorRequest
## bytes, or an empty PackedByteArray on failure (with push_error). import_dirs
## become `-I <dir>` flags. capnp's stdout is redirected to a temp file through
## the platform shell because OS.execute can't carry binary stdout.
static func compile_to_cgr(capnp: String, schema_path: String, import_dirs: PackedStringArray = PackedStringArray()) -> PackedByteArray:
	if capnp.is_empty():
		push_error("[CapnTool] no capnp binary resolved")
		return PackedByteArray()
	_ensure_dir(cache_dir())
	# Unique per call so concurrent compiles (editor + test, future parallel
	# schemas) don't clobber each other's redirect target.
	var tmp: String = cache_dir().path_join("_cgr_%d.bin" % Time.get_ticks_usec())

	var on_windows: bool = OS.get_name() == "Windows"
	var cmd: String = _quote(capnp, on_windows) + " compile -o-"
	for d: String in import_dirs:
		cmd += " -I " + _quote(d, on_windows)
	# --src-prefix = the schema's own dir, so requestedFile.filename (which names
	# the generated class + header) is the basename, not the absolute path.
	cmd += " --src-prefix=" + _quote(schema_path.get_base_dir(), on_windows)
	cmd += " " + _quote(schema_path, on_windows) + " > " + _quote(tmp, on_windows)

	var shell: String = "cmd" if on_windows else "sh"
	var shell_flag: String = "/c" if on_windows else "-c"
	var out: Array = []
	var code: int = OS.execute(shell, [shell_flag, cmd], out, true)
	if code != 0:
		push_error("[CapnTool] capnp failed (exit %d): %s" % [code, "\n".join(out)])
		_remove(tmp)
		return PackedByteArray()

	var f: FileAccess = FileAccess.open(tmp, FileAccess.READ)
	if f == null:
		push_error("[CapnTool] capnp produced no output at %s" % tmp)
		_remove(tmp)
		return PackedByteArray()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	_remove(tmp)
	return bytes


## A codegen result: ok flag, the absolute paths written, and an error message
## (empty on success). POD record (D1).
class Result extends RefCounted:
	var ok: bool = false
	var written: PackedStringArray = PackedStringArray()
	var error: String = ""


## Compile `schema_path` with `capnp` and write the generated .gd file(s) into
## `out_dir` (one per requested file, named by the schema basename). Returns a
## Result. Pure orchestration over compile_to_cgr + CapnCodegen. On failure
## mid-write, `written` lists the files written before the error (best-effort).
static func generate_to_dir(capnp: String, schema_path: String, out_dir: String, import_dirs: PackedStringArray = PackedStringArray()) -> Result:
	var r: Result = Result.new()
	var cgr_bytes: PackedByteArray = compile_to_cgr(capnp, schema_path, import_dirs)
	if cgr_bytes.is_empty():
		r.error = "capnp produced no CodeGeneratorRequest (see the error log)"
		return r
	var cgr: CapnReader.StructReader = CapnSchema.open_request(cgr_bytes)
	if cgr == null:
		r.error = "failed to parse the CodeGeneratorRequest"
		return r
	var files: Dictionary[String, String] = CapnCodegen.generate_files(cgr)
	if files.is_empty():
		r.error = "codegen produced no files"
		return r
	if not _ensure_dir(out_dir):
		r.error = "cannot create output dir %s" % out_dir
		return r
	for fname: String in files:
		var path: String = out_dir.path_join(fname.get_file()) # strip any schema-path prefix
		var w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if w == null:
			r.error = "cannot write %s (err %d)" % [path, FileAccess.get_open_error()]
			return r
		w.store_string(files[fname])
		w.close()
		r.written.append(path)
	r.ok = true
	return r

# --- helpers -------------------------------------------------------------


static func _ensure_dir(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	return DirAccess.make_dir_recursive_absolute(path) == OK


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Shell-quote a single argument. Single quotes on POSIX (escaping embedded
## single quotes); double quotes on Windows cmd (doubling embedded quotes).
static func _quote(s: String, on_windows: bool) -> String:
	if on_windows:
		return "\"" + s.replace("\"", "\"\"") + "\""
	return "'" + s.replace("'", "'\\''") + "'"
