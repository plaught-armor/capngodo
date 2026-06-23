@0xc0ffee1234567890;

# An app settings blob with schema-level field defaults. A message that leaves
# a field unset reads back its declared default — so a freshly-shipped config
# (all defaults) and a saved config (some fields overridden) use the same reader
# with no null-handling at the call site.

enum Quality {
  low    @0;
  medium @1;
  high   @2;
  ultra  @3;
}

struct Settings {
  masterVolume @0 :Float32 = 0.8;
  musicVolume  @1 :Float32 = 0.6;
  quality      @2 :Quality = high;
  fullscreen   @3 :Bool    = true;
  maxFps       @4 :UInt16  = 60;
  playerName   @5 :Text    = "Player";
}
