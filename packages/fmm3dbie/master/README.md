# fmm3dbie

[fmm3dbie](https://github.com/fastalgorithms/fmm3dbie) provides fast multipole
accelerated boundary integral equation (BIE) solvers for the Laplace,
Helmholtz, Stokes, and Maxwell equations on surfaces in R^3. The core is
Fortran and is called from MATLAB through a single pre-generated mwrap gateway
(`matlab/fmm3dbie_routs.c`). The volume FMM it relies on, FMM3D, is vendored as
a git submodule and statically linked into the MEX.

- **Authors**: T. Askham, Z. Gimbutas, T. Goodwill, L. Greengard, J. Hoskins,
  L. Lu, M. O'Neil, M. Rachh, V. Rokhlin, F. Vico (see `AUTHORS`)
- **License**: Apache-2.0 (see `LICENSE`)
- **Repository**: https://github.com/fastalgorithms/fmm3dbie (tracks `master`;
  the project has no release tags)

## Install

```matlab
mip install --channel mip-org/staging fmm3dbie
mip load fmm3dbie
```

`fmm3dbie` declares a dependency on the sibling `fmm3d` package, so `mip load`
also loads the volume-FMM wrappers (`lfmm3d`/`hfmm3d`/...) used by some
examples. The solvers themselves are self-contained (FMM3D is statically linked
into the MEX).

## What is shipped

The `matlab/` and `matlab/src/` directories are placed on the MATLAB path.
That exposes the solver namespaces — `lap3d`, `helm3d`, `stok3d`, `em3d`
(each with `.eval`, `.solver`, `.get_quadrature_correction`, `.kern`, ...) —
the `@surfer` geometry class, the `geometries` surface builders (`sphere`,
`ellipsoid`, `stellarator`, ...), and the helper m-files under `src/`.

One MEX gateway is built and shipped: `fmm3dbie_routs`.

## What is not shipped

The Python bindings (`python/`), the Fortran/C example, test, and performance
drivers (`examples/`, `test/`, `perf-test/`), the documentation sources
(`docs/`), and the bundled geometry data (`geometries/`) are removed from the
bundle — together with the corresponding trees in the vendored `FMM3D/`
submodule — since none are inputs to the MATLAB MEX build. For any of those
pieces, build from the upstream repository.

## Architectures

Pre-compiled MEX binaries ship for `linux_x86_64`, `macos_arm64`, and
`windows_x86_64`. Intel macOS is not built. There is no pure-MATLAB fallback —
the package needs the MEX to do any work.

The Linux and macOS MEX link the gfortran/OpenMP runtime dynamically; `mip
bundle` then vendors the required shared libraries (`libgfortran`, `libgomp`)
next to the MEX with a relative RPATH (`$ORIGIN` on Linux, `@loader_path` on
macOS), so they run on end-user machines without a matching gfortran runtime
installed. The Windows MEX is built with MinGW-w64 and statically links the
gfortran/OpenMP runtime via MATLAB's `mingw64.xml`, so the `.mexw64` carries no
MinGW runtime DLL dependency. BLAS/LAPACK are resolved against MATLAB's own
`libmwblas`/`libmwlapack`.

The default flags' `-march=native` is dropped so the binaries run on a generic
CPU of each platform. OpenMP is enabled (`-fopenmp`); set `OMP_NUM_THREADS` to
control parallelism.

A `numbl_wasm` build is not provided: unlike fmm3d, fmm3dbie links BLAS/LAPACK,
which has no MATLAB-provided equivalent under WebAssembly, so a wasm build would
additionally require LAPACK in wasm. That is left for a follow-up.

## Test

`test_fmm3dbie.m` solves Laplace and Helmholtz Dirichlet problems on the unit
sphere, whose layer potentials have closed-form eigenvalues, and asserts the
FMM/quadrature result against the exact answer — exercising the `fmm3dbie_routs`
MEX through `lap3d`/`helm3d` `eval`, `kern`, and the GMRES `solver`.
