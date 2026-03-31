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
from channel_config import get_base_url, release_tag_from_mhl
import shutil
import subprocess
import time
import requests
import zipfile
import yaml
import hashlib
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


def clone_git_repository(url: str, destination: str, subdirectory: str | None = None, branch: str | None = None):
    """
    Clone a git repository and remove .git directories.

    Args:
        url: The URL of the git repository to clone
        destination: The directory name to clone into
        subdirectory: If specified, only copy this subdirectory from the repo
        branch: If specified, clone this branch or tag (passed as --branch to git clone)
    """
    branch_args = ["--branch", branch] if branch else []
    if subdirectory:
        # Clone to a temp directory, then copy only the subdirectory
        temp_clone_dir = destination + "_temp_clone"
        branch_info = f", branch: {branch}" if branch else ""
        print(f'  Cloning {url} (subdirectory: {subdirectory}{branch_info})...')
        subprocess.run(
            ["git", "clone"] + branch_args + [url, temp_clone_dir],
            check=True,
            capture_output=True
        )
        subdir_path = os.path.join(temp_clone_dir, subdirectory)
        if not os.path.isdir(subdir_path):
            shutil.rmtree(temp_clone_dir)
            raise ValueError(f"Subdirectory '{subdirectory}' not found in cloned repository")
        shutil.copytree(subdir_path, destination)
        shutil.rmtree(temp_clone_dir)
    else:
        branch_info = f" (branch: {branch})" if branch else ""
        print(f'  Cloning {url}{branch_info}...')
        subprocess.run(
            ["git", "clone"] + branch_args + [url, destination],
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


def resolve_git_commit_hash(url: str, ref: str) -> str:
    """
    Resolve a branch or tag to its commit hash using git ls-remote.

    Args:
        url: Git repository URL
        ref: Branch or tag name

    Returns:
        The commit hash string

    Raises:
        RuntimeError: If the ref cannot be resolved
    """
    try:
        result = subprocess.run(
            ["git", "ls-remote", url, ref],
            check=True, capture_output=True, text=True
        )
        for line in result.stdout.strip().splitlines():
            commit_hash, remote_ref = line.split('\t', 1)
            if remote_ref in (f"refs/heads/{ref}", f"refs/tags/{ref}", ref):
                return commit_hash
        raise RuntimeError(f"Could not resolve ref '{ref}' for {url}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"git ls-remote failed for {url} {ref}: {e}") from e


def normalize_prepare_sources(prepare_config) -> List[Dict[str, Any]]:
    """
    Normalize the prepare config into a list of source entries.

    Supports both the old dict format (single source):
        prepare:
          clone_git:
            url: ...
            destination: ...

    And the new list format (multiple sources):
        prepare:
          - clone_git:
              url: ...
              destination: ...
            build_only: true
    """
    if prepare_config is None:
        return []

    if isinstance(prepare_config, list):
        return prepare_config

    # Old dict format: wrap in a list
    return [prepare_config]


def resolve_build_config(defaults: Dict[str, Any], build: Dict[str, Any]) -> Dict[str, Any]:
    """
    Merge a build entry with defaults using simple replacement semantics.

    Fields in `build` override fields in `defaults`. No deep merging.
    The `architectures` key is consumed separately and not merged.
    """
    resolved = dict(defaults)
    for key, value in build.items():
        if key == 'architectures':
            continue
        resolved[key] = value
    return resolved


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


def compute_directory_hash(directory: str) -> str:
    """
    Compute a recursive SHA1 hash of a directory's contents.
    
    This hash is deterministic and based on:
    - All file paths (relative to the directory)
    - All file contents
    
    The hash is computed by:
    1. Walking the directory tree in sorted order
    2. For each file, hashing: relative_path + file_contents
    3. Combining all file hashes into a final directory hash
    
    Args:
        directory: The directory to hash
    
    Returns:
        SHA1 hash as a hexadecimal string
    """
    sha1 = hashlib.sha1()
    
    # Walk directory in sorted order for deterministic results
    for root, dirs, files in os.walk(directory):
        # Sort directories and files for deterministic ordering
        dirs.sort()
        files.sort()
        
        for filename in files:
            file_path = os.path.join(root, filename)
            relative_path = os.path.relpath(file_path, directory)
            
            # Hash the relative path
            sha1.update(relative_path.encode('utf-8'))
            sha1.update(b'\0')  # Separator
            
            # Hash the file contents
            try:
                with open(file_path, 'rb') as f:
                    while True:
                        chunk = f.read(8192)
                        if not chunk:
                            break
                        sha1.update(chunk)
            except (IOError, OSError) as e:
                # If we can't read a file, include the error in the hash
                sha1.update(f"ERROR:{e}".encode('utf-8'))
            
            sha1.update(b'\0')  # Separator between files
    
    return sha1.hexdigest()


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
        
        if output_dir:
            self.output_dir = output_dir
        else:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.output_dir = os.path.join(project_root, 'build', 'prepared')
        
        if not self.dry_run:
            os.makedirs(self.output_dir, exist_ok=True)
    
    def _get_mhl_filename(self, package_data: Dict[str, Any], architecture: str) -> str:
        """Generate the .mhl filename for a package build."""
        return (
            f"{package_data['name']}-{package_data['version']}-"
            f"{architecture}.mhl"
        )
    
    def _check_existing_package(self, mhl_filename: str, package_data: Dict[str, Any],
                                resolved_config: Dict[str, Any],
                                source_hash: str) -> bool:
        """Check if package exists in bucket with matching metadata and source hash."""
        pkg_name = release_tag_from_mhl(mhl_filename)
        base_url = get_base_url(pkg_name)
        mip_json_url = f"{base_url}/{mhl_filename}.mip.json"

        try:
            response = requests.get(mip_json_url, timeout=10)
            if response.status_code == 404:
                print(f"  Package not found in bucket")
                return False

            response.raise_for_status()
            existing_metadata = response.json()

            # First check source_hash - this is the most important check
            existing_source_hash = existing_metadata.get('source_hash')
            if existing_source_hash != source_hash:
                print(f"  Source hash mismatch (existing: {existing_source_hash}, new: {source_hash})")
                return False

            # Compare key metadata fields from identity (top-level)
            identity_fields = [
                'name', 'description', 'version',
                'dependencies', 'homepage', 'repository', 'license'
            ]
            for field in identity_fields:
                if existing_metadata.get(field) != package_data.get(field):
                    print(f"  Metadata mismatch in field '{field}'")
                    return False

            # Compare release_number from resolved config
            if existing_metadata.get('release_number') != resolved_config.get('release_number'):
                print(f"  Metadata mismatch in field 'release_number'")
                return False

            print(f"  Package exists with matching metadata and source hash")
            return True

        except requests.RequestException as e:
            print(f"  Error checking existing package: {e}")
            return False
    
    def _prepare_package(self, package_dir: str, resolved_config: Dict[str, Any],
                        mhl_dir: str):
        """Prepare a single package.

        Args:
            package_dir: The package source directory
            resolved_config: The resolved build config (defaults merged with build overrides)
            mhl_dir: The output directory for the prepared package
        """
        prepare_sources = normalize_prepare_sources(resolved_config.get('prepare'))

        # Change to the mhl_dir for downloads/clones
        original_dir = os.getcwd()
        os.chdir(mhl_dir)

        try:
            # Process each source entry
            for source in prepare_sources:
                if 'download_zip' in source:
                    config = source['download_zip']
                    download_and_extract_zip(config['url'], config['destination'])
                elif 'clone_git' in source:
                    config = source['clone_git']
                    clone_git_repository(config['url'], config['destination'], config.get('subdirectory'), config.get('branch'))
                    # Remove specified directories after cloning
                    for dir_name in config.get('remove_dirs', []):
                        dir_path = os.path.join(config['destination'], dir_name)
                        if os.path.isdir(dir_path):
                            shutil.rmtree(dir_path)
                            print(f"    Removed directory: {dir_path}")

            # Compute all paths (addpaths is now a sibling of prepare, not nested inside it)
            addpaths_config = resolved_config.get('addpaths', [])
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
            symbol_extensions = resolved_config.get('symbol_extensions', ['.m'])
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
                        resolved_config: Dict[str, Any], architecture: str,
                        exposed_symbols: List[str],
                        prepare_duration: float, mhl_filename: str, source_hash: str):
        """Create mip.json metadata file."""
        # Collect build_only source destinations for cleanup by build_packages.py
        prepare_sources = normalize_prepare_sources(resolved_config.get('prepare'))
        build_only_sources = []
        for source in prepare_sources:
            if source.get('build_only'):
                for key in ('clone_git', 'download_zip'):
                    if key in source:
                        build_only_sources.append(source[key]['destination'])
                        break

        # Collect build_env for build_packages.py (env var name -> relative path)
        build_env = resolved_config.get('build_env', {})

        mip_data = {
            'name': yaml_data['name'],
            'description': yaml_data['description'],
            'version': yaml_data['version'],
            'release_number': resolved_config['release_number'],
            'dependencies': yaml_data.get('dependencies', []),
            'homepage': yaml_data.get('homepage', ''),
            'repository': yaml_data.get('repository', ''),
            'license': yaml_data.get('license', ''),
            'architecture': architecture,
            'build_on': resolved_config.get('build_on', 'any'),
            'usage_examples': yaml_data.get('usage_examples', []),
            'exposed_symbols': exposed_symbols,
            'source_hash': source_hash,
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'prepare_duration': round(prepare_duration, 2),
            'compile_duration': 0,
            'mhl_url': f"{get_base_url(yaml_data['name'] + '-' + yaml_data['version'])}/{mhl_filename}"
        }
        if build_only_sources:
            mip_data['build_only_sources'] = build_only_sources
        if build_env:
            mip_data['build_env'] = build_env
        
        mip_json_path = os.path.join(mhl_dir, 'mip.json')
        with open(mip_json_path, 'w') as f:
            json.dump(mip_data, f, indent=2)
    
    def prepare_package_dir(self, package_dir: str, *, release: Optional[str]) -> bool:
        """Prepare a single package directory."""
        package_name = os.path.basename(package_dir)
        print(f"\nProcessing package: {package_name}")
        
        # Check that package name doesn't contain hyphens
        if '-' in package_name:
            print(f"  Error: Package name '{package_name}' contains hyphens ('-').")
            print(f"  Please use underscores ('_') instead of hyphens in package names.")
            return False

        releases_folder_path = os.path.join(package_dir, 'releases')

        for release_version in os.listdir(releases_folder_path):
            if release is not None and release_version != release:
                print(f"  Skipping release '{release_version}' (looking for '{release}')")
                continue
            release_folder_path = os.path.join(releases_folder_path, release_version)
            if os.path.isdir(release_folder_path):
                if release is not None and release_version != release:
                    print(f"  Skipping release '{release_version}' (looking for '{release}')")
                    continue
                print(f"  Processing release: {release_version}")
                
                # Check that release version doesn't contain hyphens
                if '-' in release_version:
                    print(f"  Error: Release version '{release_version}' contains hyphens ('-').")
                    print(f"  Please use underscores ('_') instead of hyphens in release versions.")
                    return False
                
            # Load YAML
            yaml_path = os.path.join(release_folder_path, 'prepare.yaml')
            if not os.path.exists(yaml_path):
                print(f"  Warning: No prepare.yaml found")
                return True
            
            with open(yaml_path, 'r') as f:
                yaml_data = yaml.safe_load(f)

            # Get BUILD_ARCHITECTURE from environment
            architecture_env = os.environ.get('BUILD_ARCHITECTURE', 'any')

            # Get defaults section
            defaults = yaml_data.get('defaults', {})

            # Find matching (build, architecture) pairs
            builds = yaml_data.get('builds', [])
            matching_pairs: List[tuple] = []  # list of (build_entry, matched_architecture)
            for b in builds:
                archs = b.get('architectures', [])
                if architecture_env in archs:
                    matching_pairs.append((b, architecture_env))
                elif 'any' in archs and architecture_env == 'linux_x86_64':
                    matching_pairs.append((b, 'any'))

            if not matching_pairs:
                print(f"  No builds match ARCHITECTURE={architecture_env}, skipping")
                return True

            # check that version in yaml matches release_version
            if yaml_data.get('version') != release_version:
                print(f"  Error: version in prepare.yaml ({yaml_data.get('version')}) does not match release folder name ({release_version}).")
                return False

            # Compute source hash for the release folder
            print(f"  Computing source hash for {release_folder_path}...")
            source_hash = compute_directory_hash(release_folder_path)

            # Resolve remote commit hashes for branch-based git sources
            # so that changes on the remote branch trigger rebuilds
            remote_commit_hashes = []
            prepare_sources = normalize_prepare_sources(defaults.get('prepare'))
            for source in prepare_sources:
                if 'clone_git' in source:
                    config = source['clone_git']
                    branch = config.get('branch')
                    if branch:
                        commit_hash = resolve_git_commit_hash(config['url'], branch)
                        print(f"  Resolved {config['url']} {branch} -> {commit_hash[:12]}")
                        remote_commit_hashes.append(commit_hash)

            if remote_commit_hashes:
                combined = hashlib.sha1()
                combined.update(source_hash.encode('utf-8'))
                for ch in sorted(remote_commit_hashes):
                    combined.update(ch.encode('utf-8'))
                source_hash = combined.hexdigest()

            print(f"  Source hash: {source_hash}")

            # Process each matching (build, architecture) pair
            for build, matched_architecture in matching_pairs:
                # Resolve config: defaults merged with build overrides
                resolved_config = resolve_build_config(defaults, build)

                # Generate filename
                mhl_filename = self._get_mhl_filename(yaml_data, matched_architecture)
                wheel_name = mhl_filename[:-4]  # Remove .mhl
                print(f"  Wheel name: {wheel_name}")

                # Check if exists
                if not self.force and self._check_existing_package(mhl_filename, yaml_data, resolved_config, source_hash):
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
                        package_dir, resolved_config, output_dir_path
                    )

                    prepare_duration = time.time() - prepare_start
                    print(f"  Prepare completed in {prepare_duration:.2f} seconds")

                    # Create mip.json
                    print(f"  Creating mip.json...")
                    self._create_mip_json(
                        output_dir_path, yaml_data, resolved_config,
                        matched_architecture, exposed_symbols,
                        prepare_duration, mhl_filename, source_hash
                    )

                    # Ensure scripts are available in the prepared directory.
                    # For each script type, if it already exists in the prepared
                    # dir (e.g. from cloned source), use it as-is. Otherwise,
                    # copy it from the release folder.
                    for script_key in ('compile_script', 'build_script', 'test_script'):
                        if script_key not in resolved_config:
                            continue
                        script_path = resolved_config[script_key]
                        script_in_prepared = os.path.join(output_dir_path, script_path)
                        if os.path.exists(script_in_prepared):
                            print(f"  {script_key} found in prepared source: {script_path}")
                        else:
                            script_in_release = os.path.join(release_folder_path, script_path)
                            if os.path.exists(script_in_release):
                                script_dst = os.path.join(output_dir_path, script_path)
                                os.makedirs(os.path.dirname(script_dst), exist_ok=True)
                                shutil.copy2(script_in_release, script_dst)
                                print(f"  Copied {script_key} from release folder: {script_path}")
                            else:
                                print(f"  Warning: {script_key} '{script_path}' not found in prepared source or release folder")
                        # Ensure shell scripts are executable
                        final_path = os.path.join(output_dir_path, script_path)
                        if os.path.exists(final_path) and script_path.endswith('.sh'):
                            os.chmod(final_path, 0o755)

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
            print("No package directories found. Nothing to do.")
            return True
        
        print(f"Found {len(package_dirs)} package(s)")
        print(f"Output directory: {self.output_dir}")
        print(f"ARCHITECTURE: {os.environ.get('BUILD_ARCHITECTURE', 'any')}")

        # Prepare each package
        all_success = True
        for package_dir in sorted(package_dirs):
            success = self.prepare_package_dir(package_dir, release=None)
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
        print(f"ARCHITECTURE: {os.environ.get('BUILD_ARCHITECTURE', 'any')}")

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
