class_name CapnPacked extends RefCounted

## Packed encoding codec (encoding.md :296-349).
##
## Each unpacked 8-byte word becomes a tag byte (bit i set iff byte i is
## non-zero) followed by its non-zero bytes. Two special tags:
##   0x00  -> word of zeros, then 1 byte N = that many ADDITIONAL zero words.
##   0xff  -> the 8 verbatim bytes, then 1 byte N = that many MORE verbatim words.
## Both specials "decode as if not special first", so a single pass computes the
## tag and emits non-zero bytes; only the end-of-word check branches on 0x00/0xff
## (the design intent noted at :339-346).
##
## pack(x) is one valid encoding (the format permits several); the guarantee is
## unpack(pack(x)) == x and unpack(<any valid packing>) == original. The literal
## and zero run heuristics here reproduce the two spec examples (:333, :336)
## byte-for-byte.

const WORD_BYTES: int = 8
const MAX_RUN: int = 255


# --- unpack --------------------------------------------------------------

## Returns the unpacked words, or an empty array on malformed input (push_error).
static func unpack(packed: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	var n: int = packed.size()
	var i: int = 0
	# i advances by >= 1 each iteration (tag byte), so n bounds the loop.
	while i < n:
		var tag: int = packed[i]
		i += 1
		var word: PackedByteArray = PackedByteArray()
		word.resize(WORD_BYTES)
		for bit: int in WORD_BYTES:
			if (tag & (1 << bit)) != 0:
				if i >= n:
					push_error("CapnPacked.unpack: truncated content bytes")
					return PackedByteArray()
				word[bit] = packed[i]
				i += 1
			# else leave zero
		out.append_array(word)

		if tag == 0x00:
			if i >= n:
				push_error("CapnPacked.unpack: truncated zero-run count")
				return PackedByteArray()
			var zeros: int = packed[i]
			i += 1
			if zeros > 0:
				var pad: PackedByteArray = PackedByteArray()
				pad.resize(zeros * WORD_BYTES)
				out.append_array(pad)
		elif tag == 0xff:
			if i >= n:
				push_error("CapnPacked.unpack: truncated literal-run count")
				return PackedByteArray()
			var literals: int = packed[i]
			i += 1
			var raw_bytes: int = literals * WORD_BYTES
			if i + raw_bytes > n:
				push_error("CapnPacked.unpack: truncated literal-run body")
				return PackedByteArray()
			if raw_bytes > 0:
				out.append_array(packed.slice(i, i + raw_bytes))
				i += raw_bytes
	return out


# --- pack ----------------------------------------------------------------

static func pack(unpacked: PackedByteArray) -> PackedByteArray:
	if unpacked.size() % WORD_BYTES != 0:
		push_error("CapnPacked.pack: input not word-aligned (%d bytes)" % unpacked.size())
		return PackedByteArray()
	var out: PackedByteArray = PackedByteArray()
	@warning_ignore("integer_division")
	var word_count: int = unpacked.size() / WORD_BYTES
	var w: int = 0
	while w < word_count:
		var base: int = w * WORD_BYTES
		var tag: int = 0
		var content: PackedByteArray = PackedByteArray()
		for j: int in WORD_BYTES:
			var b: int = unpacked[base + j]
			if b != 0:
				tag = tag | (1 << j)
				content.append(b)
		out.append(tag)
		out.append_array(content)
		w += 1

		if tag == 0x00:
			# Count following all-zero words (capped 255).
			var run: int = 0
			while w < word_count and run < MAX_RUN and _word_is_zero(unpacked, w * WORD_BYTES):
				run += 1
				w += 1
			out.append(run)
		elif tag == 0xff:
			# Literal run: copy following dense words verbatim (>=2 zero bytes
			# stops the run, matching the reference encoder).
			var start_word: int = w
			var run2: int = 0
			while w < word_count and run2 < MAX_RUN and _zero_byte_count(unpacked, w * WORD_BYTES) < 2:
				run2 += 1
				w += 1
			out.append(run2)
			if run2 > 0:
				out.append_array(unpacked.slice(start_word * WORD_BYTES, (start_word + run2) * WORD_BYTES))
	return out


# --- helpers -------------------------------------------------------------

static func _word_is_zero(buf: PackedByteArray, base: int) -> bool:
	for j: int in WORD_BYTES:
		if buf[base + j] != 0:
			return false
	return true


static func _zero_byte_count(buf: PackedByteArray, base: int) -> int:
	var zeros: int = 0
	for j: int in WORD_BYTES:
		if buf[base + j] == 0:
			zeros += 1
	return zeros
