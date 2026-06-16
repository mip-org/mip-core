# Per-architecture build sections in `mip.yaml`

## Context

Today a `builds:` entry lists `architectures: [a, b, …]` and its `setup:` block
is keyed by **OS family** (`linux`/`macos`/`windows`). This has two warts the
team hit while expanding the build system:

1. **Vocabulary mismatch / setup can't diverge per arch.** `architectures:` uses
   full triples (`linux_x86_64`) but `setup:` uses OS families. The OS key
   assumes "one OS ⇒ one package manager," which breaks the moment two arches of
   the same OS use different build images (e.g. a future `linux_aarch64` on an
   apt image vs `linux_x86_64` on ubi8/dnf) — a real possibility since the build
   container is already chosen **per architecture** in `build-package.yml`.
2. **No clean per-arch granularity.** Expressing per-arch setup today would mean
   arch-keyed setup, which lists each arch twice (in `architectures:` and as a
   setup key).

The fix: allow each `builds:` entry to target **one architecture** via a
singular `architecture:` key, with a **flat** `setup:` list (no OS sub-map). The
arch is named once; setup is unambiguously that arch's. Shared fields
(`compile_script`/`test_script`/`paths`) come from **package-level defaults**,
which `mip.build.resolve_build_config` **already implements** (it copies
top-level `paths`/`extra_paths`/`compile_script`/`test_script`/`build_on` as
defaults, then lets a build entry override them). This path is **tool-tested**:
`tests/helpers/createTestSourcePackage.m` emits `compile_script:` at top level
with a bare `builds: - architectures: [any]` entry, so `TestCompile` exercises
the default-merge. **Caveat:** no *shipping* package (mip-dev or mip-staging) uses
top-level defaults yet — all nest scripts inside `builds:` entries — so gptoolbox
would be the **first production adopter** (low risk: same code path the tests
drive). This also aligns the source vocabulary with the *built* artifact, whose
`mip.json` already uses singular `architecture` (`create_mip_json.m`).

