#!/usr/bin/env python3
"""
Assemble package index from Cloudflare R2 bucket.

This script:
1. Lists all .mhl.mip.json files in the R2 bucket
2. Downloads each .mip.json file
3. Assembles them into a consolidated index.json
4. Saves to build/gh-pages/index.json for GitHub Pages deployment

This script should be run after bundle_and_upload_packages.py
"""

import os
import sys
import json
import argparse
from datetime import datetime

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("Error: boto3 is required. Install with: pip install boto3")
    sys.exit(1)

class IndexAssembler:
    """Handles assembling package index from R2 bucket."""
    
    def __init__(self, dry_run=False):
        """
        Initialize the index assembler.
        
        Args:
            dry_run: If True, simulate operations without actual downloading
        """
        self.dry_run = dry_run
        self.base_url = "https://mip-packages.neurosift.app/core/packages"
        self.bucket_name = "mip-packages"
        self.bucket_prefix = "core/packages"
        
        # Initialize R2 client
        if not dry_run:
            self._init_r2_client()
    
    def _init_r2_client(self):
        """Initialize boto3 client for Cloudflare R2."""
        access_key = os.environ.get('AWS_ACCESS_KEY_ID')
        secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
        endpoint_url = os.environ.get('AWS_ENDPOINT_URL')
        
        if not all([access_key, secret_key, endpoint_url]):
            raise ValueError(
                "Missing required environment variables: "
                "AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL"
            )
        
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            endpoint_url=endpoint_url,
            region_name='auto'  # R2 uses 'auto' for region
        )
    
    def _list_mip_json_files(self):
        """
        List all .mhl.mip.json files in the bucket.
        
        Returns:
            List of S3 keys for .mip.json files
        """
        print(f"Listing packages in s3://{self.bucket_name}/{self.bucket_prefix}/")
        
        mip_json_keys = []
        
        try:
            paginator = self.s3_client.get_paginator('list_objects_v2')
            pages = paginator.paginate(
                Bucket=self.bucket_name,
                Prefix=f"{self.bucket_prefix}/"
            )
            
            for page in pages:
                if 'Contents' not in page:
                    continue
                
                for obj in page['Contents']:
                    key = obj['Key']
                    if key.endswith('.mhl.mip.json'):
                        mip_json_keys.append(key)
            
            print(f"  Found {len(mip_json_keys)} .mip.json file(s)")
            return mip_json_keys
            
        except ClientError as e:
            raise Exception(f"Failed to list bucket contents: {e}")
    
    def _download_mip_json(self, key):
        """
        Download and parse a .mip.json file from R2.
        
        Args:
            key: S3 key of the .mip.json file
        
        Returns:
            Parsed JSON data, or None if download fails
        """
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket_name,
                Key=key
            )
            
            content = response['Body'].read().decode('utf-8')
            metadata = json.loads(content)
            
            # Ensure mhl_url is present (for backwards compatibility)
            if 'mhl_url' not in metadata:
                # Extract the .mhl filename from the key
                # Key format: core/packages/name-version-matlab-abi-platform.mhl.mip.json
                filename = os.path.basename(key)
                # Remove .mip.json to get .mhl filename
                mhl_filename = filename[:-9]  # Remove '.mip.json'
                metadata['mhl_url'] = f"{self.base_url}/{mhl_filename}"
            
            return metadata
            
        except ClientError as e:
            print(f"  Warning: Failed to download {key}: {e}")
            return None
        except json.JSONDecodeError as e:
            print(f"  Warning: Failed to parse JSON from {key}: {e}")
            return None
    
    def assemble_index(self):
        """
        Assemble the package index from all .mip.json files in the bucket.
        
        Returns:
            True if successful, False otherwise
        """
        if self.dry_run:
            print("\n[DRY RUN] Would assemble index.json from bucket")
            return True
        
        print("\nAssembling package index from R2 bucket...")
        
        # List all .mip.json files
        try:
            mip_json_keys = self._list_mip_json_files()
        except Exception as e:
            print(f"Error listing packages: {e}")
            return False
        
        if not mip_json_keys:
            print("Warning: No packages found in bucket")
            # Still create an empty index
            package_metadata = []
        else:
            # Download and collect metadata from each file
            package_metadata = []
            print("\nDownloading package metadata...")
            
            for i, key in enumerate(sorted(mip_json_keys), 1):
                filename = os.path.basename(key)
                print(f"  [{i}/{len(mip_json_keys)}] {filename}")
                
                metadata = self._download_mip_json(key)
                if metadata:
                    package_metadata.append(metadata)
            
            print(f"\nSuccessfully downloaded {len(package_metadata)} package metadata file(s)")
        
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
            index_path = os.path.join(gh_pages_dir, 'index.json')
            with open(index_path, 'w') as f:
                json.dump(index_data, f, indent=2)
            
            print(f"\n✓ Created index.json with {len(package_metadata)} package(s)")
            print(f"  Saved to: {index_path}")
            print(f"  This will be deployed to GitHub Pages")
            
            return True
            
        except Exception as e:
            print(f"\nError creating index.json: {e}")
            import traceback
            traceback.print_exc()
            return False

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Assemble package index from Cloudflare R2 bucket'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without downloading'
    )
    
    args = parser.parse_args()
    
    # Create assembler
    assembler = IndexAssembler(dry_run=args.dry_run)
    
    # Assemble index
    print("Starting index assembly process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual downloading will occur]")
    
    success = assembler.assemble_index()
    
    if success:
        print("\n✓ Index assembled successfully")
        return 0
    else:
        print("\n✗ Index assembly failed")
        return 1

if __name__ == '__main__':
    sys.exit(main())