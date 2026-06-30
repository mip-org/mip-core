#!/bin/bash
# Build a standalone WebAssembly module exposing JIGSAW's in-memory C library
# (lib_jigsaw) plus our flat shim, for the numbl_wasm architecture. Produces
# jigsaw.wasm in this directory.
#
# JIGSAW's MATLAB interface normally drives standalone executables over files
# via system(); numbl supports neither system() nor filesystem access from a
# builtin, so the numbl port instead calls the library API directly. The very
# same jigsaw.cpp the native shared library is built from is compiled here with
# -D__lib_jigsaw (no main(), exports the extern "C" jigsaw/tripod/marche), and
# linked against jigsaw_shim.cpp which marshals jigsaw_msh_t/jigsaw_jig_t to a
# flat ABI the jigsaw_kernel.numbl.js builtin calls over linear memory.
#
# netcdf is left disabled (USE_NETCDF undefined), so no nc_* symbols are
# referenced and the module links cleanly without a netcdf dependency.
#
# Prerequisites: emcc / em++ (Emscripten SDK) on PATH.
#
# Usage:
#   JIGSAW_SRC=/path/to/jigsaw-matlab bash build_wasm.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# JIGSAW_SRC is the jigsaw-matlab repo root (where external/jigsaw lives).
JIGSAW_SRC="${JIGSAW_SRC:-$(cd "$SCRIPT_DIR/.." && pwd)}"

JIG="$JIGSAW_SRC/external/jigsaw"
SRC="$JIG/src"
INC="$JIG/inc"

if ! command -v em++ &> /dev/null; then
  echo "Error: em++ (Emscripten) not found on PATH." >&2
  echo "Install: https://emscripten.org/docs/getting_started/downloads.html" >&2
  exit 1
fi
if [ ! -f "$SRC/jigsaw.cpp" ] || [ ! -f "$INC/lib_jigsaw.h" ]; then
  echo "Error: JIGSAW backend source not found under $JIG" >&2
  exit 1
fi

echo "JIGSAW source:   $JIG"
echo "Build directory: $SCRIPT_DIR"

# -D__lib_jigsaw: build the library form of jigsaw.cpp (no main(); exports the
#   extern "C" jigsaw/tripod/marche entry points).
# -I$SRC: jigsaw.cpp includes "libcpp/...", "jig_load.hpp", "../inc/lib_jigsaw.h"
#   relative to src/. -I$INC: jigsaw_shim.cpp includes "lib_jigsaw.h".
# -fwasm-exceptions: JIGSAW's library entry wraps the computation in try/catch
#   to turn internal errors into JIGSAW_* return codes; without real exception
#   support an invalid-options throw would trap instead of returning a code.
CXXFLAGS=(
  -std=c++17
  -O2
  -msimd128
  -fwasm-exceptions
  -D__lib_jigsaw
  -DNDEBUG
  -I"$SRC"
  -I"$INC"
  -Wno-unused-variable
  -Wno-unused-but-set-variable
)

# STANDALONE_WASM: numbl instantiates a bare WebAssembly.Instance (no emscripten
#   JS glue), so the module must be self-contained. --no-entry: it's a library,
#   not a program. Generous stack/heap: JIGSAW's refinement allocates sizeable
#   working sets; the 64 KB emscripten default stack is too small.
LDFLAGS=(
  -fwasm-exceptions
  -s STANDALONE_WASM
  --no-entry
  -s STACK_SIZE=8388608
  -s TOTAL_MEMORY=134217728
  -s ALLOW_MEMORY_GROWTH=1
)

echo "=== Compiling + linking jigsaw.wasm ==="
em++ "${CXXFLAGS[@]}" \
  "$SRC/jigsaw.cpp" \
  "$SCRIPT_DIR/jigsaw_shim.cpp" \
  "${LDFLAGS[@]}" \
  -o "$SCRIPT_DIR/jigsaw.wasm"

echo "=== Built jigsaw.wasm ($(wc -c < "$SCRIPT_DIR/jigsaw.wasm") bytes) ==="
