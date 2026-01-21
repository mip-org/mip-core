# mip-core

[Table of published packages](https://mip-org.github.io/mip-core/packages.html)

## Setup

After cloning the repository, initialize the submodules:

```bash
git submodule update --init --recursive
```

## Developing and Testing New Packages

1. Create a directory named `packages/package-name/releases/version` with a `prepare.yaml` file (see existing packages for examples)

2. Build and test:
```bash
rm -rf build
export PACKAGE_NAME=kdtree  # replace with your package name
export BUILD_ARCHITECTURE=linux_x86_64  # set to match the architecture in prepare.yaml
python scripts/prepare_packages.py --package $PACKAGE_NAME --force
matlab -batch "cd scripts; compile_packages"  # if compilation needed
python scripts/bundle_packages.py
mip uninstall $PACKAGE_NAME  # if already installed
mip install build/bundled/$PACKAGE_NAME-*.mhl
```

**Note:** The `BUILD_ARCHITECTURE` environment variable determines which package build variant to prepare locally. Set it to match one of the architecture values defined in your package's `prepare.yaml` file (e.g., `linux_x86_64`, `macos_x86_64`). This allows you to test building specific platform variants of your package.
