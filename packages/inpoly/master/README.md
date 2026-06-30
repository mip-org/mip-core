# inpoly

[INPOLY](https://github.com/dengwirda/inpoly) is a fast point(s)-in-polygon test for MATLAB / Octave. Given a set of query points and a general polygon (a planar straight-line graph), `inpoly2` returns the inside/outside status of each point. It handles non-convex and multiply-connected regions and is a fast replacement for MATLAB's built-in `inpolygon`.

- **Author**: Darren Engwirda
- **License**: Custom — free for private, research, and institutional use; commercial use by arrangement with the author (see `LICENSE.md`)
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/dengwirda/inpoly

## Install

```matlab
mip install inpoly
mip load inpoly
```

`mip load` puts the toolbox on the path (the upstream install is a single `addpath`). Usage:

```matlab
node = [0 0; 1 0; 1 1; 0 1];   % polygon vertices
P    = rand(1000, 2);          % query points
in   = inpoly2(P, node);       % logical inside/outside status
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. On MATLAB, `inpoly2` runs the pure-MATLAB kernel (`inpoly2_mat`) and relies on JIT acceleration. The bundled `inpoly2_oct.cpp` is an Octave-only accelerator (compiled to a `.oct` file via `mkoctfile`) and is not used on MATLAB; it ships unchanged for Octave users.

## Tests

`test_inpoly_channel.m` checks point-in-polygon classification against a known polygon and cross-checks `inpoly2` against MATLAB's built-in `inpolygon` over a random query set.
