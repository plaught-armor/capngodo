class_name CapnSegments
extends RefCounted
## A message's segments: a list of word-aligned byte blobs (encoding.md :17-26).
##
## Segment 0 word 0 is always the root pointer. Cross-segment references resolve
## by segment id (index into `segments`). POD container (DOD D1): construction +
## bounds query only; framing/parsing live in CapnFraming, traversal in
## CapnMessage.

const WORD_BYTES: int = 8

var segments: Array[PackedByteArray] = []

# Bytes this object spanned when parsed from a stream frame (lets a caller read
# back-to-back messages from one buffer). 0 when built in-memory.
var frame_byte_size: int = 0


func _init(p_segments: Array[PackedByteArray] = []) -> void:
	segments = p_segments


func segment_count() -> int:
	return segments.size()


func has_segment(seg_id: int) -> bool:
	return seg_id >= 0 and seg_id < segments.size()


func segment_word_count(seg_id: int) -> int:
	if not has_segment(seg_id):
		return 0
	@warning_ignore("integer_division")
	return segments[seg_id].size() / WORD_BYTES


## True when [word_off, word_off + word_len) lies inside segment seg_id.
## Bounds checks use word units to match pointer offset semantics.
func words_in_bounds(seg_id: int, word_off: int, word_len: int) -> bool:
	if not has_segment(seg_id):
		return false
	if word_off < 0 or word_len < 0:
		return false
	return (word_off + word_len) <= segment_word_count(seg_id)
