#!/usr/bin/env python3
"""
Delete packages from GitHub Releases.

This script lists or deletes .mhl and .mip.json assets from releases.
It can match by exact filename or by prefix pattern.

Usage:
  # List all packages across all releases
  python scripts/delete_packages.py --list

  # Dry-run: show what would be deleted
  python scripts/delete_packages.py --pattern "hello_mip-0.1.0-any" --dry-run

  # Delete a specific package (both .mhl and .mip.json)
  python scripts/delete_packages.py --pattern "hello_mip-0.1.0-any"

  # Delete all versions/architectures of a package
  python scripts/delete_packages.py --pattern "hello_mip-"

  # Delete an entire release (all assets + the release itself)
  python scripts/delete_packages.py --delete-release "hello_mip-0.1.0"
"""

import os
import sys
import json
import subprocess
import argparse
from channel_config import get_github_repo, release_tag_from_mhl

GITHUB_REPO = get_github_repo()


def list_all_releases():
    """List all release tags in the repo."""
    result = subprocess.run(
        ['gh', 'release', 'list',
         '--repo', GITHUB_REPO,
         '--json', 'tagName',
         '--limit', '1000'],
        capture_output=True, text=True, check=True
    )
    data = json.loads(result.stdout)
    return [r['tagName'] for r in data]


def list_release_assets(release_tag):
    """List all assets on a specific release."""
    result = subprocess.run(
        ['gh', 'release', 'view', release_tag,
         '--repo', GITHUB_REPO,
         '--json', 'assets'],
        capture_output=True, text=True, check=True
    )
    data = json.loads(result.stdout)
    return data.get('assets', [])


def delete_asset(release_tag, asset_name, dry_run=False):
    """Delete a single asset from a release."""
    if dry_run:
        print(f"  [DRY RUN] Would delete: {asset_name} from release '{release_tag}'")
        return True

    try:
        subprocess.run(
            ['gh', 'release', 'delete-asset', release_tag, asset_name,
             '--repo', GITHUB_REPO,
             '--yes'],
            capture_output=True, text=True, check=True
        )
        print(f"  Deleted: {asset_name} from release '{release_tag}'")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  Error deleting {asset_name}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Delete packages from GitHub Releases'
    )
    parser.add_argument(
        '--list',
        action='store_true',
        help='List all packages across all releases'
    )
    parser.add_argument(
        '--pattern',
        type=str,
        help='Filename prefix pattern to match for deletion (e.g. "hello_mip-0.1.0-any" or "hello_mip-")'
    )
    parser.add_argument(
        '--delete-release',
        type=str,
        help='Delete an entire release by tag name (e.g. "hello_mip-0.1.0")'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be deleted without actually deleting'
    )

    args = parser.parse_args()

    if not args.list and not args.pattern and not args.delete_release:
        parser.print_help()
        return 1

    try:
        release_tags = list_all_releases()
    except subprocess.CalledProcessError as e:
        print(f"Error listing releases: {e}")
        return 1

    if args.delete_release:
        tag = args.delete_release
        if tag not in release_tags:
            print(f"Release '{tag}' not found.")
            return 0
        if args.dry_run:
            print(f"[DRY RUN] Would delete release '{tag}' and all its assets")
            return 0
        subprocess.run(
            ['gh', 'release', 'delete', tag,
             '--repo', GITHUB_REPO,
             '--yes', '--cleanup-tag'],
            check=True
        )
        print(f"Deleted release '{tag}'")
        print("Note: Run assemble_index.py to update the package index.")
        return 0

    # Collect all assets across all releases
    all_assets = []  # list of (release_tag, asset)
    for tag in sorted(release_tags):
        try:
            assets = list_release_assets(tag)
            for a in assets:
                all_assets.append((tag, a))
        except subprocess.CalledProcessError:
            print(f"  Warning: Could not list assets for release '{tag}'")

    if args.list:
        mhl_assets = [(tag, a) for tag, a in all_assets if a['name'].endswith('.mhl')]
        if not mhl_assets:
            print("No packages found in any release.")
            return 0

        print(f"Packages across all releases ({len(mhl_assets)} packages):\n")
        for tag, asset in sorted(mhl_assets, key=lambda x: x[1]['name']):
            size_mb = asset.get('size', 0) / (1024 * 1024)
            print(f"  [{tag}] {asset['name']}  ({size_mb:.2f} MB)")
        return 0

    if args.pattern:
        matching = [(tag, a) for tag, a in all_assets if a['name'].startswith(args.pattern)]

        if not matching:
            print(f"No assets matching pattern '{args.pattern}'")
            return 0

        print(f"Found {len(matching)} asset(s) matching '{args.pattern}':")
        all_success = True
        for tag, asset in matching:
            success = delete_asset(tag, asset['name'], dry_run=args.dry_run)
            if not success:
                all_success = False

        if not args.dry_run and all_success:
            print(f"\nDeleted {len(matching)} asset(s).")
            print("Note: Run assemble_index.py to update the package index.")

        return 0 if all_success else 1


if __name__ == '__main__':
    sys.exit(main())
