#!/usr/bin/env bash
#
# Build, test, and publish a package release for THIS channel locally, using the
# exact same engine as CI. Intended for architectures GitHub Actions cannot
# build -- chiefly macos_x86_64 (Intel Mac), which MathWorks' mpm can no longer
# install on a CI runner. Run on a machine that has MATLAB, from the channel
# checkout root:
#
#   ./scripts/local_build.sh packages/<name>/<release> [flags...]
#
# Exact command to build the macos_x86_64 (Intel Mac) .mhl -- run this on the
# Intel Mac, from the root of a fresh `mip-core` checkout:
#
#   git clone https://github.com/mip-org/mip-core.git
#   cd mip-core
#   ./scripts/local_build.sh packages/fmm2d/main --architecture macos_x86_64
#
# (On an Intel Mac --architecture is optional: it auto-detects to macos_x86_64.
# Swap packages/fmm2d/main for the package/release you want to build.)
#
# Thin bootstrap (mirrors the .github/workflows thin callers): it only ensures
# the shared mip-org/mip_channel_tools engine is present, then delegates to it.
# All real logic lives in that repo so it is not duplicated per channel.
#
#   MIP_TOOLS_REF   tooling branch/tag to use   (default: main)
#   PYTHON          python interpreter           (default: python3)
#
# Flags after the package path are forwarded to `mip-channel local-build`
# (--architecture, --force, --no-test, --no-publish, --no-reindex, --matlab,
# --mip-dir, ...). Architecture defaults to the host native arch (Intel Mac ->
# macos_x86_64). The .mhl uploads to the package's GitHub Release and the
# channel index is rebuilt -- exactly as CI does for the other architectures.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
REF="${MIP_TOOLS_REF:-main}"

if [ -d mip_channel_tools/.git ]; then
  git -C mip_channel_tools fetch -q --depth 1 origin "$REF"
  git -C mip_channel_tools checkout -q FETCH_HEAD
else
  git clone -q --depth 1 --branch "$REF" \
    https://github.com/mip-org/mip_channel_tools.git mip_channel_tools
fi

exec bash mip_channel_tools/scripts/local_build.sh "$@"
