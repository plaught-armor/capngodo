@0xc1a2b3c4d5e6f788;

enum Color { red @0; green @1; blue @2; }
enum Math { pi @0; tau @1; e @2; }

struct Node {
  value      @0 :Int32;
  class      @1 :Text;
  color      @2 :Color;
  instanceId @3 :Int32;
  kind       @4 :Math;
}

struct Holder {
  child @0 :Node;
}