**The change is additive.** Multi-arch `architectures: [list]` entries (e.g.
mip-staging's `manopt`/`spm`, which share one `compile.m` across three arches)
and OS-keyed `setup:` keep working unchanged. Nothing in this channel or
mip-staging breaks; packages adopt the new shape only when they want it.

## Final schema

```yaml
# package-level defaults (already supported by resolve_build_config)
compile_script: compile.m
test_script: test_gptoolbox_mex.m
paths: [...]

builds:
  - architecture: macos_arm64               # NEW: singular, one arch per section
    setup: ["brew install cmake cgal"]       # NEW: flat list (no os: key)
  - architecture: linux_x86_64
    setup: ["dnf install -y CGAL-devel boost-devel openblas-devel cmake m4 xz"]
  - architecture: windows_x86_64
    compile_script: compile_windows.m         # per-section override of a default
    setup: ["..."]
```

Still valid (unchanged semantics): multi-arch `architectures: [a, b]` entries and
OS-keyed `setup: { linux: [...], macos: [...] }`.

## Part A — `mip` tool (separate repo `mip-org/mip`; land FIRST, as a PR)

Work in the existing clone at `/tmp/mip-fix` on a **new branch** (independent of
the open strip-prebuilt-binaries PR).

1. **`+mip/+config/read_mip_yaml.m`** — in the builds-normalization loop
   (~line 98–103), accept a singular `architecture`: if a build entry has
   `architecture` and no `architectures`, set `b.architectures = {b.architecture}`.
   Keep the existing list coercion. This is the only selection-path change —
   `match_build.m`, `resolve_build_config.m`, `get_build_field.m` then work
   unchanged (they read `b.architectures`), and package-level defaults already
   work via `resolve_build_config`.
2. **Tests** — extend `tests/TestReadMipYaml.m` and `tests/TestMatchBuild.m` with
   a singular-`architecture` entry: assert it normalizes to a one-element
   `architectures` cell and that `match_build` selects it; assert a mixed file
   (some singular, some list, plus `any`) still resolves. Run `tests/run_tests.m`.
3. Optional: update the `+mip/init.m` template comment to show the singular form.

Backward-compat: list form untouched; `any` two-pass in `match_build` unchanged.

## Part B — channel (`mip-dev`; commit to main after the tool PR merges)

1. **Shared arch-list helper.** Add `build_architectures(build) -> list` to
   `tools/src/mip_channel_tools/config.py` (already imported by channel scripts):
   returns `build.get("architectures")` or `[build["architecture"]]` if the
   singular key is present, else `[]`. Replace the duplicated inline extraction
   in:
   - `tools/src/mip_channel_tools/prepare.py` → `architectures_from_mip_yaml` (line ~191)
   - `tools/src/mip_channel_tools/build_request.py` → the `declared` loop (line ~119)
   - `tools/src/mip_channel_tools/affected.py` → `arches_from_mip_yaml`
   - `tools/src/mip_channel_tools/scheduled.py` → its arch read
2. **`tools/src/mip_channel_tools/package_setup.py`** — two changes:
   - Find the build entry via the helper (so singular `architecture:` entries are
     found).
   - Setup resolution: if `build["setup"]` is a **list**, run it directly (the
     per-arch-section flat form); if it's a **dict**, keep today's OS-key
     behavior (`raw = setup.get(os_key)`). Backward compatible.
3. **Migrate `packages/gptoolbox/master/mip.yaml`** as the first adopter: hoist
   `compile_script`/`test_script` to top-level defaults, split into one
   `architecture: macos_arm64` and one `architecture: linux_x86_64` section, each
   with a flat `setup:` list (drop the `macos:`/`linux:` sub-keys). Leave
   `fmm2d`/`fmmlib2d`/others on the list+OS-keyed form (additive — migrate later
   if desired).
4. **Docs** — note both shapes in `README.md` (schema section); add a short
   `notes/MIP-YAML-BUILDS.md` capturing the per-arch-section design and when to
   use it vs a shared multi-arch entry.

## Critical files

- Tool: `+mip/+config/read_mip_yaml.m` (only selection change), tests
  `tests/TestReadMipYaml.m`, `tests/TestMatchBuild.m`. (`match_build.m`,
  `resolve_build_config.m`, `get_build_field.m` need **no** change.)
- Channel: `tools/src/mip_channel_tools/config.py` (helper), `tools/src/mip_channel_tools/package_setup.py`
  (setup list-or-dict + helper), `tools/src/mip_channel_tools/prepare.py`,
  `tools/src/mip_channel_tools/build_request.py`, `tools/src/mip_channel_tools/affected.py`,
  `tools/src/mip_channel_tools/scheduled.py`, `packages/gptoolbox/master/mip.yaml`.

## Verification

1. **Tool**: `tests/run_tests.m` in `/tmp/mip-fix` (singular-form cases green;
   list/`any` regressions pass). PR to `mip-org/mip`.
2. **Channel scripts (local, no network)**: feed a singular-form `mip.yaml`
   through `mip-channel prepare --architecture linux_x86_64` and
   `mip-channel build-request` (an `all` expansion) and confirm the arch
   resolves; run `mip-channel package-setup --architecture linux_x86_64` against the
   migrated gptoolbox mip.yaml and confirm it runs the flat `setup:` list. Also
   confirm an old list+OS-dict package (fmm2d) still resolves and runs its
   `linux:` setup (backward-compat).
3. **End-to-end**: push the migrated gptoolbox to `main`; the dispatched
   `linux_x86_64` + `macos_arm64` builds must still install deps via `setup:` and
   bundle (re-confirming the published `.mhl`s). Watch the "Run package setup" +
   "Bundle" steps.

## Sequencing

Tool PR first (so the channel's checked-out mip understands singular
`architecture:` at build time) → then channel commits + the gptoolbox migration.
