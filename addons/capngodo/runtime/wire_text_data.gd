class_name CapnTextData extends RefCounted

## Text/Data helpers. Both are List(UInt8) on the wire (encoding.md :76-86).
## Data is raw bytes. Text is the same but the last byte MUST be a NUL
## terminator, included in the list length but not in the reported string.
##
## Leaf module: takes raw (buffer, byte offset, element count) rather than a
## CapnListReader, so it forms no dependency cycle with the readers.

const WORD_BYTES: int = 8


## Raw bytes of a byte-list, sliced straight from the segment. For Data fields.
static func data_from(buf: PackedByteArray, byte_off: int, count: int) -> PackedByteArray:
	if count <= 0:
		return PackedByteArray()
	return buf.slice(byte_off, byte_off + count)


## UTF-8 decode of a text-list, dropping the trailing NUL terminator.
static func text_from(buf: PackedByteArray, byte_off: int, count: int) -> String:
	var bytes: PackedByteArray = data_from(buf, byte_off, count)
	var n: int = bytes.size()
	if n > 0 and bytes[n - 1] == 0:
		bytes = bytes.slice(0, n - 1)
	return bytes.get_string_from_utf8()


## UTF-8 bytes for a string plus the NUL terminator — the on-wire text length.
static func text_to_bytes(s: String) -> PackedByteArray:
	var out: PackedByteArray = s.to_utf8_buffer()
	out.append(0)
	return out
