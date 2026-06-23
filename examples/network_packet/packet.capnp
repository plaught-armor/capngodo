@0xb1a2c3d4e5f60718;

# A multiplayer wire packet: a fixed header plus a tagged body (struct-level
# union). One Packet message carries exactly one of chat / move / spawn — the
# union discriminant says which, so the receiver dispatches on `body_which()`
# (or the `is_body_*()` selectors). Each arm is a single slot (Text or a struct)
# so the generated builder gets `set_body_*` setters.

struct Vec2 {
  x @0 :Float32;
  y @1 :Float32;
}

struct MoveBody {
  pos @0 :Vec2;
  vel @1 :Vec2;
}

struct SpawnBody {
  entityId @0 :UInt32;
  pos      @1 :Vec2;
}

struct Packet {
  seq      @0 :UInt32;   # per-sender sequence number
  senderId @1 :UInt32;   # which client sent this

  body :union {
    chat  @2 :Text;
    move  @3 :MoveBody;
    spawn @4 :SpawnBody;
  }
}
