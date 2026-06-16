# fmmlib2d

[FMMLIB2D](https://github.com/zgimbutas/fmmlib2d) evaluates potential fields
due to particle sources governed by either the Laplace or Helmholtz equation
in R^2, using the Fast Multipole Method. The core is Fortran and is called
from MATLAB through a pre-generated mwrap gateway (`matlab/fmm2d.c`).

- **Authors**: Leslie Greengard and Zydrunas Gimbutas
- **License**: BSD-3-Clause
- **Version**: 1.2.4
- **Repository**: https://github.com/zgimbutas/fmmlib2d

## Install

```matlab
mip install --channel mip-org/dev fmmlib2d
mip load fmmlib2d
```

## What is shipped

The `matlab/` directory is placed on the MATLAB path. That exposes the
particle FMM entry points (`rfmm2dpart`, `lfmm2dpart`, `cfmm2dpart`,
`zfmm2dpart`, `hfmm2dpart`), the direct evaluators
(`r2dpartdirect`, `l2dpartdirect`, `c2dpartdirect`, `z2dpartdirect`,
`h2dpartdirect`), the tree utilities (`d2tstrcr`, `d2tstrcrem`,
`d2tgetb`, `d2tgetl`), and `fmm2dprini`.

## Architectures

Pre-compiled MEX binaries ship for `linux_x86_64`, `macos_arm64`, and
`windows_x86_64`. Intel macOS is not currently built. There is no
pure-MATLAB fallback — the package needs the MEX to do any work.

The Linux MEX links the gfortran/OpenMP runtime dynamically and then bundles
its required shared libraries (`libgfortran` and `libgomp`) next to the MEX
with an `$ORIGIN` RPATH, so it runs on end-user machines that do not have a
matching gfortran runtime installed. (`libquadmath` is not needed — the code
uses no quad precision.) The macOS MEX statically links the gfortran/OpenMP
runtime; `libc++` and the system runtime come from the OS. The Windows MEX is
built with MinGW-w64 and statically links the gfortran/OpenMP runtime via
MATLAB's `mingw64.xml`, so the `.mexw64` carries no MinGW runtime DLL
dependency.

OpenMP is enabled (`-fopenmp`); the parallel tree builder `d2tstrcr_omp.f`
uses all available threads. Set `OMP_NUM_THREADS` to control parallelism.

## Test

`test_fmmlib2d.m` exercises `rfmm2dpart`, `lfmm2dpart`, and `hfmm2dpart`
against the direct evaluators at `iprec=4` (target ~1e-6) and asserts
relative error below 1e-3.
