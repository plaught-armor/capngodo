@0xe4f1a2b3c6d70899;

# Named (non-union) groups (CG3): a group with no discriminant is a sub-
# namespace whose fields share the parent's layout. Codegen flattens them to
# get_<group>_<field>() / set_<group>_<field>(). Covers scalar groups, a nested
# group, a pointer field inside a group, and a union nested inside a group.

struct Entity {
  name @0 :Text;

  transform :group {          # scalar named group
    posX @1 :Float32;
    posY @2 :Float32;
  }

  physics :group {            # nested named group + a pointer field
    mass @3 :Float32;
    velocity :group {
      dx @4 :Float32;
      dy @5 :Float32;
    }
    label @6 :Text;
  }

  state :group {              # named group containing a union
    hp @7 :Int32;
    mode :union {
      idle @8 :Void;
      moving @9 :Float32;
    }
  }
}

struct Outer {
  # Struct-level (anonymous) union whose arm is a named group: the reader emits
  # is_box() + flattened get_box_w/h(); the box setters omit the outer
  # discriminant (documented gap, parity with CG4 nested-union).
  union {
    empty @0 :Void;
    box :group {
      w @1 :Int32;
      h @2 :Int32;
    }
  }
}
