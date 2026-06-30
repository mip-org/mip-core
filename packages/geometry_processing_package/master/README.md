# geometry_processing_package

[Geometry Processing Package](https://github.com/cfwen/geometry-processing-package) is a MATLAB toolbox for triangle-mesh geometry processing from the Computational Geometry Group. It provides mesh I/O (OBJ/OFF/PLY), discrete differential operators (Laplace-Beltrami, gradient, face/vertex areas), connectivity/topology utilities (edges, rings, boundary, homology, cut graphs), and surface parameterization.

- **Author**: Wen Cheng Feng (Computational Geometry Group)
- **License**: MIT
- **Repository**: https://github.com/cfwen/geometry-processing-package

## Install

```matlab
mip install geometry_processing_package
mip load geometry_processing_package
```

`mip load` adds the topical subdirectories (`algebra`, `io`, `topology`, `parameterization`, …) to the path.

```matlab
[face, vertex] = read_off('bunny.off');
fa = face_area(face, vertex);          % per-face areas
L  = laplace_beltrami(face, vertex);   % cotangent Laplace-Beltrami operator
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. The toolbox is organized into topical subdirectories, all of which are placed on the path.

## Tests

`test_geometry_processing_package_channel.m` builds a triangulated grid mesh and exercises the I/O (OFF write/read round-trip), algebra (`face_area`, `laplace_beltrami` with rows summing to zero, `compute_edge` with boundary-edge detection), and topology (`dijkstra` shortest paths over the mesh graph) modules. The test is display-free (no `plot_mesh`).
