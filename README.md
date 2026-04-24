# MIP Channel

This repo is a [MIP](https://mip.sh) package channel. It hosts MATLAB packages as GitHub Release assets and publishes a package index via GitHub Pages.

## Creating your own channel

1. **Create from template** — click "Use this template" on [mip-org/mip-channel-template](https://github.com/mip-org/mip-channel-template) and name the new repo `mip-<channel_name>` (e.g., `mip-mylab`). The repo name must match the channel name.
2. **Enable GitHub Pages** — go to Settings > Pages and set source to "GitHub Actions".
3. **Add packages** — create directories under `packages/` (see below).
4. **Push to `main`** — the CI workflow will build, upload, and index your packages automatically.

## Adding a package

Each package needs a `recipe.yaml` (where to get the source) and a `mip.yaml` (package metadata and build config). The `mip.yaml` can live in the source repo or in the channel.

### Directory structure

```
packages/<name>/<version>/
  recipe.yaml       # Required: where to get the source
  mip.yaml          # Optional: overrides mip.yaml from source repo
  compile.m         # Optional: compilation script (channel-provided)
```

### recipe.yaml — source specification

```yaml
source:
  git: "https://github.com/someone/some-matlab-repo.git"
  branch: "main"              # optional
  subdirectory: "matlab"      # optional: extract specific subdir
  remove_dirs: [tests, docs]  # optional: remove after clone
```

### mip.yaml — package metadata

```yaml
name: my_package
description: "What this package does"
version: "1.0.0"
license: "MIT"
dependencies: []

paths:
  - path: "."

builds:
  - architectures: [any]
```

For packages that need compilation:

```yaml
builds:
  - architectures: [linux_x86_64, macos_x86_64, macos_arm64]
    compile_script: compile.m
```

Package names must use underscores (not hyphens). The version in the YAML must match the release folder name.

## How it works

On every push to `main`, GitHub Actions:

1. **Prepares** packages — clones/downloads source per `recipe.yaml`, overlays channel files
2. **Bundles** packages — runs `mip bundle` (compiles if needed, creates `.mhl` files)
3. **Uploads** packages — stores `.mhl` files as GitHub Release assets
4. **Assembles index** — collects metadata from all releases into `index.json`
5. **Deploys** — publishes `index.json` and `packages.html` to GitHub Pages

## Using this channel in MATLAB

```matlab
% Install a package from your channel
mip install --channel gh_user/ch_name <package_name>

% List available packages on your channel
mip avail --channel gh_user/ch_name
```
