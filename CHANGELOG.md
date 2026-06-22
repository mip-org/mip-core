# Changelog

## Unreleased

- `numbl_wasm` added to the `build-package.yml` architecture choices so push
  builds can dispatch it (the reusable workflow already supports it).

- Build-request issues opened by an admin (write+ on the repo) now dispatch
  automatically — no `approve` comment needed. README updated.

- `finufft` (`2.5.1`): extend `test_finufft.m` to cover all 9 simple-interface
  transforms (1D/2D/3D, types 1/2/3), each checked for output size, NaN, and
  accuracy against a direct evaluation.

- `fmm2d` (`main`): point `source.yaml` at upstream `flatironinstitute/fmm2d`
  (not the `fmm2d_c_translation` fork) and add a `numbl_wasm` build —
  developed and validated in the `mip-org/mip-staging` channel. It transpiles
  the upstream Fortran to C with fort2c at build time and compiles a standalone
  `fmm2d.wasm`, so it needs no fork. The native numbl builds
  (`numbl_linux_x86_64`, `numbl_macos_x86_64`) remain in the `mip-org/labs`
  channel.

- Add a daily `download-stats.yml` workflow that snapshots GitHub Release
  asset download counts and folds them into a monotonic lifetime total on
  a dedicated `stats` branch (`download-stats.json`). Survives the count
  resets that occur when a package is rebuilt (`gh release upload
  --clobber` starts the new asset at zero). Logic lives in the
  `mip-channel download-stats` subcommand in `mip-org/mip_channel_tools`.

- Move the entire build engine out of the channel into its own repo,
  `mip-org/mip_channel_tools`: the GitHub Actions logic (now **reusable
  workflows**: build-package, assemble-index, push-build, scheduled-build,
  build-request), the `mip-channel-tools` Python package (CLI subcommands
  prepare, package-setup, upload, assemble-index, build-request, affected,
  scheduled-check), the MATLAB build scripts (`bundle_one.m`, `test_one.m`,
  ...), the MEX configs (`mexopts/`), the vcpkg overlay triplets
  (`vcpkg-triplets/`), the generic GitHub Pages site template (`site/`), and the
  developer notes (`notes/`). The channel's `.github/workflows/*` are now thin
  callers that own only the event triggers and delegate to the reusable
  workflows (`uses: mip-org/mip_channel_tools/.github/workflows/<name>.yml@<ref>`,
  `secrets: inherit`). Each reusable workflow checks out the calling channel by
  default (for `packages/`) and checks out its own repo at the called ref
  (`job.workflow_sha`) into `mip_channel_tools/` for the scripts, site, and
  Python package (e.g. MATLAB `addpath('mip_channel_tools/scripts')`,
  `assemble-index --site-dir mip_channel_tools/site`). To run against a different
  tooling branch, edit the `@<ref>` on a caller's `uses:` line. Removes `tools/`,
  `scripts/`, `mexopts/`, `vcpkg-triplets/`, `site/`, `notes/`,
  `adding_a_package.md`, and `.github/actions/` from the channel; only
  `packages/` and thin caller workflows remain.

- Add test scripts for chebfun@5.7.0 (construction, integration, diff, roots,
  max, cumsum), export_fig@3.54 (crop_borders plus an end-to-end PNG export),
  and flam@master (interpolative decomposition and an rskelf multiply/solve),
  wiring each up via `test_script` in the package `mip.yaml`.

- Add finufft@2.5.1 (linux_x86_64, macos_arm64, windows_x86_64): FINUFFT — fast
  parallel nonuniform FFTs (types 1/2/3 in 1D/2D/3D), MATLAB interface (Flatiron
  Institute). The MEX is built from source with CMake (DUCC0 FFT backend on
  Linux/Windows, FFTW on macOS arm64) and statically links the C++ runtime.
  compile.m clears LD_LIBRARY_PATH around the cmake/compiler calls so MATLAB's
  bundled libstdc++ does not shadow the system toolchain.

- Rename each package's `recipe.yaml` to `source.yaml` and update all
  references in the `mip-channel-tools` package and docs.

- Consolidate the workflow Python helpers into a `mip-channel-tools` package
  under `tools/` (`mip-channel` CLI with subcommands: prepare, package-setup,
  upload, assemble-index, build-request, affected, scheduled-check). Workflows
  install it with `pip install ./tools` and invoke `python -m mip_channel_tools
  <sub>`. The old `scripts/*.py` are removed (the MATLAB `.m` helpers stay).
  `assemble-index` now takes `--repo-root` instead of deriving the channel root
  from `__file__`. The package is self-contained for eventual extraction to its
  own repo and publication on PyPI, so multiple channels can share it.

- Add geometry_processing_package@master (any): Geometry Processing Package
  (Computational Geometry Group) — triangle-mesh I/O (OBJ/OFF/PLY), discrete
  operators (Laplace-Beltrami, gradient, areas), topology utilities, and
  parameterization. Pure MATLAB.

- Add meshpart@v1.1 (any): Meshpart — a Matlab mesh-partitioning and graph-
  separator toolbox (Gilbert/Teng, modernized by Yingzhou Li) with spectral,
  coordinate, inertial, geometric, and nested-dissection methods. Pure MATLAB.
  Geometric partitioning (geopart/geodice) needs the Statistics Toolbox; the
  optional external METIS interface (metismex) is not bundled.

- Add spatialmath_matlab@master (any): Spatial Math Toolbox — rotations,
  rigid-body transforms, quaternions, twists and spatial vectors in 2D/3D
  (Peter Corke). Pure MATLAB. Dependency of robotics_toolbox_matlab.

- Add robotics_toolbox_matlab@10.4 (any): Robotics Toolbox for MATLAB — serial-
  link manipulator kinematics/dynamics, trajectories, and mobile robotics
  (Peter Corke). Pure MATLAB; depends on spatialmath_matlab. The optional frne
  RNE MEX is not built (the SerialLink class falls back to its M-file RNE). The
  HTML docs and Simulink/hardware-interface/Octave directories are excluded.

- Add disk_conformal_map@master (any): Disk Conformal Map — a fast method for
  conformally mapping simply-connected open triangle meshes onto the unit disk
  (Choi & Lui). Pure MATLAB; the Mobius area-correction extension ships but is
  not exercised in the channel test (needs the Optimization Toolbox).

- Add spherical_conformal_map@master (any): Spherical Conformal Map — a linear
  (FLASH) method for conformally mapping genus-0 closed triangle meshes onto the
  unit sphere (G. P. T. Choi). Pure MATLAB; the Mobius area-correction extension
  ships but is not exercised in the channel test (needs the Optimization
  Toolbox).

- Add jsonlab@2.9.8 (any): JSONLab — encode/decode JSON, binary JSON
  (BJData/UBJSON/MessagePack), and JData/NIfTI/HDF5 in MATLAB (NeuroJSON).
  Pure MATLAB.

- Add mole@1.2.0 (any): MOLE (Mimetic Operators Library Enhanced) — high-order
  mimetic discretizations (grad/div/laplacian/curl) for PDEs on staggered grids.
  Pure MATLAB; only the MATLAB/Octave implementation (src/matlab_octave) is
  packaged (the separate C++ library is not).

