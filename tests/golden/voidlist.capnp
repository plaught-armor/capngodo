@0xb00b5717b00b5701;

# List(Void) (CG8): a void list carries only a length (zero-width elements);
# the writer must use ElemSize.VOID, not the pointer fallback.

struct Pings {
  voids @0 :List(Void);
  label @1 :Text;
}
