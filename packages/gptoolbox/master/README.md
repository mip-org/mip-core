# gptoolbox

[gptoolbox](https://github.com/alecjacobson/gptoolbox) is Alec Jacobson's Geometry Processing Toolbox — a large collection of MATLAB functions for mesh processing, discrete differential geometry, mesh deformation and parameterization, image processing, and constrained optimization.

- **Author**: Alec Jacobson and contributors
- **License**: MIT (dual-licensed MIT / Apache-2.0 upstream; we ship under MIT)
- **Version**: `master` (the upstream repo has no tagged releases)
- **Repository**: https://github.com/alecjacobson/gptoolbox

## Install

```matlab
mip install gptoolbox
mip load gptoolbox
```

## What is included

The pure-MATLAB subdirectories `external/`, `imageprocessing/`, `matrix/`, `mesh/`, `quat/`, `utility/`, and `wrappers/` are shipped in full and added to the MATLAB path when the package is loaded. Upstream treats compiling the `mex/` functions as an optional step, so the toolbox is fully usable from the pure-MATLAB layer alone.

## MEX note

Upstream `mex/` contains ~49 C++ MEX sources built through a CMake + vcpkg pipeline (see [mex/README.md](https://github.com/alecjacobson/gptoolbox/blob/master/mex/README.md)). Building all of them would pull in CGAL, Embree, and El Topo via vcpkg, which exceeds the disk and time budget of a standard GitHub-hosted runner.

To keep the build tractable in CI, the following libigl options are **disabled** in `compile.m` / `compile_windows.m`:

- `LIBIGL_COPYLEFT_CGAL` — drops ~13 MEX files that need CGAL (`mesh_boolean`, `selfintersect`, `signed_distance_isosurface`, `snap_rounding`, `outer_hull`, `upper_envelope`, `wire_mesh`, `trim_with_solid`, `box_intersect`, `form_factor`, `intersect_other`, `point_mesh_squared_distance`, `read_mesh_from_xml`)
- `LIBIGL_EMBREE` — drops 5 MEX files that need Embree (`ambient_occlusion`, `bone_visible_embree`, `ray_mesh_intersect`, `ray_mesh_intersect_all`, `reorient_facets`)
- `WITH_ELTOPO` — drops `eltopo`
- `LIBIGL_XML` — disabled in conjunction with CGAL (the only file using it, `read_mesh_from_xml`, also needs CGAL)

`triangulate` is also dropped: upstream's `triangulate.cpp` `#include`s `<CGAL/...>` headers unconditionally (only the switch-case bodies are `#ifdef WITH_CGAL`-guarded), so it cannot compile with `LIBIGL_COPYLEFT_CGAL=OFF`. The compile scripts patch `mex/CMakeLists.txt` at build time to skip its no-CGAL build. The sibling `refine_triangulation` builds fine and is shipped.

The remaining MEX files — libigl-core, `igl::predicates`, `igl_copyleft::tetgen`, `igl_restricted::triangle` (just `refine_triangulation`), `igl::cycodebase`, and libccd-backed convex-collision functions — are built and shipped. This includes `aabb`, `exact_geodesic`, `signed_distance`, `slim`, `decimate_libigl`, `icp`, `readMSH`, `read_triangle_mesh`, `solid_angle`, `winding_number`, `tetrahedralize`, `refine_triangulation`, `orient2d`, `orient3d`, `fast_roots`, `fast_sparse`, and others.

### Disabled MEX functions

On all architectures, the disabled MEX functions still have their `.m` help stubs in `mex/`, but calling them will fail with a missing-MEX error. If you need any of these, build gptoolbox yourself following upstream's [mex/README.md](https://github.com/alecjacobson/gptoolbox/blob/master/mex/README.md).

### Portability

`compile.m` / `compile_windows.m` pass `-DCOMPILER_SUPPORTS_MARCH_NATIVE=OFF` so upstream's CMake does not add `-march=native`. Without this, the binaries would target the CI runner's CPU instruction set (e.g. AVX-512) and crash with an illegal-instruction fault on older end-user CPUs.

### Static linking

On Linux the built MEX files are statically linked against `libstdc++`/`libgcc` and built in the glibc-2.28 container, so they load on the channel's deployment fleet. On Windows the third-party deps link statically (vcpkg `x64-windows-static-md`) while the MSVC runtime links dynamically (`/MD`) to match MATLAB's own ABI (MATLAB ships those runtime DLLs). On macOS `libc++` is OS-provided and the libigl deps are static.

### Architectures

Pre-compiled MEX binaries are produced for `linux_x86_64`, `macos_arm64`, and `windows_x86_64`. Any other architecture gets the pure-MATLAB `any` fallback — the upstream sources are shipped and added to the path, but calling any `mex/*` function fails with a missing-MEX error.

### Tests

Two post-install test scripts are shipped:

- `test_gptoolbox_mex.m` — run on MEX-enabled architectures; exercises both the pure-MATLAB layer and a handful of compiled MEX functions (`fast_sparse`, `orient2d`, `winding_number`) so broken builds/links are caught by `mip test`.
- `test_gptoolbox.m` — run on the pure-MATLAB `any` fallback; exercises only the pure-MATLAB layer.

### Excluded sub-toolbox

`external/toolbox_fast_marching/` (Gabriel Peyré's fast marching toolbox, which ships with its own separate MEX build) is removed at package-prepare time and is **not** included in this bundle.
