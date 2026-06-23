@tool
class_name CapnInstaller
extends Node
## Downloads the capnp compiler for the current platform from capngodo's GitHub
## releases (built by .github/workflows/capnp-release.yml), extracts the binary
## into CapnTool.cache_dir(), and records the path in ProjectSettings so
## CapnTool.resolve_capnp() finds it. Mirrors GDQuest's GDScript-formatter
## installer: the published addon ships no binary (Asset-Store-clean) — the
## binary is fetched on demand.
##
## Usage (from the editor dock): add as a child, connect the signals, call
## install(). HTTPRequest needs to be in the tree, hence a Node.

## The GitHub repo whose releases carry the capnp-<platform>.zip assets.
const REPO: String = "plaught-armor/capngodo"
const LATEST_RELEASE_API: String = "https://api.github.com/repos/%s/releases/latest" % REPO

signal installation_completed(binary_path: String)
signal installation_failed(error_message: String)

enum Stage { IDLE, FETCHING_RELEASE, DOWNLOADING }

var _stage: Stage = Stage.IDLE
# Created in _ready (needs the tree) — null until then, so an instance used only
# for _extract_binary (e.g. in tests) allocates no HTTPRequest to leak.
var _http: HTTPRequest = null


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 30.0 # don't spin forever on a stalled API / download
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## The release asset name for this platform, matching the CI job that built it,
## or "" when the platform is unsupported (no prebuilt binary).
static func expected_asset() -> String:
	var os: String = OS.get_name()
	if os == "Windows":
		return "capnp-windows-x86_64.zip"
	if os == "macOS":
		return "capnp-macos-universal.zip"
	if os == "Linux":
		return "capnp-linux-x86_64.zip"
	return ""


## Begin the fetch-release -> download -> extract flow. Emits one of the two
## signals when done. Fails loud if the platform has no prebuilt asset.
func install() -> void:
	if _http == null:
		_fail("installer must be added to the scene tree before install()")
		return
	if expected_asset().is_empty():
		_fail("no prebuilt capnp for this platform (%s); install capnp manually" % OS.get_name())
		return
	if _stage != Stage.IDLE:
		_fail("install already in progress")
		return
	_stage = Stage.FETCHING_RELEASE
	var err: int = _http.request(LATEST_RELEASE_API)
	if err != OK:
		_fail("could not start release request (err %d)" % err)


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var what: String = "release API" if _stage == Stage.FETCHING_RELEASE else "asset download"
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("network error %d from %s (timeout / no connection)" % [result, what])
		return
	if code == 404 and _stage == Stage.FETCHING_RELEASE:
		_fail("no capnp release published yet — Browse to an existing binary or build from source")
		return
	if code != 200:
		_fail("HTTP %d from %s" % [code, what])
		return
	if _stage == Stage.FETCHING_RELEASE:
		_handle_release(body)
	elif _stage == Stage.DOWNLOADING:
		_handle_download(body)


func _handle_release(body: PackedByteArray) -> void:
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY or not json.has("assets"):
		_fail("could not parse the release info from GitHub")
		return
	var want: String = expected_asset()
	var url: String = ""
	for asset: Variant in json["assets"]:
		if typeof(asset) == TYPE_DICTIONARY and asset.get("name", "") == want:
			url = asset.get("browser_download_url", "")
			break
	if url.is_empty():
		_fail("no asset named '%s' in the latest release" % want)
		return
	_stage = Stage.DOWNLOADING
	var err: int = _http.request(url)
	if err != OK:
		_fail("could not start asset download (err %d)" % err)


func _handle_download(zip_bytes: PackedByteArray) -> void:
	_stage = Stage.IDLE
	if zip_bytes.is_empty():
		_fail("downloaded archive was empty")
		return
	var binary_path: String = _extract_binary(zip_bytes)
	if binary_path.is_empty():
		_fail("could not extract the capnp binary from the downloaded archive")
		return
	ProjectSettings.set_setting(CapnTool.SETTING_KEY, binary_path)
	ProjectSettings.save()
	installation_completed.emit(binary_path)


## Write the single executable inside `zip_bytes` to the platform cache path,
## chmod +x on POSIX. Returns the path, or "" on failure.
func _extract_binary(zip_bytes: PackedByteArray) -> String:
	var cache: String = CapnTool.cache_dir()
	if not DirAccess.dir_exists_absolute(cache) and DirAccess.make_dir_recursive_absolute(cache) != OK:
		push_error("[CapnInstaller] cannot create cache dir %s" % cache)
		return ""
	var tmp_zip: String = cache.path_join("_download.zip")
	var w: FileAccess = FileAccess.open(tmp_zip, FileAccess.WRITE)
	if w == null:
		push_error("[CapnInstaller] cannot write temp archive")
		return ""
	w.store_buffer(zip_bytes)
	w.close()

	var reader: ZIPReader = ZIPReader.new()
	if reader.open(tmp_zip) != OK:
		push_error("[CapnInstaller] cannot open downloaded zip")
		DirAccess.remove_absolute(tmp_zip)
		return ""
	# Match the binary by basename so a future zip carrying extra files (README,
	# Windows runtime DLLs) doesn't pick the wrong entry. get_files() order isn't
	# guaranteed, so don't rely on "first non-dir".
	var want: String = CapnTool.cached_binary_path().get_file()
	var data: PackedByteArray = PackedByteArray()
	for entry: String in reader.get_files():
		if entry.get_file() == want:
			data = reader.read_file(entry)
			break
	reader.close()
	DirAccess.remove_absolute(tmp_zip)
	if data.is_empty():
		push_error("[CapnInstaller] no '%s' entry inside the archive" % want)
		return ""

	var binary_path: String = CapnTool.cached_binary_path()
	var bw: FileAccess = FileAccess.open(binary_path, FileAccess.WRITE)
	if bw == null:
		push_error("[CapnInstaller] cannot write binary to %s" % binary_path)
		return ""
	bw.store_buffer(data)
	bw.close()
	if OS.get_name() != "Windows":
		var chmod_code: int = OS.execute("chmod", ["+x", binary_path])
		if chmod_code != 0:
			# Binary downloaded fine; only the +x failed. Warn (don't discard) —
			# the user can chmod manually, and resolve_capnp will still find it.
			push_warning("[CapnInstaller] chmod +x failed (exit %d) on %s" % [chmod_code, binary_path])
	return binary_path


func _fail(message: String) -> void:
	_stage = Stage.IDLE
	push_error("[CapnInstaller] " + message)
	installation_failed.emit(message)
