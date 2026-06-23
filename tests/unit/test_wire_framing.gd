extends GutTest
## CapnFraming — segment-table parse/write against the real capnp fixtures and
## synthetic multi-segment round-trips.

func _read_fixture(name: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open("res://tests/fixtures/testdata/%s" % name, FileAccess.READ)
	assert_not_null(f, "fixture %s present" % name)
	if f == null:
		return PackedByteArray()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return bytes


func test_binary_fixture_single_segment() -> void:
	var binary: PackedByteArray = _read_fixture("binary")
	var segs: CapnSegments = CapnFraming.read(binary)
	assert_not_null(segs)
	assert_eq(segs.segment_count(), 1)
	assert_eq(segs.segment_word_count(0), 351)
	assert_eq(segs.frame_byte_size, 2816)


func test_binary_fixture_reframe_identity() -> void:
	var binary: PackedByteArray = _read_fixture("binary")
	var segs: CapnSegments = CapnFraming.read(binary)
	assert_eq(CapnFraming.write(segs), binary, "reframe must be byte-identical")


func test_segmented_fixture_multi_segment() -> void:
	var segmented: PackedByteArray = _read_fixture("segmented")
	var segs: CapnSegments = CapnFraming.read(segmented)
	assert_not_null(segs)
	assert_eq(segs.segment_count(), 125)
	assert_eq(CapnFraming.write(segs), segmented, "multi-segment reframe identity")


func test_write_then_read_roundtrip() -> void:
	var segs: CapnSegments = CapnSegments.new()
	var a: PackedByteArray = PackedByteArray()
	a.resize(16) # 2 words
	a.encode_u32(0, 0xcafe)
	var b: PackedByteArray = PackedByteArray()
	b.resize(8) # 1 word
	b.encode_u32(0, 0xbeef)
	segs.segments = [a, b]
	var framed: PackedByteArray = CapnFraming.write(segs)
	var back: CapnSegments = CapnFraming.read(framed)
	assert_eq(back.segment_count(), 2)
	assert_eq(back.segments[0], a)
	assert_eq(back.segments[1], b)


func test_truncated_frame_fails_loud() -> void:
	# A header claiming 4 segments but with no body must return null, not over-read.
	var bad: PackedByteArray = PackedByteArray()
	bad.resize(4)
	bad.encode_u32(0, 3) # seg_count-1 = 3 -> 4 segments, no size table follows
	assert_null(CapnFraming.read(bad))
