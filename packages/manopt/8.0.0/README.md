# manopt

[Manopt](https://www.manopt.org) is a MATLAB toolbox for optimization on manifolds (Riemannian optimization). It provides a large library of manifolds and solvers, plus tools for automatic differentiation and gradient/Hessian checking.

- **Author**: Nicolas Boumal and the Manopt contributors
- **License**: GPL-3.0
- **Version**: `8.0.0` (upstream tag `Release_8.0`)
- **Repository**: https://github.com/NicolasBoumal/manopt

## Install

```matlab
mip install manopt
mip load manopt
```

`mip load` adds the toolbox root and every code directory under `manopt/` to the path — the same set `importmanopt.m` adds upstream. There is no separate setup step; functions such as `spherefactory`, `trustregions`, and `checkgradient` are immediately available.

```matlab
n = 100;
A = randn(n); A = 0.5*(A+A');
problem.M = spherefactory(n);
problem.cost  = @(x) -x'*(A*x);
problem.egrad = @(x) -2*(A*x);
x = trustregions(problem);   % maximizes the Rayleigh quotient on the sphere
```

## Architecture matrix

| Architecture | MEX compiled? | Test script |
| --- | --- | --- |
| `linux_x86_64`   | yes | `test_manopt_channel.m` |
| `macos_arm64`    | yes | `test_manopt_channel.m` |
| `windows_x86_64` | yes | `test_manopt_channel.m` |
| any other        | **no** (pure-MATLAB fallback) | `test_manopt_any.m` |

Manopt ships two small C MEX helpers in `manopt/tools/` — `spmaskmult` (masked sparse product) and `setsparseentries` (overwrite the nonzeros of a sparse matrix) — used by `sparseentries.m` / `replacesparseentries.m` (e.g. for fixed-rank manifolds). On the three compiled architectures these are built from source by `compile.m`. On the `[any]` fallback no MEX is shipped (the bundling pipeline strips the prebuilt `.mex*` files); the rest of the toolbox is pure MATLAB and works normally, but the few functions that call those helpers will error.

## Not included

The bundled **TTeMPS** tensor-train sub-toolbox under `manopt/manifolds/ttfixedrank/` (the `fixedTTrankfactory` manifold) is dropped at package time. It vendors a third-party library that needs several additional MEX files — including OpenMP variants that upstream's own `install_mex.m` does not build — to support a single specialized manifold. Everything else in Manopt (all other manifolds, solvers, autodiff, and tools) is included and unaffected.

## Tests

- `test_manopt_channel.m` — solves a sphere optimization (recovering the dominant eigenvalue of a symmetric matrix) and exercises both MEX helpers through their wrappers with correctness checks.
- `test_manopt_any.m` — the pure-MATLAB sphere optimization only.
