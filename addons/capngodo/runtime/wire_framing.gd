class_name CapnFraming extends RefCounted

## Stream framing: the recommended segment-table envelope (encoding.md :288-294).
##
## Layout (all u32 little-endian):
##   [segCount-1] [size0_words] .. [sizeN_words] [0|4 pad] [seg0 bytes] ..
## Header is 4*(1+segCount) bytes; pad 4 to reach a word boundary when that is
## odd. read() validates every length against the buffer and fails loud
## (push_error + null) rather than over-read.

const WORD_BYTES: int = 8

# Defensive ceilings against malicious headers (NASA rule 2/5). A real message
# never approaches these; they exist so a corrupt count can't drive an OOM.
const MAX_SEGMENTS: int = 1 << 20
const MAX_TOTAL_WORDS: int = 1 << 28  # 2 GiB of message


static func read(buf: PackedByteArray, off: int = 0) -> CapnSegments:
	if off < 0 or buf.size() - off < 4:
		push_error("CapnFraming.read: buffer too small for segment count")
		return null
	var seg_count: int = buf.decode_u32(off) + 1
	if seg_count <= 0 or seg_count > MAX_SEGMENTS:
		push_error("CapnFraming.read: implausible segment count %d" % seg_count)
		return null

	var header_bytes: int = 4 + 4 * seg_count
	var pad: int = (WORD_BYTES - (header_bytes % WORD_BYTES)) % WORD_BYTES
	var content_off: int = off + header_bytes + pad
	if buf.size() < off + header_bytes:
		push_error("CapnFraming.read: truncated segment size table")
		return null

	var sizes: PackedInt64Array = PackedInt64Array()
	sizes.resize(seg_count)
	var total_words: int = 0
	for i: int in seg_count:
		var w: int = buf.decode_u32(off + 4 + 4 * i)
		sizes[i] = w
		total_words += w
		if total_words > MAX_TOTAL_WORDS:
			push_error("CapnFraming.read: message exceeds size ceiling")
			return null

	var content_bytes: int = total_words * WORD_BYTES
	if buf.size() < content_off + content_bytes:
		push_error("CapnFraming.read: truncated segment content")
		return null

	var segs: CapnSegments = CapnSegments.new()
	var cursor: int = content_off
	for i: int in seg_count:
		var n: int = sizes[i] * WORD_BYTES
		segs.segments.append(buf.slice(cursor, cursor + n))
		cursor += n
	segs.frame_byte_size = (content_off - off) + content_bytes
	return segs


static func write(segs: CapnSegments) -> PackedByteArray:
	var seg_count: int = segs.segment_count()
	if seg_count < 1:
		push_error("CapnFraming.write: need at least one segment")
		return PackedByteArray()

	var header_bytes: int = 4 + 4 * seg_count
	var pad: int = (WORD_BYTES - (header_bytes % WORD_BYTES)) % WORD_BYTES
	var out: PackedByteArray = PackedByteArray()
	out.resize(header_bytes + pad)
	out.encode_u32(0, seg_count - 1)
	for i: int in seg_count:
		var blob: PackedByteArray = segs.segments[i]
		if blob.size() % WORD_BYTES != 0:
			push_error("CapnFraming.write: segment %d not word-aligned (%d bytes)" % [i, blob.size()])
			return PackedByteArray()
		@warning_ignore("integer_division")
		var word_len: int = blob.size() / WORD_BYTES
		out.encode_u32(4 + 4 * i, word_len)
	# pad bytes already zero from resize().
	for i: int in seg_count:
		out.append_array(segs.segments[i])
	return out
