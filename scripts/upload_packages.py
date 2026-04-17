#!/usr/bin/env python3
"""
Upload bundled MATLAB packages (.mhl files) to GitHub Releases.

This script:
1. Discovers all .mhl and .mip.json files in the input directory
2. Uploads them as assets to GitHub Releases (one release per package-version)

Each .mhl file is uploaded to a release tagged {name}-{version}.

This script processes .mhl files created by bundle_packages.py
Index assembly is handled separately by assemble_index.py
"""

import os
import sys
import json
import hashlib
import subprocess
import argparse
from channel_config import get_github_repo, release_tag_from_mhl


def _sha256_of_file(path):
    """Compute the SHA-256 digest of a file, returned as a lowercase hex string."""
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 16), b''):
            h.update(chunk)
    return h.hexdigest()


class PackageUploader:
    """Handles uploading bundled MATLAB packages to GitHub Releases."""

    def __init__(self, dry_run=False, input_dir=None):
        """
        Initialize the package uploader.

        Args:
            dry_run: If True, simulate operations without actual uploading
            input_dir: Directory containing .mhl files (default: build/bundled)
        """
        self.dry_run = dry_run
        self.github_repo = get_github_repo()

        # Set input directory
        if input_dir:
            self.input_dir = input_dir
        else:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.input_dir = os.path.join(project_root, 'build', 'bundled')

    def _ensure_release_exists(self, release_tag):
        """Create the GitHub Release if it doesn't already exist."""
        result = subprocess.run(
            ['gh', 'release', 'view', release_tag,
             '--repo', self.github_repo],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f"  Creating release '{release_tag}'...")
            subprocess.run(
                ['gh', 'release', 'create', release_tag,
                 '--repo', self.github_repo,
                 '--title', release_tag,
                 '--notes', f'Package assets for {release_tag}.'],
                check=True
            )
            print(f"  Created release '{release_tag}'")

    def _upload_file(self, release_tag, file_path):
        """
        Upload a single file as a release asset (overwriting if it exists).

        Args:
            release_tag: The release tag to upload to
            file_path: Local file path to upload
        """
        filename = os.path.basename(file_path)
        subprocess.run(
            ['gh', 'release', 'upload', release_tag, file_path,
             '--repo', self.github_repo,
             '--clobber'],
            check=True
        )
        print(f"  Uploaded {filename}")

    def upload_package(self, mhl_path):
        """
        Upload a single .mhl package and its .mip.json file.

        Args:
            mhl_path: Path to the .mhl file

        Returns:
            True if successful, False otherwise
        """
        mhl_filename = os.path.basename(mhl_path)
        release_tag = release_tag_from_mhl(mhl_filename)

        print(f"\nUploading: {mhl_filename} -> release '{release_tag}'")

        # Check for corresponding .mip.json file
        mip_json_path = f"{mhl_path}.mip.json"
        if not os.path.exists(mip_json_path):
            print(f"  Error: {mhl_filename}.mip.json not found")
            return False

        # Compute SHA-256 of the .mhl and embed it in the .mip.json so the
        # client can verify integrity after download.
        try:
            with open(mip_json_path, 'r') as f:
                mip_json = json.load(f)
            mip_json['mhl_sha256'] = _sha256_of_file(mhl_path)
            with open(mip_json_path, 'w') as f:
                json.dump(mip_json, f, indent=2)
            print(f"  SHA-256: {mip_json['mhl_sha256']}")
        except (OSError, json.JSONDecodeError) as e:
            print(f"  Error computing/writing sha256: {e}")
            return False

        if self.dry_run:
            print(f"  [DRY RUN] Would upload {mhl_filename}")
            print(f"  [DRY RUN] Would upload {mhl_filename}.mip.json")
            return True

        try:
            self._ensure_release_exists(release_tag)
            self._upload_file(release_tag, mhl_path)
            self._upload_file(release_tag, mip_json_path)
            print(f"  Successfully uploaded {mhl_filename}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"  Error uploading package: {e}")
            return False

    def upload_all(self):
        """
        Upload all .mhl packages in the input directory.

        Returns:
            True if all succeeded, False if any failed
        """
        if not os.path.exists(self.input_dir):
            print(f"Input directory {self.input_dir} does not exist. Nothing to upload.")
            return True

        # Get all .mhl files
        mhl_files = [
            os.path.join(self.input_dir, f)
            for f in os.listdir(self.input_dir)
            if f.endswith('.mhl')
        ]

        if not mhl_files:
            print(f"No .mhl files found in {self.input_dir}")
            return True

        print(f"Found {len(mhl_files)} .mhl package(s)")
        print(f"Input directory: {self.input_dir}")

        # Upload each package
        all_success = True
        for mhl_path in sorted(mhl_files):
            success = self.upload_package(mhl_path)
            if not success:
                print(f"\nError: Upload failed for {os.path.basename(mhl_path)}")
                all_success = False
                break  # Abort on first failure

        return all_success


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Upload bundled MATLAB packages to GitHub Releases'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without uploading'
    )
    parser.add_argument(
        '--input-dir',
        type=str,
        help='Directory containing .mhl files (default: build/bundled)'
    )

    args = parser.parse_args()

    uploader = PackageUploader(
        dry_run=args.dry_run,
        input_dir=args.input_dir
    )

    print("Starting package upload process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual uploading will occur]")

    success = uploader.upload_all()

    if success:
        print("\nAll packages uploaded successfully")
        return 0
    else:
        print("\nUpload process failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
