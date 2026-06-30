# jigsaw

[JIGSAW](https://github.com/dengwirda/jigsaw-matlab) is a Delaunay-based unstructured mesh generator for two- and three-dimensional geometries (planar, surface, and volumetric). This package provides the MATLAB / Octave interface together with JIGSAW's C++ backend, built from source.

- **Author**: Darren Engwirda
- **License**: Custom (see `LICENSE.md`)
- **Version**: `master` (the bundled backend is newer than the latest interface tag)
- **Repository**: https://github.com/dengwirda/jigsaw-matlab

## Install

```matlab
mip install jigsaw
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

| Architecture | Backend |
| --- | --- |
| `linux_x86_64`   | standalone C++ executables |
| `macos_arm64`    | standalone C++ executables |
| `windows_x86_64` | standalone C++ executables |
| `numbl_wasm`     | `jigsaw.wasm` (lib_jigsaw via a JS builtin) |

On the three native architectures, JIGSAW's numerical backend is a set of standalone C++ executables (`jigsaw`, `tripod`, `marche`) plus a shared library, built from the bundled source under `external/jigsaw` by `compile.m` (CMake, C++17). The MATLAB interface launches `external/jigsaw/bin/jigsaw` via `system()`.

## numbl WASM

numbl supports neither `system()` nor filesystem access from a builtin, so the executable/file protocol can't be reused. Instead the `numbl_wasm` build (`compile_numbl_wasm.m` → `numbl/build_wasm.sh`) compiles JIGSAW's **in-memory C library** — the same `external/jigsaw/src/jigsaw.cpp` the native shared library is built from, with `-D__lib_jigsaw` — to a standalone `jigsaw.wasm` (emcc, `-fwasm-exceptions`, no netcdf). The `jigsaw_kernel.numbl.js` builtin marshals mesh/option structs to and from JIGSAW's `jigsaw_msh_t` / `jigsaw_jig_t` via a small shim (`numbl/jigsaw_shim.cpp`) and calls `jigsaw` / `tripod` / `marche` directly.

The numbl-specific `jigsaw.m` / `tripod.m` / `marche.m` overrides (in `numbl/`, which the channel lists last on the path so it shadows the upstream copies) preserve the file-based `OPTS` contract: they read the input `*.MSH` files with `loadmsh`, run the WASM kernel, and write the result with `savemsh`. The upstream `loadmsh` relies on `fscanf` and `regexp(...,'split')` — neither available in numbl — so `numbl/loadmsh.m` reimplements the reader with `fgetl` + `sscanf` + `strsplit`. `initjig` is likewise overridden to drop the unsupported `genpath` call (the channel already places `tools/` and `parse/` on the path).

All three entry points are exercised by `test_jigsaw_numbl_wasm.m`.

## Static linking

On Linux the backend is linked with `-static-libstdc++ -static-libgcc`, and on Windows with the static MSVC runtime (`/MT`), so the executables carry no external C++-runtime dependency. This matters in particular because MATLAB prepends its own (often older) `libstdc++` to the library path when launching subprocesses — a dynamically linked backend built with a newer compiler would otherwise fail to start from within MATLAB. macOS uses the OS-provided `libc++`.

## Tests

`test_jigsaw.m` initialises JIGSAW, meshes a square domain via the compiled backend, and checks that a non-empty, in-domain triangulation with valid connectivity is returned.
