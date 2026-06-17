# Adding a Package to this channel

This document explains how to add a new MATLAB package to this channel
(mip-dev) from a GitHub repository URL. Each package is described by a small
set of YAML and MATLAB files under `packages/<name>/<release>/`.

Unlike a "build everything on every push" channel, builds here run **one
`(package, architecture)` pair at a time** and are triggered three ways:
automatically on push to `main` (only for the packages a push touches), daily
by a scheduled probe, or manually via a GitHub issue. The end-to-end flow for
one pair: [`mip-channel prepare`](https://github.com/mip-org/mip_channel_tools/blob/main/src/mip_channel_tools/prepare.py) clones
the upstream source per `source.yaml` and overlays the channel-provided files;
[`scripts/bundle_one.m`](scripts/bundle_one.m) runs `mip bundle` (which sets up
the MEX toolchain and runs `compile.m` if needed) to produce the `.mhl`;
[`scripts/test_one.m`](scripts/test_one.m) installs/loads/tests the bundle and
enforces the MEX-coverage gate; the `.mhl` is uploaded to GitHub Releases and
the channel index is refreshed. See [README.md](README.md) for the full build
model (push / scheduled / issue, the `approve` step, `force`, `all-packages`).

The existing packages in [packages/](packages/) are the best reference for the
patterns below — e.g. [chebfun](packages/chebfun/5.7.0) (pure MATLAB),
[sedumi](packages/sedumi/1.3.8) (many MEX + BLAS),
[fmmlib2d](packages/fmmlib2d/1.2.4) (separate `compile_windows.m`),
[gptoolbox](packages/gptoolbox/master) (CMake + vcpkg, trimmed features), and
[spm](packages/spm/master) (Makefile-driven on Linux/macOS, direct-`mex` on
Windows, with an `[any]` fallback).

The `mip` tool itself lives in a separate repo, [mip-org/mip](https://github.com/mip-org/mip);
the build workflow checks it out at build time. References below to
`+mip/...` files point into that repo.

---

## Step 1 — Investigate the upstream repository

Before creating any files, clone the repository into a working directory
(outside this channel repo) and read through it:

```bash
git clone https://github.com/<owner>/<repo> /tmp/<repo>
```

Things to determine:

1. **License.** Open `LICENSE`, `LICENSE.txt`, `COPYING`, or the README. Only
   open-source licenses that permit redistribution are acceptable
   (MIT, BSD-2/3-Clause, Apache-2.0, GPL-2.0/3.0, LGPL, MPL-2.0, etc.). If
   no license is present, the project is **not** redistributable — stop. If
   the project is clearly source-available but the file is missing, ask the
   upstream author to clarify before proceeding. Record the SPDX identifier
   to use as the `license:` field in `mip.yaml`. If the source is intentionally
   permissive but lacks an SPDX file, use `unspecified`.

   **MathWorks license.** Packages authored by The MathWorks typically ship a
   BSD-3-Clause variant whose third clause limits the end-user grant to
   "MathWorks products and service offerings" (e.g.
   [dotenv](packages/dotenv/1.1.4/mip.yaml)). Redistribution is permitted, so
   the channel may carry these. Set `license: "LicenseRef-MathWorks"` and note
   the use restriction in the package `README.md` (Step 7).

   **Custom / non-standard licenses.** Some projects ship a bespoke license
   that permits redistribution but adds conditions (non-commercial use,
   attribution requirements, research-only grants, etc.) and therefore
   doesn't map to any SPDX standard identifier. Confirm the terms actually
   allow redistribution — if they do, set `license: "LicenseRef-<PackageName>"`
   (e.g. `LicenseRef-Inpoly` for a custom non-commercial license). The
   `LicenseRef-` prefix is SPDX's escape hatch for user-defined identifiers,
   and a per-package suffix — rather than a generic `LicenseRef-Custom` —
   keeps distinct license families distinguishable to tooling and auditors.
   Spell out the restriction in the package `README.md` (Step 7). Do **not**
   use `unspecified` for this case — that identifier is reserved for projects
   that are intentionally permissive but simply lack a formal SPDX file.

2. **Security review.** Skim the source for anything that would make
   distribution inappropriate: hard-coded credentials, unsanitized `eval` of
   untrusted input, network calls to suspicious endpoints, large pre-built
   binaries of unclear provenance, vendored dependencies under restrictive
   licenses. If anything looks problematic, do not include the package.

3. **Version selection.** Look at the repository's tags
   (`git tag --sort=-v:refname | head`) and releases page. Choose either:
   - **A tagged release** — preferred for stability. The release directory and
     `mip.yaml` `version:` use the tag name with any `v`/`V` prefix stripped,
     normalized to a numeric form like `x`, `x.y`, or `x.y.z` (e.g. tag
     `v1.4.1` → version `1.4.1`). The `source.yaml` `branch:` keeps the full
     tag (`v1.4.1`). See [sedumi](packages/sedumi/1.3.8).
   - **The default branch (`main` or `master`)** — when the project has no
     tags, or you specifically want the latest development tip. Use `main` or
     `master` literally as the release directory name, and leave `mip.yaml`
     `version:` blank. The daily scheduled probe will rebuild a branch-tracked
     package whenever the upstream branch advances. See
     [spm](packages/spm/master), [cmocean](packages/cmocean/main).

   See Step 3/4 for the exact version rules the prepare step enforces.

4. **MATLAB layout.** Identify which subdirectories contain the `.m` files
   that users should have on their MATLAB path. Common patterns:
   - All `.m` files at the repo root → `paths: [{path: "."}]`
   - A `matlab/` subdirectory → `paths: [{path: "matlab"}]`
   - A nested toolbox tree where every directory matters →
     `paths: [{path: ".", recursive: true}]` (see [flam](packages/flam))

5. **MEX / native code.** Look for `.c`, `.cpp`, `.cu`, `.f`, `.f90` files
   alongside MATLAB sources, or `mex` calls in the README/install
   instructions. If MEX compilation is required, you will need a `compile.m`
   (Step 5). The architectures this channel can build are:

   - `linux_x86_64`
   - `macos_arm64`
   - `windows_x86_64`

   (`macos_x86_64` is **not** a supported channel architecture.) Most C/C++
   MEX builds work on all three; Fortran or CUDA may be more restrictive.

   **Don't reuse upstream's pre-compiled binaries.** Some upstream repos ship
   `.mexa64` / `.mexmaca64` / `.mexw64` files alongside the source. We don't
   carry those forward — the channel always rebuilds MEX from source on its
   own CI runners, so we control the toolchain flags and static-linking
   posture of every binary we ship. `mip bundle`'s prepare step calls
   `+mip/+build/strip_mex_binaries.m` to sweep all MEX extensions out of the
   source tree **before** running `compile.m`, so even if upstream ships them,
   they never make it into the `.mhl`. This means:

   - If the upstream repo contains `.c` / `.cpp` / `.f` sources, write a
     `compile.m` and the architecture-specific builds that invoke it.
   - If the upstream project ships **only** pre-built binaries (no sources),
     you can't add it with the channel's normal flow. Locate the upstream
     C/C++ source tree and build from there, or skip the package.
   - Native shared libraries / archives that aren't MATLAB MEX (`.so`,
     `.dylib`, `.dll`, `.a`, `.lib`, `.jar`) are **not** auto-stripped.
     Evaluate per package whether they are build inputs (keep) or stale
     artifacts (add to `remove_dirs` in `source.yaml`).

6. **Package name normalization.** Pick a single **canonical** name and use it
   identically in the directory name under `packages/`, the `name:` field in
   `mip.yaml`, and the generated `.mip.json` metadata. Rules:

   - **Must be all lowercase.** The prepare step rejects non-lowercase names
     (see [`mip-channel prepare`](https://github.com/mip-org/mip_channel_tools/blob/main/src/mip_channel_tools/prepare.py) —
     "package name must be lowercase"). `TFOCS` → `tfocs`, `matGeom` →
     `matgeom`.
   - **`-` and `_` are both allowed.** Match the upstream spelling when
     there's an obvious one — `matlab_progressbar` stays `matlab_progressbar`,
     `aabb-tree` stays `aabb-tree`. Don't mechanically convert between them.

   The `mip` CLI normalizes user input (lowercase, `-`↔`_`) when resolving a
   typed name, so users can type `MatGeom` and still reach `matgeom`. The
   upstream project's display name may still appear in prose, URLs, and
   `subdirectory:` entries that point at upstream layout — only the mip package
   identifier is lowercased.

   **Filename encoding.** `.mhl` / `.mhl.mip.json` files and release tags
   follow `<name>-<version>-<arch>.mhl` and use `-` as a field separator, so
   **in filenames only** a `-` in the canonical name is encoded as `_` (e.g.
   `aabb-tree` → `aabb_tree-master-any.mhl`). The bundler handles this — don't
   be surprised when the filename differs from the canonical name.

7. **Existing `mip.yaml`.** If the upstream repository already ships a valid
   `mip.yaml` at the path that becomes the package root (after
   `subdirectory`/`remove_dirs`), you don't need to provide one — `source.yaml`
   alone is enough. Most third-party projects won't ship one, so you'll be
   writing it.

---

## Step 2 — Create the release directory

```
packages/<name>/<release>/
  source.yaml             # required — where to fetch the source from
  mip.yaml                # required unless the upstream repo provides one
  compile.m               # optional — only if MEX/native compilation is needed
  compile_windows.m       # optional — Windows-specific compile (see Step 5)
  test_<name>.m           # optional but strongly recommended
  README.md               # required when the bundle differs from upstream
  example.m               # optional — runnable usage example
```

The `<release>` directory name is the version (Step 3/4): either a numeric
version (`1.2.9`) matching `mip.yaml` `version:`, or a branch name
(`master`, `main`) for branch-tracked packages.

---

## Step 3 — Write `source.yaml`

`source.yaml` tells the prepare step where to fetch the upstream source. It is
processed by [`mip-channel prepare`](https://github.com/mip-org/mip_channel_tools/blob/main/src/mip_channel_tools/prepare.py).

### Minimal form (clone default branch)

```yaml
source:
  git: "https://github.com/<owner>/<repo>"
```

### All supported fields

```yaml
source:
  git: "https://github.com/<owner>/<repo>"   # repo URL (required if using git)
  branch: "v1.4.1"                            # branch OR tag name (optional)
  subdirectory: "matlab"                      # extract only this subdir (optional)
  remove_dirs: [html, deprecated, dev]        # delete these dirs after clone (optional)
```

### Alternate: ZIP source

If a project has no public git repo, a direct ZIP URL works:

```yaml
source:
  zip: "https://example.com/path/to/release.zip"
  remove_dirs: [html, deprecated]   # optional — same semantics as the git form
```

`subdirectory:` is **not** supported for zip sources. This channel currently
sources everything from upstream git repositories.

### Version rules (enforced by the prepare step)

`validate_channel_version_rules` in
[`mip-channel prepare`](https://github.com/mip-org/mip_channel_tools/blob/main/src/mip_channel_tools/prepare.py) enforces:

- **`source.yaml` must not contain a `version:` field.** The release directory
  name *is* the version.
- **`mip.yaml` `version:` must be blank or numeric** (`x`, `x.y`, `x.y.z`).
- **The release directory name must equal either `mip.yaml`'s `version:` or
  the recipe's `source.branch`.**

So the two valid shapes are:

- *Tagged release:* dir `1.4.1`, `mip.yaml` `version: "1.4.1"`, recipe
  `branch: "v1.4.1"` (dir matches the version).
- *Branch-tracked:* dir `master`, `mip.yaml` `version:` blank, recipe with no
  `branch:` or `branch: master` (the equality check is skipped when the
  version is blank).

### Notes

- `branch:` accepts a branch name (`main`, `master`) **or** a tag name
  (`v1.4.1`) — git treats both the same for cloning.
- `subdirectory:` is for repos that keep the MATLAB code under a nested folder
  (e.g. matGeom's code lives in `matGeom/` — see
  [matgeom source.yaml](packages/matgeom/1.2.9/source.yaml)). Only with `git:`.
- `remove_dirs:` trims trees that shouldn't ship at all — pre-rendered HTML
  docs, deprecated/legacy code, developer scaffolding, or vendored heavy
  third-party code that `compile.m` disables. For `tests/`, `examples/`, and
  `benchmarks/` — which users may reasonably want — prefer shipping them and
  declaring `extra_paths` in `mip.yaml` (Step 4) instead of deleting them.
- The `.git/` directory is removed automatically after clone.

---

## Step 4 — Write `mip.yaml`

`mip.yaml` is the package manifest, consumed by
`+mip/+config/read_mip_yaml.m` and the build pipeline in `+mip/+build/`.

### Minimal form (pure MATLAB, no compilation)

```yaml
name: my_package
description: "One-line description of the package."
version: "1.0.0"
license: "MIT"
homepage: "https://github.com/owner/repo"
repository: "https://github.com/owner/repo"
dependencies: []

paths:
  - path: "."

builds:
  - architectures: [any]
```

### Top-level fields

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Canonical package name. **Required.** Matches the directory name; all lowercase. |
| `version` | string | Version string. Must match the release directory name, or be blank for a branch-tracked package. Quote it (`"1.0"`) so YAML doesn't coerce it to a number. |
| `description` | string | Short human-readable summary. |
| `license` | string | SPDX identifier (`"MIT"`, `"BSD-3-Clause"`, `"GPL-2.0"`, `"LicenseRef-MathWorks"`, …). |
| `homepage` | string | Project homepage URL. |
| `repository` | string | Source repository URL. |
| `dependencies` | list | Other mip packages needed at load time (e.g. `["chebfun"]`). Resolved via mip's channel priority. |
| `paths` | list | Default `addpath` entries (below). May be overridden per-build. |
| `extra_paths` | mapping | Named groups of optional dirs users opt into via `mip load --with <group>` (below). |
| `builds` | list | One or more build entries (below). **Required.** |

### `paths`

Each entry adds directories to the MATLAB path on load. Resolved by
`+mip/+build/compute_addpaths.m`. Two forms:

```yaml
paths:
  - path: "matlab"                  # add a single directory (relative to package root)
  - path: "."                       # the package root itself
    recursive: true                 # add this dir AND every subdir containing .m files
    exclude: ["test", "paper"]      # skip these subdir names when recursing
```

`recursive: true` walks the tree and includes any directory with at least one
`.m` file. Directories starting with `.`, `+` (namespaces), or `@` (classes)
are excluded automatically — MATLAB discovers those without an explicit
`addpath`. See [flam](packages/flam) for a recursive example.

### `extra_paths`

`extra_paths` declares **named groups** of optional directories **not** added
on a plain `mip load <package>`. Users opt in with
`mip load <package> --with <group>` (repeatable). This is the right home for
`examples/`, `tests/`, `benchmarks/` — useful to some, noise for everyone else.

```yaml
paths:
  - path: "."

extra_paths:
  examples:
    - path: "examples"
  tests:
    - path: "tests"
```

`mip load my_package` adds only the root; `mip load my_package --with examples`
additionally puts `examples/` on the path. `tests`, `examples`, `benchmarks`
are the conventional group names. See [sedumi](packages/sedumi/1.3.8/mip.yaml)
for an `extra_paths: examples:` example.

### `builds`

The `builds:` list is a sequence of build entries. On a target architecture,
`mip bundle` picks the **first** entry whose `architectures:` list contains an
exact match, falling back to the first entry that lists `any`
(`+mip/+build/match_build.m`).

| Field | Description |
| --- | --- |
| `architectures` | List of architecture strings this build applies to. **Required.** |
| `compile_script` | Path (relative to package root) to a MATLAB script that compiles MEX/native code. Run by `+mip/+build/run_compile.m`. |
| `test_script` | Path to a MATLAB script run after install by `mip test`. |
| `paths` | Per-build override of the top-level `paths`. |

Supported architecture values: `linux_x86_64`, `macos_arm64`,
`windows_x86_64`, and `any` (pure MATLAB, runs everywhere).

> A build entry may instead use the singular `architecture:` (one arch per
> entry) with a flat `setup:` list; package-level `compile_script` /
> `test_script` / `paths` then act as defaults. Both shapes are supported; the
> list form is the common one. See [notes/MIP-YAML-BUILDS.md](notes/MIP-YAML-BUILDS.md).

### Common patterns

**Pure MATLAB, runs anywhere:**

```yaml
builds:
  - architectures: [any]
```

**MEX-compiled, one test for all platforms** (see
[sedumi](packages/sedumi/1.3.8/mip.yaml)):

```yaml
builds:
  - architectures: [linux_x86_64, macos_arm64, windows_x86_64]
    compile_script: compile.m
    test_script: test_my_package.m
```

**Separate Windows compile script** (see
[fmmlib2d](packages/fmmlib2d/1.2.4/mip.yaml)):

```yaml
builds:
  - architectures: [linux_x86_64, macos_arm64]
    compile_script: compile.m
    test_script: test_my_package.m
  - architectures: [windows_x86_64]
    compile_script: compile_windows.m
    test_script: test_my_package.m
```

**MEX where some platforms compile and others fall back to pure MATLAB** (see
[spm](packages/spm/master/mip.yaml)):

```yaml
builds:
  - architectures: [linux_x86_64, macos_arm64]
    compile_script: compile.m
    test_script: test_my_package_mex.m
  - architectures: [windows_x86_64]
    compile_script: compile_windows.m
    test_script: test_my_package_mex.m
  - architectures: [any]
    test_script: test_my_package.m
```

The `[any]` entry is a catch-all for architectures not listed explicitly. Keep
it when the MEX layer is optional — it lets users on unsupported architectures
still load the pure-MATLAB parts. When you have a MEX build **and** an `[any]`
fallback, use **two test scripts** (Step 6): the MEX test must call **every**
shipped MEX (CI fails the build otherwise); the `[any]` test exercises only the
pure-MATLAB layer.

---

## Step 5 — Write `compile.m` (only if needed)

If a build entry references `compile_script: compile.m`, you must provide it.
The script:

- Runs with `pwd` set to the **package source root** (cloned upstream source
  plus overlaid channel files).
- Compiles every MEX the package needs and places the output next to its
  source so the `addpath` entries pick it up.
- Depends only on a working `mex` toolchain (and system tools like `cmake` if
  needed) — nothing outside the package directory.
- Compiles for a generic machine of the target platform. **No `-march=native`**
  or other CPU-specific flags.
- Calls `error()` on any failure — the bundle pipeline aborts on error, which
  is what you want.

### Build environment

The MEX toolchain is selected by
[`scripts/setup_mex_compilers.m`](scripts/setup_mex_compilers.m) before
`compile.m` runs (so a plain `mex(...)` call uses the right compiler):

- **Linux** builds run in the `mathworks/matlab-deps:r2022a-ubi8` container
  with `gcc-toolset-10`, pinning the glibc floor to 2.28 for portability across
  the RHEL/Rocky 8 fleet; a "glibc gate" checks the output binaries.
- **macOS** builds run natively on `macos-14` (Apple Silicon).
- **Windows** builds use MinGW-w64 8.1.0 with MATLAB's static-linking
  `mingw64.xml`; CMake-based packages can use vcpkg (see
  [vcpkg-triplets/](vcpkg-triplets/)).

### Patterns from existing packages

- Many single-file MEX linking MATLAB's BLAS (`-lmwblas`) —
  [sedumi/compile.m](packages/sedumi/1.3.8/compile.m).
- Fortran + a mwrap gateway, with a separate Windows script —
  [fmmlib2d/compile.m](packages/fmmlib2d/1.2.4/compile.m) and
  [fmmlib2d/compile_windows.m](packages/fmmlib2d/1.2.4/compile_windows.m).
- CMake + vcpkg with heavy features trimmed to fit CI, plus a `patchelf`
  post-build pass — [gptoolbox/compile.m](packages/gptoolbox/master/compile.m).
- Driving an upstream recursive Makefile on Linux/macOS, then reproducing the
  same build as direct `mex()` calls on Windows —
  [spm/compile.m](packages/spm/master/compile.m) and
  [spm/compile_windows.m](packages/spm/master/compile_windows.m).

### Windows MEX

The Windows runner provides MinGW-w64; `setup_mex_compilers.m` points `mex` at
`mingw64.xml` (C) / `mingw64_g++.xml` (C++), both of which **link the MinGW
runtime statically**, so the resulting `.mexw64` carries no MinGW DLL
dependency. The channel convention is to drive `mex()` **directly** from a
`compile_windows.m` rather than rely on an upstream Unix Makefile (which assumes
`sh`/`rm`/`mv`/`uname`). See
[fmmlib2d/compile_windows.m](packages/fmmlib2d/1.2.4/compile_windows.m) for a
small example and [spm/compile_windows.m](packages/spm/master/compile_windows.m)
for a large one (it reproduces an entire recursive-make build — a static
archive built with MinGW `ar`, dozens of core MEX, and the bundled externals —
as direct `mex` calls).

For CMake-driven Windows builds with native third-party deps, use vcpkg with
the `x64-windows-static-md` triplet (static deps, dynamic MSVC runtime):
`-DVCPKG_TARGET_TRIPLET=x64-windows-static-md`,
`-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL`,
`-DCMAKE_POLICY_DEFAULT_CMP0091=NEW`.

### Static linking (required)

**Ship statically linked MEX binaries.** `.mhl` archives load on arbitrary
end-user machines where matching Boost / CGAL / Eigen / libstdc++ versions
aren't guaranteed. Only OS-provided libraries (libc, libpthread, libm on Linux;
libSystem, libc++ on macOS; ucrtbase, MSVCP140 on Windows) should remain
dynamic.

- **Linux.** Link libstdc++/libgcc statically. Plain `mex`:
  `LDFLAGS=$LDFLAGS -static-libstdc++ -static-libgcc`. CMake: pass
  `-DCMAKE_SHARED_LINKER_FLAGS="-static-libstdc++ -static-libgcc"` (and the
  module-linker equivalent). vcpkg's `x64-linux` triplet builds static deps.
- **macOS.** Apple Clang doesn't support (or need) `-static-libstdc++` —
  `libc++` is OS-provided. vcpkg `arm64-osx` builds static deps. For Apple
  Silicon pass `-DCMAKE_OSX_ARCHITECTURES=arm64` and
  `-DMatlab_MEX_EXTENSION=mexmaca64`.
- **Windows.** The MEX must link the dynamic MSVC runtime (`/MD`) to match
  MATLAB's ABI, but third-party deps should be statically bundled (the
  `x64-windows-static-md` triplet above). MinGW builds via `mingw64.xml` are
  already statically linked.

Verify on a fresh machine or with `ldd` (Linux) / `otool -L` (macOS) /
`dumpbin /dependents` (Windows) — the dependency list should contain only
OS-provided libraries.

### Trimming for GitHub-runner budgets

Bundles build on GitHub-hosted runners (~14 GB disk, 6 h timeout/job).
CMake+vcpkg stacks pulling heavy deps (CGAL, Embree, Boost, GMP, MPFR, …) can
blow past either limit. When that happens, **disable the heavy optional
features** via CMake flags rather than dropping the whole MEX layer (gptoolbox
disables CGAL/Embree/El Topo through `-DLIBIGL_*=OFF`, shedding ~18 MEX so the
rest ship). Document anything disabled in the package `README.md` (Step 7).

### Linux CMake+MATLAB MEX: patch `DT_NEEDED` after build

When a CMake build links a MEX against MATLAB's own shared libraries, the
`.mexa64` can end up with absolute paths to the CI runner's MATLAB install
baked into `DT_NEEDED` (because MATLAB's `libmex.so`/`libmx.so` ship without a
`DT_SONAME`). On an end-user machine those paths don't exist and `mip test`
fails with `libmex.so: cannot open shared object file`. The fix is a post-build
`patchelf` pass in `compile.m`: rewrite each absolute `NEEDED` entry to its
basename (`patchelf --replace-needed /abs/.../libmex.so libmex.so <file>`), and
drop `libMatlabEngine.so` entirely (`--remove-needed`, since MATLAB doesn't add
its dir to `LD_LIBRARY_PATH` and classic `mx*`/`mex*`-API code doesn't call it).
See [gptoolbox/compile.m](packages/gptoolbox/master/compile.m) for a full block.
`patchelf` is installed by the build workflow's toolchain step, not in
`compile.m`.

### Clear `LD_LIBRARY_PATH` before `system()` calls on Linux

MATLAB injects its own `libcurl`/`libssl` into `LD_LIBRARY_PATH`, which is
ABI-incompatible with what system tools (e.g. vcpkg's bootstrap `curl`) expect.
At the top of a Linux `compile.m`:

```matlab
if isunix && ~ismac
    origLdPath = getenv('LD_LIBRARY_PATH');
    setenv('LD_LIBRARY_PATH', '');
    restoreLdPath = onCleanup(@() setenv('LD_LIBRARY_PATH', origLdPath));
end
```

`onCleanup` restores it when `run_compile` exits; CMake/GCC don't need MATLAB
on `LD_LIBRARY_PATH` at compile/link time.

### Other tips

- Use `ispc`, `ismac`, `isunix`, `computer('arch')` to switch per-platform
  flags.
- When shelling out to CMake/Make, pass `-j$(maxNumCompThreads)`.

---

## Step 6 — Write `test_<name>.m`

The test script is run by `mip test <name>` after the package is loaded, via
[`scripts/test_one.m`](scripts/test_one.m). It should:

- Use only the public API (it runs after `mip load`).
- **Exercise every MEX the package builds.** This is enforced: after
  `mip test`, `test_one.m` calls `assert_all_mex_exercised`, which diffs
  `mip.build.list_mex` (every `*.mex*` shipped in the package's own source dir)
  against MATLAB's `inmem` list (a MEX appears there only once it has been
  *invoked*). Any built-but-never-loaded MEX fails the build with
  `mip:test:mexNotExercised`. So a 30-MEX package's test must cause all 30 to
  load, or the package won't ship. (Loading is what's checked — a MEX that
  loads then errors on dummy args still counts; a MEX that won't load on the
  target machine is exactly what this catches.)
- `assert(...)` on each invariant that should hold.
- `fprintf('SUCCESS\n')` at the very end.
- Be deterministic — call `rng('default')` if randomness is involved.

### Skeleton

```matlab
% Test script for my_package.
rng('default');

fprintf('Testing some_function...\n');
out = some_function(1, 2);
assert(abs(out - 3) < 1e-12, ...
    sprintf('some_function returned %g, expected 3', out));

fprintf('SUCCESS\n');
```

> **Namespaced functions.** `exist('pkg.fcn', 'file')` returns `0` for
> functions inside a `+pkg` folder in many MATLAB versions. Assert with
> `~isempty(which('pkg.fcn'))` or check the file on disk instead.

### Covering many MEX

For a handful of MEX, call each with a small deterministic input and `assert`
the result (see [sedumi/test_sedumi_channel.m](packages/sedumi/1.3.8/test_sedumi_channel.m),
whose test was extended to exercise all 34 shipped MEX). For a package with
*many* MEX across unrelated domains — where genuine functional inputs are
impractical and some live in `private/` folders not callable by bare name — a
dynamic sweep that force-loads every shipped MEX is appropriate: enumerate the
`*.mex*` files, `cd` into each one's folder (so private/class-private MEX
resolve), and invoke it once inside `try/catch`. See
[spm/test_spm_mex.m](packages/spm/master/test_spm_mex.m), which keeps a few
genuine functional checks and adds the sweep for full coverage.

> If a `compile.m` builds different MEX sets per platform (e.g. drops a couple
> on Windows), the test must skip the same ones on those platforms so
> `built == loaded` stays balanced — see the Windows split in
> [gptoolbox](packages/gptoolbox/master).

### Two test scripts when you have a MEX build + `[any]` fallback

Ship **two** scripts and wire each build entry to its own `test_script:`:

- `test_<name>_mex.m` — exercises the pure-MATLAB layer **and every shipped
  MEX**. Used by the architecture-specific MEX builds.
- `test_<name>.m` — exercises only the pure-MATLAB layer. Used by the `[any]`
  fallback, where no MEX is built so the coverage gate is a no-op.

---

## Step 7 — `README.md` and `example.m`

A `README.md` in the release directory is **required whenever the bundled
package differs from upstream in ways a user might notice**: MEX features
disabled to fit CI, sub-toolboxes removed via `remove_dirs`, a license chosen
from a dual-license upstream, architectures where MEX isn't produced, etc.

At minimum, document:

- What the package does (one paragraph); author, license, version, upstream
  repository.
- How to install and load via `mip` (copy-paste block):

  ```matlab
  mip install --channel mip-org/dev <name>
  mip load <name>
  ```

- **What is shipped** — which subdirectories/modules are on the path after
  `mip load`.
- **What is not shipped**, if anything — removed sub-toolboxes, MEX disabled
  because a dependency is too heavy for CI, with a pointer to upstream for users
  who need those pieces.
- **Static linking / architecture matrix**, if the package has a MEX build —
  which architectures get binaries and the fact that they're statically linked.
- **Tests** — which `test_<…>.m` scripts ship and roughly what each exercises.

See [sedumi/README.md](packages/sedumi/1.3.8/README.md) and
[spm/README.md](packages/spm/master/README.md) for examples covering an
architecture matrix, static linking, and a per-build test split.

An `example.m` shows minimal end-to-end usage, beginning with the install/load
line so a user can copy-paste it:

```matlab
mip install --channel mip-org/dev my_package
mip load my_package

% ... example body ...
```

---

## Step 8 — Verify locally (optional but recommended)

Install the channel tooling once (`pip install "git+https://github.com/mip-org/mip_channel_tools.git@main"`) if needed. Prepare a
single `(package, architecture)` pair the same way CI does:

```bash
python3 -m mip_channel_tools prepare \
  --package-path packages/<name>/<release> \
  --architecture <arch>
```

This writes `build/prepared/<name>-<release>/`. Then, in MATLAB from the repo
root, set the architecture and bundle:

```bash
BUILD_ARCHITECTURE=<arch> matlab -batch "addpath('mip'); addpath('scripts'); bundle_one"
```

(`mip` here is the checked-out tool repo; `bundle_one` calls
`setup_mex_compilers` then `mip.bundle`.) If it produces a `.mhl` plus
`.mhl.mip.json` under `build/bundled/`, the packaging layer is sound.

### End-to-end (install → load → test)

Bundling doesn't run the `test_script`. To exercise the full flow against the
prepared tree, use `mip`'s editable install:

```bash
matlab -batch "mip('install', '-e', '/abs/path/to/build/prepared/<name>-<release>'); mip('test', '<name>')"
```

`-e` installs a thin wrapper pointing at the prepared directory (no `.mhl`, no
GitHub roundtrip). `mip test` loads the package, runs the matching build
entry's `test_script`, and — for a MEX build — applies the coverage gate. A
successful run ends with the test's `SUCCESS` print. Tear down afterward:

```bash
matlab -batch "mip('uninstall', '<name>')"
rm -rf build/
```

---

## Step 9 — Hand off for commit and push

When you (the assistant working on this channel) finish writing the new files
under `packages/<name>/<release>/`, **stop there**. Do **not** run `git add`,
`git commit`, or `git push` unless the user explicitly asks in the current
turn. Summarize what you changed, point at the files, and let the user inspect
and commit.

Once the user pushes to `main`, the `push-build.yml` workflow dispatches a
build for each `(package, architecture)` pair the push touched; each runs
prepare → bundle (`compile.m`) → test (with the coverage gate) → upload `.mhl`
→ refresh the index. A build can also be requested via a GitHub issue (title
starting with `Build`, an admin replying `approve`) — see [README.md](README.md).

After the workflow completes, users install with:

```matlab
mip install --channel mip-org/dev <name>
mip load <name>
mip test <name>      % if you provided a test_<name>.m
```
