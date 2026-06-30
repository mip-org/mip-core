# mmess

[M-M.E.S.S.](https://www.mpi-magdeburg.mpg.de/projects/mess) (the Matrix Equation Sparse Solver library) provides low-rank solvers for large-scale, sparse matrix equations — Lyapunov, Riccati, and Sylvester — together with tools for model order reduction of dynamical systems.

- **Authors**: Jens Saak, Martin Köhler, Peter Benner, and the M-M.E.S.S. contributors (Max Planck Institute for Dynamics of Complex Technical Systems, Magdeburg)
- **License**: BSD-2-Clause
- **Version**: `3.1`
- **Repository**: https://gitlab.mpi-magdeburg.mpg.de/mess/mmess-releases

## Install

```matlab
mip install mmess
mip load mmess
```

`mip load` adds the toolbox and all of its subfolders to the path — the same set `mess_path` adds upstream (`genpath` of the root, excluding the documentation/build-only folders). No further setup is needed:

```matlab
A = -gallery('tridiag', 100);   % stable
B = randn(100, 2);
Z = mess_lyap(A, B);            % low-rank factor: X = Z*Z' solves A X + X A' + B B' = 0
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. (M-M.E.S.S. can optionally take advantage of the Control System Toolbox for the small dense Lyapunov/Riccati subproblems, but it is not required.)

## What is shipped

The full toolbox, including the `DEMOS/` examples and their bundled benchmark model data (e.g. the steel-rail `Data_Rail` set). The documentation/build-only folders that `mess_path` excludes from the path (`html`, `_prototypes`, `_packages`, `resources`, `private`) are likewise kept off the path here.

## Tests

`test_mmess_channel.m` solves a continuous-time Lyapunov equation with the high-level `mess_lyap` solver and checks that the low-rank solution's residual is at machine-precision level.
