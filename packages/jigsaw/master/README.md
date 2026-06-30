# jigsaw

[JIGSAW](https://github.com/dengwirda/jigsaw-matlab) is a Delaunay-based unstructured mesh generator for two- and three-dimensional geometries (planar, surface, and volumetric). This package provides the MATLAB / Octave interface together with JIGSAW's C++ backend, built from source.

- **Author**: Darren Engwirda
- **License**: Custom (see `LICENSE.md`)
- **Version**: `master` (the bundled backend is newer than the latest interface tag)
- **Repository**: https://github.com/dengwirda/jigsaw-matlab

## Install

```matlab
mip install --channel mip-org/dev jigsaw
mip load jigsaw
```

`mip load` adds the interface and its `tools/` and `parse/` folders to the path. Call `initjig` once per session to set JIGSAW's global constants, then drive the mesher via the `jigsaw` function:

```matlab
initjig;
opts.geom_file = 'domain.msh';   % input geometry
opts.jcfg_file = 'domain.jig';   % config
opts.mesh_file = 'mesh.msh';     % output
% ... populate a geometry struct, savemsh(opts.geom_file, geom) ...
opts.hfun_hmax = 0.05;
opts.mesh_dims = 2;
mesh = jigsaw(opts);
```

## Architecture

| Architecture | Backend compiled? |
| --- | --- |
| `linux_x86_64`   | yes |
| `macos_arm64`    | yes |
| `windows_x86_64` | yes |

Unlike a MEX toolbox, JIGSAW's numerical backend is a set of standalone C++ executables (`jigsaw`, `tripod`, `marche`) plus a shared library, built from the bundled source under `external/jigsaw` by `compile.m` (CMake, C++17). The MATLAB interface launches `external/jigsaw/bin/jigsaw` via `system()`.

There is no pure-MATLAB fallback: the backend is required, so the package is built only for the three native architectures.

## Static linking

On Linux the backend is linked with `-static-libstdc++ -static-libgcc`, and on Windows with the static MSVC runtime (`/MT`), so the executables carry no external C++-runtime dependency. This matters in particular because MATLAB prepends its own (often older) `libstdc++` to the library path when launching subprocesses — a dynamically linked backend built with a newer compiler would otherwise fail to start from within MATLAB. macOS uses the OS-provided `libc++`.

## Tests

`test_jigsaw.m` initialises JIGSAW, meshes a square domain via the compiled backend, and checks that a non-empty, in-domain triangulation with valid connectivity is returned.
