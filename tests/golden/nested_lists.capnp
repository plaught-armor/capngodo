@0xaac3319437c7e542;

# CG10: nested + pointer-element lists. A List(List(T)) outer is a pointer list
# whose elements point to inner lists; the generated reader exposes each element
# as a lazy CapnReader.ListReader, and the builder hands back the outer
# ListBuilder so the caller fills inner lists via init_list_at /
# init_composite_list_at. List(interface) decodes to cap-table indices
# (serialization-only, no setter).

struct Cell {
  v @0 :Int32;
}

interface Empty {}

struct Nested {
  matrix @0 :List(List(Int32));   # nested primitive list
  rows   @1 :List(List(Text));    # nested pointer (text) inner list
  cells  @2 :List(List(Cell));    # nested struct (composite) inner list
  handles @3 :List(Empty);        # capability list -> cap indices
}
