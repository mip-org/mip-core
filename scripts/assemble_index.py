#!/usr/bin/env python3
"""
Assemble package index from Cloudflare R2 bucket.

This script:
1. Lists all .mhl.mip.json files in the R2 bucket
2. Downloads each .mip.json file
3. Assembles them into a consolidated index.json
4. Generates a human-readable packages.md
5. Saves both to build/gh-pages/ for GitHub Pages deployment

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
            
            # Also add mip_json_url for easy access to metadata
            if 'mip_json_url' not in metadata:
                filename = os.path.basename(key)
                mhl_filename = filename[:-9]  # Remove '.mip.json'
                metadata['mip_json_url'] = f"{self.base_url}/{mhl_filename}.mip.json"
            
            return metadata
            
        except ClientError as e:
            print(f"  Warning: Failed to download {key}: {e}")
            return None
        except json.JSONDecodeError as e:
            print(f"  Warning: Failed to parse JSON from {key}: {e}")
            return None
    
    def _generate_index_md(self, package_metadata, last_updated):
        """
        Generate a human-readable markdown index from package metadata.
        
        Args:
            package_metadata: List of package metadata dicts
            last_updated: ISO timestamp of when index was updated
        
        Returns:
            Markdown string
        """
        lines = []
        lines.append("# MATLAB Package Index")
        lines.append("")
        lines.append("Available MATLAB packages for installation via MIP.")
        lines.append("")
        
        if package_metadata:
            # Sort packages alphabetically by name
            sorted_packages = sorted(package_metadata, key=lambda p: p.get('name', '').lower())
            
            lines.append(f"**Total packages:** {len(sorted_packages)}")
            lines.append(f"**Last updated:** {last_updated}")
            lines.append("")
            
            # Create table header
            lines.append("| Package | Version | Description | Platform | Download |")
            lines.append("|---------|---------|-------------|----------|----------|")
            
            # Add each package as a table row
            for pkg in sorted_packages:
                name = pkg.get('name', 'unknown')
                version = pkg.get('version', 'unknown')
                description = pkg.get('description', '')
                homepage = pkg.get('homepage', '')
                mhl_url = pkg.get('mhl_url', '')
                mip_json_url = pkg.get('mip_json_url', '')
                
                # Truncate long descriptions
                if len(description) > 80:
                    description = description[:77] + "..."
                
                # Create package name link (to homepage if available)
                if homepage:
                    name_link = f"[{name}]({homepage})"
                else:
                    name_link = name
                
                # Determine platform info
                matlab_tag = pkg.get('matlab_tag', 'any')
                abi_tag = pkg.get('abi_tag', 'none')
                platform_tag = pkg.get('platform_tag', 'any')
                
                # Simplify platform display
                if matlab_tag == 'any' and abi_tag == 'none' and platform_tag == 'any':
                    platform_info = "All"
                else:
                    platform_parts = []
                    if matlab_tag != 'any':
                        platform_parts.append(f"MATLAB {matlab_tag}")
                    if platform_tag != 'any':
                        platform_parts.append(platform_tag)
                    platform_info = ", ".join(platform_parts) if platform_parts else "All"
                
                # Create download links
                download_links = []
                if mhl_url:
                    download_links.append(f"[.mhl]({mhl_url})")
                if mip_json_url:
                    download_links.append(f"[metadata]({mip_json_url})")
                download_cell = " ".join(download_links) if download_links else "N/A"
                
                # Escape pipe characters in descriptions
                description = description.replace('|', '\\|')
                
                lines.append(f"| {name_link} | {version} | {description} | {platform_info} | {download_cell} |")
            
            lines.append("")
            lines.append("---")
            lines.append("")
            lines.append("## Installation")
            lines.append("")
            lines.append("To install packages, use the MIP package manager:")
            lines.append("")
            lines.append("```matlab")
            lines.append("% Install a package")
            lines.append("mip install <package-name>")
            lines.append("```")
            lines.append("")
            lines.append("For more information, visit the [MIP documentation](https://github.com/mip-org/mip-core).")
        else:
            lines.append("No packages available yet.")
        
        lines.append("")
        return "\n".join(lines)
    
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
            # Save index.json
            index_path = os.path.join(gh_pages_dir, 'index.json')
            with open(index_path, 'w') as f:
                json.dump(index_data, f, indent=2)
            
            print(f"\n✓ Created index.json with {len(package_metadata)} package(s)")
            print(f"  Saved to: {index_path}")
            
            # Generate and save packages.md
            packages_md_path = os.path.join(gh_pages_dir, 'packages.md')
            markdown_content = self._generate_index_md(
                package_metadata, 
                index_data['last_updated']
            )
            with open(packages_md_path, 'w') as f:
                f.write(markdown_content)
            
            print(f"✓ Created packages.md")
            print(f"  Saved to: {packages_md_path}")
            print(f"  Will be available as packages.html on GitHub Pages")
            
            return True
            
        except Exception as e:
            print(f"\nError creating index files: {e}")
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
