# distmesh

[DistMesh](https://persson.berkeley.edu/distmesh/) is a simple MATLAB code for the generation of unstructured triangular and tetrahedral meshes, by Per-Olof Persson and Gilbert Strang. Geometries are described implicitly via signed distance functions, and meshes are produced by a force-based smoothing of an initial point distribution.

- **Authors**: Per-Olof Persson and Gilbert Strang
- **License**: MIT
- **Version**: `main` — the modernized **v1.2** line (CITATION.cff `1.2.0`), which is fully pure-MATLAB (all C/MEX binaries removed); the only tagged releases (`v1.0`, `v1.1`) are the older versions.
- **Repository**: https://github.com/popersson/DistMesh

## Install

```matlab
mip install --channel mip-org/dev distmesh
mip load distmesh
```

`mip load` adds the `src/` (toolbox functions) and `examples/` folders to the path — the same set `startup.m` adds upstream.

```matlab
fd = @(p) sqrt(sum(p.^2,2)) - 1;             % unit disc (signed distance)
[p, t] = distmesh2d(fd, @huniform, 0.2, [-1,-1;1,1], []);
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code (v1.2 removed the legacy C/MEX components).

## Tests

`test_distmesh_channel.m` meshes the unit disc with `distmesh2d` and verifies the resulting triangulation (valid connectivity, vertices inside the domain, non-degenerate triangles).
