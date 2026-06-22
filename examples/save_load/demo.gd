class_name SaveLoadDemo extends Node

## Minimal capngodo example: save/load game state to Cap'n Proto bytes.
##
## Serializes a plain Dictionary (player name, level, hp, position, inventory)
## into a `GameState` message via the generated `GameStateCapnp` classes, writes
## it to `user://`, and reads it back. The save/load functions are static and
## pure so they double as a unit-testable API (see tests/integration).
##
## Generate the schema classes with:
##   capnp compile -o gdscript examples/save_load/game_state.capnp

const SAVE_PATH: String = "user://savegame.capnp"


func _ready() -> void:
	var state: Dictionary = {
		"player_name": "Aria",
		"level": 7,
		"hp": 84,
		"pos_x": 12.5,
		"pos_y": -3.25,
		"inventory": [
			{"name": "sword", "count": 1},
			{"name": "potion", "count": 5},
		],
	}
	var err: int = save_game(SAVE_PATH, state)
	if err != OK:
		push_error("save failed: %d" % err)
		return
	var loaded: Dictionary = load_game(SAVE_PATH)
	var text: String = "Saved + loaded GameState:\n%s" % JSON.stringify(loaded, "  ")
	print(text)
	var label: Label = get_node_or_null(^"Output")
	if label != null:
		label.text = text


## Serialize `state` to a GameState message and write it to `path`.
static func save_game(path: String, state: Dictionary) -> int:
	var b: GameStateCapnp.GameState.Builder = GameStateCapnp.new_game_state()
	b.set_player_name(state["player_name"])
	b.set_level(state["level"])
	b.set_hp(state["hp"])
	b.set_pos_x(state["pos_x"])
	b.set_pos_y(state["pos_y"])

	var items: Array = state["inventory"]
	var slots: Array = b.init_inventory(items.size())   # Array of Item.Builder
	for i: int in items.size():
		var item: Dictionary = items[i]
		var slot: GameStateCapnp.Item.Builder = slots[i]
		slot.set_name(item["name"])
		slot.set_count(item["count"])

	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(b.to_bytes())
	f.close()
	return OK


## Read a GameState message from `path` back into a plain Dictionary.
static func load_game(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	var r: GameStateCapnp.GameState.Reader = GameStateCapnp.read_game_state(bytes)
	var inv_readers: Array = r.get_inventory()
	var inventory: Array = []
	for i: int in inv_readers.size():
		var it: GameStateCapnp.Item.Reader = inv_readers[i]
		inventory.append({"name": it.get_name(), "count": it.get_count()})

	return {
		"player_name": r.get_player_name(),
		"level": r.get_level(),
		"hp": r.get_hp(),
		"pos_x": r.get_pos_x(),
		"pos_y": r.get_pos_y(),
		"inventory": inventory,
	}
