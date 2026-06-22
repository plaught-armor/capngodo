@0xc0ffee1234567801;

# Acronym handling (CQ3): _snake must split at the end of a capital run that
# starts a new word, so "parseHTTPRequest" -> parse_http_request (not
# parse_httprequest). Type names keep their original case.

struct HTTPServer {
  parseHTTPRequest @0 :Bool;     # acronym in the middle
  serverID         @1 :Int32;    # trailing acronym
  urlField         @2 :Text;     # leading lowercase acronym word
  responseKind :union {          # _pascal -> enum ResponseKind
    okStatus  @3 :Void;
    errStatus @4 :Int32;
  }
}
