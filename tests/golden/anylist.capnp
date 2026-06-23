@0xd9e1f0a2b3c4d5e6;

# CG10b: List(AnyPointer) — capnp admits this only via List(AnyList); a literal
# List(AnyPointer) (or List(T) of a generic parameter) is rejected by the
# compiler. The element type is erased, so the generated reader returns the raw
# outer CapnReader.ListReader and the builder returns the raw
# CapnBuilder.ListBuilder. The caller materializes each element with the
# per-element accessors: get_list / get_struct_ptr / get_text / get_data /
# get_cap_index on the reader; init_list_at / init_composite_list_at /
# init_struct_ptr / set_text / set_data on the builder.

struct Bag {
  rows @0 :List(AnyList);   # erased pointer-list elements
}
