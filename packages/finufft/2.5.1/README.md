# finufft

[FINUFFT](https://finufft.readthedocs.io) (Flatiron Institute Nonuniform Fast Fourier Transform) computes fast, parallel nonuniform FFTs of types 1, 2, and 3 in 1D, 2D, and 3D. This package provides the MATLAB interface.

- **Authors**: Alex Barnett and the FINUFFT team (Flatiron Institute)
- **License**: Apache-2.0
- **Version**: `2.5.1`
- **Repository**: https://github.com/flatironinstitute/finufft

## Install

```matlab
mip install finufft
mip load finufft
```

Usage:

```matlab
x = pi * (2*rand(100,1) - 1);          % nonuniform points in [-pi, pi]
c = randn(100,1) + 1i*randn(100,1);    % strengths
f = finufft1d1(x, c, -1, 1e-9, 64);    % type-1 transform onto 64 modes
```

## Architecture

A compiled MEX package. `compile.m` builds the FINUFFT C++ static library with
CMake (using the bundled DUCC0 FFT backend, OpenMP off) and links it into the
`finufft` MEX in `matlab/`, which the m-file wrappers (`finufft1d1.m`,
`finufft_plan.m`, …) dispatch through. The C++ runtime is statically linked for
portability. Built for `linux_x86_64`, `macos_arm64`, and `windows_x86_64`
(macOS uses FFTW instead of the DUCC0 backend).

## Tests

`test_finufft.m` runs 1D type-1, 1D type-2, and 2D type-1 transforms, checking
output sizes, absence of NaNs, and (for type 1) agreement with a direct DFT of a
single mode. All transforms dispatch through the single `finufft` MEX.
