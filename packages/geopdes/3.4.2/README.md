# geopdes

[GeoPDEs](http://rafavzqz.github.io/geopdes/) is a research tool for Isogeometric Analysis (IGA) of partial differential equations, by Rafael Vázquez and Carlo de Falco. It provides the building blocks of an IGA solver — geometry handling, B-spline/NURBS spaces, meshes, and operator assembly — for scalar and vector problems on single- and multi-patch domains.

- **Authors**: Rafael Vázquez, Carlo de Falco
- **License**: GPL-3.0
- **Version**: `3.4.2`
- **Repository**: https://github.com/rafavzqz/geopdes

## Install

```matlab
mip install --channel mip-org/dev geopdes
mip load geopdes
mip load nurbs
```

GeoPDEs depends on the [`nurbs`](../../nurbs) toolbox for spline geometry; it is installed automatically and must be loaded alongside `geopdes`. See the bundled `examples/` directory for complete worked problems (Laplace, elasticity, Stokes, Maxwell, …).

```matlab
geometry = geo_load(nrb4surf([0 0],[1 0],[0 1],[1 1]));
% ... build msh_cartesian, sp_nurbs, and assemble operators (op_*_tp) ...
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. (Upstream `src/` `.cc` files are Octave-only `.oct` accelerators with pure-MATLAB `op_*.m` equivalents under `operators/`, which is what MATLAB uses; only `inst/` is packaged.)

## Tests

`test_geopdes_channel.m` runs a minimal IGA pipeline on the unit square (geometry → mesh → NURBS space → mass-matrix assembly) and checks that the total assembled mass equals the domain area and that the matrix is symmetric.
