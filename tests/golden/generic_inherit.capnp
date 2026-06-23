@0xc7a1b2c3d4e5f608;

# CG1d: inherit scopes. A struct nested inside a generic that uses the generic's
# type parameter (`Outer(T) { struct Inner { value @0 :T } }`) inherits T via an
# INHERIT brand scope. Monomorphizing Outer(Text) emits a per-instantiation inner
# mono Outer_Inner_Text whose `value` resolves to String, and Outer_Text.inner
# resolves to it (not the erased Outer_Inner floor). The inner mono reuses the
# enclosing subst — Inner.value's param scopes to Outer, so the existing
# _param_override types it when _emit_struct re-emits Inner with that subst.

struct Outer(T) {
  struct Inner {
    value @0 :T;
    label @1 :Text;
  }
  inner @0 :Inner;
}

struct Use {
  o @0 :Outer(Text);
}
