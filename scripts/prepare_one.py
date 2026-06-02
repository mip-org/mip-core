#!/usr/bin/env python3
"""
Prepare a single package release for one architecture.

Usage:
  python scripts/prepare_one.py \
      --package-path packages/<name>/<release> \
      --architecture <arch>

The script:
  1. Reads recipe.yaml from the package release directory
  2. Fetches source per recipe.yaml (git clone or zip download)
  3. Overlays channel-provided files (mip.yaml, compile.m, test scripts, ...)
  4. Validates channel version rules and architecture support
  5. Writes build/prepared/<name>-<release>/ ready for `mip bundle`
  6. Writes .release_version / .source_hash / .commit_hash side files

If the requested architecture is not listed under any `builds:` entry of
the package's mip.yaml, the script exits 0 without producing output
(the calling workflow then short-circuits the bundle/test/upload steps).

If --force is not set and a matching .mhl already exists on the channel's
GitHub Releases (matching source hash and metadata), prepare exits 0
without producing output, signalling "nothing to do".
"""

import os
import sys
import stat
import shutil
import argparse
import hashlib
import subprocess
import requests
import yaml
from channel_config import get_base_url, release_tag_from_mhl


def _rmtree_on_error(func, path, exc_info):
    """Handle read-only files on Windows (e.g. .git/objects/pack)."""
    os.chmod(path, stat.S_IWRITE)
    func(path)


def clone_git_repository(url, destination, subdirectory=None, branch=None):
    """Clone a git repository, optionally extracting a subdirectory."""
    branch_args = ["--branch", branch] if branch else []
    if subdirectory:
        temp_clone_dir = destination + "_temp_clone"
        print(f'  Cloning {url} (subdirectory: {subdirectory})...')
        subprocess.run(
            ["git", "clone"] + branch_args + [url, temp_clone_dir],
            check=True, capture_output=True
        )
        subdir_path = os.path.join(temp_clone_dir, subdirectory)
        if not os.path.isdir(subdir_path):
            shutil.rmtree(temp_clone_dir, onerror=_rmtree_on_error)
            raise ValueError(
                f"Subdirectory '{subdirectory}' not found in cloned repo")
        if destination == '.':
            for item in os.listdir(subdir_path):
                s = os.path.join(subdir_path, item)
                d = os.path.join('.', item)
                if os.path.isdir(s):
                    shutil.copytree(s, d)
                else:
                    shutil.copy2(s, d)
        else:
            shutil.copytree(subdir_path, destination)
        shutil.rmtree(temp_clone_dir, onerror=_rmtree_on_error)
    else:
        print(f'  Cloning {url}...')
        subprocess.run(
            ["git", "clone"] + branch_args + [url, destination],
            check=True, capture_output=True
        )

    for root, dirs, _ in os.walk(destination):
        if ".git" in dirs:
            shutil.rmtree(os.path.join(root, ".git"),
                          onerror=_rmtree_on_error)
            dirs.remove(".git")


def download_and_extract_zip(url, destination):
    import zipfile
    download_file = "temp_download.zip"
    print(f'  Downloading {url}...')
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    with open(download_file, 'wb') as f:
        f.write(response.content)
    print(f"  Extracting to {destination}...")
    with zipfile.ZipFile(download_file, 'r') as z:
        z.extractall(destination)
    os.remove(download_file)


def resolve_git_commit_hash(url, ref):
    result = subprocess.run(
        ["git", "ls-remote", url, ref],
        check=True, capture_output=True, text=True
    )
    for line in result.stdout.strip().splitlines():
        commit_hash, remote_ref = line.split('\t', 1)
        if remote_ref in (f"refs/heads/{ref}", f"refs/tags/{ref}", ref):
            return commit_hash
    raise RuntimeError(f"Could not resolve ref '{ref}' for {url}")


def compute_directory_hash(directory):
    sha1 = hashlib.sha1()
    for root, dirs, files in os.walk(directory):
        dirs.sort()
        files.sort()
        for filename in files:
            file_path = os.path.join(root, filename)
            rel = os.path.relpath(file_path, directory)
            sha1.update(rel.encode('utf-8'))
            sha1.update(b'\0')
            try:
                with open(file_path, 'rb') as f:
                    while True:
                        chunk = f.read(8192)
                        if not chunk:
                            break
                        sha1.update(chunk)
            except (IOError, OSError) as e:
                sha1.update(f"ERROR:{e}".encode('utf-8'))
            sha1.update(b'\0')
    return sha1.hexdigest()


