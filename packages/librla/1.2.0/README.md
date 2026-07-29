# librla

Randomized linear algebra routines for MATLAB/Octave by Adrianna Gillman and
Zydrunas Gimbutas. librla computes low-rank matrix factorizations via
randomized sketching — orthonormal range basis (`librla.orth_sketch`),
truncated pivoted QR (`librla.qr_sketch`), truncated SVD
(`librla.svd_sketch`), and interpolative decomposition (`librla.id_sketch`) —
plus a deterministic ID (`librla.id_qrpiv`) and a scipy-style
`LinearOperator` class for matrix-free operators. Every sketching routine
takes either a relative tolerance (`rtol < 1`, adaptive rank) or a target
rank (`rtol >= 1`), and handles real and complex matrices. The library is
described in [arXiv:2607.20732](https://arxiv.org/abs/2607.20732).

- Upstream: <https://github.com/agillman20/librla>, tag `v1.2.0`
- License: MIT (the upstream `DISCLAIMER.txt` with NIST's standard
  no-warranty disclaimer ships alongside)

## Install

```matlab
mip install --channel mip-org/staging librla
mip load librla
```

## What is shipped

The upstream repository carries MATLAB, Python, and Julia implementations
with a common API; this package ships only the MATLAB one (the
`distrib/matlab/` subdirectory): `librla.m`, `LinearOperator.m`, and
upstream's README, license, and disclaimer. The Python and Julia
implementations are not included — get those from upstream.

`mip load librla` puts the package root on the path. Two optional groups are
off the path by default:

- `mip load librla --with examples` — upstream `demo/` scripts
  (`demo01_basic` … `demo05_methods`).
- `mip load librla --with tests` — upstream `test/` suite (run `test_all`).

## Tests

`test_librla.m` runs on the `any` build and exercises all five public
routines on an ill-conditioned Hilbert-type matrix — tolerance mode against
a full-SVD reference, rank mode, and the matrix-free `LinearOperator` path
in both rank and tolerance mode.
