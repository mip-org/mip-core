# The list of upstream Fortran files fort2c transpiles for the WASM build,
# sourced by build_wasm.sh. Each row is
#   name | source (relative to the fmm2d repo root) | optional routine subset
#
# These 36 files cover the full Laplace/Helmholtz/biharmonic/Stokes/modified-
# biharmonic call graph reachable from the matlab/fmm2d.c MEX entry; together
# they provide every Fortran-ABI symbol that gateway references. Keep in sync
# with the upstream src/ layout (paths are relative to FMM2D_SRC).
FILES=(
  "next235|src/common/next235.f|"
  "cdjseval2d|src/common/cdjseval2d.f|"
  "cumsum|src/common/cumsum.f|"
  "hank103|src/common/hank103.f|"
  "dfft_threadsafe|src/common/dfft_threadsafe.f|"
  "hndiv2d|src/helmholtz/hndiv2d.f|"
  "fmmcommon2d|src/common/fmmcommon2d.f|dreorderf,dreorderi,init_carray"
  "l2dterms|src/laplace/l2dterms.f|l2dterms"
  "cauchykernels2d|src/laplace/cauchykernels2d.f|"
  "lapkernels2d|src/laplace/lapkernels2d.f|"
  "rlapkernels2d|src/laplace/rlapkernels2d.f|"
  "laprouts2d|src/laplace/laprouts2d.f|"
  "tree_routs2d|src/common/tree_routs2d.f|tree_refine_boxes,tree_copy,computecoll,updateflags,tree_refine_boxes_flag,computemnlists,computelists"
  "pts_tree2d|src/common/pts_tree2d.f|"
  "cfmm2d|src/laplace/cfmm2d.f|"
  "cfmm2d_ndiv|src/laplace/cfmm2d_ndiv.f|"
  "rfmm2d_ndiv|src/laplace/rfmm2d_ndiv.f|"
  "lfmm2d_ndiv|src/laplace/lfmm2d_ndiv.f|"
  "h2dcommon|src/helmholtz/h2dcommon.f|"
  "h2dterms|src/helmholtz/h2dterms.f|h2dterms"
  "helmkernels2d|src/helmholtz/helmkernels2d.f|"
  "helmrouts2d|src/helmholtz/helmrouts2d.f|"
  "wideband2d|src/helmholtz/wideband2d.f|"
  "hfmm2d|src/helmholtz/hfmm2d.f|"
  "hfmm2d_ndiv|src/helmholtz/hfmm2d_ndiv.f|"
  "bhndiv2d|src/biharmonic/bhndiv2d.f|"
  "bh2dterms|src/biharmonic/bh2dterms.f|bh2dterms"
  "bhkernels2d|src/biharmonic/bhkernels2d.f|"
  "bhrouts2d|src/biharmonic/bhrouts2d.f|"
  "bhfmm2d|src/biharmonic/bhfmm2d.f|"
  "stfmm2d|src/stokes/stfmm2d.f|"
  "stokkernels2d|src/stokes/stokkernels2d.f|"
  "mbhgreen2d|src/modified-biharmonic/mbhgreen2d.f|"
  "mbhkernels2d|src/modified-biharmonic/mbhkernels2d.f|"
  "mbhrouts2d|src/modified-biharmonic/mbhrouts2d.f|"
  "mbhfmm2d|src/modified-biharmonic/mbhfmm2d.f|"
)
