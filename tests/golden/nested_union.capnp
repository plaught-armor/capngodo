@0xaa11bb22cc33dd44;

# Nested union in a struct-level union (CG4): a union-group that is itself an
# arm of the struct-level union. Selecting an inner arm must also write the
# OUTER discriminant. Covers a non-union field, a void outer arm, the
# union-group outer arm, and a plain-slot outer arm alongside it.

struct Msg {
  id @0 :UInt32;            # plain field outside the union

  union {                   # struct-level union
    none @1 :Void;
    payload :union {        # union-group arm of the struct-level union
      text @2 :Text;
      num @3 :Int32;
      reset @5 :Void;       # void inner arm (double-discriminant, no value)
    }
    count @4 :UInt16;       # plain-slot arm alongside the union-group arm
  }
}
