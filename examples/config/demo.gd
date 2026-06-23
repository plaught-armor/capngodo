class_name ConfigDemo extends Node

## capngodo example: app settings with schema-level defaults + an enum field.
##
## `Settings` declares a default for every field (see settings.capnp). A message
## that leaves a field unset reads back that default — so the very first launch
## (a default-everything blob) and a saved config (some fields overridden) both
## decode through one reader with no null-handling at the call site.
##
## The enum field (`quality`) is `int` on the wire but the generated getter
## returns the `Quality` enum, and the setter takes it — typed at the API
## boundary (CQ2 / D10a).
##
## Generate the schema classes with:
##   capnp compile -o gdscript examples/config/settings.capnp


func _ready() -> void:
	# A brand-new config: serialize an untouched builder. Every field is unset,
	# so every getter returns its schema default.
	var fresh: PackedByteArray = SettingsCapnp.new_settings().to_bytes()
	print("fresh config (all defaults): %s" % load_settings(fresh))

	# A saved config: override two fields, leave the rest defaulted.
	var saved: PackedByteArray = save_settings({
		"quality": SettingsCapnp.Quality.ULTRA,
		"max_fps": 144,
	})
	print("saved config (2 overrides):  %s" % load_settings(saved))


# --- save / load (static + pure, testable) -------------------------------

## Serialize a sparse overrides dict. Any key absent stays at its schema default.
static func save_settings(overrides: Dictionary[String, Variant]) -> PackedByteArray:
	var s: SettingsCapnp.Settings.Builder = SettingsCapnp.new_settings()
	if overrides.has("master_volume"):
		s.set_master_volume(overrides["master_volume"])
	if overrides.has("music_volume"):
		s.set_music_volume(overrides["music_volume"])
	if overrides.has("quality"):
		s.set_quality(overrides["quality"])
	if overrides.has("fullscreen"):
		s.set_fullscreen(overrides["fullscreen"])
	if overrides.has("max_fps"):
		s.set_max_fps(overrides["max_fps"])
	if overrides.has("player_name"):
		s.set_player_name(overrides["player_name"])
	return s.to_bytes()


## Decode to a fully-populated dict — unset fields surface as their defaults.
static func load_settings(bytes: PackedByteArray) -> Dictionary[String, Variant]:
	var s: SettingsCapnp.Settings.Reader = SettingsCapnp.read_settings(bytes)
	return {
		"master_volume": s.get_master_volume(),
		"music_volume": s.get_music_volume(),
		"quality": s.get_quality(),
		"fullscreen": s.get_fullscreen(),
		"max_fps": s.get_max_fps(),
		"player_name": s.get_player_name(),
	}
