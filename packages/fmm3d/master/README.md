# fmm3d

[FMM3D](https://github.com/flatironinstitute/fmm3d) evaluates potential fields
due to particle sources governed by the Laplace, Helmholtz, Maxwell, or Stokes
equations in R^3, using the Fast Multipole Method. The core is Fortran and is
called from MATLAB through two pre-generated mwrap gateways
(`matlab/fmm3d.c`, `matlab/fmm3d_legacy.c`).

- **Author**: FMM3D Development Team (Flatiron Institute, Center for
  Computational Mathematics — see `AUTHORS`)
- **License**: Apache-2.0 (a few bundled files under `src/` are BSD-3-Clause
  or public domain; see `LICENSE`)
- **Version**: 2.1.0
- **Repository**: https://github.com/flatironinstitute/fmm3d

## Install

```matlab
mip install --channel mip-org/staging fmm3d
mip load fmm3d
```

## What is shipped

The `matlab/` directory is placed on the MATLAB path. That exposes the modern
FMM entry points and their direct-sum references —
`lfmm3d`/`l3ddir` (Laplace), `hfmm3d`/`h3ddir` (Helmholtz),
`emfmm3d`/`em3ddir` (Maxwell), `stfmm3d`/`st3ddir` (Stokes) — the legacy CMCL
particle wrappers (`lfmm3dpart`, `hfmm3dpart`, `l3dpartdirect`,
`h3dpartdirect`), and the bundled example and test scripts.

Two MEX gateways are built and shipped: `fmm3d` (the modern API) and
`fmm3d_legacy` (the legacy API).

## What is not shipped

The other-language bindings (`c/`, `python/`, `julia/`), the Fortran/C example
and test drivers (`examples/`, `test/`), the documentation sources (`docs/`),
developer scaffolding (`devel/`), and the SIMD vectorized kernels
(`vec-kernels/`) are removed from the bundle — none are inputs to the MATLAB
MEX build. The package is built with the standard Fortran kernels; the optional
`FAST_KER` (vectorized C++ kernel) path is left off. For any of those pieces,
build from the upstream repository.

## Architectures

Pre-compiled MEX binaries ship for `linux_x86_64`, `macos_arm64`, and
`windows_x86_64`, plus a `numbl_wasm` build (below). Intel macOS is not built.
There is no pure-MATLAB fallback — the package needs the MEX (or the WASM) to
do any work.

The Linux and macOS MEX link the gfortran/OpenMP runtime dynamically; `mip
bundle` then vendors the required shared libraries (`libgfortran`, `libgomp`)
next to each MEX with a relative RPATH (`$ORIGIN` on Linux, `@loader_path` on
macOS), so they run on end-user machines without a matching gfortran runtime
installed. The Windows MEX is built with MinGW-w64 and statically links the
gfortran/OpenMP runtime via MATLAB's `mingw64.xml`, so the `.mexw64` carries no
MinGW runtime DLL dependency.

The default flags' `-march=native` is dropped so the binaries run on a generic
CPU of each platform. OpenMP is enabled (`-fopenmp`); set `OMP_NUM_THREADS` to
control parallelism.

### numbl WASM

The `numbl_wasm` build runs fmm3d in [numbl](https://github.com/magland/numbl)
(MATLAB-in-the-browser/JS). There is no practical Fortran→WASM path, so
`matlab/numbl/build_wasm.sh` transpiles the upstream Fortran to C with
[`fort2c`](https://github.com/magland/fort2c) and compiles it to two standalone
modules with Emscripten — `fmm3d.wasm` and `fmm3d_legacy.wasm`, one per mwrap
gateway. The `fmm3d.numbl.js` / `fmm3d_legacy.numbl.js` builtins marshal each
call through those modules in place of the native MEX. The whole Fortran
library (Laplace, Helmholtz, Stokes, Maxwell) is transpiled; the Helmholtz
plane-wave quadrature tables make these modules a few MB each.

## Test

`test_fmm3d.m` runs the upstream test drivers, which compare the FMM against
the direct evaluators. It exercises both shipped MEX: the modern `fmm3d`
gateway via `lfmm3dTest`, `hfmm3dTest`, `stfmm3dTest`, and `emfmm3dTest` (each
asserts FMM-vs-direct relative error internally), and the `fmm3d_legacy`
gateway via `lfmm3dLegacyTest` and `hfmm3dLegacyTest`.
