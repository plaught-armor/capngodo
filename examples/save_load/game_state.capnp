@0xd4c3b2a1f0e9d8c7;

struct Item {
  name  @0 :Text;
  count @1 :UInt32;
}

struct GameState {
  playerName @0 :Text;
  level      @1 :UInt16;
  hp         @2 :Int32;
  posX       @3 :Float32;
  posY       @4 :Float32;
  inventory  @5 :List(Item);
}
