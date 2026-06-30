# jigsaw-geo

[JIGSAW(GEO)](https://github.com/dengwirda/jigsaw-geo-matlab) is a collection of worked examples and datasets for geographic / global unstructured mesh generation with [JIGSAW](https://github.com/dengwirda/jigsaw-matlab) — uniform and variable-resolution global grids, coastal meshes, and mesh-spacing functions built from real topography data.

- **Author**: Darren Engwirda
- **License**: Custom (see `LICENSE.md`)
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/dengwirda/jigsaw-geo-matlab

## Install

```matlab
mip install jigsaw-geo
mip load jigsaw-geo
mip load jigsaw
```

JIGSAW(GEO) is a companion to (and depends on) [`jigsaw`](../../jigsaw), which provides the meshing engine; it is installed automatically and must be loaded alongside this package.

This package contains no library functions of its own — it ships `example.m`, a set of worked geographic-meshing demos, together with the input datasets they use (global topography and regional coastline meshes under `files/`):

```matlab
initjig;
example(1);   % uniform-resolution global grid
example(2);   % regionally-refined global grid
example(6);   % coastal mesh for the Australasian region
% ... see `help example` for the full list
```

## Architecture

Pure MATLAB / data — a single `[any]` build, no compiled code (the compiled meshing backend comes from the [`jigsaw`](../../jigsaw) dependency).

## Tests

`test_jigsaw_geo.m` confirms the `jigsaw` dependency is available and loads each bundled geographic dataset through JIGSAW's mesh reader.
