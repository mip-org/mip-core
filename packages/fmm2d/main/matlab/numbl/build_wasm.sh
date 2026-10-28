#!/bin/bash
# Build a numbl-compatible WebAssembly module exposing the fmm2d mexFunction
# (from upstream matlab/fmm2d.c) via a small mex shim. Produces fmm2d.wasm in
# this directory.
#
# Unlike the magland/fmm2d_c_translation fork (which ships a hand-written C
# port in c_translation/src), this build transpiles the upstream Fortran to C
# with fort2c at build time, then compiles the generated C with emcc. The two
# are equivalent: fort2c reproduces the same drop-in C, and the file list in
# files.sh matches the fork's hand-written set 1:1.
#
# Fortran-to-WASM is not practical with current toolchains, which is why the
# Fortran is transpiled to C first. Each generated .c is compiled with
# -DFMM2D_DROP_IN so its symbols are exported under the bare Fortran ABI names
# (rfmm2d_ndiv_, hndiv2d_, cfmm2d_, ...) and link against matlab/fmm2d.c.
#
# Prerequisites: emcc (Emscripten SDK) and fort2c on PATH.
#
# Usage:
#   FMM2D_SRC=/path/to/fmm2d bash build_wasm.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FMM2D_SRC="${FMM2D_SRC:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
BUILD_DIR="$SCRIPT_DIR/build_wasm"
GEN_DIR="$BUILD_DIR/generated"

if ! command -v emcc &> /dev/null; then
  echo "Error: emcc (Emscripten) not found on PATH." >&2
  echo "Install: https://emscripten.org/docs/getting_started/downloads.html" >&2
  exit 1
fi
if ! command -v fort2c &> /dev/null; then
  echo "Error: fort2c not found on PATH." >&2
  echo "Install: pip install git+https://github.com/magland/fort2c" >&2
  exit 1
fi
if [ ! -d "$FMM2D_SRC/src" ] || [ ! -f "$FMM2D_SRC/matlab/fmm2d.c" ]; then
  echo "Error: upstream fmm2d source not found at $FMM2D_SRC" >&2
  exit 1
fi

echo "fmm2d source:    $FMM2D_SRC"
echo "Build directory: $BUILD_DIR"

mkdir -p "$GEN_DIR"
# The generated headers #include "fmm2d_c.h" (the hand-written runtime shim,
# carried alongside this script, not emitted by fort2c). Put it on the include
# path next to the generated sources.
cp "$SCRIPT_DIR/fmm2d_c.h" "$GEN_DIR/fmm2d_c.h"

# Step 0: transpile every Fortran source listed in files.sh to C with fort2c.
# fort2c -o writes <name>.c and <name>.h; fort2c's defaults already target
# fmm2d (runtime header fmm2d_c.h, guard prefix FMM2D_).
source "$SCRIPT_DIR/files.sh"
echo "=== Transpiling $(printf '%s' "${#FILES[@]}") Fortran files with fort2c ==="
for row in "${FILES[@]}"; do
  IFS='|' read -r name src only <<< "$row"
  onlyarg=(); [ -n "$only" ] && onlyarg=(--only "$only")
  echo "  F2C $src -> $name.c"
  fort2c "$FMM2D_SRC/$src" --basename "$name" "${onlyarg[@]}" -o "$GEN_DIR" >/dev/null
done

SHIM_INC="-I$SCRIPT_DIR/mex_shim"
# c_translation provides Fortran routines as `void` functions, but fmm2d.c
# declares them with MWF77_RETURN which defaults to `int`. Override to `void`
# so wasm-ld accepts the matching signatures.
DEFS="-DMX_HAS_INTERLEAVED_COMPLEX=1 -DMWF77_UNDERSCORE1 -DMWF77_RETURN=void"

# Step 1: compile each generated .c with -DFMM2D_DROP_IN so it exports the bare
# Fortran ABI symbol name (e.g. rfmm2d_ndiv_, not rfmm2d_ndiv_c_).
#
# -fno-strict-aliasing: the rmlexp workspace is declared `double *` in Fortran
#   but holds complex expansion data accessed via `(fcomplex *)` casts (~136
#   sites). Without this, clang's strict-aliasing analysis at -O3 may reorder
#   reads/writes assuming the double*/fcomplex* views don't overlap, corrupting
#   expansion data.
# -fwrapv: a few int32 `fint` index/size computations could overflow on large
#   workloads; -fwrapv defines signed overflow as two's-complement wrap.
CFLAGS="-O3 -std=c99 -DFMM2D_DROP_IN -msimd128 -fno-strict-aliasing -fwrapv -Wno-unused-parameter -Wno-unused-variable"
INCLUDES="-I$GEN_DIR"

OBJS=()
for src in "$GEN_DIR"/*.c; do
  base=$(basename "$src" .c)
  obj="$BUILD_DIR/${base}.o"
  echo "  CC  $base.c"
  emcc $CFLAGS $INCLUDES -c "$src" -o "$obj"
  OBJS+=("$obj")
done

# Step 2: compile the upstream MEX source against our mex shim.
echo "  CC  fmm2d.c"
FMM2D_OBJ="$BUILD_DIR/fmm2d.o"
emcc -O3 -std=c99 -msimd128 \
     -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-variable \
     $SHIM_INC $DEFS \
     -c "$FMM2D_SRC/matlab/fmm2d.c" -o "$FMM2D_OBJ"
OBJS+=("$FMM2D_OBJ")

# Step 3: compile the shim implementation (C++). SUPPORT_LONGJMP=wasm is also a
# compile-time flag — it must be passed here so the setjmp call inside
# mex_dispatch is lowered to wasm-native sjlj instead of the emscripten JS shim
# (which standalone wasm doesn't have).
echo "  CXX mex_shim.cpp"
SHIM_OBJ="$BUILD_DIR/mex_shim.o"
em++ -O3 -msimd128 \
     -Wno-unused-parameter \
     -s SUPPORT_LONGJMP=wasm \
     $SHIM_INC $DEFS \
     -c "$SCRIPT_DIR/mex_shim.cpp" -o "$SHIM_OBJ"
OBJS+=("$SHIM_OBJ")

# Step 4: link into a standalone WASM module. STANDALONE_WASM produces a module
# any wasm runtime can instantiate (numbl runs it under its own loader, not
# emscripten's JS shim).
#
# STACK_SIZE: the Helmholtz path nests deep enough (hfmm2dmain -> term/eval
# routines, several with multi-kilobyte fcomplex stack locals) to overflow a
# small wasm shadow stack and trap as OOB; the Laplace-only path (cfmm2d) does
# not. 32 MB clears the whole fmm2d suite (cauchy/helmholtz/laplace). emscripten's
# default is 64 KB; native builds get the OS default (~8 MB) and never hit this.
echo "=== Linking fmm2d.wasm ==="
em++ "${OBJS[@]}" \
  -O3 \
  -msimd128 \
  -s STANDALONE_WASM \
  -s SUPPORT_LONGJMP=wasm \
  -s STACK_SIZE=33554432 \
  --no-entry \
  -s TOTAL_MEMORY=67108864 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -o "$SCRIPT_DIR/fmm2d.wasm"

echo "=== Built fmm2d.wasm ($(wc -c < "$SCRIPT_DIR/fmm2d.wasm") bytes) ==="
