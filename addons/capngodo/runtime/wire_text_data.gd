class_name CapnTextData
extends RefCounted
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
## Single slice: trim the NUL from the span end before copying, rather than
## slicing the full span and re-slicing to drop the last byte.
static func text_from(buf: PackedByteArray, byte_off: int, count: int) -> String:
	if count <= 0:
		return ""
	var end: int = byte_off + count
	if buf[end - 1] == 0:
		end -= 1
	return buf.slice(byte_off, end).get_string_from_utf8()


## UTF-8 bytes for a string plus the NUL terminator — the on-wire text length.
static func text_to_bytes(s: String) -> PackedByteArray:
	var out: PackedByteArray = s.to_utf8_buffer()
	out.append(0)
	return out
