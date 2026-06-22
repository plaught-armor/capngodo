@0xc0117a9e22220002;

# A field of an imported type (Common.Point) must resolve to the other file's
# generated umbrella class (CommonCapnp.Point) — CG7.

using Common = import "common.capnp";

struct Line {
  start @0 :Common.Point;
  end   @1 :Common.Point;
  label @2 :Text;
}
