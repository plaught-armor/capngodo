#!/usr/bin/env sh
# build_capnp.sh — build the `capnp` compiler from a Cap'n Proto source checkout.
#
# capngodo's codegen plugin (capnpc-gdscript) needs the `capnp` binary at
# GENERATE time only (it computes the struct field offsets that the spec leaves
# to the compiler). End users of generated code never need capnp.
#
# This builds capnp with cmake + ninja, no sudo. Distro packages also work, e.g.
#   Arch:   sudo pacman -S capnproto
#   Debian: sudo apt install capnproto
#   macOS:  brew install capnp
# Use those instead if you prefer; this script is for building from source.
#
# Config (env vars):
#   CAPNPROTO_SRC   path to the capnproto repo root OR its c++/ dir
#                   (default: ../capnproto relative to this repo, then common spots)
#   CAPNP_BUILD_DIR build output dir (default: ${TMPDIR:-/tmp}/capnp-build)
#
# On success it prints the path to the built `capnp` binary on the last line.

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BUILD_DIR="${CAPNP_BUILD_DIR:-${TMPDIR:-/tmp}/capnp-build}"

# Resolve the c++/ source dir (where the buildable CMake project lives).
find_src() {
	if [ -n "${CAPNPROTO_SRC:-}" ]; then
		if [ -f "$CAPNPROTO_SRC/c++/CMakeLists.txt" ]; then echo "$CAPNPROTO_SRC/c++"; return; fi
		if [ -f "$CAPNPROTO_SRC/CMakeLists.txt" ]; then echo "$CAPNPROTO_SRC"; return; fi
		echo "CAPNPROTO_SRC=$CAPNPROTO_SRC has no CMakeLists.txt (c++/ or root)" >&2
		exit 1
	fi
	# Auto-discover a sibling checkout, resolved against the script's own dir
	# (tools/ -> repo -> Repos/) so it works regardless of $PWD.
	for d in "$SCRIPT_DIR/../../capnproto/c++" "$SCRIPT_DIR/../capnproto/c++"; do
		[ -f "$d/CMakeLists.txt" ] && { echo "$d"; return; }
	done
	echo "Cannot find a capnproto checkout. Set CAPNPROTO_SRC=/path/to/capnproto" >&2
	exit 1
}

for tool in cmake ninja; do
	command -v "$tool" >/dev/null 2>&1 || { echo "missing build tool: $tool" >&2; exit 1; }
done

SRC="$(find_src)"
SRC="$(CDPATH= cd -- "$SRC" && pwd)"  # absolute, to compare against the cache
echo "Building capnp from: $SRC" >&2
echo "Build dir:           $BUILD_DIR" >&2

# Drop a stale build cache configured against a different source tree (cmake
# refuses to reconfigure across source dirs and would otherwise fail or, worse,
# build the wrong tree).
CACHE="$BUILD_DIR/CMakeCache.txt"
if [ -f "$CACHE" ] && ! grep -q "^CMAKE_HOME_DIRECTORY:INTERNAL=$SRC\$" "$CACHE"; then
	echo "Build dir was configured for a different source; clearing it." >&2
	rm -rf "$BUILD_DIR"
fi

cmake -S "$SRC" -B "$BUILD_DIR" -GNinja -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release >&2
ninja -C "$BUILD_DIR" capnp_tool >&2

CAPNP="$BUILD_DIR/src/capnp/capnp"
[ -x "$CAPNP" ] || { echo "build finished but $CAPNP not found" >&2; exit 1; }
"$CAPNP" --version >&2
echo "$CAPNP"
