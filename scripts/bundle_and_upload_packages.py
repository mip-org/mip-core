#!/usr/bin/env python3
"""
Bundle and upload prepared MATLAB packages to Cloudflare R2 bucket.

This script:
1. Discovers all .dir directories in the input directory
2. For each .dir:
   - Reads mip.json metadata
   - Zips the directory into a .mhl file
   - Creates standalone .mip.json file
   - Uploads both to Cloudflare R2

This script processes .dir directories created by prepare_packages.py
Index assembly is handled separately by assemble_index.py
"""

import os
import sys
import json
import zipfile
import shutil
import tempfile
import argparse

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("Error: boto3 is required. Install with: pip install boto3")
    sys.exit(1)

class PackageBundler:
    """Handles bundling and uploading prepared MATLAB packages."""
    
    def __init__(self, dry_run=False, input_dir=None):
        """
        Initialize the package bundler.
        
        Args:
            dry_run: If True, simulate operations without actual uploading
            input_dir: Directory containing .dir packages (default: build/prepared)
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
            self.input_dir = os.path.join(project_root, 'build', 'prepared')
        
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
    
    def _create_mhl_file(self, dir_path, output_path):
        """
        Create a .mhl file by zipping the directory.
        
        Args:
            dir_path: Directory to zip
            output_path: Path for the output .mhl file
        """
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(dir_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, dir_path)
                    zipf.write(file_path, arcname)
    
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
    
    def bundle_and_upload_package(self, dir_path):
        """
        Bundle and upload a single .dir package.
        
        Args:
            dir_path: Path to the .dir directory
        
        Returns:
            True if successful, False otherwise
        """
        dir_name = os.path.basename(dir_path)
        
        # Verify it's a .dir directory
        if not dir_name.endswith('.dir'):
            print(f"Skipping {dir_name} - not a .dir directory")
            return True
        
        # Extract wheel name (remove .dir extension)
        wheel_name = dir_name[:-4]
        mhl_filename = f"{wheel_name}.mhl"
        
        print(f"\nProcessing: {dir_name}")
        print(f"  MHL filename: {mhl_filename}")
        
        # Read mip.json from the directory
        mip_json_path = os.path.join(dir_path, 'mip.json')
        if not os.path.exists(mip_json_path):
            print(f"  Error: mip.json not found in {dir_path}")
            return False
        
        try:
            with open(mip_json_path, 'r') as f:
                mip_data = json.load(f)
        except Exception as e:
            print(f"  Error reading mip.json: {e}")
            return False
        
        if self.dry_run:
            print(f"  [DRY RUN] Would bundle and upload {mhl_filename}")
            return True
        
        # Create temporary directory for bundling
        temp_dir = tempfile.mkdtemp(prefix=f"mip_bundle_{wheel_name}_")
        
        try:
            # Create .mhl file
            mhl_path = os.path.join(temp_dir, mhl_filename)
            print(f"  Creating .mhl file...")
            self._create_mhl_file(dir_path, mhl_path)
            
            # Create standalone mip.json for upload
            mip_json_upload_path = os.path.join(temp_dir, f"{mhl_filename}.mip.json")
            with open(mip_json_upload_path, 'w') as f:
                json.dump(mip_data, f, indent=2)
            
            # Upload to R2
            print(f"  Uploading to R2...")
            mhl_key = f"{self.bucket_prefix}/{mhl_filename}"
            mip_json_key = f"{self.bucket_prefix}/{mhl_filename}.mip.json"
            
            self._upload_to_r2(mhl_path, mhl_key)
            self._upload_to_r2(mip_json_upload_path, mip_json_key)
            
            print(f"  Successfully bundled and uploaded {mhl_filename}")
            return True
            
        except Exception as e:
            print(f"  Error bundling/uploading package: {e}")
            import traceback
            traceback.print_exc()
            return False
        
        finally:
            # Clean up temp directory
            shutil.rmtree(temp_dir, ignore_errors=True)
    
    def bundle_and_upload_all(self):
        """
        Bundle and upload all .dir packages in the input directory.
        
        Returns:
            True if all succeeded, False if any failed
        """
        if not os.path.exists(self.input_dir):
            print(f"Error: input directory not found at {self.input_dir}")
            return False
        
        # Get all .dir directories
        dir_paths = [
            os.path.join(self.input_dir, d)
            for d in os.listdir(self.input_dir)
            if os.path.isdir(os.path.join(self.input_dir, d)) and d.endswith('.dir')
        ]
        
        if not dir_paths:
            print(f"No .dir directories found in {self.input_dir}")
            return True
        
        print(f"Found {len(dir_paths)} .dir package(s)")
        print(f"Input directory: {self.input_dir}")
        
        # Bundle and upload each package
        all_success = True
        for dir_path in sorted(dir_paths):
            success = self.bundle_and_upload_package(dir_path)
            if not success:
                print(f"\nError: Bundle/upload failed for {os.path.basename(dir_path)}")
                all_success = False
                break  # Abort on first failure
        
        return all_success

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Bundle and upload prepared MATLAB packages to Cloudflare R2'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without uploading'
    )
    parser.add_argument(
        '--input-dir',
        type=str,
        help='Directory containing .dir packages (default: build/prepared)'
    )
    
    args = parser.parse_args()
    
    # Create bundler
    bundler = PackageBundler(
        dry_run=args.dry_run,
        input_dir=args.input_dir
    )
    
    # Bundle and upload all packages
    print("Starting package bundle and upload process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual uploading will occur]")
    
    success = bundler.bundle_and_upload_all()
    
    if success:
        print("\n✓ All packages bundled and uploaded successfully")
        return 0
    else:
        print("\n✗ Bundle/upload process failed")
        return 1

if __name__ == '__main__':
    sys.exit(main())
