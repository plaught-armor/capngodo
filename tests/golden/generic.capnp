@0xb7e3d9a1c4f60582;

# Generics (CG1a): on the wire a type parameter is a plain pointer, so a
# parameter-typed field gets type-erased accessors. An explicit AnyPointer
# field is the same shape.

struct Inner {
  n @0 :Int32;
}

struct Box(T) {
  value @0 :T;        # generic parameter -> erased pointer accessors
  label @1 :Text;     # a concrete field alongside, proving layout
}

struct Container {
  boxedText   @0 :Box(Text);          # parameter bound to Text (caller knows)
  boxedStruct @1 :Box(Inner);         # parameter bound to a struct
  boxedList   @2 :Box(List(Int32));   # parameter bound to a list
  raw         @3 :AnyPointer;         # explicit AnyPointer -> same erased accessors
  # struct-level union with an AnyPointer arm: the erased setters must write the
  # outer discriminant (covers the disc_line path in _emit_anyptr_setter).
  union {
    optPtr @4 :AnyPointer;
    optNum @5 :Int32;
  }
}
