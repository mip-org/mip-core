#!/usr/bin/env python3
"""
Prepare MATLAB packages by building them into .dir directories.

This script:
1. Iterates through all package directories in packages/
2. Checks if the package already exists in the cloud bucket (optional skip)
3. Builds packages that don't exist or have changed
4. Saves built packages as [wheel_name].dir directories in build/prepared/

The output .dir directories can then be processed by bundle_and_upload_packages.py
"""

import os
import sys
import json
import shutil
import importlib.util
import argparse
import time
import requests
from datetime import datetime
from pathlib import Path

# Add parent directory to path to import mip_build_helpers
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class PackagePreparer:
    """Handles preparing MATLAB packages by building them into .dir directories."""
    
    def __init__(self, dry_run=False, force=False, output_dir=None):
        """
        Initialize the package preparer.
        
        Args:
            dry_run: If True, simulate operations without actual building
            force: If True, rebuild packages even if they exist in the bucket
            output_dir: Directory where .dir packages will be created (default: build/prepared)
        """
        self.dry_run = dry_run
        self.force = force
        self.base_url = "https://mip-packages.neurosift.app/core/packages"
        
        # Set output directory
        if output_dir:
            self.output_dir = output_dir
        else:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.output_dir = os.path.join(project_root, 'build', 'prepared')
        
        # Create output directory if it doesn't exist
        if not self.dry_run:
            os.makedirs(self.output_dir, exist_ok=True)
    
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
    
    def _get_wheel_name(self, package):
        """
        Generate the wheel name (mhl filename without extension) for a package.
        
        Args:
            package: Package instance
        
        Returns:
            Wheel name string
        """
        mhl_filename = self._get_mhl_filename(package)
        return mhl_filename[:-4]  # Remove .mhl extension
    
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
    
    def _create_mip_json(self, *, mhl_build_dir, package, prepare_duration, compile_duration, mhl_filename):
        """
        Create mip.json metadata file in the mhl_build directory.
        
        Args:
            mhl_build_dir: Directory containing the built package
            package: Package instance
            prepare_duration: Time taken to prepare in seconds
            compile_duration: Time taken to compile in seconds
            mhl_filename: The .mhl filename for this package
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
            'prepare_duration': round(prepare_duration, 2),
            'compile_duration': round(compile_duration, 2),
            'mhl_url': f"{self.base_url}/{mhl_filename}"
        }
        
        mip_json_path = os.path.join(mhl_build_dir, 'mip.json')
        with open(mip_json_path, 'w') as f:
            json.dump(mip_data, f, indent=2)
        
        return mip_data
    
    def prepare_package(self, package_dir):
        """
        Prepare a single package by building it into a .dir directory.
        
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
        
        # Generate filename and wheel name
        mhl_filename = self._get_mhl_filename(package)
        wheel_name = self._get_wheel_name(package)
        print(f"  Wheel name: {wheel_name}")
        
        # Check if package already exists (unless force flag is set)
        if not self.force and self._check_existing_package(mhl_filename, package):
            print(f"  Skipping - package already up to date")
            return True
        
        if self.dry_run:
            print(f"  [DRY RUN] Would prepare {wheel_name}.dir")
            return True
        
        # Create output directory path
        output_dir_path = os.path.join(self.output_dir, f"{wheel_name}.dir")
        
        # Remove existing .dir if it exists
        if os.path.exists(output_dir_path):
            print(f"  Removing existing directory: {output_dir_path}")
            shutil.rmtree(output_dir_path)
        
        print(f"  Output directory: {output_dir_path}")
        
        try:
            # Create the .dir directory
            os.makedirs(output_dir_path)
            
            # Build the package
            print(f"  Building package...")
            build_start = time.time()
            
            # Change to output directory for build
            original_dir = os.getcwd()
            os.chdir(self.output_dir)
            
            try:
                package.prepare(output_dir_path)
                prepare_duration = time.time() - build_start
                print(f"  Prepare completed in {prepare_duration:.2f} seconds")
            finally:
                os.chdir(original_dir)
            
            # Create mip.json inside the .dir
            print(f"  Creating mip.json...")
            self._create_mip_json(output_dir_path=output_dir_path, package=package, prepare_duration=prepare_duration, compile_duration=0, mhl_filename=mhl_filename)

            print(f"  Successfully prepared {wheel_name}.dir")
            return True
            
        except Exception as e:
            print(f"  Error preparing package: {e}")
            import traceback
            traceback.print_exc()
            
            # Clean up failed directory
            if os.path.exists(output_dir_path):
                shutil.rmtree(output_dir_path, ignore_errors=True)
            
            return False
    
    def prepare_all_packages(self):
        """
        Prepare all packages in the packages/ directory.
        
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
        print(f"Output directory: {self.output_dir}")
        
        # Prepare each package
        all_success = True
        for package_dir in sorted(package_dirs):
            success = self.prepare_package(package_dir)
            if not success:
                print(f"\nError: Preparation failed for {os.path.basename(package_dir)}")
                all_success = False
                break  # Abort on first failure
        
        return all_success

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Prepare MATLAB packages by building them into .dir directories'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without building'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Rebuild packages even if they exist in the bucket'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        help='Directory where .dir packages will be created (default: build/prepared)'
    )
    
    args = parser.parse_args()
    
    # Create preparer
    preparer = PackagePreparer(
        dry_run=args.dry_run,
        force=args.force,
        output_dir=args.output_dir
    )
    
    # Prepare all packages
    print("Starting package preparation process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual building will occur]")
    if args.force:
        print("[FORCE MODE - Will rebuild all packages]")
    
    success = preparer.prepare_all_packages()
    
    if success:
        print("\n✓ All packages prepared successfully")
        return 0
    else:
        print("\n✗ Preparation process failed")
        return 1

if __name__ == '__main__':
    sys.exit(main())
