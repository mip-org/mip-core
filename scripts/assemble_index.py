#!/usr/bin/env python3
"""
Assemble package index from GitHub Release assets.

This script:
1. Lists all releases in the repo
2. For each release, finds .mhl.mip.json assets
3. Downloads each .mip.json file
4. Assembles them into a consolidated index.json
5. Copies site/* (static index.html and assets) alongside it
6. Saves everything to build/gh-pages/ for GitHub Pages deployment

This script should be run after upload_packages.py
"""

import os
import sys
import json
import shutil
import argparse
import subprocess
import tempfile
from datetime import datetime
from channel_config import get_github_repo, get_base_url


def _version_sort_key(version_str):
    """Convert a version string like '1.2.5' to a tuple of ints for sorting."""
    try:
        return tuple(int(x) for x in version_str.split('.'))
    except (ValueError, AttributeError):
        return (0,)


def _package_sort_key(pkg):
    """Sort key for packages: by name (case-insensitive), then version, then architecture."""
    return (
        pkg.get('name', '').lower(),
        _version_sort_key(pkg.get('version', '0')),
        pkg.get('architecture', ''),
    )


class IndexAssembler:
    """Handles assembling package index from GitHub Release assets."""

    def __init__(self, dry_run=False):
        """
        Initialize the index assembler.

        Args:
            dry_run: If True, simulate operations without actual downloading
        """
        self.dry_run = dry_run
        self.github_repo = get_github_repo()

    def _list_all_releases(self):
        """
        List all releases in the repo.

        Returns:
            List of release tag names
        """
        print(f"Listing releases in {self.github_repo}...")

        result = subprocess.run(
            ['gh', 'release', 'list',
             '--repo', self.github_repo,
             '--json', 'tagName',
             '--limit', '1000'],
            capture_output=True, text=True, check=True
        )

        data = json.loads(result.stdout)
        tags = [r['tagName'] for r in data]
        print(f"  Found {len(tags)} release(s)")
        return tags

    def _list_valid_release_tags(self):
        """
        Build the set of release tags backed by a packages/<name>/<release>/
        folder containing recipe.yaml. Tags use the same encoding as filenames:
        '{name_with_underscores}-{release_version}'.
        """
        project_root = os.path.dirname(
            os.path.dirname(os.path.abspath(__file__)))
        packages_dir = os.path.join(project_root, 'packages')

        if not os.path.isdir(packages_dir):
            print(f"  Warning: packages/ directory not found at {packages_dir}")
            return set()

        valid_tags = set()
        for name in os.listdir(packages_dir):
            package_dir = os.path.join(packages_dir, name)
            if not os.path.isdir(package_dir):
                continue
            for release_version in os.listdir(package_dir):
                release_folder = os.path.join(package_dir, release_version)
                if not os.path.isdir(release_folder):
                    continue
                if not os.path.exists(
                        os.path.join(release_folder, 'recipe.yaml')):
                    continue
                valid_tags.add(
                    f"{name.replace('-', '_')}-{release_version}")
        return valid_tags

    def _list_release_assets(self, release_tag):
        """
        List all assets on a specific release.

        Returns:
            List of dicts with 'name' and 'url' keys
        """
        result = subprocess.run(
            ['gh', 'release', 'view', release_tag,
             '--repo', self.github_repo,
             '--json', 'assets'],
            capture_output=True, text=True, check=True
        )

        data = json.loads(result.stdout)
        return data.get('assets', [])

    def _download_mip_json(self, release_tag, asset_name, download_dir):
        """
        Download a .mip.json asset from a release.

        Args:
            release_tag: The release tag to download from
            asset_name: Name of the asset to download
            download_dir: Directory to download into

        Returns:
            Parsed JSON data, or None if download fails
        """
        try:
            subprocess.run(
                ['gh', 'release', 'download', release_tag,
                 '--repo', self.github_repo,
                 '--pattern', asset_name,
                 '--dir', download_dir,
                 '--clobber'],
                capture_output=True, text=True, check=True
            )

            file_path = os.path.join(download_dir, asset_name)
            with open(file_path, 'r') as f:
                metadata = json.load(f)

            base_url = get_base_url(release_tag)

            # Ensure mhl_url is present
            if 'mhl_url' not in metadata:
                mhl_filename = asset_name[:-9]  # Remove '.mip.json'
                metadata['mhl_url'] = f"{base_url}/{mhl_filename}"

            # Also add mip_json_url for easy access to metadata
            if 'mip_json_url' not in metadata:
                mhl_filename = asset_name[:-9]
                metadata['mip_json_url'] = f"{base_url}/{mhl_filename}.mip.json"

            return metadata

        except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
            print(f"  Warning: Failed to download/parse {asset_name}: {e}")
            return None

    def _copy_static_site(self, gh_pages_dir):
        """
        Copy the static site assets (index.html, etc.) from site/ into
        the GitHub Pages output directory.
        """
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        site_dir = os.path.join(project_root, 'site')
        if not os.path.isdir(site_dir):
            print(f"  Warning: no site/ directory at {site_dir}, skipping static copy")
            return

        for entry in os.listdir(site_dir):
            src = os.path.join(site_dir, entry)
            dst = os.path.join(gh_pages_dir, entry)
            if os.path.isdir(src):
                shutil.copytree(src, dst, dirs_exist_ok=True)
            else:
                shutil.copy2(src, dst)
            print(f"  Copied site/{entry}")

    def assemble_index(self):
        """
        Assemble the package index from all .mip.json assets across all releases.

        Returns:
            True if successful, False otherwise
        """
        if self.dry_run:
            print("\n[DRY RUN] Would assemble index.json from release assets")
            return True

        print("\nAssembling package index from GitHub Release assets...")

        # List all releases
        try:
            release_tags = self._list_all_releases()
        except subprocess.CalledProcessError as e:
            print(f"Error listing releases: {e}")
            return False

        if not release_tags:
            print("Warning: No releases found")

        # Restrict to releases that still have a matching folder in packages/.
        valid_tags = self._list_valid_release_tags()
        print(f"  Found {len(valid_tags)} package/release folder(s) in packages/")
        filtered = [t for t in release_tags if t in valid_tags]
        skipped = len(release_tags) - len(filtered)
        if skipped:
            print(f"  Skipping {skipped} release(s) with no matching "
                  f"folder in packages/")
        release_tags = filtered

        # Collect .mip.json assets from all releases
        package_metadata = []

        with tempfile.TemporaryDirectory() as tmpdir:
            for release_tag in sorted(release_tags):
                try:
                    assets = self._list_release_assets(release_tag)
                except subprocess.CalledProcessError:
                    print(f"  Warning: Could not list assets for release '{release_tag}'")
                    continue

                mip_json_assets = [a for a in assets if a['name'].endswith('.mhl.mip.json')]
                if not mip_json_assets:
                    continue

                print(f"\n  Release '{release_tag}': {len(mip_json_assets)} .mip.json file(s)")

                for asset in sorted(mip_json_assets, key=lambda a: a['name']):
                    print(f"    {asset['name']}")
                    metadata = self._download_mip_json(release_tag, asset['name'], tmpdir)
                    if metadata:
                        package_metadata.append(metadata)

        print(f"\nCollected {len(package_metadata)} package metadata file(s) total")

        # Sort packages
        package_metadata.sort(key=_package_sort_key)

        # Create index data
        index_data = {
            'github_repo': self.github_repo,
            'packages': package_metadata,
            'total_packages': len(package_metadata),
            'last_updated': datetime.utcnow().isoformat() + 'Z'
        }

        # Create output directory for GitHub Pages
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        gh_pages_dir = os.path.join(project_root, 'build', 'gh-pages')
        os.makedirs(gh_pages_dir, exist_ok=True)

        try:
            # Save index.json
            index_path = os.path.join(gh_pages_dir, 'index.json')
            with open(index_path, 'w') as f:
                json.dump(index_data, f, indent=2)

            print(f"\nDone: Created index.json with {len(package_metadata)} package(s)")
            print(f"  Saved to: {index_path}")

            # Copy static site assets (index.html, etc.)
            print("\nCopying static site assets...")
            self._copy_static_site(gh_pages_dir)

            repo_name = get_github_repo().split('/')[-1]
            owner = get_github_repo().split('/')[0]
            print(f"\n  Will be available at: https://{owner}.github.io/{repo_name}/")

            return True

        except Exception as e:
            print(f"\nError creating index files: {e}")
            import traceback
            traceback.print_exc()
            return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Assemble package index from GitHub Release assets'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without downloading'
    )

    args = parser.parse_args()

    assembler = IndexAssembler(dry_run=args.dry_run)

    print("Starting index assembly process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual downloading will occur]")

    success = assembler.assemble_index()

    if success:
        print("\nDone: Index assembled successfully")
        return 0
    else:
        print("\nError: Index assembly failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
