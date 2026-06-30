# hm-toolbox

[hm-toolbox](https://github.com/numpi/hm-toolbox) provides MATLAB classes for working with rank-structured (hierarchical) matrices: HODLR (`@hodlr`), HSS (`@hss`), and HALR (`@halr`), together with solvers for Sylvester/Lyapunov equations and a range of structured linear-algebra routines.

- **Authors**: Stefano Massei, Davide Palitta, Leonardo Robol, and contributors
- **License**: GPL-3.0
- **Version**: `master` (the toolbox has a single release tag, `v1.0` from 2023, well behind two years of upstream fixes)
- **Repository**: https://github.com/numpi/hm-toolbox
- **Reference**: Massei, Robol & Kressner, *hm-toolbox: MATLAB Software for HODLR and HSS Matrices*, SIAM J. Sci. Comput. 42(2), C43–C68 (2020).

## Install

```matlab
mip install --channel mip-org/dev hm-toolbox
mip load hm-toolbox
```

`mip load` puts the toolbox root on the path — the same single `addpath` the upstream README prescribes. The `@hodlr` / `@hss` / `@halr` class folders and `private/` resolve from there, so no further setup is needed.

```matlab
A = ... ;            % a dense matrix with low-rank off-diagonal blocks
H = hodlr(A);        % build the HODLR representation
y = H \ b;           % fast structured solve
```

See the `examples/` folder (shipped with the package, off the default path) for more.

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code.

## Tests

`test_hm_toolbox.m` builds HODLR and HSS representations of a well-conditioned, rank-structured matrix and checks that matrix-vector products and linear solves agree with the dense reference to near machine precision.
