# mip-core

[Table of published packages](https://mip-org.github.io/mip-core/packages.html)

## Setup

After cloning the repository, initialize the submodules:

```bash
git submodule update --init --recursive
```

## Developing and Testing New Packages

1. Create a directory in `packages/` with a `prepare.yaml` file (see existing packages for examples)

2. Build and test:
```bash
rm -rf build
python scripts/prepare_packages.py --package package_name --force
matlab -batch "cd scripts; compile_packages"  # if compilation needed
python scripts/bundle_packages.py
mip uninstall package_name
mip install build/bundled/package_name-*.mhl
```
