#!/usr/bin/env python3
"""
Prepare MATLAB packages from YAML specifications.

This script reads prepare.yaml files from packages/ and:
1. Downloads/clones source code based on YAML specifications
2. Computes all paths (including recursive paths with exclusions)
3. Collects exposed symbols
4. Creates load_package.m and unload_package.m scripts
5. Generates mip.json metadata
"""

import os
import sys
import json
import shutil
import subprocess
import time
import requests
import zipfile
import yaml
from datetime import datetime
from typing import List, Dict, Any, Optional

import argparse


def download_and_extract_zip(url: str, destination: str):
    """
    Download a ZIP file from a URL and extract it to destination.
    
    Args:
        url: The URL to download the ZIP file from
        destination: The directory name to extract to
    """
    download_file = "temp_download.zip"
    
    print(f'  Downloading {url}...')
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    
    with open(download_file, 'wb') as f:
        f.write(response.content)
    print('  Download complete.')
    
    print(f"  Extracting to {destination}...")
    with zipfile.ZipFile(download_file, 'r') as zip_ref:
        zip_ref.extractall(destination)
    
    os.remove(download_file)


def clone_git_repository(url: str, destination: str):
    """
    Clone a git repository and remove .git directories.
    
    Args:
        url: The URL of the git repository to clone
        destination: The directory name to clone into
    """
    print(f'  Cloning {url}...')
    subprocess.run(
        ["git", "clone", url, destination],
        check=True,
        capture_output=True
    )
    
    # Remove .git directories to reduce size
    print("  Removing .git directories...")
    for root, dirs, files in os.walk(destination):
        if ".git" in dirs:
            git_dir = os.path.join(root, ".git")
            shutil.rmtree(git_dir)
            dirs.remove(".git")


def collect_exposed_symbols(base_dir: str, extensions: List[str]) -> List[str]:
    """
    Collect exposed symbols from a directory.
    
    Args:
        base_dir: The directory to scan
        extensions: List of file extensions to include (e.g., ['.m', '.c'])
    
    Returns:
        List of symbol names
    """
    symbols = []

    if not os.path.exists(base_dir):
        return symbols

    items = os.listdir(base_dir)

    for item in sorted(items):
        item_path = os.path.join(base_dir, item)

        if os.path.isfile(item_path):
            # Check if file has one of the specified extensions
            for ext in extensions:
                if item.endswith(ext):
                    # Remove the extension
                    symbols.append(item[:-len(ext)])
                    break
        elif os.path.isdir(item_path) and (item.startswith('+') or item.startswith('@')):
            # Add package or class directory (without + or @)
            symbols.append(item[1:])
    
    return symbols


def generate_recursive_paths(base_path: str, exclude_dirs: List[str]) -> List[str]:
    """
    Generate a list of all subdirectories recursively, excluding specified directories.
    
    Args:
        base_path: The base directory to start from
        exclude_dirs: List of directory names to exclude
    
    Returns:
        List of relative paths
    """
    paths = []
    
    for root, dirs, files in os.walk(base_path):
        # Remove excluded directories from the search
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        # Add this directory if it contains .m files
        m_files = [f for f in files if f.endswith('.m')]
        if m_files:
            # Get relative path from base_path parent
            rel_path = os.path.relpath(root, os.path.dirname(base_path))
            paths.append(rel_path)
    
    return sorted(paths)


def create_load_and_unload_scripts(mhl_dir: str, paths: List[str]):
    """
    Create load_package.m and unload_package.m scripts.
    
    Args:
        mhl_dir: The MHL package directory
        paths: List of paths to add to MATLAB path
    """
    # Create load_package.m
    load_script_path = os.path.join(mhl_dir, 'load_package.m')
    with open(load_script_path, 'w') as f:
        f.write("function load_package()\n")
        f.write("    % Add package directories to MATLAB path\n")
        f.write("    pkg_dir = fileparts(mfilename('fullpath'));\n")
        for path in paths:
            f.write(f"    addpath(fullfile(pkg_dir, '{path}'));\n")
        f.write("end\n")
    
    # Create unload_package.m
    unload_script_path = os.path.join(mhl_dir, 'unload_package.m')
    with open(unload_script_path, 'w') as f:
        f.write("function unload_package()\n")
        f.write("    % Remove package directories from MATLAB path\n")
        f.write("    pkg_dir = fileparts(mfilename('fullpath'));\n")
        for path in paths:
            f.write(f"    rmpath(fullfile(pkg_dir, '{path}'));\n")
        f.write("end\n")


