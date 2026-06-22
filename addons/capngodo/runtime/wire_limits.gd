class_name CapnLimits extends RefCounted

## Security limits applied while traversing an untrusted message.
##
## encoding.md §"Security" (:392-427): a reader MUST bound total bytes visited
## (traversal limit, defends list-amplification) and pointer recursion depth.
## Defaults mirror the C++ reference: 64 MiB traversal, depth 64.

const WORD_BYTES: int = 8

# 64 MiB expressed in words (8 MiW). Matches capnp ReaderOptions default.
var traversal_word_limit: int = 8 * 1024 * 1024
var pointer_depth_limit: int = 64


func _init(p_traversal_word_limit: int = 8 * 1024 * 1024, p_depth: int = 64) -> void:
	traversal_word_limit = p_traversal_word_limit
	pointer_depth_limit = p_depth
