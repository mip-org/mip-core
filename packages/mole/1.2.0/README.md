# mole

[MOLE](https://github.com/csrc-sdsu/mole) (Mimetic Operators Library Enhanced) implements high-order mimetic finite-difference operators for solving partial differential equations. It provides discrete analogs of the common vector-calculus operators — gradient, divergence, Laplacian, bilaplacian, and curl — as highly sparse matrices acting on staggered grids (uniform, non-uniform, curvilinear) that satisfy local and global conservation laws.

- **Authors**: Computational Science Research Center, SDSU (J. Corbino, J. E. Castillo, and contributors)
- **License**: GPL-3.0
- **Version**: `1.2.0`
- **Repository**: https://github.com/csrc-sdsu/mole

## Install

```matlab
mip install mole
mip load mole
```

`mip load` puts the MOLE operator functions on the path (equivalent to the upstream `addpath('src/matlab_octave')`).

```matlab
k = 6; m = 2*k+1; dx = 1/m;     % order, cells, spacing
L = lap(k, m, dx);              % 1-D mimetic Laplacian (sparse)
L = L + robinBC(k, m, dx, 1, 1);
U = L \ rhs;                    % solve a boundary-value problem
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. MOLE also ships a C++ library (`src/cpp`, built with CMake against Eigen/OpenBLAS); only the pure-MATLAB/Octave implementation (`src/matlab_octave`) is packaged here.

## Tests

`test_mole_channel.m` checks that the mimetic Laplacian is exact on a quadratic (`Lap(x^2) = 2`) and solves the 1-D elliptic getting-started problem (Robin BCs), verifying the solution against `exp(x)`.
