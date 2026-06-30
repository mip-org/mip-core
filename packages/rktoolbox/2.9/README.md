# rktoolbox

The [Rational Krylov Toolbox](http://guettel.com/rktoolbox/) (RKToolbox) provides functionality for working with rational Krylov spaces: an implementation of the rational Arnoldi algorithm (`rat_krylov`), the RKFIT method for nonlinear rational approximation (`rkfit`), and the `RKFUN` / `RKFUNM` classes for numerical computing with rational functions.

- **Authors**: Mario Berljafa, Steven Elsworth, Stefan Güttel (The Rational Krylov Team, University of Manchester)
- **License**: BSD-3-Clause
- **Version**: `2.9`
- **Website**: http://guettel.com/rktoolbox/

## Install

```matlab
mip install rktoolbox
mip load rktoolbox
```

`mip load` adds the toolbox folder to the path (the `@rkfun` / `@rkfunm` / `@rkfunb` / `@baryfun` class folders resolve from there) — equivalent to the upstream `addpath` install. No further setup is needed:

```matlab
A = gallery('tridiag', 100);
[V, K, H] = rat_krylov(A, ones(100,1), [-1, 1i, -1i, inf]);  % A*V*K = V*H
```

## Source

RKToolbox is distributed only as a zip archive from the project website (there is no public git repository and no versioned download URL). This package fetches that archive — currently version 2.9 — which unpacks into a top-level `rktoolbox/` folder; only that folder is placed on the path, matching the upstream install. The `examples/`, `guide/`, and `tests/` subfolders ship with the package but stay off the default path.

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code.

## Tests

`test_rktoolbox_channel.m` builds a rational Arnoldi decomposition with `rat_krylov` and verifies both the defining relation `A*V*K = V*H` and the orthonormality of the basis to machine precision.
