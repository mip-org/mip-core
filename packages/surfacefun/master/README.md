# surfacefun (mip package)

Surfacefun is a MATLAB package by Dan Fortunato for computing with functions
on surfaces with high-order accuracy. It provides abstractions for high-order
unstructured surface meshes (`surfacemesh`), scalar functions and vector
fields on surfaces (`surfacefun`, `surfacefunv`), and a fast direct solver
for surface PDEs (`surfaceop`).

- Upstream repository: https://github.com/danfortunato/surfacefun
- Documentation: https://surfacefun.readthedocs.io
- Version: tracks the upstream `master` branch
- License: the upstream project is intentionally permissive but does not
  currently ship a formal license file (`unspecified`)

## Install

```matlab
mip install --channel mip-org/staging surfacefun
mip load surfacefun
```

Loading surfacefun also loads [chebfun](https://www.chebfun.org), which it
depends on (declared as a mip dependency; the upstream repo vendors it as a
git submodule instead).

## What is shipped

Everything in the upstream repository except:

- `docs/` — Sphinx documentation sources (~24 MB, mostly images); see the
  rendered docs at https://surfacefun.readthedocs.io
- `external/` — the chebfun git submodule, replaced by the mip `chebfun`
  dependency

The default load path is the package root (which exposes the `surfacefun`,
`surfacefunv`, `surfacemesh`, and `surfaceop` classes) plus `tools/`. The
upstream demos and apps ship but are not on the path by default; opt in with

```matlab
mip load surfacefun --with examples
```

which adds `demo/` and `apps/`. The `models/` directory (mesh data used by
some demos) ships alongside them.

## Tests

`test_surfacefun.m` checks quadrature on the unit sphere, verifies the
Laplace-Beltrami eigenfunction identity for spherical harmonics via `lap`
and `div(grad(...))`, and solves a Laplace-Beltrami problem with `surfaceop`
against a known solution.