- Add gramm@3.1.2 (any): gramm — a grammar-of-graphics plotting toolbox for
  MATLAB (ggplot2-style). Pure MATLAB. Only the toolbox `gramm/` directory is
  packaged (the repo's large sample_data/images/paper dirs are excluded).

- Add spot@1.2 (any, linux_x86_64, macos_arm64, windows_x86_64): Spot — a
  linear-operator toolbox for matrix-free linear algebra (van den Berg &
  Friedlander). Mostly pure MATLAB with an `any` build; the four bundled Rice
  Wavelet Toolbox MEX (`+spot/+rwt`: mdwt/midwt/mrdwt/mirdwt, backing the
  wavelet operators) are built from source on the three native arches.

- Add ultrasem@master (any): ultraSEM — an ultraspherical spectral element
  method for solving PDEs on unstructured polygonal/curved domains (Fortunato,
  Hale, Townsend). Pure MATLAB; self-contained (no Chebfun dependency).

- Add geopdes@3.4.2 (any): GeoPDEs — a research tool for Isogeometric Analysis
  (IGA) of PDEs (Vazquez & de Falco). Pure MATLAB; depends on nurbs. Only the
  toolbox `inst/` tree is packaged (the `src/` `.cc` are Octave-only `.oct`
  accelerators with pure-MATLAB equivalents).

- Add nurbs@1.4.4 (any): the NURBS toolbox (Non-Uniform Rational B-Splines —
  curves/surfaces/volumes). Pure MATLAB (the upstream `.cc` files are
  Octave-only accelerators with `.m` equivalents). Sourced from the
  Octave-Forge tarball; it is the geometry dependency of geopdes.

- scripts/prepare_one.py: support a `tarball:` source (gzip/bzip2/xz),
  stripping a single top-level directory — for sources distributed only as
  tarballs (e.g. Octave-Forge packages).

- Add bisection@master (any): BISECTION — a fast, robust, fully vectorized
  bisection root-finder for n-dimensional array inputs (Sky Sartorius). Pure
  MATLAB.

- Add sc_toolbox@3.1.3 (any): the Schwarz-Christoffel Toolbox (Driscoll) —
  conformal maps between the disk/half-plane/strip/rectangle and polygonal
  regions. Pure MATLAB.

- Add distmesh@main (any): DistMesh — a simple MATLAB generator for
  unstructured triangular/tetrahedral meshes (Persson & Strang). Pure MATLAB.
  Tracks the default branch (the modernized v1.2 line, CITATION 1.2.0, which
  removed all C/MEX); the only release tags (v1.0/v1.1) are the older versions.

- Add jigsaw_geo_matlab@master (any): JIGSAW(GEO) — worked examples and
  geographic datasets for global/regional mesh generation with JIGSAW. No
  library of its own (example.m + datasets); depends on jigsaw_matlab.

- Add jigsaw_matlab@master (linux_x86_64, macos_arm64, windows_x86_64): JIGSAW,
  a Delaunay-based unstructured mesh generator. The MATLAB interface plus the
  C++ backend (jigsaw/tripod/marche executables + shared lib), built from the
  bundled `external/jigsaw` source via CMake (C++17). The backend is statically
  linked (`-static-libstdc++ -static-libgcc` on Linux, static MSVC runtime on
  Windows) so it runs when launched from within MATLAB. No pure-MATLAB fallback.

- Add mesh2d@master (any): MESH2D — Delaunay-refinement / Frontal-Delaunay
  unstructured triangular mesh generation. Pure MATLAB; depends on inpoly
  (its poly-test copy is dropped). Keeps its bundled aabb-tree, which is a
  richer variant than the aabb_tree package (adds findball/findline/etc.).

- Add find_tria@master (any): FINDTRIA — fast spatial queries (point-in-simplex
  / intersection) for collections of d-simplexes. Pure MATLAB; depends on
  aabb_tree (its vendored copy is dropped in favour of that package).

- Add find_poly@master (any): FINDPOLY — fast point-in-polygon queries for
  polygon collections. Pure MATLAB; depends on aabb_tree and inpoly (vendored
  copies dropped in favour of those packages).

- Add aabb_tree@master (any): AABB-TREE — d-dimensional axis-aligned
  bounding-box tree construction and spatial queries (Darren Engwirda). Pure
  MATLAB. Base spatial-query package for the dengwirda find/mesh family
  (find_tria, find_poly, mesh2d depend on it).

- Add inpoly@master (any): INPOLY, a fast point(s)-in-polygon test for general
  (non-convex, multiply-connected) polygons. Pure MATLAB (the bundled
  `inpoly2_oct.cpp` is an Octave-only accelerator, unused on MATLAB). No
  upstream release tags, so it tracks the default branch.

- Add rktoolbox@2.9 (any): the Rational Krylov Toolbox (rational Arnoldi,
  RKFIT, and the RKFUN class). Pure MATLAB, fetched from the project's zip
  (no git repo / versioned URL); the archive's top-level `rktoolbox/` folder is
  the one placed on the path.

- Add mmess@3.1 (any): M-M.E.S.S., the Matrix Equation Sparse Solver library
  (low-rank solvers for large-scale Lyapunov/Riccati/Sylvester equations and
  model order reduction). Pure MATLAB; paths mirror `mess_path` (the whole tree
  minus the doc/build-only folders).

- Add tensor_toolbox@3.8 (any, linux_x86_64, macos_arm64, windows_x86_64): the
  Tensor Toolbox for MATLAB (dense/sparse/decomposed N-way arrays; CP, Tucker,
  ...). Mostly pure MATLAB with an `any` build; the one compiled component,
  `lbfgsb_wrapper` (Stephen Becker's self-contained L-BFGS-B-C under
  `libraries/lbfgsb`), is built from source on the three native arches.

- Add hm_toolbox@master (any): hm-toolbox — HODLR, HSS and HALR hierarchical
  (rank-structured) matrices in MATLAB. Pure MATLAB; the package root on the
  path is the whole install (the `@hodlr`/`@hss`/`@halr` classes resolve from
  there). Tracks the default branch: the only release tag (`v1.0`, 2023) is two
  years behind upstream.

- Add manopt@8.0.0 (any, linux_x86_64, macos_arm64, windows_x86_64): the Manopt
  toolbox for optimization on manifolds. Pure-MATLAB core with an `any` build;
  the two `manopt/tools` sparse-helper MEX (`spmaskmult`, `setsparseentries`)
  are built from source on the three native arches. The bundled TTeMPS
  tensor-train sub-toolbox (`manopt/manifolds/ttfixedrank`, the
  `fixedTTrankfactory` manifold) is dropped — it vendors a third-party library
  needing several extra MEX (incl. OpenMP variants upstream's installer skips)
  for one niche manifold.

- Add cvx@2.2.2 (linux_x86_64, macos_arm64, windows_x86_64): the CVX disciplined
  convex programming modeling system. Sourced from the cvxr/CVX git tree (no
  bundled solvers / prebuilt binaries); the two presolver MEX helpers are built
  from source and the channel's `sedumi` package supplies the solver via a
  declared dependency. `compile.m` builds with `-fno-strict-aliasing -fwrapv`
  because newer GCC `-O2` otherwise miscompiles these legacy C sources and
  corrupts the heap (intermittent solve-time segfaults).

- Add `adding_a_package.md`: a guide for adding packages to this channel,
  adapted from mip-staging for this channel's conventions (per-arch dispatch /
  scheduled / issue build model, `prepare_one.py`/`bundle_one.m`/`test_one.m`,
  supported arch set without `macos_x86_64`, the strict version rules, the
  all-MEX-exercised coverage gate, and the MinGW/direct-`mex` Windows pattern).

- spm@master (Windows): add `windows_x86_64` MEX build via a new
  `compile_windows.m`. SPM's upstream Makefile assumes a Unix shell, so
  rather than reproduce that on the runner, `compile_windows.m` drives the
  identical compilations as direct `mex` calls (the channel's native-Windows
  convention) — the `spm_vol_utils` static archive (MinGW `ar`), the ~30 core
  MEX, the `@file_array`/`@gifti`/`@xmltree`/`FieldMap` subdir MEX, and the
  bemcp/fieldtrip externals including fieldtrip's `external-install` copy
  layout. MinGW links the runtime statically (`mingw64.xml`). Windows now uses
  `test_spm_mex.m` (the all-MEX sweep) instead of the pure-MATLAB fallback.

- ci: assemble-index workflow now also runs on pushes to `main` that touch
  `site/`, so site changes are redeployed without a manual dispatch.

- site: derive the channel identifier by stripping the `mip-` repo prefix,
  so install commands and the page title show `<owner>/<channel>` (e.g.
  `mip-org/dev`) instead of the raw repo name `mip-org/mip-dev`.

- spm@master: migrated from mip-staging. Neuroimaging toolbox (SPM); MEX
  compiled on `linux_x86_64`/`macos_arm64` via the upstream `src/Makefile`,
  with an `any` pure-MATLAB fallback. Dropped staging's `macos_x86_64`
  build entry (not a supported dev channel architecture). Tracks the
  upstream `main` branch (no pinned version). ~130 MB bundles.
  `test_spm_mex.m` reworked to satisfy the channel's all-MEX-exercised gate
  (issue #16): it keeps the three functional MEX checks and adds a dynamic
  sweep that force-loads every shipped MEX (including the `private/`,
  `@class/private/` and bundled fieldtrip/bemcp/FieldMap binaries) from each
  one's own directory.

- dotenv@1.1.4: migrated from mip-staging. Pure-MATLAB `.env` loader, `any`
  architecture. Upstream license is a MathWorks-restricted BSD-3-Clause
  variant (`LicenseRef-MathWorks`).

- matlab_progressbar@3.4.1: migrated from mip-staging. Pure-MATLAB
  TQDM-style progress bar, `any` architecture.

- matlab_tree@master: migrated from mip-staging. Pure-MATLAB tree data
  structure class, `any` architecture. Tracks the upstream default branch
  (no pinned version).

- cmocean@main: migrated from mip-staging. Pure-MATLAB perceptually-uniform
  colormaps, `any` architecture. Tracks the upstream default branch (no
  pinned version).

- docmaker@0.7: migrated from mip-staging. Pure-MATLAB toolbox-documentation
  generator, `any` architecture. Ships the upstream `tbx/` subtree
  (`docmaker`, `docmakerdoc`).

- matlab2tikz@1.1.0: migrated from mip-staging. Pure-MATLAB figure-to-TikZ
  converter, `any` architecture. Ships the upstream `src/` tree; `src/dev/`
  is removed.

- matlab_schemer@1.4.0: migrated from mip-staging. Pure-MATLAB editor/GUI
  color-scheme tool, `any` architecture. Upstream `develop/` is removed.

- matgeom@1.2.9: migrated from mip-staging. Pure-MATLAB geometry library
  (2D/3D), `any` architecture. Ships the six active MatGeom modules
  (`geom2d`, `polygons2d`, `graphs`, `geom3d`, `meshes3d`, `utils`) plus the
  package root; upstream `deprecated/` is removed.

- build_request_from_issue: parse build lines from the issue body only; the
  title is no longer folded into the parsed text. A descriptive title such as
  `build mip@numbl and mip@main` was read as a request line with two package
  references and reported as a "multiple package references" error, even when
  the body was well-formed (issue #18).

- test_one: skip the `mip uninstall` step when the package being built is
  `mip` itself. Uninstalling the running package is a tricky edge case we
  don't want to exercise as part of the package build test.

- Windows strip: retry the rename for up to 60s before falling back to
  `Move-Item`. An NTFS directory rename fails while any process holds a handle
  anywhere under the tree; on a fresh runner that pin is transient (Defender
  scan, ngen, VS background services), but the old code fell back on the first
  throw, and a blocked `Move-Item` degrades to a recursive copy+delete — ~5 min
  on the Visual Studio tree (hit 1 of 8 Windows runs on June 12, vs 5–12s for
  the rename path). Waiting out the handle keeps the metadata-only rename;
  per-path logging now records which tree was pinned and for how long.

- glibc gate: don't die silently on binaries with no versioned GLIBC
  references. The per-binary `max=$(objdump | grep ...)` assignment ran under
  the runner's `bash -e -o pipefail`, so a binary whose libc calls the compiler
  inlined away (grep exits 1) killed the step before any output — sedumi's
  Linux build hit this after the gcc-toolset-10 swap left 10 of its 34 MEX
  with no versioned references. Such binaries cannot violate the floor; report
  them as OK.

- sedumi: extend the channel test beyond the single small LP so every shipped
  MEX is exercised (the coverage check failed with 10 of 34 MEX never loaded).
  Adds a sparse LP with dense columns (triggers the dense-column
  factorization), an SOCP, and an SDP. Verified 34/34 coverage against a
  CI-identical Linux build (ubi8 + gcc-toolset-10 + R2022a).

- Fix install instructions in the sedumi and fmmlib2d READMEs to use the
  `mip-org/dev` channel slug.
- Windows vcpkg deps: cache port binaries on a GitHub Packages NuGet feed
  instead of `actions/cache`. The old design tarred the whole archives dir under
  one write-once key shared by every package, so the first job to save (always
  a cheap package) froze the cache and gptoolbox's gmp/mpfr never persisted —
  every Windows gptoolbox build cold-built them (~15 min); entries also expired
  after 7 idle days. The NuGet provider stores each port under its own
  ABI-hashed package mid-install: no key races, no expiry, and all channels
  share one org-wide cache. Auth is the `MIP_CACHE_TOKEN` org secret (a
  machine-account classic PAT with `write:packages`) so every publish uses one
  identity and package ownership never fragments across repos; without the
  secret, builds skip caching and compile deps from source. Setup output now
  surfaces vcpkg restore/push counts in the job summary so a silently cold
  cache is visible. The feed is derived from the repo owner (not hardcoded to
  mip-org), so channels hosted under other owners cache in their own namespace
  with their own `MIP_CACHE_TOKEN`.

- test_one: set `MIP_CONFIRM=y` so prompts never block batch MATLAB. Uninstalling
  the `mip` package itself routes to mip's interactive self-uninstall
  confirmation, which errors in batch mode (broke `packages/mip/main` builds on
  mip-core daily since June 6). No `mip` package here yet; applied for harness
  parity with mip-core.

- Add root `.gitattributes` with `* -text` (no line-ending conversion). Windows
  runners checked out the channel with CRLF (Git for Windows `core.autocrlf=true`
  default), so `prepare_one.py` recorded CRLF-flavored source hashes in published
  Windows `.mip.json` files; the Linux-based scheduled probe computed LF-flavored
  hashes, never matched, and re-dispatched every `windows_x86_64` build nightly.
  Checkouts are now byte-identical on all platforms. Expect one final rebuild
  cycle for the Windows packages before the probe reports them up to date.

- gptoolbox (Windows): drop `read_mesh_from_xml` and `read_triangle_mesh` from the
  Windows build (ships 56 MEX there, was 58). Both are broken on Windows by an
  upstream gptoolbox bug — each extracts the input file path only inside a POSIX
  `#if defined(__unix__)` (`wordexp`) block, so on Windows `read_mesh_from_xml`
  reads an empty filename and `read_triangle_mesh` reads a still-quoted path, and
  both fail at runtime with "file not found". (`readMSH` does the same job correctly
  — unconditional `mxArrayToString`, no quotes — and works.) We don't carry patches
  for upstream source bugs, so `compile.m` excludes the two on Windows via a per-arch
  `setdiff`, and `test_gptoolbox.m` skips their sections under `if ~ispc`; the two
  must stay in sync so `test_one.m`'s coverage gate (built == loaded) stays balanced.
  Linux/macOS are unaffected and still build and exercise both.

- gptoolbox (Windows): define `_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR` on the MSVC
  MEX compile. The `mesh_boolean` MEX crashed at runtime with an Access Violation
  (`0xc0000005`) inside MATLAB R2023a's bundled `MSVCP140.dll` (`_Thrd_yield`,
  null deref) — surfaced once the every-shipped-MEX test sweep first invoked it;
  the build itself was unchanged and `intersect_other` (same CGAL/GMP exact-
  arithmetic stack) passed. Root cause: the MEX is built `/MD` with the runner's
  latest VS2022 toolset (14.4x, past the 14.40 `std::mutex` constexpr-constructor
  ABI change) but loads against MATLAB's older (pre-14.40) `MSVCP140.dll`, which
  the host searches ahead of System32. A v143 zero-init mutex run by the old lock
  code null-derefs the first time `mesh_boolean`'s CGAL exact-construction path
  touches `std::mutex`. Microsoft's opt-out macro restores the non-constexpr
  constructor so the MEX stays compatible with the runtime MATLAB ships; applied
  to all Windows MEX (no-op where no `std::mutex` is constructed). See
  microsoft/STL#4730.

- gptoolbox: add a pure-MATLAB `any` build to `mip.yaml`. Non-compiled arches
  now resolve to a source-only fallback (no `compile_script`, no native setup)
  instead of erroring in `match_build`, matching what the README already
  describes. `test_gptoolbox.m` runs the pure-MATLAB checks and skips the MEX
  sweep there (`mip.build.has_mex` is false with no MEX present) — which is what
  makes the gate below reachable; previously gptoolbox built only the three
  compiled arches.

- gptoolbox: gate the MEX sweep on whether the package actually ships MEX,
  instead of the host machine's architecture. The test now stops after the
  pure-MATLAB checks when `~mip.build.has_mex(mip.test.get_fqn())`, replacing
  the old `mip.build.arch()` host-arch check — which was wrong for an `any`
  build produced on a compiled-arch runner (host arch is concrete, so the MEX
  sweep ran against a package with no MEX). `has_mex` is
  `~isempty(mip.build.list_mex(fqn))`, which scans the package's own source dir
  for `*.<mexext>`; `test_one.m`'s issue-#16 coverage gate now sources its
  built-MEX list from that same `mip.build.list_mex`, so the gate and the
  coverage check share one implementation and can't drift. Requires the helpers
  added to `mip-org/mip` (`mip.build.list_mex`, `mip.build.has_mex`,
  `mip.test.get_fqn`), so that change must ship before this one. No behavior
  change on the current compiled builds (gptoolbox has no `any` build yet).

- gptoolbox: document the `wrappers/` gap in `BUILD_NOTES.md`. The `wrappers/*.m`
  functions shell out to external command-line binaries (meshfix, qslim, medit,
  …) that `compile.m` does not build and we do not bundle, and the issue-#16
  coverage gate is MEX-only, so they are outside it by design. Recorded which
  wrappers are redundant (tetgen/triangle — the real work ships as MEX), genuine
  gaps (meshfix has no MEX equivalent), and dead stubs (nested_cages/readSCISIM
  hardcode paths to the upstream author's machine), plus the pattern to follow if
  we ever build & ship the meshfix binary. Documentation only — no build change.

- gptoolbox / channel: exercise every shipped MEX in the test, and enforce it
  channel-wide (issue #16). The gptoolbox test now invokes all built MEX (was 3)
  with inputs that reach each one's real work — loading alone misses runtime ABI
  bugs like the El Topo BLAS crash. `scripts/test_one.m` gained a post-test
  coverage gate that diffs the package's built `.mex*` against what `inmem` shows
  was loaded and fails the build on any un-exercised MEX (no-op for pure-MATLAB
  packages), so this holds for every package, not just gptoolbox. The two test
  scripts were merged into one arch-aware `test_gptoolbox.m` (pure-MATLAB checks
  always run; the MEX sweep runs only on the compiled arches).

- gptoolbox: add the `images/` directory to `mip.yaml` paths. It was missing (the
  canonical gptoolbox addpath includes it), so `imdata.m` — the data-URI encoder
  `mesh/writeGLTF.m` calls — was off the path, breaking `writeGLTF` on a textured
  mesh. The files already ship in the `.mhl` (the bundler stages the full source);
  only the path entry was absent.

- gptoolbox: fix El Topo (`eltopo` MEX) crashing MATLAB on Linux + Windows — a
  BLAS integer-width (LP64 vs ILP64) ABI bug. El Topo declares 32-bit `int` BLAS
  args but the MEX links MATLAB's 64-bit-integer `libmwblas`/`libmwlapack`, so
  the first BLAS call walked MKL off its buffers (access violation inside
  `mkl.dll`). Added `eltopo_blas_shim.cpp`, a thin 32→64-bit argument-marshaling
  layer: `CMakeLists.txt` renames El Topo's BLAS/LAPACK symbols to private
  `eltopo_*` names that bind to the shim, which widens the integer args and
  forwards to MATLAB's BLAS (the math still runs in MKL). macOS is unaffected
  (links Accelerate's 32-bit-int CBLAS) and unchanged. `test_gptoolbox_mex.m`
  now runs an `eltopo` two-sphere collision so the strip-and-test job exercises
  it on every arch (previously `eltopo` was built but never run). See
  `BUILD_NOTES.md` ("BLAS integer width").

- `build-package.yml`: apply the channel's release-only vcpkg overlay triplets
  globally via `VCPKG_OVERLAY_TRIPLETS` (set alongside `VCPKG_DEFAULT_BINARY_CACHE`
  in the Windows vcpkg prep step) instead of a per-package `--overlay-triplets`
  flag. gptoolbox's `mip.yaml` setup drops the flag accordingly. An overlay triplet
  only applies when its filename matches the requested triplet name, so this is
  harmless to ports using other triplets, and future Windows+vcpkg packages get the
  debug-skipping triplets (and shared binary cache) automatically.

- docs: refresh gptoolbox `BUILD_NOTES.md` for the now-shipped Windows build —
  El Topo built (own `eltopo_msvc` target), the vcpkg release-only triplet +
  binary cache, and a new "Windows / MSVC specifics" section capturing the
  static-define / `WIN32` / BLAS-naming / per-config-manifest gotchas. Also
  corrected the Linux compiler to gcc-toolset-10 (GCC 10.3) and cleared the
  resolved "open risks."

- `build-package.yml`: bump the vcpkg cache steps from `actions/cache/restore@v4`
  / `actions/cache/save@v4` to `@v5` (Node 24 runtime; Node 20 is deprecated).
  The channel's other actions (`checkout@v5`, `setup-python@v6`,
  `upload-artifact@v7`, …) are already on Node 24-era versions.

- gptoolbox (Windows): build El Topo too (previously skipped). eltopo3d's own
  `CMakeLists.txt` is gcc/clang-only — it hardcodes `-std=c++11`/`-Wall`/`-fPIC`
  into `CMAKE_CXX_FLAGS` and calls `find_package(BLAS REQUIRED)`, which fails with
  no system BLAS — so on Windows build `libeltopo` ourselves from the same source
  globs as an MSVC static target (`eltopo_msvc`, aliased to `libeltopo`) with
  `NO_GUI` + `USE_FORTRAN_BLAS` and no `find_package(BLAS)`; non-Windows still
  uses eltopo3d's CMake. El Topo shipped VS projects historically (`vs_files/`),
  so the source is MSVC-buildable. `compile.m` now builds the `eltopo` MEX on
  Windows linking MATLAB's `-lmwlapack`/`-lmwblas`. Two MSVC-specific fixups were
  needed: (1) Win64 MATLAB's BLAS/LAPACK export the *bare* Fortran names
  (`daxpy`), opposite to Linux/macOS (`daxpy_`), but `USE_FORTRAN_BLAS` emits the
  underscore form — so the deps CMake preprocessor-renames every BLAS/LAPACK
  symbol the wrappers declare (`daxpy_`→`daxpy`, 28 in all) on the `eltopo_msvc`
  lib; (2) `common/util.h` polyfills `lround`/`remainder` under a bare
  `#ifdef _MSC_VER`, colliding with modern MSVC's CRT declarations
  (`C2556`/`C2371`/`C2491`), so the CMake step renames those two definitions out
  of the way in our FetchContent copy. Windows now ships the full MEX set except
  the macOS-only `impaste`.

- `build-package.yml` (Windows strip): rename the toolchain trees with
  `[System.IO.Directory]::Move` (a metadata-only Win32 `MoveFile` for a
  same-volume rename) instead of `Move-Item`, which falls back to a recursive
  copy of the whole tree and took minutes on the multi-million-file Visual
  Studio dir. Falls back to `Move-Item` if the atomic move throws (e.g. a
  cross-volume path), preserving the prior behavior; "Verify strip" remains the
  hard gate. Applies to every Windows build (gptoolbox, fmm2d, sedumi).

- gptoolbox (Windows): define `WIN32` for the MEX build. libigl's `Timer.h`
  (pulled in by the embree MEX via `EmbreeIntersector`) guards its `<windows.h>`
  include on bare `#ifdef WIN32` and otherwise includes POSIX `<sys/time.h>`,
  which MSVC lacks (`C1083` on `bone_visible_embree`). MSVC defines `_WIN32` but
  not `WIN32` (MinGW defines both), so add `-DWIN32` to the Windows `mex()`
  flags — the conventional Windows macro, safe for the other deps.

- gptoolbox (Windows): fix libccd/embree static linkage under MSVC. Both
  decorate their public API with `__declspec(dllimport)` unless
  `CCD_STATIC_DEFINE` / `EMBREE_STATIC_LIB` are defined, and we link both as
  static libs. Two sides needed it: (1) the consuming MEX — added both defines
  to the Windows `mex()` flags, since the MEX compile via `mex()` (not CMake)
  and don't inherit the static targets' compile definitions (`gjk_intersect`
  failed with unresolved `__imp_ccdGJKIntersect`); (2) the libccd *library*
  build — its CMake never defines `CCD_STATIC_DEFINE` for a static build, so even
  `ccd.lib`'s own objects referenced their cross-TU API via `__imp_*`
  (`ccd.obj -> __imp_ccdVec3PointSegmentDist2`, 12 unresolved), fixed with
  `target_compile_definitions(ccd PUBLIC CCD_STATIC_DEFINE)` in the deps
  `CMakeLists.txt`. embree's CMake already handles its own static build. All
  Windows-only — a no-op on GCC/Clang (no import stubs), which is why
  macOS/Linux linked fine without any of this.

- gptoolbox (Windows): also make the host triplet release-only. gmp's
  `{"name":"gmp","host":true}` self-dependency builds gmp for the *host* triplet
  (`x64-windows`), which the target-only overlay didn't cover, so host gmp still
  built debug+release. Added `vcpkg-triplets/x64-windows.cmake` (the builtin host
  triplet + `VCPKG_BUILD_TYPE release`); `--overlay-triplets` already points at
  the whole `vcpkg-triplets/` dir, so vcpkg picks it up.

- gptoolbox (Windows): two fixes found in CI. (1) The deps `CMakeLists.txt`
  emitted `L eltopo $<TARGET_FILE:libeltopo>` into the manifest unconditionally,
  but El Topo is skipped on Windows (`libeltopo` target absent), so
  `file(GENERATE)` failed with "No target libeltopo" — now guarded with
  `if(TARGET libeltopo)`. (2) The vcpkg binary cache used the combined
  `actions/cache`, which only saves on job success, so a Bundle failure
  discarded the freshly-built gmp/mpfr; split into `actions/cache/restore`
  before setup + `actions/cache/save` right after it, so the cache persists once
  the install succeeds regardless of whether Bundle later fails.

- gptoolbox (Windows): speed up the vcpkg gmp/mpfr install. A channel-level
  release-only overlay triplet (`vcpkg-triplets/`, shadowing the builtin
  `x64-windows-static-md` with `VCPKG_BUILD_TYPE release`) stops vcpkg building
  the unused debug variant of each port, ~halving the cold build, and
  `build-package.yml` now persists vcpkg's binary cache across Windows runs via
  `actions/cache` over `VCPKG_DEFAULT_BINARY_CACHE` (warm runs restore gmp/mpfr
  instead of rebuilding). The triplet keeps the builtin's name, so `compile.m`'s
  `VCPKG_TARGET_TRIPLET` is unchanged; vcpkg still validates each port by ABI
  hash, so the cache can't serve stale binaries. It lives at the channel level
  (not per-package) so every Windows+vcpkg package gets an identical triplet ABI
  and shares the cached gmp/mpfr.

- Linux `g++` mexopts: guard `-lstdc++` with `-Wl,--push-state,--no-as-needed
  ... -Wl,--pop-state`, mirroring the existing `gcc` mexopts fix. The
  `--as-needed` token in `LDFLAGS` is sticky and also governs the `-lstdc++`
  the `g++` driver appends, so gcc-toolset's base `libstdc++.so.6` was dropped
  out of its split-lib linker script for C++ MEX too — not just the C path the
  original fix covered. Surfaced on gptoolbox's `bone_visible`, the first C++
  MEX in the channel to use `std::filesystem`, which drags `fs_*.o` out of
  `libstdc++_nonshared.a` and then can't resolve their `operator new` /
  `__cxa_throw` / `basic_filebuf` references against the dropped shared half.
  See `notes/LINUX-LIBSTDCXX-ASNEEDED.md`.

- `scripts/package_setup.py` now resolves Git for Windows' `bash` explicitly on
  Windows instead of spawning a bare `bash`. On Windows `CreateProcess` resolves
  a bare `bash` to `C:\Windows\System32\bash.exe` (the WSL launcher) before
  Git's bash on PATH, so a package with a `windows:` setup script failed
  immediately with "Windows Subsystem for Linux has no installed distributions."
  gptoolbox is the first package with a Windows setup script, so it was the
  first to hit this.

- gptoolbox: add the `windows_x86_64` build (MSVC 2022). `compile.m` re-selects
  MSVC over the channel-default MinGW, configures the deps with the Visual Studio
  generator, fetches header-only CGAL/Boost releases, and links static gmp/mpfr
  from vcpkg (`x64-windows-static-md`); the MEX get `/std:c++17 /bigobj` plus
  `NOMINMAX`/`_USE_MATH_DEFINES`. El Topo and the macOS-only impaste are skipped
  on Windows, and `CMakeLists.txt` gates the El Topo dep off under `WIN32`.
  `mip.yaml` declares the arch and adds a `windows:` setup that `vcpkg install`s
  gmp/mpfr. The deps `CMakeLists.txt` now emits its manifest per-config as
  `manifest-<CONFIG>.txt` (`compile.m` reads `manifest-Release.txt`): the
  multi-config VS generator can't write a single fixed-path manifest whose
  `$<TARGET_FILE>` entries differ per config — this also corrects a writer/reader
  filename mismatch that affected every arch.

- gptoolbox (macOS): compile `impaste`'s `paste.mm` with `-fno-objc-arc` so the
  manual-reference-counting Objective-C++ builds regardless of the toolchain's
  ARC default (set at the `mex()` call site, since the memory model is a per-`.mm`
  property).

- Rewrote `scripts/setup_mex_compilers.m` as a single `(architecture, compiler)`
  switch that resolves the mexopts XML pair to apply and the compiler to export,
  followed by one shared tail that runs `mex -setup` and exports
  `CC`/`CXX`/`CMAKE_<LANG>_COMPILER`. The exported compiler is a plain path up
  front for clang (`xcrun -find`) and mingw (`$MW_MINGW64_LOC`), or a deferred
  handle for gcc (read from the `Selected` config after setup); MSVC exports
  nothing (the VS CMake generator finds `cl.exe` itself). An unknown architecture
  now errors instead of skipping silently (`any`/`numbl_*` still skip).

- Renamed the Linux/macOS GNU mexopts `gcc_static.xml`/`g++_static.xml` →
  `gcc.xml`/`g++.xml` (filename and internal `Name`/`ShortName`). Pure rename, no
  flag changes; the `-O3 -DNDEBUG` level is unchanged and now recorded as settled
  channel policy in `notes/MEXOPTS.md`.

- Fixed the Linux MEX link failing with undefined `libstdc++` symbols (e.g. `vtable for
  std::basic_filebuf`, `std::locale::~locale`) pulled from gcc-toolset-10's
  `libstdc++_nonshared.a`. RHEL's gcc-toolset splits `libstdc++` into the base-system
  shared `libstdc++.so.6` plus a static `libstdc++_nonshared.a` for the newer symbols;
  the static half back-references the shared half. The channel's `-Wl,--as-needed`
  dropped `libstdc++.so.6` (nothing in the Fortran/C objects referenced it directly),
  so once a `_nonshared.a` member was pulled its references to the base library went
  unresolved. Guard `-lstdc++` in the `gcc` mexopts with
  `-Wl,--push-state,--no-as-needed … -Wl,--pop-state` so the base library is always
  retained as a `NEEDED` entry, while `--as-needed` still trims other libs. (Stock
  R2022a carries `-lstdc++` but no `--as-needed`, so it never hit this.) See
  `notes/LINUX-LIBSTDCXX-ASNEEDED.md` for the full root-cause analysis.

- Fixed the Linux build failing at `mex -setup` (`compiler is not detected`) after the
  gcc-toolset-10 switch. The toolset lives under `/opt/rh`, and prepending it to PATH via
  `$GITHUB_ENV` reaches `run:` steps but not MATLAB's mex compiler detection, which runs
  `which gcc` against only the baseline PATH (`/usr/bin` etc.) — so the gcc mexopts went
  undetected (stock GCC 8.5 worked only because it sat at `/usr/bin/gcc`). The toolchain
  step now symlinks the toolset bin into `/usr/bin` (`ln -sf /opt/rh/gcc-toolset-10/root/usr/bin/*
  /usr/bin/`) instead of the PATH prepend. This also pins the binutils: `gcc-toolset-10-gcc`
  pulls in the base `binutils` 2.30 as a dependency and gcc-10 resolves `as`/`ld` by bare
  name via PATH, so without the symlinks it assembled/linked with 2.30 rather than the
  toolset's 2.35. Symlinks touch only PATH-based tool resolution, never `LD_LIBRARY_PATH`,
  so the strip-test environment is unaffected. Verified on a RHEL 8.10 runner: `which gcc`
  resolves, gcc finds its own `cc1`/`libexec` through the symlink, `as`/`ld` are 2.35, and
  C++17 and Fortran both compile and run.

- Build-request issues now get a canonical title even when they resolve to more than
  one dispatch. `canonical_title()` lists the architectures for a single-package request
  with three or fewer of them (e.g. `Build: \`fmm2d@main\` (linux_x86_64, macos_arm64,
  windows_x86_64)`), falls back to a dispatch count above that, and summarizes
  multi-package requests as `Build: N dispatches across M packages`. Previously only
  single-dispatch requests were renamed; everything else kept its raw title (e.g. `build`).

- Switched the Linux build from ubi8's stock GCC 8.5 to **gcc-toolset-10** (GCC 10.3),
  installed from the Rocky AppStream repos the toolchain step already adds. RHEL's
  gcc-toolset dynamic-links the base-system `libstdc++` (`GLIBCXX_3.4.25`) and
  statically supplies any newer C++17/20 symbols via `libstdc++_nonshared.a`, so the
  GLIBCXX floor stays `3.4.25` (within R2022a's bundled `libstdc++`) — a newer compiler
  with no compatibility regression — and glibc stays 2.28. gcc-toolset is a Software
  Collection under `/opt/rh` (not on the default PATH), so the step symlinks its bin into
  `/usr/bin` (see the fix entry above for why a `$GITHUB_ENV` PATH prepend doesn't reach
  MATLAB's mex detection); the toolset's own binutils 2.35 comes too (keeping gcc-10
  paired with its matching `as`/`ld`, not the system 2.30). Verified on ubi8: a C++17
  `std::filesystem` `.so` links yet requires only `GLIBCXX_3.4.21`, and the toolset runs
  from PATH alone (no `LD_LIBRARY_PATH`).

- Dropped `-static-libstdc++`/`-static-libgcc` from the Linux `gcc`/`g++` mexopts:
  the MEX now dynamic-links `libstdc++`/`libgcc_s` (like it already does `libgfortran`)
  and lets MATLAB resolve them (all in `linux_skip_set`). The static linking was
  redundant defense — the GCC-8.5 pin caps `GLIBCXX` at 3.4.25 (within MATLAB's bundled
  `libstdc++`) and the strip-test gate catches any overshoot — and was inconsistent with
  `libgfortran`, whose `.a` is non-PIC and can't be static-linked anyway. Dynamic is
  uniform, matches stock, and avoids a second `libstdc++`/unwinder copy alongside
  MATLAB's. (macOS keeps static linking — MATLAB ships no GNU runtime there.) Verified on
  R2022a that a dynamic C++ MEX builds, loads, and runs. Also documents the macOS-vs-Linux
  GCC-version and static-link distinction in `notes/MACOS-DEPLOYMENT-TARGET.md`.

- Pinned the `macos_arm64` CI runner to `macos-14` (from `macos-latest`) and set the
  macOS `clang`/`clang++`/`gcc`/`g++` mexopts `MACOSX_DEPLOYMENT_TARGET` to `14.0`. A
  macOS MEX's real deployment floor is set by the statically-linked Homebrew bottles
  (`gmp`/`mpfr`; and `libgfortran`/`libstdc++`/`libquadmath` from Homebrew GCC), which
  are built for the runner's macOS — not by `-mmacosx-version-min` (which `dyld` does not
  even enforce at `dlopen`). `macos-latest` drifts upward (macOS 15 today → floor 15+);
  `macos-14` is the oldest arm64 runner Homebrew bottles exist for, giving floor 14+.
  `14.0` matches the bottle so the stamp is honest and the version-min warning stays
  meaningful. See `notes/MACOS-DEPLOYMENT-TARGET.md`.

- Removed `-w` from the macOS `g++` mexopts (both arches). It suppressed *all*
  linker warnings — including the `-mmacosx-version-min` mismatch warning, which
  catches an object or dependency built for a newer macOS than the 11.0 floor (a
  MEX that would fail to load on macOS 11), the macOS analogue of the glibc-floor
  check. The `-ld_classic` deprecation warning now shows too, doubling as a
  reminder to migrate off it. Consistent with leaving the `clang++` link warnings
  visible. See `notes/MACOS-MEX-CPP-LINKER.md`.

- Restored stock's C++ MEX API support in the macOS `clang++` mexopts
  (`LINKEXPORTCPP`/`cppMexFunction.map`, `-lMatlabDataArray`, libc++ via
  `-stdlib=libc++`) and added `-ld_classic` (as `g++.xml` already does) so the
  `cppMexFunction.map` export list works on Apple's new linker (`ld-prime`,
  Xcode 15+), which no longer honors `-U` for undefined export-list symbols.
  One static XML now builds both classic `mexFunction` and class-based
  `matlab::mex::Function` MEX. See `notes/MACOS-MEX-CPP-LINKER.md` — including how
  R2025b/R2026a fixed this differently (a symbol-triggered conditional relink in
  the `mex` driver) and when to drop `-ld_classic`.

- Dropped `-std=c++17` from the macOS `clang++` mexopts, leaving the C++
  standard unset like the channel's gcc/g++ mexopts (which dropped stock's
  `-std=c++11`). The standard is a per-package property declared at the call
  site: gptoolbox already passes `-std=c++17` in its `compile.m`, so the build
  is unchanged. Keeps the channel's toolchains uniformly std-neutral.

- Dropped `-fno-omit-frame-pointer` from the macOS `clang`/`clang++` mexopts.
  These target `-arch arm64`, and Apple's ARM64 ABI mandates the frame-pointer
  chain — clang keeps it even under `-fomit-frame-pointer` — so the flag is a
  no-op there; stock macOS clang omits it. (The macOS `gcc`/`g++` mexopts keep
  it, as it is meaningful for x86_64.)

- Dropped `-pthread` from the macOS `clang`/`clang++` mexopts. On Darwin it adds
  no `-lpthread` (pthreads live in `libSystem`) and only defines the `_REENTRANT`
  macro, which the system headers ignore; stock macOS clang omits it. (Linux
  keeps `-pthread` — it is required there and is in stock.)

- Dropped `-fPIC` from the macOS `clang`/`clang++` mexopts. Darwin compiles
  position-independent code by default for dylibs/bundles, so the flag is a
  no-op there; stock macOS clang omits it for the same reason. (Linux keeps
  `-fPIC` — it is required for ELF shared objects and is already in stock.)

- Reverted the macOS `clang`/`clang++` mexopts from weak-linking the MATLAB
  libraries (`-weak-lmx -weak-lmex -weak-lmat`) back to hard `-lmx -lmex -lmat`,
  matching stock and the channel's own gcc mexopts. The weak link was a vestige
  of the old MathWorks Mac template: a MEX only loads inside MATLAB, where
  `@rpath/libmx.dylib` always resolves, so weak-linking bought nothing and only
  degraded a missing-symbol error from a clean load failure to a NULL-pointer
  runtime crash. Verified on R2023b: hard/weak load identically.

- Documented the MEX-API compatibility axis in `notes/MATLAB-GCC.md` (with a
  cross-reference in `notes/MATLAB-GLIBC.md`): a MEX is forward-compatible only
  on the `libmx`/`libmex` + MEX-file-version axis, so the build MATLAB — not the
  GCC version — sets the minimum supported release. Corrects the note's earlier
  "GCC 8 → R2020b+" claim (true only for the libstdc++ axis) and adds a
  three-axis (glibc / compiler-runtime / MEX-API) summary table.

- Added `linux_x86_64` to the `gptoolbox` package. Same split build as macOS
  (CMake builds the static dependency libs; `mex()` links each MEX through the
  channel `gcc_static` mexopts), adapted for the ubi8 / GCC-8.5 container: CGAL,
  Boost, and OpenBLAS headers come from dnf (the Rocky repos added below;
  OpenBLAS only satisfies El Topo's configure-time `find_package(BLAS)` and is
  not linked in), and static `gmp`/`mpfr` are built from source into an
  ephemeral prefix `compile.m` owns (RHEL ships no `.a`; no `/usr/local`
  pollution). El Topo links MATLAB's Fortran BLAS (`-lmwlapack -lmwblas`).
  Everything static keeps the shipped binaries within the glibc-2.28 floor; a
  `libgomp` leaf is bundled if it appears. The dependency build (incl. embree 4
  and El Topo under GCC 8.5) was validated on a RHEL 8.10 container.
- Linux builds now add the Rocky 8 BaseOS/AppStream/PowerTools repos in the
  `build-package.yml` toolchain step. UBI 8's AppStream is a subset that lacks
  `boost-devel`, and EPEL's `CGAL-devel` requires that unversioned package, so
  CGAL/Boost couldn't resolve on UBI alone. Rocky 8 is a 1:1 RHEL 8 rebuild with
  open repos (same glibc 2.28 / GCC 8.5), so only RHEL8-compatible leaf packages
  are pulled — verified to not replace glibc/base. `gpgcheck=1` with the Rocky
  GPG key.
- Added the `gptoolbox` package (`master`, Alec Jacobson's Geometry Processing
  Toolbox) for `macos_arm64`. Built with Apple Clang: CMake builds the C/C++
  dependency static libs (predicates, tetgen, triangle, libccd, tinyxml2, embree
  with internal tasking, El Topo) and discovers header-only CGAL/Boost + static
  gmp/mpfr; `compile.m` then links each MEX with `mex()` so it goes through the
  channel mexopts. Ships the full feature set — CGAL, Embree, XML, El Topo, and
  the macOS-only impaste — ~59 MEX, all self-contained (only MATLAB + OS
  libraries). See `packages/gptoolbox/master/BUILD_NOTES.md`. Windows build to
  follow.
- `scripts/setup_mex_compilers.m` now takes an optional compiler name
  (`setup_mex_compilers(arch, 'clang')`) in addition to the architecture, and
  exports `CMAKE_C_COMPILER`/`CMAKE_CXX_COMPILER` (alongside `CC`/`CXX`) so a
  package's CMake builds use the same compiler as MEX. Defaults to `gcc`
  (Windows still uses MinGW), so existing packages are unaffected. Also dropped
  the Objective-C-only `-fobjc-arc` from `clang++.xml` (it warned on every C++
  source and isn't needed for the one Objective-C++ file that motivated it).
- `macos_arm64` mexopts now pin the deployment target to macOS 11.0
  (`-mmacosx-version-min=11.0` in `gcc_static.xml` and `g++_static.xml`).
  Previously no minimum was set, so each MEX inherited the *build runner's*
  macOS version as its minimum-load version (e.g. `minos 15.0` on the macos-15
  runner), refusing to load on older end-user Macs. 11.0 is the oldest
  Apple-Silicon macOS; the MEX then load on any Mac where MATLAB itself runs.
  Existing macOS packages keep their baked-in minimum until rebuilt.
- Added `clang.xml` and `clang++.xml` mexopts for `macos_arm64` — Apple Clang
  (Xcode) + libc++, deployment target 11.0. A clang alternative to the
  Homebrew-gcc `gcc_static.xml`/`g++_static.xml` for C++ packages where clang is
  the native toolchain (CGAL/libigl/embree) or Objective-C++ sources are
  involved; the channel default remains gcc. Flags are matched to the gcc
  mexopts (`-O3`, `-ffp-contract=off`, `-fwrapv`, frame pointers, …), except the
  legitimately compiler-specific ones (`-isysroot`/`-syslibroot`, libc++ vs
  static `libstdc++`). Produced MEX depend only on OS-provided
  `libc++`/`libSystem`, so end users need neither Xcode nor Command Line Tools.
- Added the `sedumi` package (1.3.8, upstream tag `v1.3.8` from sqlp/sedumi)
  for `linux_x86_64`, `macos_arm64`, and `windows_x86_64`. `compile.m`
  reproduces upstream `install_sedumi`'s 34 MEX targets linking `-lmwblas`,
  with static `libstdc++`/`libgcc` on Linux. Repo root and `conversion/` are
  on the default path; `examples/` is gated behind `--with examples` and
  `doc/` is dropped from the bundle. The MEX sources include f2c-translated
  K&R code, so the build pins `-std=gnu17` (the C23 default in GCC 15, used by
  macos_arm64's Homebrew toolchain, reads `()` as `(void)` and rejects the
  unprototyped calls; harmless on the pinned GCC 8.5 / MinGW 8.1.0 used for
  Linux/Windows). Ported from mip-staging#10, dropping the unsupported
  `macos_x86_64` architecture.
- Windows builds now use the MathWorks-certified MinGW-w64 8.1.0 instead of
  the runner's modern GCC, so `mex` builds the C gateway against a supported
  compiler (no more "unsupported MinGW" warning). A new build-job step
  installs the certified toolchain and exports `MW_MINGW64_LOC`, and
  `scripts/setup_mex_compilers.m` now selects MinGW as the session MEX
  compiler on Windows (mirroring the Linux/macOS `gcc_static.xml` setup).
  Per-package `compile_windows.m` scripts (fmm2d, fmmlib2d) no longer set
  `MW_MINGW64_LOC`/`PATH`, pass `-f mingw64.xml`, or pass
  `-fallow-argument-mismatch` (unneeded on gfortran 8) — removing duplicated,
  drifting toolchain setup. With the modern-GCC blocker gone, the Windows
  MATLAB floor drops from R2023b to R2023a (the oldest release certifying
  8.1.0) for wider forward compatibility. See `notes/MATLAB-MINGW.md`.
- Fixed `push-build.yml` failing with `fatal: bad object <BEFORE>` on any push
  carrying more than one new commit: the changed-files diff needs the push's
  BEFORE commit, but `fetch-depth: 2` only reached AFTER's immediate parent.
  Checkout now uses `fetch-depth: 0` (full history).
- Windows strip step now renames toolchain directories (`Move-Item` to
  `*.deleted`) instead of running the slow VS uninstaller and
  `Remove-Item -Recurse` over million-file trees. An NTFS same-volume rename is
  metadata-only, cutting the step from ~4 min to seconds. Mirrors the macOS
  strip step; the runner is ephemeral so leaving bytes on disk is fine. Added a
  "Verify strip (Windows)" gate (mirrors Linux) that fails the job if a
  compiler/linker still resolves under a stripped root, so a silently-failed
  rename can't let a non-self-contained package pass. The gate matches on
  resolved path (not bare name) so benign collisions — e.g. Git for Windows'
  GNU coreutils `link.exe` — don't trip it.
- Upgraded all GitHub Actions to Node 24-native major versions (`checkout@v5`,
  `setup-python@v6`, `upload-artifact@v7`, `download-artifact@v8`,
  `upload-pages-artifact@v5`, `deploy-pages@v5`, `matlab-actions/*@v3`) and
  dropped the `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` workaround, which only
  forced the runtime without silencing the Node 20 deprecation warning.
- Stop bundling `libgfortran.so.5` in Linux MEX bundles: MATLAB ships it and
  resolves it via `LD_LIBRARY_PATH`, so the bundled copy was dead weight.
  `libgomp.so.1` is still bundled (MATLAB does not ship it). See
  `notes/MEX-RUNTIME-LIBS.md`.
- Added `fmmlib2d` 1.2.4 (Greengard & Gimbutas' Laplace/Helmholtz FMM in
  R^2), built with OpenMP for `linux_x86_64`, `macos_arm64`, and
  `windows_x86_64`.
- Build-request issues now use `<name>@<release> <arch>` syntax in the body
  instead of `packages/<name>/<version> <arch>`.
- `all` now expands only to the architectures declared in the package's
  `mip.yaml`; packages without a channel-side `mip.yaml` no longer dispatch
  every architecture.
- Build-request issues now close automatically after all build jobs are
  successfully dispatched.
