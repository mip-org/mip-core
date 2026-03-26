# MIP Channel

This repo is a [MIP](https://mip.sh) package channel. It hosts MATLAB packages as GitHub Release assets and publishes a package index via GitHub Pages.

## Creating your own channel

1. **Create from template** — click "Use this template" on [mip-org/mip-channel-template](https://github.com/mip-org/mip-channel-template) and name the new repo `mip-<channel_name>` (e.g., `mip-mylab`). The repo name must match the channel name.
2. **Enable GitHub Pages** — go to Settings > Pages and set source to "GitHub Actions".
3. **Add packages** — create directories under `packages/` (see below).
4. **Push to `main`** — the CI workflow will build, upload, and index your packages automatically.

## Adding a package

Create `packages/<name>/releases/<version>/prepare.yaml`:

```yaml
name: my_package
description: "What this package does"
version: "1.0.0"
dependencies: []
homepage: ""
repository: ""
license: "MIT"

defaults:
  release_number: 1
  prepare:
    clone_git:
      url: "https://github.com/someone/some-matlab-repo.git"
      destination: "my_package"
  addpaths:
    - path: "my_package"

builds:
  - architectures: [any]
```

Package names must use underscores (not hyphens). The version in the YAML must match the release folder name.

## Staying up to date

To pull in the latest infrastructure (scripts, workflows) from the base repo:

```bash
# First time only:
git remote add base https://github.com/mip-org/mip-channel-template.git

# To update:
git fetch base
git merge base/main --allow-unrelated-histories
```

The `--allow-unrelated-histories` flag is needed because template repos don't share git history with the base. Your `packages/` directory won't conflict since that's channel-specific.

## How it works

On every push to `main`, GitHub Actions:

1. **Prepares** packages — clones/downloads source, computes MATLAB paths, generates metadata
2. **Compiles** packages — runs MATLAB compile scripts if specified
3. **Bundles** packages — creates `.mhl` files (ZIP archives)
4. **Uploads** packages — stores `.mhl` files as GitHub Release assets (one release per package-version)
5. **Assembles index** — collects metadata from all releases into `index.json`
6. **Deploys** — publishes `index.json` and `packages.html` to GitHub Pages

The MATLAB client (`mip install <package>`) fetches the index from GitHub Pages and downloads `.mhl` files from the releases.

## Using this channel in MATLAB

Channels are specified as `gh_user/ch_name`, which maps to the repo `https://github.com/gh_user/mip-ch_name`.

```matlab
% Install a package from your channel
mip install --channel gh_user/ch_name <package_name>

% List available packages on your channel
mip avail --channel gh_user/ch_name
```
