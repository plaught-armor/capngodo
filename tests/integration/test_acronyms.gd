extends GutTest

## Acronym name handling (CQ3): _snake splits at the end of a capital run that
## starts a new word, so accessor names read naturally. Type names keep their
## original case (HTTPServer). Uses the generated AcronymsCapnp (from
## tests/golden/acronyms.capnp).


func test_acronym_field_accessors_round_trip() -> void:
	var s: AcronymsCapnp.HTTPServer.Builder = AcronymsCapnp.new_http_server()
	s.set_parse_http_request(true)        # parseHTTPRequest -> parse_http_request
	s.set_server_id(42)                   # serverID -> server_id
	s.set_url_field("http://example")     # urlField -> url_field

	var r: AcronymsCapnp.HTTPServer.Reader = AcronymsCapnp.read_http_server(s.to_bytes())
	assert_true(r.get_parse_http_request(), "acronym-in-middle field")
	assert_eq(r.get_server_id(), 42, "trailing-acronym field")
	assert_eq(r.get_url_field(), "http://example", "leading-acronym-word field")


func test_acronym_union_enum_name() -> void:
	# responseKind union -> enum ResponseKind (via _pascal of response_kind).
	var s: AcronymsCapnp.HTTPServer.Builder = AcronymsCapnp.new_http_server()
	s.set_response_kind_err_status(7)

	var r: AcronymsCapnp.HTTPServer.Reader = AcronymsCapnp.read_http_server(s.to_bytes())
	assert_eq(r.response_kind_which(), AcronymsCapnp.HTTPServer.ResponseKind.ERR_STATUS, "union discriminant")
	assert_true(r.is_response_kind_err_status(), "is_err_status")
	assert_eq(r.get_response_kind_err_status(), 7, "err value")