def overlay_channel_files(release_folder, target_dir):
    """Copy channel-provided files (everything except recipe.yaml) into target."""
    for item in os.listdir(release_folder):
        if item == 'recipe.yaml':
            continue
        src = os.path.join(release_folder, item)
        dst = os.path.join(target_dir, item)
        if os.path.isdir(src):
            if os.path.exists(dst):
                for root, _, files in os.walk(src):
                    rel_root = os.path.relpath(root, src)
                    dst_root = os.path.join(dst, rel_root)
                    os.makedirs(dst_root, exist_ok=True)
                    for f in files:
                        shutil.copy2(
                            os.path.join(root, f),
                            os.path.join(dst_root, f))
            else:
                shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)


def is_numeric_version(s):
    if not s:
        return False
    parts = s.split('.')
    return all(p.isdigit() for p in parts) and len(parts) >= 1


def validate_channel_version_rules(mip_yaml_path, recipe, release_version):
    """See mip-channel-template README for the rules."""
    if 'version' in recipe:
        raise ValueError(
            "recipe.yaml must not contain a 'version' field "
            "(release dir is the version)")

    with open(mip_yaml_path, 'r') as f:
        mip_yaml = yaml.safe_load(f) or {}
    mv = str(mip_yaml.get('version') or '').strip()
    source_branch = (recipe.get('source') or {}).get('branch') or ''

    if mv and not is_numeric_version(mv):
        raise ValueError(
            f"mip.yaml 'version' must be blank or numeric, got {mv!r}.")

    if mv and release_version != mv and release_version != source_branch:
        raise ValueError(
            f"Release directory {release_version!r} must equal mip.yaml "
            f"version {mv!r} or recipe source.branch {source_branch!r}.")


def read_mip_yaml(mip_yaml_path):
    with open(mip_yaml_path, 'r') as f:
        return yaml.safe_load(f) or {}


def architectures_from_mip_yaml(mip_yaml):
    archs = set()
    for build in mip_yaml.get('builds', []):
        for a in build.get('architectures', []):
            archs.add(a)
    return archs


def check_existing_package(mhl_filename, source_hash, mip_yaml,
                           release_version):
    """Return True if a matching package is already published."""
    release_tag = release_tag_from_mhl(mhl_filename)
    base_url = get_base_url(release_tag)
    mip_json_url = f"{base_url}/{mhl_filename}.mip.json"

    try:
        response = requests.get(mip_json_url, timeout=10)
        if response.status_code == 404:
            return False
        response.raise_for_status()
        existing = response.json()
    except requests.RequestException as e:
        print(f"  Error checking existing package: {e}")
        return False

    if existing.get('source_hash') != source_hash:
        return False
    if existing.get('version') != release_version:
        return False
    # Treat None / '' / [] as equivalent ("absent") on both sides — the
    # mip.json writer normalises missing fields to '' or [], while the
    # locally-read yaml leaves them as None.
    def _norm(v):
        return v if v else None
    for field in ('name', 'description', 'dependencies',
                  'homepage', 'repository', 'license'):
        if _norm(existing.get(field)) != _norm(mip_yaml.get(field)):
            return False
    return True


def fetch_source(recipe, target_dir):
    source = recipe.get('source')
    if not source:
        return
    original_dir = os.getcwd()
    os.chdir(target_dir)
    try:
        if 'git' in source:
            clone_git_repository(
                url=source['git'],
                destination='.',
                subdirectory=source.get('subdirectory'),
                branch=source.get('branch'),
            )
        elif 'zip' in source:
            download_and_extract_zip(source['zip'], '.')

        for dir_name in source.get('remove_dirs', []):
            dir_path = os.path.join(target_dir, dir_name)
            if os.path.isdir(dir_path):
                shutil.rmtree(dir_path, onerror=_rmtree_on_error)
                print(f"    Removed directory: {dir_name}")
    finally:
        os.chdir(original_dir)


