@tool
extends EditorPlugin

## Editor dock for capngodo: resolve/install the capnp compiler and generate
## GDScript from a .capnp schema in-process (via CapnTool — no CLI, no PATH/env
## setup). The runtime codec and the CLI shim work without the editor; this dock
## is the zero-config path for everyone else.

const _DOCK_TITLE: String = "Cap'n Proto"

var _dock: VBoxContainer = null
var _status: Label = null
var _schema_edit: LineEdit = null
var _out_edit: LineEdit = null
var _log: Label = null
var _installer: CapnInstaller = null
var _capnp_dialog: EditorFileDialog = null
var _schema_dialog: EditorFileDialog = null
var _out_dialog: EditorFileDialog = null


func _enter_tree() -> void:
	_dock = _build_dock()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)
	_refresh_status()


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	# The installer lives under _dock and is freed with it; drop the ref so a
	# disable+re-enable rebuilds it instead of touching the freed node.
	_installer = null


# --- UI construction -----------------------------------------------------

func _build_dock() -> VBoxContainer:
	var root: VBoxContainer = VBoxContainer.new()
	root.name = _DOCK_TITLE

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var install_row: HBoxContainer = HBoxContainer.new()
	install_row.add_child(_button("Install capnp", _on_install_pressed))
	install_row.add_child(_button("Browse…", _on_browse_capnp_pressed))
	root.add_child(install_row)

	root.add_child(HSeparator.new())
	root.add_child(_labeled("Schema (.capnp):"))
	_schema_edit = LineEdit.new()
	_schema_edit.placeholder_text = "res://…/schema.capnp"
	root.add_child(_field_row(_schema_edit, _on_browse_schema_pressed))

	root.add_child(_labeled("Output dir:"))
	_out_edit = LineEdit.new()
	_out_edit.placeholder_text = "res://generated"
	root.add_child(_field_row(_out_edit, _on_browse_out_pressed))

	root.add_child(_button("Generate .gd", _on_generate_pressed))

	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_log)

	_capnp_dialog = _make_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, EditorFileDialog.ACCESS_FILESYSTEM, _on_capnp_chosen)
	_schema_dialog = _make_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, EditorFileDialog.ACCESS_RESOURCES, _on_schema_chosen)
	_schema_dialog.add_filter("*.capnp", "Cap'n Proto schema")
	_out_dialog = _make_dialog(EditorFileDialog.FILE_MODE_OPEN_DIR, EditorFileDialog.ACCESS_RESOURCES, _on_out_chosen)
	root.add_child(_capnp_dialog)
	root.add_child(_schema_dialog)
	root.add_child(_out_dialog)
	return root


func _button(text: String, handler: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b


func _labeled(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	return l


## A LineEdit that expands + a trailing "…" browse button wired to `handler`.
func _field_row(edit: LineEdit, handler: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	row.add_child(_button("…", handler))
	return row


func _make_dialog(mode: EditorFileDialog.FileMode, access: EditorFileDialog.Access, handler: Callable) -> EditorFileDialog:
	var fd: EditorFileDialog = EditorFileDialog.new()
	fd.file_mode = mode
	fd.access = access
	fd.dir_selected.connect(handler)
	fd.file_selected.connect(handler)
	return fd


# --- status + actions ----------------------------------------------------

func _refresh_status() -> void:
	var capnp: String = CapnTool.resolve_capnp()
	if capnp.is_empty():
		_status.text = "capnp: not found — Install or Browse to a binary."
	else:
		_status.text = "capnp: %s" % capnp


func _on_install_pressed() -> void:
	if _installer == null:
		_installer = CapnInstaller.new()
		_dock.add_child(_installer)
		_installer.installation_completed.connect(_on_install_done)
		_installer.installation_failed.connect(_on_install_failed)
	_log.text = "Downloading capnp…"
	_installer.install()


func _on_install_done(path: String) -> void:
	_log.text = "Installed capnp -> %s" % path
	_refresh_status()


func _on_install_failed(message: String) -> void:
	_log.text = "Install failed: %s" % message


func _on_browse_capnp_pressed() -> void:
	_capnp_dialog.popup_centered_ratio(0.6)


func _on_browse_schema_pressed() -> void:
	_schema_dialog.popup_centered_ratio(0.6)


func _on_browse_out_pressed() -> void:
	_out_dialog.popup_centered_ratio(0.6)


func _on_capnp_chosen(path: String) -> void:
	ProjectSettings.set_setting(CapnTool.SETTING_KEY, path)
	ProjectSettings.save()
	_refresh_status()


func _on_schema_chosen(path: String) -> void:
	_schema_edit.text = path


func _on_out_chosen(path: String) -> void:
	_out_edit.text = path


func _on_generate_pressed() -> void:
	var capnp: String = CapnTool.resolve_capnp()
	if capnp.is_empty():
		_log.text = "No capnp — Install or Browse first."
		return
	var schema: String = _schema_edit.text.strip_edges()
	var out_dir: String = _out_edit.text.strip_edges()
	if schema.is_empty() or out_dir.is_empty():
		_log.text = "Set a schema and an output dir."
		return
	# capnp runs as a subprocess, so it needs a real filesystem path; the output
	# dir stays res:// (FileAccess writes it in-editor).
	var schema_abs: String = ProjectSettings.globalize_path(schema)
	var result: CapnTool.Result = CapnTool.generate_to_dir(capnp, schema_abs, out_dir)
	if result.ok:
		_log.text = "Generated %d file(s):\n%s" % [result.written.size(), "\n".join(result.written)]
		EditorInterface.get_resource_filesystem().scan()
	else:
		_log.text = "Generate failed: %s" % result.error
