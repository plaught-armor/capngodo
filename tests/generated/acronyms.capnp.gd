class_name AcronymsCapnp extends RefCounted

## GENERATED from acronyms.capnp by capnpc-gdscript — do not edit.

class HTTPServer extends RefCounted:
	const DATA_WORDS: int = 2
	const PTR_WORDS: int = 1
	enum ResponseKind { OK_STATUS, ERR_STATUS }

	class Reader extends RefCounted:
		var _r: CapnReader.StructReader

		static func wrap(r: CapnReader.StructReader) -> Reader:
			var o: Reader = Reader.new()
			o._r = r
			return o

		func get_parse_http_request() -> bool:
			return _r.get_bool(0, false)

		func get_server_id() -> int:
			return _r.get_i32(4, 0)

		func get_url_field() -> String:
			return _r.get_text(0, "")

		func response_kind_which() -> int:
			return _r.get_u16(2, 0)

		func is_response_kind_ok_status() -> bool:
			return _r.get_u16(2, 0) == 0

		func is_response_kind_err_status() -> bool:
			return _r.get_u16(2, 0) == 1

		func get_response_kind_err_status() -> int:
			return _r.get_i32(8, 0)

	class Builder extends RefCounted:
		var _b: CapnBuilder.StructBuilder

		static func wrap(b: CapnBuilder.StructBuilder) -> Builder:
			var o: Builder = Builder.new()
			o._b = b
			return o

		func to_bytes(packed: bool = false) -> PackedByteArray:
			return CapnBuilder.to_bytes(_b, packed)

		func set_parse_http_request(value: bool) -> void:
			_b.set_bool(0, value, false)

		func set_server_id(value: int) -> void:
			_b.set_i32(4, value, 0)

		func set_url_field(value: String) -> void:
			_b.set_text(0, value)

		func set_response_kind_ok_status() -> void:
			_b.set_u16(2, 0, 0)

		func set_response_kind_err_status(value: int) -> void:
			_b.set_u16(2, 1, 0)
			_b.set_i32(8, value, 0)


static func read_http_server(bytes: PackedByteArray, packed: bool = false) -> HTTPServer.Reader:
	var msg: CapnReader.Message = CapnReader.open(bytes, packed)
	return HTTPServer.Reader.wrap(msg.get_root())

static func new_http_server() -> HTTPServer.Builder:
	return HTTPServer.Builder.wrap(CapnBuilder.new_message(HTTPServer.DATA_WORDS, HTTPServer.PTR_WORDS))
