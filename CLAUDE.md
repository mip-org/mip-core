# CLAUDE.md

Guidance for working in this repository.

## What this is

A MIP package channel. Packages live under `packages/<name>/<release>/` with
a `source.yaml` and (usually) a `mip.yaml` declaring supported architectures.
Builds run one `(package, architecture)` pair at a time via GitHub Actions.

## Layout

This repo holds only channel-specific content:

- `packages/<name>/<release>/` — package definitions.
- `site/` — this channel's static GitHub Pages site, copied into the published
  index by `mip-channel assemble-index`.
- `.github/workflows/` — build, scheduled, and issue-driven build triggers.
- `.github/actions/install-channel-tools/` — composite action that clones the
  shared tooling repo into `mip_channel_tools/` and `pip install`s its Python
  package (see below).

The shared build engine lives in its own repo, `mip-org/mip_channel_tools`, and
is cloned into `mip_channel_tools/` at CI time by the install action above. It
holds the `mip-channel` CLI (`mip-channel-tools` package; subcommands prepare,
package-setup, upload, assemble-index, build-request, affected,
scheduled-check), the MATLAB build scripts (`bundle_one.m`, `test_one.m`, ...),
the MEX compiler configs (`mexopts/`), the shared vcpkg overlay triplets
(`vcpkg-triplets/`), and the developer notes (`notes/`). Workflows reference it
from the clone, e.g. MATLAB `addpath('mip_channel_tools/scripts')`. The install
action is the single source of truth for the tooling repo URL and ref; edit its
`ref` input default (`main`) to develop against a different tooling branch.

## Conventions

- Record every notable change in `CHANGELOG.md`. Keep entries brief.
- Supported channel architectures: `any`, `linux_x86_64`, `macos_arm64`,
  `windows_x86_64`.
- Build requests are submitted via issues (title starts with `build`); each
  body line is `<name>@<release> <architecture>`. See `README.md` for details.
