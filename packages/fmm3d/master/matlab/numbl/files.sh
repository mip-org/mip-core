# The upstream Fortran files fort2c transpiles for the WASM build, sourced by
# build_wasm.sh. Each row is
#   name | source (relative to the fmm3d repo root) | optional routine subset
#
# This is the full non-FAST_KER static-library object set (makefile OBJS) minus
# src/Common/prini.f (diagnostic I/O only; every prin* call is stripped and no
# other routine references it). Together these provide every Fortran-ABI symbol
# the matlab/fmm3d.c and matlab/fmm3d_legacy.c gateways reach. Keep in sync with
# the makefile's COMOBJS/HOBJS/LOBJS/STOBJS/EMOBJS (paths relative to FMM3D_SRC).
FILES=(
  "besseljs3d|src/Common/besseljs3d.f|"
  "cdjseval3d|src/Common/cdjseval3d.f|"
  "dfft|src/Common/dfft.f|"
  "fmmcommon|src/Common/fmmcommon.f|"
  "legeexps|src/Common/legeexps.f|"
  "rotgen|src/Common/rotgen.f|"
  "rotproj|src/Common/rotproj.f|"
  "rotviarecur|src/Common/rotviarecur.f|"
  "tree_routs3d|src/Common/tree_routs3d.f|"
  "pts_tree3d|src/Common/pts_tree3d.f|"
  "yrecursion|src/Common/yrecursion.f|"
  "cumsum|src/Common/cumsum.f|"
  "h3dcommon|src/Helmholtz/h3dcommon.f|"
  "h3dterms|src/Helmholtz/h3dterms.f|"
  "h3dtrans|src/Helmholtz/h3dtrans.f|"
  "helmrouts3d|src/Helmholtz/helmrouts3d.f|"
  "hfmm3d|src/Helmholtz/hfmm3d.f|"
  "hfmm3dwrap|src/Helmholtz/hfmm3dwrap.f|"
  "hfmm3dwrap_legacy|src/Helmholtz/hfmm3dwrap_legacy.f|"
  "hfmm3dwrap_vec|src/Helmholtz/hfmm3dwrap_vec.f|"
  "hpwrouts|src/Helmholtz/hpwrouts.f|"
  "hwts3e|src/Helmholtz/hwts3e.f|"
  "hnumphys|src/Helmholtz/hnumphys.f|"
  "hnumfour|src/Helmholtz/hnumfour.f|"
  "projections|src/Helmholtz/projections.f|"
  "hfmm3d_mps|src/Helmholtz/hfmm3d_mps.f90|"
  "hfmm3d_memest|src/Helmholtz/hfmm3d_memest.f|"
  "hfmm3d_ndiv|src/Helmholtz/hfmm3d_ndiv.f|"
  "helmkernels|src/Helmholtz/helmkernels.f|"
  "hndiv|src/Helmholtz/hndiv.f|"
  "lwtsexp_sep1|src/Laplace/lwtsexp_sep1.f|"
  "l3dterms|src/Laplace/l3dterms.f|"
  "l3dtrans|src/Laplace/l3dtrans.f|"
  "laprouts3d|src/Laplace/laprouts3d.f|"
  "lfmm3d|src/Laplace/lfmm3d.f|"
  "lfmm3dwrap|src/Laplace/lfmm3dwrap.f|"
  "lfmm3dwrap_legacy|src/Laplace/lfmm3dwrap_legacy.f|"
  "lfmm3dwrap_vec|src/Laplace/lfmm3dwrap_vec.f|"
  "lwtsexp_sep2|src/Laplace/lwtsexp_sep2.f|"
  "lpwrouts|src/Laplace/lpwrouts.f|"
  "lfmm3d_ndiv|src/Laplace/lfmm3d_ndiv.f|"
  "lapkernels|src/Laplace/lapkernels.f|"
  "lndiv|src/Laplace/lndiv.f|"
  "stfmm3d|src/Stokes/stfmm3d.f|"
  "stokkernels|src/Stokes/stokkernels.f|"
  "emfmm3d|src/Maxwell/emfmm3d.f90|"
)

# Large machine-generated table files compiled at -O0 (pure data assignments;
# optimization gives nothing but costs compile time/memory). Matched by name.
BIG_TABLE_FILES="hwts3e hnumphys hnumfour"
