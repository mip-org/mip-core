# jigsaw_geo_matlab

[JIGSAW(GEO)](https://github.com/dengwirda/jigsaw-geo-matlab) is a collection of worked examples and datasets for geographic / global unstructured mesh generation with [JIGSAW](https://github.com/dengwirda/jigsaw-matlab) — uniform and variable-resolution global grids, coastal meshes, and mesh-spacing functions built from real topography data.

- **Author**: Darren Engwirda
- **License**: Custom (see `LICENSE.md`)
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/dengwirda/jigsaw-geo-matlab

## Install

```matlab
mip install --channel mip-org/dev jigsaw_geo_matlab
mip load jigsaw_geo_matlab
mip load jigsaw_matlab
```

JIGSAW(GEO) is a companion to (and depends on) [`jigsaw_matlab`](../../jigsaw_matlab), which provides the meshing engine; it is installed automatically and must be loaded alongside this package.

This package contains no library functions of its own — it ships `example.m`, a set of worked geographic-meshing demos, together with the input datasets they use (global topography and regional coastline meshes under `files/`):

```matlab
initjig;
example(1);   % uniform-resolution global grid
example(2);   % regionally-refined global grid
example(6);   % coastal mesh for the Australasian region
% ... see `help example` for the full list
```

## Architecture

Pure MATLAB / data — a single `[any]` build, no compiled code (the compiled meshing backend comes from the [`jigsaw_matlab`](../../jigsaw_matlab) dependency).

## Tests

`test_jigsaw_geo_matlab_channel.m` confirms the `jigsaw_matlab` dependency is available and loads each bundled geographic dataset through JIGSAW's mesh reader.
