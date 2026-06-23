@0xe1d2c3b4a5968778;

# CG1d: a generic parameter slot nested inside a *group* of the generic body. The
# CG1b/CG1c path resolves only top-level param slots; a param inside a named group
# or a union group of the generic body emitted erased AnyPointer accessors. Now the
# bound type is threaded through the group emitters down to each leaf, so the mono
# resolves the nested param. Box(Text) -> get_holder_value() -> String (named
# group); Tagged(Text) -> set_body_item(value: String) on the union arm.

struct Box(T) {
  holder :group {       # named group with a param field + a normal field
    value @0 :T;
    label @1 :Text;
  }
}

struct Tagged(T) {
  body :union {         # union group with a param arm
    item @0 :T;
    count @1 :Int32;
  }
}

# A *generic-typed* slot nested inside a group (the dual of the above): the
# instantiation collector recurses into group fields, so Box(Text) here registers
# the Box_Text mono and the leaf resolves to it (not the erased floor).
struct Holder {
  inner :group {
    boxed @0 :Box(Text);
  }
}

struct Use {
  boxText @0 :Box(Text);
  taggedText @1 :Tagged(Text);
}