def get_current_platform_tag() -> str:
    """Get the current platform tag."""
    import platform
    system = platform.system().lower()
    machine = platform.machine().lower()
    
    if system == 'linux':
        if 'x86_64' in machine or 'amd64' in machine:
            return 'linux_x86_64'
        elif 'aarch64' in machine or 'arm64' in machine:
            return 'linux_aarch64'
    elif system == 'darwin':
        if 'arm64' in machine:
            return 'macos_arm64'
        else:
            return 'macos_x86_64'
    elif system == 'windows':
        return 'windows_x86_64'
    
    return 'any'


class PackagePreparer:
    """Handles preparing MATLAB packages from YAML specifications."""
    
    def __init__(self, dry_run=False, force=False, output_dir=None):
        self.dry_run = dry_run
        self.force = force
        self.base_url = "https://mip-packages.neurosift.app/core/packages"
        
        if output_dir:
            self.output_dir = output_dir
        else:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.output_dir = os.path.join(project_root, 'build', 'prepared')
        
        if not self.dry_run:
            os.makedirs(self.output_dir, exist_ok=True)
    
    def _get_mhl_filename(self, package_data: Dict[str, Any], build: Dict[str, Any]) -> str:
        """Generate the .mhl filename for a package build."""
        return (
            f"{package_data['name']}-{package_data['version']}-"
            f"{build['matlab_tag']}-{build['abi_tag']}-{build['platform_tag']}.mhl"
        )
    
    def _check_existing_package(self, mhl_filename: str, package_data: Dict[str, Any]) -> bool:
        """Check if package exists in bucket with matching metadata."""
        mip_json_url = f"{self.base_url}/{mhl_filename}.mip.json"
        
        try:
            response = requests.get(mip_json_url, timeout=10)
            if response.status_code == 404:
                print(f"  Package not found in bucket")
                return False
            
            response.raise_for_status()
            existing_metadata = response.json()
            
            # Compare key metadata fields
            fields_to_compare = [
                'name', 'description', 'version', 'release_number',
                'dependencies', 'homepage', 'repository', 'license'
            ]
            
            for field in fields_to_compare:
                if existing_metadata.get(field) != package_data.get(field):
                    print(f"  Metadata mismatch in field '{field}'")
                    return False
            
            print(f"  Package exists with matching metadata")
            return True
            
        except requests.RequestException as e:
            print(f"  Error checking existing package: {e}")
            return False
    
    def _prepare_package(self, package_dir: str, yaml_data: Dict[str, Any], 
                        build: Dict[str, Any], mhl_dir: str):
        """Prepare a single package."""
        prepare_config = yaml_data.get('prepare', {})
        
        # Change to the mhl_dir for downloads/clones
        original_dir = os.getcwd()
        os.chdir(mhl_dir)
        
        try:
            # Handle download_zip
            if 'download_zip' in prepare_config:
                if 'clone_git' in prepare_config:
                    raise ValueError("Cannot have both download_zip and clone_git in prepare.yaml")
                config = prepare_config['download_zip']
                download_and_extract_zip(config['url'], config['destination'])
            
            # Handle clone_git
            elif 'clone_git' in prepare_config:
                config = prepare_config['clone_git']
                clone_git_repository(config['url'], config['destination'])
            
            # Compute all paths
            addpaths_config = prepare_config.get('addpaths', [])
            all_paths = []
            
            for path_item in addpaths_config:
                if isinstance(path_item, str):
                    # Simple path string
                    all_paths.append(path_item)
                elif isinstance(path_item, dict):
                    path = path_item['path']
                    if path_item.get('recursive', False):
                        # Generate recursive paths
                        exclude = path_item.get('exclude', [])
                        full_path = os.path.join(mhl_dir, path)
                        recursive_paths = generate_recursive_paths(full_path, exclude)
                        all_paths.extend(recursive_paths)
                    else:
                        all_paths.append(path)
            
            print(f"  Computed {len(all_paths)} path(s)")

            # Remove all mex binaries from source tree, for security
            # for example, kdtree has windows and macos mex files checked in
            mex_extensions = ['.mexw64', '.mexa64', '.mexmaci64', '.mexmaca64', '.mexw32', '.mexglx', '.mexmac']
            print("  Removing mex binaries from source tree...")
            for root, dirs, files in os.walk(mhl_dir):
                for file in files:
                    if any(file.endswith(ext) for ext in mex_extensions):
                        file_path = os.path.join(root, file)
                        os.remove(file_path)
                        print(f"    Removed mex binary: {file_path}")
            
            # Create load/unload scripts
            create_load_and_unload_scripts(mhl_dir, all_paths)
            
            # Collect exposed symbols from all paths
            symbol_extensions = yaml_data.get('symbol_extensions', ['.m'])
            exposed_symbols = []
            
            for path in all_paths:
                full_path = os.path.join(mhl_dir, path)
                if os.path.exists(full_path):
                    symbols = collect_exposed_symbols(full_path, symbol_extensions)
                    exposed_symbols.extend(symbols)
            
            print(f"  Collected {len(exposed_symbols)} exposed symbol(s)")
            
            return exposed_symbols
            
        finally:
            os.chdir(original_dir)
    
    def _create_mip_json(self, mhl_dir: str, yaml_data: Dict[str, Any],
                        build: Dict[str, Any], exposed_symbols: List[str],
                        prepare_duration: float, mhl_filename: str):
        """Create mip.json metadata file."""
        mip_data = {
            'name': yaml_data['name'],
            'description': yaml_data['description'],
            'version': yaml_data['version'],
            'release_number': yaml_data['release_number'],
            'dependencies': yaml_data.get('dependencies', []),
            'homepage': yaml_data.get('homepage', ''),
            'repository': yaml_data.get('repository', ''),
            'license': yaml_data.get('license', ''),
            'matlab_tag': build['matlab_tag'],
            'abi_tag': build['abi_tag'],
            'platform_tag': build['platform_tag'],
            'usage_examples': yaml_data.get('usage_examples', []),
            'exposed_symbols': exposed_symbols,
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'prepare_duration': round(prepare_duration, 2),
            'compile_duration': 0,
            'mhl_url': f"{self.base_url}/{mhl_filename}"
        }
        
        mip_json_path = os.path.join(mhl_dir, 'mip.json')
        with open(mip_json_path, 'w') as f:
            json.dump(mip_data, f, indent=2)
    
    def prepare_package_dir(self, package_dir: str, *, release: Optional[str]) -> bool:
        """Prepare a single package directory."""
        package_name = os.path.basename(package_dir)
        print(f"\nProcessing package: {package_name}")

        releases_folder_path = os.path.join(package_dir, 'releases')

        for release_version in os.listdir(releases_folder_path):
            release_folder_path = os.path.join(releases_folder_path, release_version)
            if os.path.isdir(release_folder_path):
                if release is not None and release_version != release:
                    print(f"  Skipping release '{release_version}' (looking for '{release}')")
                    continue
                print(f"  Processing release: {release_version}")
                
            # Load YAML
            yaml_path = os.path.join(release_folder_path, 'prepare.yaml')
            if not os.path.exists(yaml_path):
                print(f"  Warning: No prepare.yaml found")
                return True
            
            with open(yaml_path, 'r') as f:
                yaml_data = yaml.safe_load(f)
            
            # Get BUILD_TYPE from environment
            build_type_env = os.environ.get('BUILD_TYPE', 'standard')
            
            # Find matching builds
            builds = yaml_data.get('builds', [])
            matching_builds = [b for b in builds if b.get('build_type') == build_type_env]
            
            if not matching_builds:
                print(f"  No builds match BUILD_TYPE={build_type_env}, skipping")
                return True
            
            # check that version in yaml matches release_version
            if yaml_data.get('version') != release_version:
                print(f"  Error: version in prepare.yaml ({yaml_data.get('version')}) does not match release folder name ({release_version}).")
                return False
            
            # Process each matching build
            for build in matching_builds:
                # Generate filename
                mhl_filename = self._get_mhl_filename(yaml_data, build)
                wheel_name = mhl_filename[:-4]  # Remove .mhl
                print(f"  Wheel name: {wheel_name}")
                
                # Check if exists
                if not self.force and self._check_existing_package(mhl_filename, yaml_data):
                    print(f"  Skipping - package already up to date")
                    continue
                
                if self.dry_run:
                    print(f"  [DRY RUN] Would prepare {wheel_name}.dir")
                    continue
                
                # Create output directory
                output_dir_path = os.path.join(self.output_dir, f"{wheel_name}.dir")
                
                if os.path.exists(output_dir_path):
                    print(f"  Removing existing directory")
                    shutil.rmtree(output_dir_path)
                
                os.makedirs(output_dir_path)
                print(f"  Output directory: {output_dir_path}")
                
                try:
                    # Prepare package
                    print(f"  Preparing package...")
                    prepare_start = time.time()
                    
                    exposed_symbols = self._prepare_package(
                        package_dir, yaml_data, build, output_dir_path
                    )
                    
                    prepare_duration = time.time() - prepare_start
                    print(f"  Prepare completed in {prepare_duration:.2f} seconds")
                    
                    # Create mip.json
                    print(f"  Creating mip.json...")
                    self._create_mip_json(
                        output_dir_path, yaml_data, build, exposed_symbols,
                        prepare_duration, mhl_filename, release=release_version
                    )
                    
                    # Copy compile script if specified
                    if 'compile_script' in build:
                        compile_script = build['compile_script']
                        compile_script_src = os.path.join(package_dir, compile_script)
                        if os.path.exists(compile_script_src):
                            compile_script_dst = os.path.join(output_dir_path, compile_script)
                            shutil.copy2(compile_script_src, compile_script_dst)
                            print(f"  Copied compile script: {compile_script}")
                        else:
                            print(f"  Warning: compile_script '{compile_script}' not found in package directory")
                    
                    print(f"  Successfully prepared {wheel_name}.dir")
                    
                except Exception as e:
                    print(f"  Error preparing package: {e}")
                    import traceback
                    traceback.print_exc()
                    
                    if os.path.exists(output_dir_path):
                        shutil.rmtree(output_dir_path, ignore_errors=True)
                    
                    return False
            
            return True
    
    def prepare_all_packages(self) -> bool:
        """Prepare all packages in packages/."""
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        packages_dir = os.path.join(project_root, 'packages')

        if not os.path.exists(packages_dir):
            print(f"Error: packages directory not found at {packages_dir}")
            return False
        
        # Get all package directories
        package_dirs = [
            os.path.join(packages_dir, d)
            for d in os.listdir(packages_dir)
            if os.path.isdir(os.path.join(packages_dir, d))
        ]
        
        if len(package_dirs) == 0:
            print("No package directories found")
            return False
        
        print(f"Found {len(package_dirs)} package(s)")
        print(f"Output directory: {self.output_dir}")
        print(f"BUILD_TYPE: {os.environ.get('BUILD_TYPE', 'standard')}")
        
        # Prepare each package
        all_success = True
        for package_dir in sorted(package_dirs):
            success = self.prepare_package_dir(package_dir)
            if not success:
                print(f"\nError: Preparation failed for {os.path.basename(package_dir)}")
                all_success = False
                break
        
        return all_success


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Prepare MATLAB packages from YAML specifications'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without building'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Rebuild packages even if they exist in the bucket'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        help='Directory where .dir packages will be created (default: build/prepared)'
    )
    parser.add_argument(
        '--package',
        type=str,
        help='Prepare only the specified package by name'
    )
    parser.add_argument(
        '--release',
        type=str,
        help='Prepare only the specified release of the package'
    )

    args = parser.parse_args()
    
    preparer = PackagePreparer(
        dry_run=args.dry_run,
        force=args.force,
        output_dir=args.output_dir
    )
    
    print("Starting package preparation process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual building will occur]")
    if args.force:
        print("[FORCE MODE - Will rebuild all packages]")
    
    if args.package:
        # Prepare single package
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        packages_dir = os.path.join(project_root, 'packages')
        package_dir = os.path.join(packages_dir, args.package)
        
        if not os.path.exists(package_dir):
            print(f"\n✗ Error: Package '{args.package}' not found at {package_dir}")
            return 1
        
        if not os.path.isdir(package_dir):
            print(f"\n✗ Error: '{args.package}' is not a directory")
            return 1
        
        print(f"Preparing single package: {args.package}")
        print(f"Output directory: {preparer.output_dir}")
        print(f"BUILD_TYPE: {os.environ.get('BUILD_TYPE', 'standard')}")
        
        success = preparer.prepare_package_dir(package_dir, release=args.release)
    else:
        # Prepare all packages
        success = preparer.prepare_all_packages()
    
    if success:
        print("\n✓ All packages prepared successfully")
        return 0
    else:
        print("\n✗ Preparation process failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
