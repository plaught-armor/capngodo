#!/usr/bin/env sh
# run_interop.sh - bidirectional interop test against the reference capnp.
#
# Direction A (capnp reads us):  capngodo builds a message -> `capnp decode`
#                                must parse it and show the expected fields.
# Direction B (we read capnp):   `capnp encode` a known message -> capngodo
#                                reads it and asserts the fields (exit code).
#
# This is the conformance method recommended by capnproto.org/otherlang.html.
#
# Config (env vars):
#   CAPNGODO_GODOT  path to a Godot 4.6+ binary
#   CAPNP           path to the capnp binary (default: `capnp` on PATH)

set -eu

GODOT="${CAPNGODO_GODOT:?set CAPNGODO_GODOT to your Godot binary}"
CAPNP="${CAPNP:-capnp}"
command -v "$CAPNP" >/dev/null 2>&1 || [ -x "$CAPNP" ] || { echo "capnp not found: $CAPNP" >&2; exit 1; }

PROJECT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCHEMA="$PROJECT/tests/interop/interop.capnp"
DRIVER="res://tests/interop/interop_build.gd"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/capngodo-interop.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

"$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true

echo "== Direction A: capngodo builds -> capnp decodes =="
"$GODOT" --headless --quiet --path "$PROJECT" --script "$DRIVER" -- build "$TMP/ours.bin" 1>&2
"$CAPNP" decode "$SCHEMA" Root < "$TMP/ours.bin" > "$TMP/decoded.txt"
echo "capnp decoded our output:"; sed 's/^/    /' "$TMP/decoded.txt"
for pat in 'id = 123456' 'name = "Alice"' '"alpha"' '"charlie"' 'scores = \[10, -20, 30\]' 'note = "child note"' 'kind = beta' 'banned = "spam"'; do
	grep -q "$pat" "$TMP/decoded.txt" || { echo "FAIL: capnp decode missing /$pat/" >&2; exit 1; }
done
echo "  A: ok"

echo "== Direction B: capnp encodes -> capngodo reads =="
"$CAPNP" encode "$SCHEMA" Root < "$PROJECT/tests/interop/sample.txt" > "$TMP/capnp.bin"
"$GODOT" --headless --quiet --path "$PROJECT" --script "$DRIVER" -- verify "$TMP/capnp.bin"
echo "  B: ok"

echo "INTEROP PASSED"
