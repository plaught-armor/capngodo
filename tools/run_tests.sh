#!/usr/bin/env sh
# run_tests.sh — import the project and run the GUT test suite headless.
#
# Config (env vars):
#   CAPNGODO_GODOT  path to a Godot 4.6+ binary (or pass as $1)
#
# Exit code is non-zero if any test fails (GUT's -gexit propagates it).

set -eu

GODOT="${CAPNGODO_GODOT:-${1:-}}"
[ -n "$GODOT" ] || { echo "set CAPNGODO_GODOT (or pass the godot binary as arg 1)" >&2; exit 1; }
command -v "$GODOT" >/dev/null 2>&1 || [ -x "$GODOT" ] || { echo "godot not found: $GODOT" >&2; exit 1; }

PROJECT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Import first so freshly-added class_name globals register before the test
# collector parses (stale global_script_class_cache -> "Could not find type").
"$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true

exec "$GODOT" --headless --path "$PROJECT" \
	-s addons/gut/gut_cmdln.gd \
	-gdir=res://tests -ginclude_subdirs -gexit
