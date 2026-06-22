# CLAUDE.md

Guidance for working in this repository.

## What this is

A MIP package channel. Packages live under `packages/<name>/<release>/` with
a `source.yaml` and (usually) a `mip.yaml` declaring supported architectures.
Builds run one `(package, architecture)` pair at a time via GitHub Actions.

## Layout

This repo holds only channel-specific content:

- `packages/<name>/<release>/` — package definitions.
- `.github/workflows/` — thin **caller** workflows. Each owns its event
  triggers (push, schedule, issues, dispatch) and concurrency, then delegates
  all logic to a reusable workflow in `mip-org/mip_channel_tools` via
  `uses: mip-org/mip_channel_tools/.github/workflows/<name>.yml@<ref>` with
  `secrets: inherit`. (`claude.yml` is the exception — a self-contained PR
  assistant.)

The build engine lives in its own repo, `mip-org/mip_channel_tools`: the
reusable workflows (build-package, assemble-index, push-build, scheduled-build,
build-request), the `mip-channel` CLI (`mip-channel-tools` package; subcommands
prepare, package-setup, upload, assemble-index, build-request, affected,
scheduled-check), the MATLAB build scripts (`bundle_one.m`, `test_one.m`, ...),
the MEX compiler configs (`mexopts/`), the shared vcpkg overlay triplets
(`vcpkg-triplets/`), the generic GitHub Pages site template (`site/`), and the
developer notes (`notes/`). A reusable workflow checks out the calling channel
by default (for `packages/`) and checks out its own repo at the called ref
(`job.workflow_sha`) into `mip_channel_tools/` for the scripts, site, and Python
package, e.g. MATLAB `addpath('mip_channel_tools/scripts')` and
`assemble-index --site-dir mip_channel_tools/site`. To run against a different
tooling branch, edit the `@<ref>` on the caller's `uses:` line.

## Conventions

- Record every notable change in `CHANGELOG.md`. Keep entries brief.
- Supported channel architectures: `any`, `linux_x86_64`, `macos_arm64`,
  `windows_x86_64`, `numbl_wasm`.
- Build requests are submitted via issues (title starts with `build`); each
  body line is `<name>@<release> <architecture>`. See `README.md` for details.
