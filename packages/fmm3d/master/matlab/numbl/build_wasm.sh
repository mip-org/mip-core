#!/bin/bash
# Build numbl-compatible WebAssembly modules for fmm3d's two mwrap gateways:
#   fmm3d.wasm         <- matlab/fmm3d.c        (modern lfmm3d/hfmm3d/stfmm3d/emfmm3d)
#   fmm3d_legacy.wasm  <- matlab/fmm3d_legacy.c (legacy lfmm3dpart/hfmm3dpart ...)
#
# Fortran-to-WASM is not practical directly, so the upstream Fortran is
# transpiled to C with fort2c at build time, then compiled with emcc. Each
# generated .c is compiled with -DFMM3D_DROP_IN so its symbols carry the bare
# Fortran ABI names (lfmm3d_, hfmm3d_, ...) the gateways link against. The two
# gateways share the same Fortran library objects and the same mex shim; only
# the gateway object differs per module.
#
# Prerequisites: emcc (Emscripten SDK) and fort2c on PATH.
#
# Usage:
#   FMM3D_SRC=/path/to/fmm3d bash build_wasm.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FMM3D_SRC="${FMM3D_SRC:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
BUILD_DIR="$SCRIPT_DIR/build_wasm"
GEN_DIR="$BUILD_DIR/generated"
NJOBS="${NJOBS:-$(nproc 2>/dev/null || echo 4)}"

if ! command -v emcc &> /dev/null; then
  echo "Error: emcc (Emscripten) not found on PATH." >&2
  exit 1
fi
if ! command -v fort2c &> /dev/null; then
  echo "Error: fort2c not found on PATH (pip install git+https://github.com/magland/fort2c)." >&2
  exit 1
fi
if [ ! -d "$FMM3D_SRC/src" ] || [ ! -f "$FMM3D_SRC/matlab/fmm3d.c" ]; then
  echo "Error: upstream fmm3d source not found at $FMM3D_SRC" >&2
  exit 1
fi

echo "fmm3d source:    $FMM3D_SRC"
echo "Build directory: $BUILD_DIR"
echo "Parallel jobs:   $NJOBS"

rm -rf "$BUILD_DIR"
mkdir -p "$GEN_DIR"
# The generated headers #include "fmm3d_c.h" (the hand-written runtime shim,
# carried alongside this script). Put it on the include path next to them.
cp "$SCRIPT_DIR/fmm3d_c.h" "$GEN_DIR/fmm3d_c.h"

# Step 0: transpile every Fortran source listed in files.sh to C with fort2c,
# in parallel. The three large machine-generated table files (hwts3e and its
# INCLUDEd weight files, hnumphys, hnumfour) dominate transpile time, so
# overlapping them with each other and the rest cuts the wall time to roughly
# the single slowest file. Each fort2c writes a distinct <name>.c/.h, so the
# parallel writes don't collide.
source "$SCRIPT_DIR/files.sh"
echo "=== Transpiling ${#FILES[@]} Fortran files with fort2c (-j$NJOBS) ==="
transpile_one() {
  IFS='|' read -r name src only <<< "$1"
  onlyarg=(); [ -n "$only" ] && onlyarg=(--only "$only")
  echo "  F2C $src -> $name.c"
  fort2c "$FMM3D_SRC/$src" --basename "$name" "${onlyarg[@]}" \
    --runtime-header fmm3d_c.h --guard-prefix FMM3D_ -o "$GEN_DIR" >/dev/null
}
export -f transpile_one
export FMM3D_SRC GEN_DIR
printf '%s\n' "${FILES[@]}" | xargs -P "$NJOBS" -I{} bash -c 'transpile_one "$@"' _ {}

SHIM_INC="-I$SCRIPT_DIR/mex_shim"
# The mwrap gateways declare the Fortran routines with MWF77_RETURN (default
# int); the transpiled drop-ins return void, so force void to match.
# Interleaved-complex + single-underscore mangling match the gfortran ABI.
DEFS="-DMX_HAS_INTERLEAVED_COMPLEX=1 -DMWF77_UNDERSCORE1 -DMWF77_RETURN=void"

# Step 1: compile each generated .c with -DFMM3D_DROP_IN (bare Fortran ABI
# names). -fno-strict-aliasing: expansion workspaces are declared double* in
# Fortran but accessed through fcomplex* casts; -fwrapv: a few int index/size
# computations rely on two's-complement wraparound. The large machine-generated
# table files (hwts3e/hnumphys/hnumfour: tens of thousands of straight-line
# assignments) are compiled at -O0 -- optimization buys nothing there but costs
# a lot of compile time and memory.
CFLAGS_COMMON="-std=c99 -DFMM3D_DROP_IN -msimd128 -fno-strict-aliasing -fwrapv -Wno-unused-parameter -Wno-unused-variable -Wno-parentheses"
INCLUDES="-I$GEN_DIR"

echo "=== Compiling generated C with emcc (-j$NJOBS) ==="
compile_one() {
  src="$1"; base=$(basename "$src" .c); opt="-O2"
  for big in $BIG_TABLE_FILES; do [ "$base" = "$big" ] && opt="-O0"; done
  emcc $opt $CFLAGS_COMMON $INCLUDES -c "$src" -o "$BUILD_DIR/${base}.o"
}
export -f compile_one
export CFLAGS_COMMON INCLUDES BUILD_DIR BIG_TABLE_FILES
printf '%s\n' "$GEN_DIR"/*.c | xargs -P "$NJOBS" -I{} bash -c 'compile_one "$@"' _ {}
LIB_OBJS=("$BUILD_DIR"/*.o)

# Step 2: compile the shared mex shim (C++). SUPPORT_LONGJMP=wasm lowers the
# setjmp in mex_dispatch to wasm-native sjlj (standalone wasm has no JS shim).
echo "  CXX mex_shim.cpp"
em++ -O2 -msimd128 -Wno-unused-parameter -s SUPPORT_LONGJMP=wasm \
     $SHIM_INC $DEFS -c "$SCRIPT_DIR/mex_shim.cpp" -o "$BUILD_DIR/mex_shim.o"

# Steps 3-4: per gateway, compile matlab/<gw>.c against the shim and link a
# standalone module. STACK_SIZE is generous: the 3D translation/recursion paths
# nest deep with multi-kilobyte complex stack locals.
for gw in fmm3d fmm3d_legacy; do
  echo "  CC  matlab/$gw.c"
  emcc -O2 -std=c99 -msimd128 \
       -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-variable \
       $SHIM_INC $DEFS \
       -c "$FMM3D_SRC/matlab/$gw.c" -o "$BUILD_DIR/$gw.gw.o"
  echo "=== Linking $gw.wasm ==="
  em++ "${LIB_OBJS[@]}" "$BUILD_DIR/$gw.gw.o" "$BUILD_DIR/mex_shim.o" \
    -O2 -msimd128 \
    -s STANDALONE_WASM \
    -s SUPPORT_LONGJMP=wasm \
    -s STACK_SIZE=67108864 \
    --no-entry \
    -s TOTAL_MEMORY=134217728 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -o "$SCRIPT_DIR/$gw.wasm"
  echo "=== Built $gw.wasm ($(wc -c < "$SCRIPT_DIR/$gw.wasm") bytes) ==="
done
