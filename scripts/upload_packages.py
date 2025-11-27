#!/usr/bin/env python3
"""
Upload bundled MATLAB packages (.mhl files) to Cloudflare R2 bucket.

This script:
1. Discovers all .mhl and .mip.json files in the input directory
2. Uploads them to Cloudflare R2

This script processes .mhl files created by bundle_packages.py
Index assembly is handled separately by assemble_index.py
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

class PackageUploader:
    """Handles uploading bundled MATLAB packages to R2."""
    
    def __init__(self, dry_run=False, input_dir=None):
        """
        Initialize the package uploader.
        
        Args:
            dry_run: If True, simulate operations without actual uploading
            input_dir: Directory containing .mhl files (default: build/bundled)
        """
        self.dry_run = dry_run
        self.base_url = "https://mip-packages.neurosift.app/core/packages"
        self.bucket_name = "mip-packages"
        self.bucket_prefix = "core/packages"
        
        # Set input directory
        if input_dir:
            self.input_dir = input_dir
        else:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.input_dir = os.path.join(project_root, 'build', 'bundled')
        
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
    
    def _upload_to_r2(self, local_path, remote_key):
        """
        Upload a file to Cloudflare R2.
        
        Args:
            local_path: Local file path
            remote_key: S3 key (path in bucket)
        """
        try:
            self.s3_client.upload_file(
                local_path,
                self.bucket_name,
                remote_key,
                ExtraArgs={'ContentType': self._get_content_type(local_path)}
            )
            print(f"  Uploaded to s3://{self.bucket_name}/{remote_key}")
        except ClientError as e:
            raise Exception(f"Failed to upload to R2: {e}")
    
    def _get_content_type(self, file_path):
        """Get appropriate content type for file."""
        if file_path.endswith('.mhl'):
            return 'application/zip'
        elif file_path.endswith('.json'):
            return 'application/json'
        return 'application/octet-stream'
    
    def upload_package(self, mhl_path):
        """
        Upload a single .mhl package and its .mip.json file.
        
        Args:
            mhl_path: Path to the .mhl file
        
        Returns:
            True if successful, False otherwise
        """
        mhl_filename = os.path.basename(mhl_path)
        
        print(f"\nUploading: {mhl_filename}")
        
        # Check for corresponding .mip.json file
        mip_json_path = f"{mhl_path}.mip.json"
        if not os.path.exists(mip_json_path):
            print(f"  Error: {mhl_filename}.mip.json not found")
            return False
        
        if self.dry_run:
            print(f"  [DRY RUN] Would upload {mhl_filename}")
            print(f"  [DRY RUN] Would upload {mhl_filename}.mip.json")
            return True
        
        try:
            # Upload .mhl file
            mhl_key = f"{self.bucket_prefix}/{mhl_filename}"
            self._upload_to_r2(mhl_path, mhl_key)
            
            # Upload .mip.json file
            mip_json_key = f"{self.bucket_prefix}/{mhl_filename}.mip.json"
            self._upload_to_r2(mip_json_path, mip_json_key)
            
            print(f"  Successfully uploaded {mhl_filename}")
            return True
            
        except Exception as e:
            print(f"  Error uploading package: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def upload_all(self):
        """
        Upload all .mhl packages in the input directory.
        
        Returns:
            True if all succeeded, False if any failed
        """
        if not os.path.exists(self.input_dir):
            # assume nothing to upload
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
        description='Upload bundled MATLAB packages to Cloudflare R2'
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
    
    # Create uploader
    uploader = PackageUploader(
        dry_run=args.dry_run,
        input_dir=args.input_dir
    )
    
    # Upload all packages
    print("Starting package upload process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual uploading will occur]")
    
    success = uploader.upload_all()
    
    if success:
        print("\n✓ All packages uploaded successfully")
        return 0
    else:
        print("\n✗ Upload process failed")
        return 1

if __name__ == '__main__':
    sys.exit(main())