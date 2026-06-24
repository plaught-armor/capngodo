extends GutTest
## CapnPacked — the three hand-verifiable examples from encoding.md plus
## round-trip identity against the real capnp packed fixtures.

func _hex(s: String) -> PackedByteArray:
	return PackedByteArray(s.hex_decode())


func _read_fixture(name: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open("res://tests/fixtures/testdata/%s" % name, FileAccess.READ)
	assert_not_null(f, "fixture %s present" % name)
	if f == null:
		return PackedByteArray()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return bytes


func test_pack_struct_then_text_example() -> void:
	# encoding.md :310-311.
	var unpacked: PackedByteArray = _hex("0800000003000200") + _hex("19000000aa010000")
	assert_eq(CapnPacked.pack(unpacked), _hex("510803023119aa01"))
	assert_eq(CapnPacked.unpack(CapnPacked.pack(unpacked)), unpacked)


func test_zero_run_example() -> void:
	# encoding.md :333 — 32 zero bytes -> 00 03.
	var unpacked: PackedByteArray = []
	unpacked.resize(32)
	assert_eq(CapnPacked.pack(unpacked), _hex("0003"))
	assert_eq(CapnPacked.unpack(_hex("0003")), unpacked)


func test_literal_run_example() -> void:
	# encoding.md :336 — 0x8a x32 -> ff 8a*8 03 8a*24.
	var unpacked: PackedByteArray = []
	unpacked.resize(32)
	unpacked.fill(0x8a)
	var expected: PackedByteArray = _hex("ff") + _repeat(0x8a, 8) + _hex("03") + _repeat(0x8a, 24)
	assert_eq(CapnPacked.pack(unpacked), expected)
	assert_eq(CapnPacked.unpack(expected), unpacked)


func test_packed_fixture_unpacks_to_binary() -> void:
	# The packed fixture is framing+packed; unpacking the whole stream yields the
	# byte-identical framed `binary` fixture.
	var packed: PackedByteArray = _read_fixture("packed")
	var binary: PackedByteArray = _read_fixture("binary")
	assert_eq(CapnPacked.unpack(packed), binary)


func test_packedflat_fixture_unpacks_to_flat() -> void:
	var packedflat: PackedByteArray = _read_fixture("packedflat")
	var flat: PackedByteArray = _read_fixture("flat")
	assert_eq(CapnPacked.unpack(packedflat), flat)


func test_roundtrip_binary_fixture() -> void:
	var binary: PackedByteArray = _read_fixture("binary")
	assert_eq(CapnPacked.unpack(CapnPacked.pack(binary)), binary)


func test_unpack_amplification_capped() -> void:
	# Packed zero-runs expand ~1024x: a 2-byte "00 ff" tag emits 256 zero words
	# (2 KiB). Without a cap, a hostile all-zero-run stream balloons to gigabytes
	# during unpack — before framing or the reader's traversal limit ever apply.
	# unpack() must abort (empty) once output passes max_out_words; 0 = unlimited
	# so trusted round-trip callers (every assert above) are unaffected.
	var packed: PackedByteArray = []
	var k: int = 0
	while k < 64:
		packed.append(0x00) # zero-word tag
		packed.append(0xff) # + 255 more zero words = 256 words per run
		k += 1
	# 64 runs * 256 words = 16384 words = 131072 bytes when uncapped.
	assert_eq(CapnPacked.unpack(packed, 0).size(), 131072, "max_out_words=0 stays unlimited")
	assert_true(CapnPacked.unpack(packed, 100).is_empty(), "unpack aborts empty past the cap")
	# End-to-end: open() caps unpack against the traversal limit, so a packed
	# stream that unpacks past it is rejected without the giant allocation.
	var tiny: CapnLimits = CapnLimits.new(100, 64) # 100-word traversal ceiling
	assert_null(
		CapnReader.open(packed, true, tiny),
		"open must reject a packed stream that unpacks past the traversal limit",
	)


func _repeat(byte_value: int, count: int) -> PackedByteArray:
	var out: PackedByteArray = []
	out.resize(count)
	out.fill(byte_value)
	return out
