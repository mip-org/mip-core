# meshpart

[Meshpart](https://github.com/YingzhouLi/meshpart) is a MATLAB toolbox for mesh partitioning and graph separators, originally by John Gilbert and Shang-Hua Teng and modernized by Yingzhou Li. It provides geometric, spectral, coordinate, and inertial partitioning, vertex separators, nested dissection orderings, and a set of grid/mesh generators.

- **Authors**: Yingzhou Li, John R. Gilbert, Shang-Hua Teng
- **License**: MIT
- **Version**: `1.1`
- **Repository**: https://github.com/YingzhouLi/meshpart

## Install

```matlab
mip install meshpart
mip load meshpart
```

`mip load` puts the toolbox on the path (equivalent to the upstream `addpath(genpath('src'))`).

```matlab
[A, xy] = grid5(20);          % 20x20 five-point grid graph
[p1, p2] = specpart(A);       % spectral bisection (Fiedler vector)
map = specdice(A, 3);         % spectral multiway partition into 8 parts
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. Two notes on optional/external pieces:

- **Geometric partitioning** (`geopart`, `geodice`, `geosep`, `geond`) requires the MATLAB Statistics Toolbox (it calls `randsample`).
- **METIS interface**: meshpart can interface to the external METIS library via `metismex`, which is not bundled here. The spectral, coordinate, inertial, and geometric partitioners do not need it.

## Tests

`test_meshpart.m` builds a 20×20 grid graph and exercises spectral bisection (`specpart`) and spectral multiway dicing (`specdice`), verifying valid, balanced partitions. The geometric partitioners ship but are not exercised in the test (they need the Statistics Toolbox). The test is display-free (no `gplotmap`).
