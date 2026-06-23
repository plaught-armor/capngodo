class_name AcronymsCapnp extends RefCounted

## GENERATED from acronyms.capnp by capnpc-gdscript — do not edit.

class HTTPServer extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 1
	enum ResponseKind { OK_STATUS, ERR_STATUS }

	class Reader extends CapnReader.StructReader:
		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o.set_from_inline(r.msg, r.seg_id, r.data_byte_off, r.data_bytes, r.ptr_word, r.ptr_words, r.depth_remaining)
			return o

		func get_parse_http_request() -> bool:
			return self.get_bool(0, false)

		func get_server_id() -> int:
			return self.get_i32(4, 0)

		func get_url_field() -> String:
			return self.get_text(0, "")

		func response_kind_which() -> int:
			return self.get_u16(2, 0)

		func is_response_kind_ok_status() -> bool:
			return self.get_u16(2, 0) == 0

		func is_response_kind_err_status() -> bool:
			return self.get_u16(2, 0) == 1

		func get_response_kind_err_status() -> int:
			return self.get_i32(8, 0)

	class Builder extends CapnBuilder.StructBuilder:
		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o.set_from(b.arena, b.seg_id, b.data_word, b.data_words, b.ptr_words)
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(self, packed)

		func set_parse_http_request(value: bool) -> void:
			self.set_bool(0, value, false)

		func set_server_id(value: int) -> void:
			self.set_i32(4, value, 0)

		func set_url_field(value: String) -> void:
			self.set_text(0, value)

		func set_response_kind_ok_status() -> void:
			self.set_u16(2, 0, 0)

		func set_response_kind_err_status(value: int) -> void:
			self.set_u16(2, 1, 0)
			self.set_i32(8, value, 0)


static func read_http_server(bytes: PackedByteArray, packed: bool = false) -> HTTPServer.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	var r: HTTPServer.Reader = HTTPServer.Reader.new()
	msg.fill_root(r)
	return r

static func new_http_server() -> HTTPServer.Builder:
	return HTTPServer.Builder.wrap(CapnBuilder.new_message(HTTPServer.DATA_WORDS, HTTPServer.PTR_WORDS))
