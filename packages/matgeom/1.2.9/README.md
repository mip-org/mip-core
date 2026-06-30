# matgeom

[MatGeom](https://github.com/mattools/matGeom) is a MATLAB library for geometry processing and geometric computing in 2D and 3D. It provides several hundred functions for creating, manipulating, and displaying geometric primitives: points, lines, circles, ellipses, polygons, polyhedra, and 3D polygonal meshes.

- **Author**: David Legland
- **License**: BSD-2-Clause
- **Version**: 1.2.9
- **Repository**: https://github.com/mattools/matGeom

## Install

```matlab
mip install matgeom
mip load matgeom
```

## What is shipped

The bundle contains the six active MatGeom modules, each added to the MATLAB path:

- `geom2d` — general functions in the Euclidean plane
- `polygons2d` — functions on polygons and polylines
- `graphs` — geometric graphs
- `geom3d` — general functions in 3D Euclidean space
- `meshes3d` — 3D polygonal mesh manipulation
- `utils` — shared helpers

The package root itself is also on the path so `setupMatGeom` is callable, though loading via `mip` already puts every module on the path and no further setup is required.

## What is not shipped

The upstream `deprecated/` directory (legacy functions retained for backward compatibility) is removed from the bundle. Code that depends on those deprecated entry points should migrate to the current API or install MatGeom directly from source.

The upstream repository also contains a top-level `tests/`, `demos/`, `docs/`, and `resources/` tree; those live outside the `matGeom/` library folder and are not part of the bundle.

## Tests

`test_matgeom.m` exercises a cross-section of the library — 2D polygon area, circle-to-polygon conversion, line/point distance, bounding boxes, 3D plane construction, and mesh volume/surface area on a unit cube — to confirm the modules load and the core numerics behave.
