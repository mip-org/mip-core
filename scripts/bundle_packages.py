#!/usr/bin/env python3
"""
Bundle prepared MATLAB packages into .mhl files.

This script:
1. Discovers all .dir directories in the input directory
2. For each .dir:
   - Reads mip.json metadata
   - Zips the directory into a .mhl file
   - Creates standalone .mip.json file
   - Outputs to a staging directory

The resulting .mhl and .mip.json files can then be uploaded separately.
"""

import os
import sys
import json
import zipfile
import argparse

class PackageBundler:
    """Handles bundling prepared MATLAB packages into .mhl files."""
    
    def __init__(self, dry_run=False, input_dir=None, output_dir=None):
        """
        Initialize the package bundler.
        
        Args:
            dry_run: If True, simulate operations without actual bundling
            input_dir: Directory containing .dir packages (default: build/prepared)
            output_dir: Directory for output .mhl files (default: build/bundled)
        """
        self.dry_run = dry_run
        
        # Set input directory
        if input_dir:
            self.input_dir = input_dir
        else:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.input_dir = os.path.join(project_root, 'build', 'prepared')
        
        # Set output directory
        if output_dir:
            self.output_dir = output_dir
        else:
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.output_dir = os.path.join(project_root, 'build', 'bundled')
    
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
    
    def bundle_package(self, dir_path):
        """
        Bundle a single .dir package into a .mhl file.
        
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
            print(f"  [DRY RUN] Would bundle {mhl_filename}")
            return True
        
        try:
            # Create output directory if it doesn't exist
            os.makedirs(self.output_dir, exist_ok=True)
            
            # Create .mhl file
            mhl_path = os.path.join(self.output_dir, mhl_filename)
            print(f"  Creating .mhl file...")
            self._create_mhl_file(dir_path, mhl_path)
            
            # Create standalone mip.json file
            mip_json_output_path = os.path.join(self.output_dir, f"{mhl_filename}.mip.json")
            with open(mip_json_output_path, 'w') as f:
                json.dump(mip_data, f, indent=2)
            
            print(f"  Successfully bundled {mhl_filename}")
            print(f"  Output: {mhl_path}")
            return True
            
        except Exception as e:
            print(f"  Error bundling package: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def bundle_all(self):
        """
        Bundle all .dir packages in the input directory.
        
        Returns:
            True if all succeeded, False if any failed
        """
        if not os.path.exists(self.input_dir):
            print(f"Input directory {self.input_dir} does not exist. Nothing to bundle.")
            return True
        
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
        print(f"Output directory: {self.output_dir}")
        
        # Bundle each package
        all_success = True
        for dir_path in sorted(dir_paths):
            success = self.bundle_package(dir_path)
            if not success:
                print(f"\nError: Bundle failed for {os.path.basename(dir_path)}")
                all_success = False
                break  # Abort on first failure
        
        return all_success

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Bundle prepared MATLAB packages into .mhl files'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Simulate operations without bundling'
    )
    parser.add_argument(
        '--input-dir',
        type=str,
        help='Directory containing .dir packages (default: build/prepared)'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        help='Directory for output .mhl files (default: build/bundled)'
    )
    
    args = parser.parse_args()
    
    # Create bundler
    bundler = PackageBundler(
        dry_run=args.dry_run,
        input_dir=args.input_dir,
        output_dir=args.output_dir
    )
    
    # Bundle all packages
    print("Starting package bundling process...")
    if args.dry_run:
        print("[DRY RUN MODE - No actual bundling will occur]")
    
    success = bundler.bundle_all()
    
    if success:
        print("\n✓ All packages bundled successfully")
        return 0
    else:
        print("\n✗ Bundling process failed")
        return 1

if __name__ == '__main__':
    sys.exit(main())
