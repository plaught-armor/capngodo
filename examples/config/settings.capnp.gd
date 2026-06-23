class_name SettingsCapnp extends RefCounted

## GENERATED from settings.capnp by capnpc-gdscript — do not edit.

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

class Settings extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 1

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_master_volume() -> float:
			return _r.get_f32(0, 1061997773)

		func get_music_volume() -> float:
			return _r.get_f32(4, 1058642330)

		func get_quality() -> Quality:
			return _r.get_u16(8, 2) as Quality

		func get_fullscreen() -> bool:
			return _r.get_bool(80, true)

		func get_max_fps() -> int:
			return _r.get_u16(12, 60)

		func get_player_name() -> String:
			return _r.get_text(0, "Player")

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_master_volume(value: float) -> void:
			_b.set_f32(0, value, 1061997773)

		func set_music_volume(value: float) -> void:
			_b.set_f32(4, value, 1058642330)

		func set_quality(value: Quality) -> void:
			_b.set_u16(8, value, 2)

		func set_fullscreen(value: bool) -> void:
			_b.set_bool(80, value, true)

		func set_max_fps(value: int) -> void:
			_b.set_u16(12, value, 60)

		func set_player_name(value: String) -> void:
			_b.set_text(0, value)


static func read_settings(bytes: PackedByteArray, packed: bool = false) -> Settings.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Settings.Reader.wrap(msg.get_root())

static func new_settings() -> Settings.Builder:
	return Settings.Builder.wrap(CapnBuilder.new_message(Settings.DATA_WORDS, Settings.PTR_WORDS))
