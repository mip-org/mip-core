#!/usr/bin/env python3
"""
Run shell-based build scripts for prepared packages.

This script handles non-MATLAB build steps (e.g., emscripten/wasm builds).
It discovers .dir directories in build/prepared/, reads their corresponding
prepare.yaml to check for a build_script field, and executes matching shell
scripts.

This runs BEFORE compile_packages.m (which handles .m compile scripts).
"""

import os
import sys
import json
import shutil
import subprocess
import time
import yaml
import argparse


def build_all_packages(prepared_dir: str, packages_dir: str, architecture: str) -> bool:
    """Run build scripts for all prepared packages."""
    if not os.path.exists(prepared_dir):
        print(f"Prepared packages directory not found: {prepared_dir}")
        return True  # Nothing to do

    dir_entries = [
        d for d in os.listdir(prepared_dir)
        if os.path.isdir(os.path.join(prepared_dir, d)) and d.endswith('.dir')
    ]

    if not dir_entries:
        print("No .dir directories found")
        return True

    print(f"Found {len(dir_entries)} .dir package(s)")

    packages_with_build = 0
    for dir_name in sorted(dir_entries):
        dir_path = os.path.join(prepared_dir, dir_name)

        # Extract package name and version from directory name (format: name-version-arch.dir)
        base_name = dir_name[:-4]  # Remove .dir
        parts = base_name.split('-')
        package_name = parts[0]
        release_version = parts[1] if len(parts) > 1 else 'unspecified'

        # Find prepare.yaml
        yaml_path = os.path.join(packages_dir, package_name, 'releases', release_version, 'prepare.yaml')
        if not os.path.exists(yaml_path):
            print(f"\n{dir_name}: prepare.yaml not found at {yaml_path}, skipping")
            continue

        with open(yaml_path, 'r') as f:
            yaml_data = yaml.safe_load(f)

        defaults = yaml_data.get('defaults', {})
        builds = yaml_data.get('builds', [])

        # Find matching build and resolve build_script
        build_script = None
        for build in builds:
            archs = build.get('architectures', [])
            if architecture in archs or ('any' in archs and architecture == 'linux_x86_64'):
                # Resolve: build overrides defaults
                build_script = build.get('build_script', defaults.get('build_script'))
                break

        if not build_script:
            print(f"\n{dir_name}: No build_script for ARCHITECTURE={architecture}")
            continue

        build_script_path = os.path.join(dir_path, build_script)
        if not os.path.exists(build_script_path):
            print(f"\n{dir_name}: Build script not found: {build_script_path}")
            return False

        packages_with_build += 1
        print(f"\n{dir_name}: Running {build_script}...")

        # Read mip.json for build_env and build_only_sources
        mip_json_path = os.path.join(dir_path, 'mip.json')
        build_only_sources = []
        build_env_map = {}
        if os.path.exists(mip_json_path):
            with open(mip_json_path, 'r') as f:
                mip_data = json.load(f)
            build_only_sources = mip_data.get('build_only_sources', [])
            build_env_map = mip_data.get('build_env', {})

        # Set up environment with build_env (values are paths relative to dir_path)
        build_env = os.environ.copy()
        for env_var, rel_path in build_env_map.items():
            abs_path = os.path.abspath(os.path.join(dir_path, rel_path))
            build_env[env_var] = abs_path
            print(f"  Setting {env_var}={abs_path}")

        build_start = time.time()
        try:
            result = subprocess.run(
                ['bash', build_script_path],
                cwd=dir_path,
                env=build_env,
                check=True,
                capture_output=False,
            )
        except subprocess.CalledProcessError as e:
            print(f"  Build script failed with exit code {e.returncode}")
            return False

        build_duration = time.time() - build_start
        print(f"  Build completed in {build_duration:.2f} seconds")

        # Clean up build_only sources
        for destination in build_only_sources:
            build_only_path = os.path.join(dir_path, destination)
            if os.path.exists(build_only_path):
                print(f"  Cleaning up build_only source: {destination}")
                shutil.rmtree(build_only_path)

        # Update mip.json with build duration and remove build-time-only fields
        if os.path.exists(mip_json_path):
            with open(mip_json_path, 'r') as f:
                mip_data = json.load(f)
            mip_data['compile_duration'] = round(build_duration, 2)
            mip_data.pop('build_only_sources', None)
            mip_data.pop('build_env', None)
            with open(mip_json_path, 'w') as f:
                json.dump(mip_data, f, indent=2)

    print(f"\nPackages with build scripts: {packages_with_build}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description='Run shell-based build scripts for prepared packages'
    )
    parser.add_argument(
        '--prepared-dir',
        type=str,
        help='Directory containing .dir packages (default: build/prepared)'
    )

    args = parser.parse_args()

    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    prepared_dir = args.prepared_dir or os.path.join(project_root, 'build', 'prepared')
    packages_dir = os.path.join(project_root, 'packages')
    architecture = os.environ.get('BUILD_ARCHITECTURE', 'any')

    print("Starting build script execution...")
    print(f"BUILD_ARCHITECTURE: {architecture}")

    success = build_all_packages(prepared_dir, packages_dir, architecture)

    if success:
        print("\n✓ All build scripts completed successfully")
        return 0
    else:
        print("\n✗ Build script execution failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
