@0xd00dfeed12345601;

# Const declarations (CG9): schema-level consts emit class-scoped GDScript
# consts (int at the wire for enums; Data/struct/list consts are out of scope).

enum Shade { red @0; green @1; blue @2; }

const maxItems  :Int32   = 100;
const greeting  :Text    = "hello";
const ratio     :Float32 = 1.5;
const enabled   :Bool    = true;
const bigNum    :UInt64  = 9000000000;
const favourite :Shade   = green;
const pi        :Float64 = 3.141592653589793;   # precision round-trip
const infinity  :Float64 = inf;                  # str() would emit invalid "inf"
const notNumber :Float64 = nan;
const tricky    :Text    = "q\" b\\ t\t";        # escape round-trip
