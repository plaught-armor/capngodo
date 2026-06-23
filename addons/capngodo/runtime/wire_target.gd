class_name CapnTarget
extends RefCounted
## Resolved pointer target — where an object lives and its shape, after
## far-pointer chasing (CapnMessage.follow). A leaf POD (only depends on
## CapnPointer enums) so the reader files can share it without forming an
## inner-class dependency cycle through CapnMessage.
##
## is_null means "follow returned nothing": a null pointer, an out-of-bounds
## target, or a limit hit (check CapnMessage.had_error to tell them apart).

var is_null: bool = true
var kind: CapnPointer.Kind = CapnPointer.Kind.STRUCT
var seg_id: int = 0
var content_word: int = 0 # struct: data start; list: first elem (or tag for composite)

# struct
var data_words: int = 0
var ptr_words: int = 0

# list
var elem_size_code: CapnPointer.ElemSize = CapnPointer.ElemSize.VOID
var elem_count: int = 0 # element count (C<>7) or word count excl tag (C=7)

# capability
var is_cap: bool = false
var cap_index: int = 0
