@0xb7e1f2a3c4d5e6f7;

enum Kind { alpha @0; beta @1; }

struct Child {
  note @0 :Text;
}

struct Root {
  id     @0 :UInt32;
  name   @1 :Text;
  tags   @2 :List(Text);
  scores @3 :List(Int32);
  child  @4 :Child;
  kind   @5 :Kind;
  status :union {
    active @6 :Void;
    banned @7 :Text;
  }
}
