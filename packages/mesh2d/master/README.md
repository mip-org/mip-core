# mesh2d

[MESH2D](https://github.com/dengwirda/mesh2d) is a MATLAB toolbox for unstructured triangular mesh generation in the two-dimensional plane, using Delaunay-refinement and Frontal-Delaunay techniques. Given a polygonal domain (a planar straight-line graph), it produces high-quality triangular meshes, with control over element size and grading.

- **Author**: Darren Engwirda
- **License**: Custom — free for private, research, and institutional use; commercial use by arrangement with the author (see `LICENSE.md`)
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/dengwirda/mesh2d

## Install

```matlab
mip install --channel mip-org/dev mesh2d
mip load mesh2d
mip load inpoly
```

`mip load` adds the MESH2D code subfolders to the path (the same set `initmsh.m` adds upstream). MESH2D depends on [`inpoly`](../../inpoly) for its point-in-polygon kernel; it is installed automatically and must be loaded alongside `mesh2d`.

```matlab
node = [0 0; 1 0; 1 1; 0 1];
edge = [1 2; 2 3; 3 4; 4 1];
[vert, etri, tria, tnum] = refine2(node, edge);   % generate a mesh
[vert, etri, tria, tnum] = smooth2(vert, etri, tria, tnum);  % optimise it
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code.

The upstream `poly-test/` folder is a copy of INPOLY and is replaced here by the [`inpoly`](../../inpoly) dependency. The bundled `aabb-tree/` folder is **kept**: unlike the standalone [`aabb_tree`](../../aabb_tree) package, MESH2D's copy is a richer variant (it adds `findball`/`findline`/`lineline`/`linenear` and `findtria`, which MESH2D uses), so it cannot be replaced by that dependency and ships with the package.

## Tests

`test_mesh2d_channel.m` meshes the unit square with `refine2`, verifies the resulting triangulation (valid indices, vertices inside the domain, non-degenerate triangles), and runs `smooth2`.
