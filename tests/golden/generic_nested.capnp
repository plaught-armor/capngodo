@0xaa6ca706ff04ebf7;

# CG1c: nested-generic monomorphization. A generic instantiated with another
# generic — Box(Box(Text)) — emits a typed outer (Box_Box_Text) whose value
# resolves to the typed inner (Box_Text), itself with get_value() -> String. The
# collector recurses into brand bindings so the inner instantiation is registered
# and named distinctly (Box_Box_Text vs Box_Box_Cell).

struct Cell {
  v @0 :Int32;
}

struct Box(T) {
  value @0 :T;
}

struct Holder {
  bb  @0 :Box(Box(Text));   # -> Box_Box_Text { value -> Box_Text { value -> String } }
  bbc @1 :Box(Box(Cell));   # -> Box_Box_Cell { value -> Box_Cell { value -> Cell } }
}
