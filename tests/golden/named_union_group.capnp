@0xba7c3c552bc927cc;

# CG11 — a *group* arm inside a *named* (non-anonymous) union. Distinct from the
# struct-level union group arm (CG3/CG4), which already worked. Here `body` is a
# named union field whose `chat` / `move` arms are groups, and `quit` is a void
# slot arm. The group arms flatten to get_/set_body_<arm>_<field>(); each leaf
# setter writes `body`'s discriminant so selecting any leaf selects the arm.
struct Command {
  id @0 :UInt32;
  body :union {
    chat :group {
      sender @1 :Text;
      text @2 :Text;
    }
    move :group {
      dx @3 :Int32;
      dy @4 :Int32;
    }
    quit @5 :Void;
  }
}
