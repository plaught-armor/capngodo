@0xdf0532b88ce6888f;

# CG1d: a generic bound to an interface (capability) type. Interfaces are pointer
# types, so capnp accepts them as generic args. Box(Handle) monomorphizes to
# Box_Handle whose value is a capability — get_value() -> int (cap-table index,
# -1 absent), no value setter (serialization-only, no RPC). Confirms the CG1b/CG1c
# param-substitution path drives the INTERFACE accessor arms.

interface Handle {}

struct Box(T) {
  value @0 :T;
}

struct Use {
  h @0 :Box(Handle);   # -> Box_Handle { get_value() -> int }
}
