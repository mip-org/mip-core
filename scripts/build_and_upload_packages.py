#!/usr/bin/env python3
"""
Build and upload MATLAB packages (.mhl files) to Cloudflare R2 bucket.

This script:
1. Iterates through all package directories in packages/
2. Checks if the package already exists in the cloud bucket
3. Builds packages that don't exist or have changed
4. Uploads built packages to Cloudflare R2
"""

import os
import sys
import json
import zipfile
import shutil
import tempfile
import importlib.util
import argparse
import time
import requests
from datetime import datetime
from pathlib import Path

# Add parent directory to path to import mip_build_helpers
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("Error: boto3 is required. Install with: pip install boto3")
    sys.exit(1)


class PackageBuilder:
    """Handles building and uploading MATLAB packages."""
    
    def __init__(self, dry_run=False, force=False, keep_dirs=True):
        """
        Initialize the package builder.
        
        Args:
            dry_run: If True, simulate operations without actual building/uploading
            force: If True, rebuild packages even if they exist in the bucket
            keep_dirs: If True, keep temporary working directories for inspection
        """
        self.dry_run = dry_run
        self.force = force
        self.keep_dirs = keep_dirs
        self.base_url = "https://mip-packages.neurosift.app/packages/core"
        self.bucket_name = "mip-packages"
        self.bucket_prefix = "packages/core"
        self.work_dirs = []
        
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
    
    def _get_mhl_filename(self, package):
        """
        Generate the .mhl filename for a package.
        
        Args:
            package: Package instance
        
        Returns:
            Filename string in format: name-version-matlab_tag-abi_tag-platform_tag.mhl
        """
        return (
            f"{package.name}-{package.version}-{package.matlab_tag}-"
            f"{package.abi_tag}-{package.platform_tag}.mhl"
        )
    
    def _check_existing_package(self, mhl_filename, package):
        """
        Check if package exists in bucket and if metadata matches.
        
        Args:
            mhl_filename: The .mhl filename
            package: Package instance to compare against
        
        Returns:
            True if package exists and metadata matches, False otherwise
        """
        mip_json_url = f"{self.base_url}/{mhl_filename}.mip.json"
        
        try:
            response = requests.get(mip_json_url, timeout=10)
            if response.status_code == 404:
                print(f"  Package not found in bucket")
                return False
            
            response.raise_for_status()
            existing_metadata = response.json()
            
            # Compare key metadata fields
            fields_to_compare = [
                'name', 'description', 'version', 'build_number',
                'dependencies', 'homepage', 'repository'
            ]
            
            for field in fields_to_compare:
                if existing_metadata.get(field) != getattr(package, field):
                    print(f"  Metadata mismatch in field '{field}'")
                    print(f"    Existing: {existing_metadata.get(field)}")
                    print(f"    Current:  {getattr(package, field)}")
                    return False
            
            print(f"  Package exists with matching metadata")
            return True
            
        except requests.RequestException as e:
            print(f"  Error checking existing package: {e}")
            return False
    
    def _load_package(self, package_dir):
        """
        Dynamically load Package class from package.py in the given directory.
        
        Args:
            package_dir: Path to the package directory
        
        Returns:
            Package instance or None if loading fails
        """
        package_py_path = os.path.join(package_dir, 'package.py')
        
        if not os.path.exists(package_py_path):
            print(f"  Warning: No package.py found in {package_dir}")
            return None
        
        try:
            # Load the module
            spec = importlib.util.spec_from_file_location("package_module", package_py_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            # Instantiate Package class
            if not hasattr(module, 'Package'):
                print(f"  Warning: No Package class found in {package_py_path}")
                return None
            
            return module.Package()
            
        except Exception as e:
            print(f"  Error loading package from {package_py_path}: {e}")
            return None
    
    def _create_mip_json(self, mhl_build_dir, package, build_duration):
        """
        Create mip.json metadata file in the mhl_build directory.
        
        Args:
            mhl_build_dir: Directory containing the built package
            package: Package instance
            build_duration: Time taken to build in seconds
        """
        mip_data = {
            'name': package.name,
            'description': package.description,
            'version': package.version,
            'build_number': package.build_number,
            'dependencies': package.dependencies,
            'homepage': package.homepage,
            'repository': package.repository,
            'matlab_tag': package.matlab_tag,
            'abi_tag': package.abi_tag,
            'platform_tag': package.platform_tag,
            'exposed_symbols': package.exposed_symbols,
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'build_duration': round(build_duration, 2)
        }
        
        mip_json_path = os.path.join(mhl_build_dir, 'mip.json')
        with open(mip_json_path, 'w') as f:
            json.dump(mip_data, f, indent=2)
        
        return mip_data
    
    def _create_mhl_file(self, mhl_build_dir, output_path):
        """
        Create a .mhl file by zipping the mhl_build directory.
        
        Args:
            mhl_build_dir: Directory to zip
            output_path: Path for the output .mhl file
        """
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(mhl_build_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, mhl_build_dir)
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
    
    def build_package(self, package_dir):
        """
        Build a single package.
        
        Args:
            package_dir: Path to the package directory
        
        Returns:
            True if successful, False otherwise
        """
        package_name = os.path.basename(package_dir)
        print(f"\nProcessing package: {package_name}")
        
        # Load package
        package = self._load_package(package_dir)
        if package is None:
            return False
        
        # Generate filename
        mhl_filename = self._get_mhl_filename(package)
        print(f"  MHL filename: {mhl_filename}")
        
        # Check if package already exists (unless force flag is set)
        if not self.force and self._check_existing_package(mhl_filename, package):
            print(f"  Skipping - package already up to date")
            return True
        
        if self.dry_run:
            print(f"  [DRY RUN] Would build and upload {mhl_filename}")
            return True
        
        # Create temporary working directory
        temp_dir = tempfile.mkdtemp(prefix=f"mip_build_{package_name}_")
        if self.keep_dirs:
            self.work_dirs.append(temp_dir)
        print(f"  Working directory: {temp_dir}")
        
        try:
            # Create mhl_build directory
            mhl_build_dir = os.path.join(temp_dir, 'mhl_build')
            os.makedirs(mhl_build_dir)
            
            # Build the package
            print(f"  Building package...")
            build_start = time.time()
            
            # Change to temp directory for build
            original_dir = os.getcwd()
            os.chdir(temp_dir)
            
            try:
                package.build(mhl_build_dir)
                build_duration = time.time() - build_start
                print(f"  Build completed in {build_duration:.2f} seconds")
            finally:
                os.chdir(original_dir)
            
            # Create mip.json
            print(f"  Creating mip.json...")
            mip_data = self._create_mip_json(mhl_build_dir, package, build_duration)
            
            # Create .mhl file
            mhl_path = os.path.join(temp_dir, mhl_filename)
            print(f"  Creating .mhl file...")
            self._create_mhl_file(mhl_build_dir, mhl_path)
            
            # Create standalone mip.json for upload
            mip_json_path = os.path.join(temp_dir, f"{mhl_filename}.mip.json")
            with open(mip_json_path, 'w') as f:
                json.dump(mip_data, f, indent=2)
            
            # Upload to R2
            print(f"  Uploading to R2...")
            mhl_key = f"{self.bucket_prefix}/{mhl_filename}"
            mip_json_key = f"{self.bucket_prefix}/{mhl_filename}.mip.json"
            
            self._upload_to_r2(mhl_path, mhl_key)
            self._upload_to_r2(mip_json_path, mip_json_key)
            
            print(f"  Successfully built and uploaded {mhl_filename}")
            return True
            
        except Exception as e:
            print(f"  Error building package: {e}")
            import traceback
            traceback.print_exc()
            return False
        
        finally:
            # Clean up temp directory if not keeping
            if not self.keep_dirs:
                shutil.rmtree(temp_dir, ignore_errors=True)
    
    def build_all_packages(self):
        """
        Build all packages in the packages/ directory.
        
        Returns:
            True if all succeeded, False if any failed
        """
        packages_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'packages')
        
        if not os.path.exists(packages_dir):
            print(f"Error: packages directory not found at {packages_dir}")
            return False
        
        # Get all package directories
        package_dirs = [
            os.path.join(packages_dir, d)
            for d in os.listdir(packages_dir)
            if os.path.isdir(os.path.join(packages_dir, d))
        ]
        
        if not package_dirs:
            print("No package directories found")
            return False
        
        print(f"Found {len(package_dirs)} package(s)")
        
        # Build each package
        all_success = True
        for package_dir in sorted(package_dirs):
            success = self.build_package(package_dir)
            if not success:
                print(f"\nError: Build failed for {os.path.basename(package_dir)}")
                all_success = False
                break  # Abort on first failure
        
        return all_success
    
    def cleanup(self):
        """Print information about kept working directories."""
        if self.keep_dirs and self.work_dirs:
            print("\n" + "="*60)
            print("Working directories kept for inspection:")
            for work_dir in self.work_dirs:
                print(f"  {work_dir}")
            print("="*60)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Build and upload MATLAB packages to Cloudflare R2'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without building or uploading'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Rebuild packages even if they exist in the bucket'
    )
    parser.add_argument(
        '--no-keep-dirs',
        action='store_true',
        help='Do not keep temporary working directories (they are kept by default)'
    )
    
    args = parser.parse_args()
    
    # Create builder
    builder = PackageBuilder(
        dry_run=args.dry_run,
        force=args.force,
        keep_dirs=not args.no_keep_dirs
    )
    
    # Build all packages
    print("Starting package build process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual building or uploading will occur]")
    if args.force:
        print("[FORCE MODE - Will rebuild all packages]")
    
    success = builder.build_all_packages()
    
    # Cleanup and report
    builder.cleanup()
    
    if success:
        print("\n✓ All packages processed successfully")
        return 0
    else:
        print("\n✗ Build process failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())