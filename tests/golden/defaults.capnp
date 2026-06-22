@0xf1e2d3c4b5a69788;

enum Shade { red @0; green @1; blue @2; }

struct Defaults {
  i32f   @0 :Int32   = -42;
  u16f   @1 :UInt16  = 7;
  boolf  @2 :Bool    = true;
  f32f   @3 :Float32 = 1.5;
  f64f   @4 :Float64 = 2.5;
  textf  @5 :Text    = "hello";
  enumf  @6 :Shade   = green;
}
