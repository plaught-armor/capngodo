class_name CapnError
extends RefCounted
## POD error record for decode/encode failures.
##
## Cap'n Proto readers validate lazily (bounds, traversal limit, pointer depth)
## and must fail loud rather than return corrupt data. Systems return a typed
## CapnError (or push it onto a context) instead of silently swallowing — NASA
## rule 6. `code` is a Code enum; `message` is human-facing.

enum Code {
	NONE,
	OUT_OF_BOUNDS,
	TRAVERSAL_LIMIT,
	DEPTH_LIMIT,
	BAD_POINTER,
	BAD_FRAMING,
	BAD_PACKING,
	UNSUPPORTED,
}

var code: Code = Code.NONE
var message: String = ""


func _init(p_code: Code = Code.NONE, p_message: String = "") -> void:
	code = p_code
	message = p_message


func is_error() -> bool:
	return code != Code.NONE
