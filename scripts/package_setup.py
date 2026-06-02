#!/usr/bin/env python3
"""Run a package's per-OS setup commands for a prepared package.

Reads build/prepared/<pkg>/mip.yaml, finds the build entry whose
`architectures:` list contains the requested architecture, and runs the
shell script under that entry's `setup:` field for the current OS.

The mip.yaml shape this script expects:

    builds:
      - architectures: [linux_x86_64, macos_arm64]
        setup:
          linux:
            - "sudo apt update"
            - "sudo apt install -y libfftw3-dev"
          macos:
            - "brew install fftw"
          windows:
            - "choco install -y some-tool"
        compile_script: compile.m

Each OS value is a list of shell commands (or a single string). List
items are joined with newlines and run as one `bash -eu -o pipefail`
script, so later items see variables/state from earlier items.

Keys are optional. A missing key is a no-op on that OS. If the package
declares no `setup:` block (or none for the current OS), this script
exits 0.

Block scalars (`|`, `>`) are intentionally avoided: mip's MATLAB-side
YAML parser doesn't support them, and the same mip.yaml is consumed by
both this Python script and `mip.bundle` in MATLAB.
"""

import argparse
import os
import subprocess
import sys

import yaml


def find_prepared_mip_yaml():
    prepared = os.path.join('build', 'prepared')
    if not os.path.isdir(prepared):
        return None
    subdirs = [
        d for d in os.listdir(prepared)
        if os.path.isdir(os.path.join(prepared, d))
    ]
    if len(subdirs) != 1:
        sys.exit(
            f'package_setup: expected exactly one prepared subdir, '
            f'found: {subdirs}'
        )
    path = os.path.join(prepared, subdirs[0], 'mip.yaml')
    if not os.path.isfile(path):
        sys.exit(f'package_setup: no mip.yaml at {path}')
    return path


def find_build_entry(config, arch):
    for b in (config.get('builds') or []):
        if arch in (b.get('architectures') or []):
            return b
    return None


def current_os_key():
    if sys.platform.startswith('linux'):
        return 'linux'
    if sys.platform == 'darwin':
        return 'macos'
    if sys.platform == 'win32':
        return 'windows'
    sys.exit(f'package_setup: unsupported platform {sys.platform}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--architecture', required=True)
    args = ap.parse_args()

    mip_yaml_path = find_prepared_mip_yaml()
    if mip_yaml_path is None:
        print('package_setup: no prepared dir; nothing to do.')
        return

    with open(mip_yaml_path) as f:
        config = yaml.safe_load(f) or {}

    build = find_build_entry(config, args.architecture)
    if build is None:
        print(f'package_setup: no build entry for {args.architecture}.')
        return

    setup = build.get('setup') or {}
    os_key = current_os_key()
    raw = setup.get(os_key)
    if raw is None:
        print(f'package_setup: no {os_key} setup for {args.architecture}.')
        return

    if isinstance(raw, list):
        script = '\n'.join(raw)
    elif isinstance(raw, str):
        script = raw
    else:
        sys.exit(
            f'package_setup: `setup.{os_key}` must be a string or a list '
            f'of strings, got {type(raw).__name__}'
        )

    if not script.strip():
        print(f'package_setup: empty {os_key} setup for {args.architecture}.')
        return

    print(f'--- Running {os_key} setup for {args.architecture} ---')
    print(script)
    print('---')
    subprocess.run(
        ['bash', '-eu', '-o', 'pipefail', '-c', script],
        check=True,
    )


if __name__ == '__main__':
    main()
