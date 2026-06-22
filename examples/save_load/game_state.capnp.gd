class_name GameStateCapnp extends RefCounted

## GENERATED from game_state.capnp by capnpc-gdscript — do not edit.

class Item extends RefCounted:
	const DATA_WORDS: int = 1
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_name() -> String:
			return _r.get_text(0, "")

		func get_count() -> int:
			return _r.get_u32(0, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_name(value: String) -> void:
			_b.set_text(0, value)

		func set_count(value: int) -> void:
			_b.set_u32(0, value, 0)

class GameState extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 2

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_player_name() -> String:
			return _r.get_text(0, "")

		func get_level() -> int:
			return _r.get_u16(0, 0)

		func get_hp() -> int:
			return _r.get_i32(4, 0)

		func get_pos_x() -> float:
			return _r.get_f32(8, 0)

		func get_pos_y() -> float:
			return _r.get_f32(12, 0)

		func get_inventory() -> Array:
			var lr: CapnReader.ListReader = _r.get_list(1)
			var out: Array = []
			out.resize(lr.size())
			for i: int in lr.size():
				out[i] = Item.Reader.wrap(lr.get_struct(i))
			return out

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_player_name(value: String) -> void:
			_b.set_text(0, value)

		func set_level(value: int) -> void:
			_b.set_u16(0, value, 0)

		func set_hp(value: int) -> void:
			_b.set_i32(4, value, 0)

		func set_pos_x(value: float) -> void:
			_b.set_f32(8, value, 0)

		func set_pos_y(value: float) -> void:
			_b.set_f32(12, value, 0)

		func init_inventory(n: int) -> Array:
			var lb: CapnBuilder.ListBuilder = _b.init_composite_list(1, n, Item.DATA_WORDS, Item.PTR_WORDS)
			var out: Array = []
			out.resize(n)
			for i: int in n:
				out[i] = Item.Builder.wrap(lb.init_struct(i))
			return out


static func read_item(bytes: PackedByteArray, packed: bool = false) -> Item.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Item.Reader.wrap(msg.get_root())

static func new_item() -> Item.Builder:
	return Item.Builder.wrap(CapnBuilder.new_message(Item.DATA_WORDS, Item.PTR_WORDS))

static func read_game_state(bytes: PackedByteArray, packed: bool = false) -> GameState.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return GameState.Reader.wrap(msg.get_root())

static func new_game_state() -> GameState.Builder:
	return GameState.Builder.wrap(CapnBuilder.new_message(GameState.DATA_WORDS, GameState.PTR_WORDS))
