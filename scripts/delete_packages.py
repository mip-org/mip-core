#!/usr/bin/env python3
"""
Delete packages from Cloudflare R2 bucket.

This script lists or deletes .mhl and .mip.json files from the R2 bucket.
It can match by exact filename or by prefix pattern.

Usage:
  # List all packages in the bucket
  python scripts/delete_packages.py --list

  # Dry-run: show what would be deleted
  python scripts/delete_packages.py --pattern "finufft-2.5.0-any" --dry-run

  # Delete a specific package (both .mhl and .mip.json)
  python scripts/delete_packages.py --pattern "finufft-2.5.0-any"

  # Delete all versions/architectures of a package
  python scripts/delete_packages.py --pattern "finufft-"
"""

import os
import sys
import argparse

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("Error: boto3 is required. Install with: pip install boto3")
    sys.exit(1)


BUCKET_NAME = "mip-packages"
BUCKET_PREFIX = "core/packages"


def get_s3_client():
    access_key = os.environ.get('AWS_ACCESS_KEY_ID')
    secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
    endpoint_url = os.environ.get('AWS_ENDPOINT_URL')

    if not all([access_key, secret_key, endpoint_url]):
        print("Error: Missing required environment variables:")
        print("  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL")
        sys.exit(1)

    return boto3.client(
        's3',
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        endpoint_url=endpoint_url,
        region_name='auto'
    )


def list_packages(client):
    """List all packages in the bucket."""
    paginator = client.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=BUCKET_NAME, Prefix=f"{BUCKET_PREFIX}/")

    files = []
    for page in pages:
        for obj in page.get('Contents', []):
            key = obj['Key']
            # Strip prefix to get just the filename
            filename = key[len(BUCKET_PREFIX) + 1:]
            size_mb = obj['Size'] / (1024 * 1024)
            files.append((filename, size_mb))

    return files


def delete_objects(client, keys, dry_run=False):
    """Delete objects from the bucket."""
    if not keys:
        print("Nothing to delete.")
        return True

    for key in keys:
        filename = key[len(BUCKET_PREFIX) + 1:]
        if dry_run:
            print(f"  [DRY RUN] Would delete: {filename}")
        else:
            try:
                client.delete_object(Bucket=BUCKET_NAME, Key=key)
                print(f"  Deleted: {filename}")
            except ClientError as e:
                print(f"  Error deleting {filename}: {e}")
                return False

    return True


def main():
    parser = argparse.ArgumentParser(
        description='Delete packages from Cloudflare R2 bucket'
    )
    parser.add_argument(
        '--list',
        action='store_true',
        help='List all packages in the bucket'
    )
    parser.add_argument(
        '--pattern',
        type=str,
        help='Filename prefix pattern to match for deletion (e.g. "finufft-2.5.0-any" or "finufft-")'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be deleted without actually deleting'
    )

    args = parser.parse_args()

    if not args.list and not args.pattern:
        parser.print_help()
        return 1

    client = get_s3_client()

    if args.list:
        files = list_packages(client)
        if not files:
            print("No packages found in bucket.")
            return 0

        # Group by package (strip .mip.json suffix for grouping)
        mhl_files = [f for f in files if f[0].endswith('.mhl')]
        print(f"Packages in bucket ({len(mhl_files)} packages):\n")
        for filename, size_mb in sorted(mhl_files):
            print(f"  {filename}  ({size_mb:.2f} MB)")
        return 0

    if args.pattern:
        # Find matching objects
        files = list_packages(client)
        matching_keys = []
        for filename, _ in files:
            if filename.startswith(args.pattern):
                matching_keys.append(f"{BUCKET_PREFIX}/{filename}")

        if not matching_keys:
            print(f"No files matching pattern '{args.pattern}'")
            return 0

        print(f"Found {len(matching_keys)} file(s) matching '{args.pattern}':")
        success = delete_objects(client, matching_keys, dry_run=args.dry_run)

        if not args.dry_run and success:
            print(f"\nDeleted {len(matching_keys)} file(s).")
            print("Note: Run assemble_index.py to update the package index.")

        return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
