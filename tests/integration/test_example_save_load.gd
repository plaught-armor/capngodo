extends GutTest
## Smoke test for the save/load example (examples/save_load): a plain Dictionary
## round-trips through the generated GameStateCapnp via SaveLoadDemo's static
## save/load — proving the example (and a real save-game use case) works.

const SAVE_PATH: String = "user://test_savegame.capnp"


func after_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_save_then_load_round_trips() -> void:
	var state: Dictionary = {
		"player_name": "Aria",
		"level": 7,
		"hp": 84,
		"pos_x": 12.5,
		"pos_y": -3.25,
		"inventory": [
			{ "name": "sword", "count": 1 },
			{ "name": "potion", "count": 5 },
		],
	}
	assert_eq(SaveLoadDemo.save_game(SAVE_PATH, state), OK, "save succeeds")
	var loaded: Dictionary = SaveLoadDemo.load_game(SAVE_PATH)

	assert_eq(loaded["player_name"], "Aria")
	assert_eq(loaded["level"], 7)
	assert_eq(loaded["hp"], 84)
	assert_almost_eq(loaded["pos_x"], 12.5, 0.0001)
	assert_almost_eq(loaded["pos_y"], -3.25, 0.0001)
	var inv: Array = loaded["inventory"]
	assert_eq(inv.size(), 2, "two items")
	assert_eq(inv[0]["name"], "sword")
	assert_eq(inv[0]["count"], 1)
	assert_eq(inv[1]["name"], "potion")
	assert_eq(inv[1]["count"], 5)


func test_load_missing_file_returns_empty() -> void:
	assert_eq(SaveLoadDemo.load_game("user://does_not_exist.capnp"), { })
