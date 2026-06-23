extends GutTest

## Smoke test for the config example (examples/config): schema defaults surface
## for unset fields, overrides round-trip, and the enum field is enum-typed.


func test_fresh_config_reads_all_defaults() -> void:
	var fresh: PackedByteArray = SettingsCapnp.new_settings().to_bytes()
	var c: Dictionary[String, Variant] = ConfigDemo.load_settings(fresh)
	assert_almost_eq(c["master_volume"], 0.8, 0.0001, "master default")
	assert_almost_eq(c["music_volume"], 0.6, 0.0001, "music default")
	assert_eq(c["quality"], SettingsCapnp.Quality.HIGH, "quality default")
	assert_eq(c["fullscreen"], true, "fullscreen default")
	assert_eq(c["max_fps"], 60, "fps default")
	assert_eq(c["player_name"], "Player", "name default")


func test_overrides_round_trip_others_stay_default() -> void:
	var saved: PackedByteArray = ConfigDemo.save_settings({
		"quality": SettingsCapnp.Quality.ULTRA,
		"max_fps": 144,
	})
	var c: Dictionary[String, Variant] = ConfigDemo.load_settings(saved)
	# Overridden.
	assert_eq(c["quality"], SettingsCapnp.Quality.ULTRA, "quality overridden")
	assert_eq(c["max_fps"], 144, "fps overridden")
	# Untouched -> still defaults.
	assert_almost_eq(c["master_volume"], 0.8, 0.0001, "master still default")
	assert_eq(c["player_name"], "Player", "name still default")


func test_quality_getter_is_enum_typed() -> void:
	# Setter takes the enum, getter returns it — int at the wire, enum at the API.
	var saved: PackedByteArray = ConfigDemo.save_settings({"quality": SettingsCapnp.Quality.LOW})
	var got: SettingsCapnp.Quality = SettingsCapnp.read_settings(saved).get_quality()
	assert_eq(got, SettingsCapnp.Quality.LOW)
