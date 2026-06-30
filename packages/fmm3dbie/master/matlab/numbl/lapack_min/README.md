# lapack_min — minimal BLAS/LAPACK for the numbl_wasm build

The native fmm3dbie MEX resolves BLAS/LAPACK against MATLAB's
`libmwblas`/`libmwlapack`. The `numbl_wasm` build has no MATLAB BLAS, so this
directory vendors the **minimal closure** of reference BLAS/LAPACK that
fmm3dbie's live code paths actually reach, to be transpiled to C with `fort2c`
and compiled into the wasm alongside the fmm3dbie/FMM3D Fortran.

All of fmm3dbie's LAPACK use goes through `src/common/lapack_wrap_64.f90`. The
only wrappers with callers are `dinverse` (→ `dgetrf`+`dgetri`) and `dleastsq`
(→ `dgelsy`, only in `rigidbodies.f`). `dgelsy`/SVD/eig/expert-solve wrappers
are unused, so the closure is just LU + inverse + the BLAS the live wrappers
use.

## Provenance

Unmodified files are from netlib **Reference-LAPACK v3.12.1**
(https://github.com/Reference-LAPACK/lapack), BSD-3-Clause (see
`LICENSE.lapack`):

- LAPACK (`SRC/`): `dgetrf dgetrf2 dgetri dtrtri dtrti2 dlaswp`
- LAPACK (`INSTALL/`): `dlamch`
- BLAS (`BLAS/SRC/`): `dcopy dgemm dgemv dscal dswap dtrmm dtrmv dtrsm idamax
  lsame zcopy zgemm zgemv`

Two files are local stubs (not from netlib):

- `ilaenv.f` — always returns 1 (forces the unblocked code paths; avoids the
  real ILAENV's environment heuristics and its IEEECK/IPARMQ deps).
- `xerbla.f` — no-op (the real one does Fortran I/O + STOP; arguments are valid
  and `info` is returned to the caller anyway).

The closure was determined empirically (link a `dgetrf`/`dgetri`/BLAS driver
against all of reference LAPACK and take the pulled members) and verified
bit-exact between gfortran and `fort2c`+gcc, including the partial-pivoting path.
