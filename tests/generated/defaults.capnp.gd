class_name DefaultsCapnp extends RefCounted

## GENERATED from defaults.capnp by capnpc-gdscript — do not edit.

enum Shade { RED, GREEN, BLUE }

class Defaults extends RefCounted:
	const DATA_WORDS: int = 3
	const PTR_WORDS: int = 4

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_i32f() -> int:
			return _r.get_i32(0, -42)

		func get_u16f() -> int:
			return _r.get_u16(4, 7)

		func get_boolf() -> bool:
			return _r.get_bool(48, true)

		func get_f32f() -> float:
			return _r.get_f32(8, 1069547520)

		func get_f64f() -> float:
			return _r.get_f64(16, 4612811918334230528)

		func get_textf() -> String:
			return _r.get_text(0, "hello")

		func get_enumf() -> Shade:
			return _r.get_u16(12, 1) as Shade

		func get_dataf() -> PackedByteArray:
			return _r.get_data(1, PackedByteArray([222, 173, 190, 239]))

		func get_datas() -> PackedByteArray:
			return _r.get_data(2, PackedByteArray([97, 98, 99]))

		func get_emptyd() -> PackedByteArray:
			return _r.get_data(3, PackedByteArray())

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_i32f(value: int) -> void:
			_b.set_i32(0, value, -42)

		func set_u16f(value: int) -> void:
			_b.set_u16(4, value, 7)

		func set_boolf(value: bool) -> void:
			_b.set_bool(48, value, true)

		func set_f32f(value: float) -> void:
			_b.set_f32(8, value, 1069547520)

		func set_f64f(value: float) -> void:
			_b.set_f64(16, value, 4612811918334230528)

		func set_textf(value: String) -> void:
			_b.set_text(0, value)

		func set_enumf(value: Shade) -> void:
			_b.set_u16(12, value, 1)

		func set_dataf(value: PackedByteArray) -> void:
			_b.set_data(1, value)

		func set_datas(value: PackedByteArray) -> void:
			_b.set_data(2, value)

		func set_emptyd(value: PackedByteArray) -> void:
			_b.set_data(3, value)


static func read_defaults(bytes: PackedByteArray, packed: bool = false) -> Defaults.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return Defaults.Reader.wrap(msg.get_root())

static func new_defaults() -> Defaults.Builder:
	return Defaults.Builder.wrap(CapnBuilder.new_message(Defaults.DATA_WORDS, Defaults.PTR_WORDS))
