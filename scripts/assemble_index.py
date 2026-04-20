#!/usr/bin/env python3
"""
Assemble package index from GitHub Release assets.

This script:
1. Lists all releases in the repo
2. For each release, finds .mhl.mip.json assets
3. Downloads each .mip.json file
4. Assembles them into a consolidated index.json
5. Generates a human-readable packages.html
6. Saves both to build/gh-pages/ for GitHub Pages deployment

This script should be run after upload_packages.py
"""

import os
import sys
import json
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

    def _generate_index_html(self, package_metadata, last_updated):
        """
        Generate a human-readable HTML index from package metadata.

        Args:
            package_metadata: List of package metadata dicts
            last_updated: ISO timestamp of when index was updated

        Returns:
            HTML string
        """
        html = []
        html.append('<!DOCTYPE html>')
        html.append('<html lang="en">')
        html.append('<head>')
        html.append('    <meta charset="UTF-8">')
        html.append('    <meta name="viewport" content="width=device-width, initial-scale=1.0">')
        html.append('    <title>MIP Package Index</title>')
        html.append('    <style>')
        html.append('        body {')
        html.append('            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;')
        html.append('            line-height: 1.6;')
        html.append('            max-width: 1200px;')
        html.append('            margin: 0 auto;')
        html.append('            padding: 20px;')
        html.append('            color: #333;')
        html.append('        }')
        html.append('        h1 {')
        html.append('            border-bottom: 2px solid #e1e4e8;')
        html.append('            padding-bottom: 10px;')
        html.append('        }')
        html.append('        .info {')
        html.append('            color: #586069;')
        html.append('            margin: 20px 0;')
        html.append('        }')
        html.append('        table {')
        html.append('            width: 100%;')
        html.append('            border-collapse: collapse;')
        html.append('            margin: 20px 0;')
        html.append('        }')
        html.append('        th, td {')
        html.append('            text-align: left;')
        html.append('            padding: 12px;')
        html.append('            border: 1px solid #e1e4e8;')
        html.append('        }')
        html.append('        th {')
        html.append('            background-color: #f6f8fa;')
        html.append('            font-weight: 600;')
        html.append('        }')
        html.append('        tr:hover {')
        html.append('            background-color: #f6f8fa;')
        html.append('        }')
        html.append('        a {')
        html.append('            color: #0366d6;')
        html.append('            text-decoration: none;')
        html.append('        }')
        html.append('        a:hover {')
        html.append('            text-decoration: underline;')
        html.append('        }')
        html.append('        .footer {')
        html.append('            margin-top: 40px;')
        html.append('            padding-top: 20px;')
        html.append('            border-top: 1px solid #e1e4e8;')
        html.append('            color: #586069;')
        html.append('        }')
        html.append('    </style>')
        html.append('</head>')
        html.append('<body>')
        html.append('    <h1>MIP Package Index</h1>')
        html.append('    <p>Available MATLAB packages for installation via MIP.</p>')

        if package_metadata:
            sorted_packages = sorted(package_metadata, key=_package_sort_key)

            html.append(f'    <div class="info">')
            html.append(f'        <strong>Total packages:</strong> {len(sorted_packages)}<br>')
            html.append(f'        <strong>Last updated:</strong> {last_updated}')
            html.append(f'    </div>')

            html.append('    <table>')
            html.append('        <thead>')
            html.append('            <tr>')
            html.append('                <th>Package</th>')
            html.append('                <th>Version</th>')
            html.append('                <th>Description</th>')
            html.append('                <th>Platform</th>')
            html.append('                <th>Download</th>')
            html.append('            </tr>')
            html.append('        </thead>')
            html.append('        <tbody>')

            for pkg in sorted_packages:
                name = pkg.get('name', 'unknown')
                version = pkg.get('version', 'unknown')
                description = pkg.get('description', '')
                homepage = pkg.get('homepage', '')
                mhl_url = pkg.get('mhl_url', '')
                mip_json_url = pkg.get('mip_json_url', '')

                from html import escape
                description = escape(description)

                if len(description) > 80:
                    description = description[:77] + "..."

                if homepage:
                    name_cell = f'<a href="{escape(homepage)}">{escape(name)}</a>'
                else:
                    name_cell = escape(name)

                architecture = pkg.get('architecture', 'any')
                platform_info = f"architecture={architecture}"

                download_links = []
                if mhl_url:
                    download_links.append(f'<a href="{escape(mhl_url)}">.mhl</a>')
                if mip_json_url:
                    download_links.append(f'<a href="{escape(mip_json_url)}">metadata</a>')
                download_cell = " ".join(download_links) if download_links else "N/A"

                html.append('            <tr>')
                html.append(f'                <td>{name_cell}</td>')
                html.append(f'                <td>{escape(version)}</td>')
                html.append(f'                <td>{description}</td>')
                html.append(f'                <td>{escape(platform_info)}</td>')
                html.append(f'                <td>{download_cell}</td>')
                html.append('            </tr>')

            html.append('        </tbody>')
            html.append('    </table>')
        else:
            html.append('    <p>No packages available yet.</p>')

        html.append('    <div class="footer">')
        html.append('        <p>For more information, visit the <a href="https://github.com/mip-org/mip">MIP documentation</a>.</p>')
        html.append('    </div>')
        html.append('</body>')
        html.append('</html>')

        return "\n".join(html)

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

            # Generate and save packages.html
            packages_html_path = os.path.join(gh_pages_dir, 'packages.html')
            html_content = self._generate_index_html(
                package_metadata,
                index_data['last_updated']
            )
            with open(packages_html_path, 'w') as f:
                f.write(html_content)

            print(f"Done: Created packages.html")
            print(f"  Saved to: {packages_html_path}")
            repo_name = get_github_repo().split('/')[-1]
            owner = get_github_repo().split('/')[0]
            print(f"  Will be available at: https://{owner}.github.io/{repo_name}/packages.html")

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
