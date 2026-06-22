extends GutTest

## Field defaults: an unset field reads its declared default (wire 0 XOR default
## = default); a set field overrides it and round-trips. Uses the generated
## DefaultsCapnp (from tests/golden/defaults.capnp).


func test_unset_fields_read_their_defaults() -> void:
	# A freshly-built message writes no fields -> every getter returns its default.
	var d: DefaultsCapnp.Defaults.Builder = DefaultsCapnp.new_defaults()
	var r: DefaultsCapnp.Defaults.Reader = DefaultsCapnp.read_defaults(d.to_bytes())
	assert_eq(r.get_i32f(), -42, "i32 default")
	assert_eq(r.get_u16f(), 7, "u16 default")
	assert_true(r.get_boolf(), "bool default true")
	assert_almost_eq(r.get_f32f(), 1.5, 0.0001, "f32 default")
	assert_almost_eq(r.get_f64f(), 2.5, 0.0001, "f64 default")
	assert_eq(r.get_textf(), "hello", "text default")
	assert_eq(r.get_enumf(), DefaultsCapnp.Shade.GREEN, "enum default green")
	# Data defaults (CG5): unset reads the authored bytes.
	assert_eq(r.get_dataf(), PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF]), "hex Data default")
	assert_eq(r.get_datas(), PackedByteArray([0x61, 0x62, 0x63]), "string Data default 'abc'")
	assert_eq(r.get_emptyd(), PackedByteArray(), "no-default Data reads empty")


func test_set_fields_override_defaults() -> void:
	var d: DefaultsCapnp.Defaults.Builder = DefaultsCapnp.new_defaults()
	d.set_i32f(100)
	d.set_boolf(false)
	d.set_f32f(9.25)
	d.set_textf("bye")
	d.set_enumf(DefaultsCapnp.Shade.BLUE)
	d.set_dataf(PackedByteArray([0x01, 0x02]))
	var r: DefaultsCapnp.Defaults.Reader = DefaultsCapnp.read_defaults(d.to_bytes())
	assert_eq(r.get_i32f(), 100, "i32 overridden")
	assert_false(r.get_boolf(), "bool overridden")
	assert_almost_eq(r.get_f32f(), 9.25, 0.0001, "f32 overridden")
	assert_eq(r.get_textf(), "bye", "text overridden")
	assert_eq(r.get_enumf(), DefaultsCapnp.Shade.BLUE, "enum overridden")
	# A set Data field overrides its default (Data never XOR-encodes).
	assert_eq(r.get_dataf(), PackedByteArray([0x01, 0x02]), "data overridden")
	# Untouched Data field still reads its authored default.
	assert_eq(r.get_datas(), PackedByteArray([0x61, 0x62, 0x63]), "untouched data still default")
	# Untouched fields still read their defaults.
	assert_eq(r.get_u16f(), 7, "untouched u16 still default")
	assert_almost_eq(r.get_f64f(), 2.5, 0.0001, "untouched f64 still default")


func test_setting_to_default_encodes_zero() -> void:
	# Setting a field to its own default must XOR-encode to wire 0.
	var d: DefaultsCapnp.Defaults.Builder = DefaultsCapnp.new_defaults()
	d.set_i32f(-42)
	d.set_u16f(7)
	var msg: CapnReader.Message = CapnReader.open(d.to_bytes(), false)
	var root: CapnReader.StructReader = msg.get_root()
	# Read the raw wire bytes (default 0) — they must be zero where the defaults sit.
	assert_eq(root.get_i32(0, 0), 0, "i32 set to default -> wire 0")
	assert_eq(root.get_u16(4, 0), 0, "u16 set to default -> wire 0")
