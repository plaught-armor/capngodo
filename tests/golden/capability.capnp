@0xca9ab1117ab1e001;

# Interface (capability) field types (CG6): no RPC layer, so a capability field
# decodes to its cap-table index (-1 when absent) and has no setter.

interface Greeter {}

struct Session {
  id      @0 :UInt32;
  greeter @1 :Greeter;   # capability field -> get_greeter() : int (cap index)
}

struct Event {
  # capability as a struct-level union arm: selectable (writes which()), but the
  # cap itself stays unset (no RPC).
  union {
    none    @0 :Void;
    handler @1 :Greeter;
    count   @2 :UInt16;
  }
}