def main():
    parser = argparse.ArgumentParser(
        description='Prepare a single package release for one architecture')
    parser.add_argument(
        '--package-path', required=True,
        help='Path to the release dir, e.g. packages/<name>/<release>')
    parser.add_argument(
        '--architecture',
        default=os.environ.get('BUILD_ARCHITECTURE'),
        help='Target architecture (or $BUILD_ARCHITECTURE)')
    parser.add_argument('--force', action='store_true')
    parser.add_argument(
        '--output-dir',
        help='Output dir (default: build/prepared)')
    args = parser.parse_args()

    if not args.architecture:
        print("Error: --architecture or $BUILD_ARCHITECTURE required",
              file=sys.stderr)
        return 2

    release_folder = os.path.abspath(args.package_path)
    if not os.path.isdir(release_folder):
        print(f"Error: package path not found: {release_folder}",
              file=sys.stderr)
        return 2

    recipe_path = os.path.join(release_folder, 'recipe.yaml')
    if not os.path.exists(recipe_path):
        print(f"Error: no recipe.yaml in {release_folder}", file=sys.stderr)
        return 2

    package_name = os.path.basename(os.path.dirname(release_folder))
    release_version = os.path.basename(release_folder)

    if package_name != package_name.lower():
        print(f"Error: package name must be lowercase: {package_name}",
              file=sys.stderr)
        return 2

    print(f"Package: {package_name}")
    print(f"Release: {release_version}")
    print(f"Architecture: {args.architecture}")

    with open(recipe_path, 'r') as f:
        recipe = yaml.safe_load(f) or {}

    source_hash = compute_directory_hash(release_folder)
    remote_hashes = []
    source = recipe.get('source') or {}
    if 'git' in source and source.get('branch'):
        commit_hash = resolve_git_commit_hash(
            source['git'], source['branch'])
        print(f"  Resolved {source['git']} {source['branch']} -> "
              f"{commit_hash[:12]}")
        remote_hashes.append(commit_hash)

    if remote_hashes:
        combined = hashlib.sha1()
        combined.update(source_hash.encode('utf-8'))
        for h in sorted(remote_hashes):
            combined.update(h.encode('utf-8'))
        source_hash = combined.hexdigest()
    print(f"  Source hash: {source_hash}")

    output_dir = args.output_dir or os.path.join(
        os.path.abspath(os.curdir), 'build', 'prepared')
    os.makedirs(output_dir, exist_ok=True)

    # Probe mip.yaml (it may live in source or be overlaid from channel)
    # by doing a tentative fetch into a temp dir.
    temp_dir = os.path.join(
        output_dir, f"_temp_{package_name}_{release_version}")
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir, onerror=_rmtree_on_error)
    os.makedirs(temp_dir)

    try:
        fetch_source(recipe, temp_dir)
        overlay_channel_files(release_folder, temp_dir)
        mip_yaml_path = os.path.join(temp_dir, 'mip.yaml')
        if not os.path.exists(mip_yaml_path):
            print("  Error: no mip.yaml after overlay", file=sys.stderr)
            return 1
        validate_channel_version_rules(
            mip_yaml_path, recipe, release_version)
        mip_yaml = read_mip_yaml(mip_yaml_path)
        archs = architectures_from_mip_yaml(mip_yaml)
    finally:
        shutil.rmtree(temp_dir, onerror=_rmtree_on_error)

    if args.architecture not in archs:
        print(f"  Architecture {args.architecture!r} not in {sorted(archs)}; "
              f"nothing to prepare for this arch.")
        return 0

    name_for_filename = mip_yaml['name'].replace('-', '_')
    mhl_filename = (
        f"{name_for_filename}-{release_version}-{args.architecture}.mhl")

    if not args.force and check_existing_package(
            mhl_filename, source_hash, mip_yaml, release_version):
        print(f"  {mhl_filename} already published with matching hash; "
              f"skipping.")
        return 0

    out_name = f"{mip_yaml['name']}-{release_version}"
    out_path = os.path.join(output_dir, out_name)
    if os.path.exists(out_path):
        shutil.rmtree(out_path, onerror=_rmtree_on_error)
    os.makedirs(out_path)

    fetch_source(recipe, out_path)
    overlay_channel_files(release_folder, out_path)
    validate_channel_version_rules(
        os.path.join(out_path, 'mip.yaml'), recipe, release_version)

    with open(os.path.join(out_path, '.release_version'), 'w') as f:
        f.write(release_version)
    with open(os.path.join(out_path, '.source_hash'), 'w') as f:
        f.write(source_hash)
    if remote_hashes:
        with open(os.path.join(out_path, '.commit_hash'), 'w') as f:
            f.write(remote_hashes[0])

    print(f"  Prepared: {out_path}")
    print(f"  Expected output: {mhl_filename}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
