#!/usr/bin/env python3
"""
Assemble package index from Cloudflare R2 bucket.

This script:
1. Lists all .mhl.mip.json files in the R2 bucket
2. Downloads each .mip.json file
3. Assembles them into a consolidated index.json
4. Generates a human-readable packages.html
5. Saves both to build/gh-pages/ for GitHub Pages deployment

This script should be run after upload_packages.py
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
            # Sort packages alphabetically by name
            sorted_packages = sorted(package_metadata, key=lambda p: p.get('name', '').lower())
            
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
            
            # Add each package as a table row
            for pkg in sorted_packages:
                name = pkg.get('name', 'unknown')
                version = pkg.get('version', 'unknown')
                description = pkg.get('description', '')
                homepage = pkg.get('homepage', '')
                mhl_url = pkg.get('mhl_url', '')
                mip_json_url = pkg.get('mip_json_url', '')
                
                # Escape HTML special characters
                from html import escape
                description = escape(description)
                
                # Truncate long descriptions
                if len(description) > 80:
                    description = description[:77] + "..."
                
                # Create package name link (to homepage if available)
                if homepage:
                    name_cell = f'<a href="{escape(homepage)}">{escape(name)}</a>'
                else:
                    name_cell = escape(name)
                
                # Determine platform info
                architecture = pkg.get('architecture', 'any')
                
                platform_info = f"architecture={architecture}"
                
                # Create download links
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
        html.append('        <p>For more information, visit the <a href="https://github.com/mip-org/mip-package-manager">MIP documentation</a>.</p>')
        html.append('    </div>')
        html.append('</body>')
        html.append('</html>')
        
        return "\n".join(html)
    
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
            
            # Generate and save packages.html
            packages_html_path = os.path.join(gh_pages_dir, 'packages.html')
            html_content = self._generate_index_html(
                package_metadata, 
                index_data['last_updated']
            )
            with open(packages_html_path, 'w') as f:
                f.write(html_content)
            
            print(f"✓ Created packages.html")
            print(f"  Saved to: {packages_html_path}")
            print(f"  Will be available at: https://mip-org.github.io/mip-core/packages.html")
            
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
