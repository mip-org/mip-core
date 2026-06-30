# SeDuMi

SeDuMi (Self-Dual-Minimization) is a MATLAB solver for convex
optimization problems involving linear equations and inequalities,
second-order-cone constraints, rotated quadratic cones, and
semidefinite (linear matrix inequality) constraints. The primary
entry point is

```matlab
[x, y, info] = sedumi(A, b, c, K)
```

where `K` describes the product cone structure (`K.f` free, `K.l`
nonnegative, `K.q` Lorentz, `K.r` rotated Lorentz, `K.s`
semidefinite).

- Upstream: https://github.com/sqlp/sedumi (community fork)
- Official site: https://sedumi.ie.lehigh.edu/
- Original author: Jos F. Sturm (Tilburg University); continued by
  Imre Pólik, Oleksandr Romanko, Michael C. Grant, and others
  under the direction of Tamás Terlaky (Lehigh).
- Version: 1.3.8 (upstream tag `v1.3.8`)
- License: GNU GPL-2.0 (see upstream `COPYING`)

## What is shipped

After `mip load sedumi`, the repository root and `conversion/` are
on the MATLAB path. That covers the solver entry points and the
converters (`feasreal`, `feascpx`, `fromsdpa`, `prelp`, `writesdp`,
`blk2vec`, `sdpa2vec`, `sdpasplit`, `getproblem`).

The `examples/` directory (sample problems `arch0.mat`,
`control07.mat`, `nb.mat`, `quantum.mat`, `trto3.mat`,
`OH_2Pi_STO-6GN9r12g1T2.mat`, and the upstream `test_sedumi.m`
runner) is **not** on the default path. Opt in with:

```matlab
mip load sedumi --with examples
test_sedumi   % runs the full benchmark suite
```

The `doc/` directory (PDF/PostScript user guides) is dropped from
the bundle — download from the upstream repository if needed.

## Install

```matlab
mip install sedumi
mip load sedumi
```

## MEX binaries and architectures

SeDuMi compiles 34 MEX files that wrap its sparse Cholesky,
symbolic factorization, cone projection, and scaling kernels.
Pre-compiled binaries are built in CI and shipped for:

- `linux_x86_64`
- `macos_arm64`
- `windows_x86_64`

Intel macOS is not currently built. On Linux, `libstdc++`/`libgcc`
are linked statically so the binaries load on end-user machines
without matching the builder's libstdc++ ABI. The Windows MEX is
built with MinGW-w64 and statically links its runtime via MATLAB's
`mingw64.xml`, so the `.mexw64` carries no MinGW runtime DLL
dependency. The MEX layer binds MATLAB's own BLAS via `-lmwblas`.
There is no pure-MATLAB fallback — the solver calls into MEX
routines unconditionally, so unsupported architectures cannot run
SeDuMi.

## Tests

`test_sedumi_channel.m` solves a 2-variable LP
(minimize `2*x1 + 3*x2` s.t. `x1 + x2 = 1`, `x >= 0`; optimum
`c'*x = 2`) and verifies that `info.pinf == info.dinf == 0`, that
both primal and dual costs match, and that the primal solution is
close to `[1; 0]`. This exercises the full MEX-backed solve path
on a tiny problem.

The upstream `examples/test_sedumi.m` (behind `--with examples`)
runs the full 6-problem SDP/SOCP benchmark suite; it calls
`install_sedumi` at the top, which is a no-op when the mip-shipped
binaries are already present.
