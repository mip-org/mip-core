#!/usr/bin/env python3
"""
Test all published packages from the MIP package index.

This script:
1. Checks that ARCHITECTURE environment variable is set
2. Downloads the package index from https://mip-org.github.io/mip-core/index.json
3. Filters packages by architecture (must match ARCHITECTURE or be "any")
4. For each matching package:
   - Creates a temporary directory for testing
   - Sets up MIP_DIR in a subdirectory
   - Creates a test_package.m file that:
     * Installs the package
     * Loads the package
     * (Later: tests the package)
     * Unloads the package
     * Uninstalls the package
   - Runs the test in MATLAB
   - Verifies all steps completed successfully
   - Provides verbose output throughout
"""

import os
import sys
import json
import shutil
import subprocess
import tempfile
import requests
from typing import List, Dict, Any

class PackageTester:
    """Handles testing of published MIP packages."""
    
    def __init__(self, architecture: str):
        """
        Initialize the package tester.
        
        Args:
            architecture: The architecture to filter packages by
        """
        self.architecture = architecture
        self.index_url = "https://mip-org.github.io/mip-core/index.json"
        self.packages = []
        self.test_results = []
    
    def download_index(self) -> bool:
        """
        Download the package index from the published URL.
        
        Returns:
            True if successful, False otherwise
        """
        print(f"\nDownloading package index from {self.index_url}...")
        
        try:
            response = requests.get(self.index_url, timeout=30)
            response.raise_for_status()
            
            index_data = response.json()
            self.packages = index_data.get('packages', [])
            
            print(f"✓ Downloaded index successfully")
            print(f"  Total packages in index: {len(self.packages)}")
            print(f"  Last updated: {index_data.get('last_updated', 'unknown')}")
            
            return True
            
        except requests.RequestException as e:
            print(f"✗ Error downloading index: {e}")
            return False
        except json.JSONDecodeError as e:
            print(f"✗ Error parsing index JSON: {e}")
            return False
    
    def filter_packages_by_architecture(self) -> List[Dict[str, Any]]:
        """
        Filter packages that match the target architecture.
        
        A package matches if its architecture is either:
        - Equal to self.architecture
        - Equal to "any"
        
        Returns:
            List of matching package metadata dictionaries
        """
        print(f"\nFiltering packages for architecture: {self.architecture}")
        
        matching_packages = []
        for pkg in self.packages:
            pkg_arch = pkg.get('architecture', 'any')
            if pkg_arch == self.architecture or pkg_arch == 'any':
                matching_packages.append(pkg)
        
        print(f"✓ Found {len(matching_packages)} matching package(s):")
        for pkg in matching_packages:
            print(f"  - {pkg.get('name')} ({pkg.get('version')}) [architecture={pkg.get('architecture')}]")
        
        return matching_packages
    
    def create_test_matlab_script(self, temp_dir: str, package_name: str) -> str:
        """
        Create the test_package.m MATLAB script.
        
        Args:
            temp_dir: The temporary directory to create the script in
            package_name: The name of the package to test
        
        Returns:
            Path to the created script
        """
        script_path = os.path.join(temp_dir, 'test_package.m')
        
        with open(script_path, 'w') as f:
            f.write(f"% Test script for {package_name}\n")
            f.write(f"fprintf('\\n=== Testing package: {package_name} ===\\n');\n")
            f.write(f"\n")
            f.write(f"% Install package\n")
            f.write(f"fprintf('Step 1: Installing {package_name}...\\n');\n")
            f.write(f"mip install {package_name}\n")
            f.write(f"fprintf('✓ Install completed\\n');\n")
            f.write(f"\n")
            f.write(f"% Load package\n")
            f.write(f"fprintf('Step 2: Loading {package_name}...\\n');\n")
            f.write(f"mip load {package_name}\n")
            f.write(f"fprintf('✓ Load completed\\n');\n")
            f.write(f"\n")
            f.write(f"% Test package (commented out for now)\n")
            f.write(f"% fprintf('Step 3: Testing {package_name}...\\n');\n")
            f.write(f"% mip test {package_name}\n")
            f.write(f"% fprintf('✓ Test completed\\n');\n")
            f.write(f"\n")
            f.write(f"% Unload package\n")
            f.write(f"fprintf('Step 3: Unloading {package_name}...\\n');\n")
            f.write(f"mip unload {package_name}\n")
            f.write(f"fprintf('✓ Unload completed\\n');\n")
            f.write(f"\n")
            f.write(f"% Uninstall package\n")
            f.write(f"fprintf('Step 4: Uninstalling {package_name}...\\n');\n")
            f.write(f"mip uninstall {package_name}\n")
            f.write(f"fprintf('✓ Uninstall completed\\n');\n")
            f.write(f"\n")
            f.write(f"fprintf('\\n=== All tests passed for {package_name} ===\\n');\n")
        
        return script_path
    
    def test_package(self, package: Dict[str, Any]) -> bool:
        """
        Test a single package.
        
        Args:
            package: Package metadata dictionary
        
        Returns:
            True if test passed, False otherwise
        """
        package_name = package.get('name', 'unknown')
        package_version = package.get('version', 'unknown')
        
        print(f"\n{'=' * 70}")
        print(f"Testing: {package_name} (version {package_version})")
        print(f"{'=' * 70}")
        
        # Create temporary directory for testing
        temp_dir = tempfile.mkdtemp(prefix=f'mip_test_{package_name}_')
        print(f"Created temporary test directory: {temp_dir}")
        
        try:
            # Create mip subdirectory for MIP_DIR
            mip_dir = os.path.join(temp_dir, 'mip')
            os.makedirs(mip_dir)
            print(f"Created MIP_DIR: {mip_dir}")
            
            # Create test script
            script_path = self.create_test_matlab_script(temp_dir, package_name)
            print(f"Created test script: {script_path}")
            
            # Prepare MATLAB command
            # We need to:
            # 1. Set MIP_DIR environment variable
            # 2. Change to the temp directory
            # 3. Run test_package
            matlab_cmd = f'cd {temp_dir}; test_package'
            
            print(f"\nRunning MATLAB command: matlab -batch \"{matlab_cmd}\"")
            print(f"With MIP_DIR={mip_dir}")
            print("-" * 70)
            
            # Run MATLAB with MIP_DIR environment variable
            env = os.environ.copy()
            env['MIP_DIR'] = mip_dir
            
            result = subprocess.run(
                ['matlab', '-batch', matlab_cmd],
                env=env,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout per package
            )
            
            print("-" * 70)
            
            # Display MATLAB output
            if result.stdout:
                print("MATLAB stdout:")
                print(result.stdout)
            
            if result.stderr:
                print("MATLAB stderr:")
                print(result.stderr)
            
            # Check exit code
            if result.returncode == 0:
                print(f"\n✓ Test PASSED for {package_name}")
                return True
            else:
                print(f"\n✗ Test FAILED for {package_name}")
                print(f"  Exit code: {result.returncode}")
                return False
                
        except subprocess.TimeoutExpired:
            print(f"\n✗ Test FAILED for {package_name}: Timeout (exceeded 5 minutes)")
            return False
        except Exception as e:
            print(f"\n✗ Test FAILED for {package_name}: {e}")
            import traceback
            traceback.print_exc()
            return False
        finally:
            # Clean up temporary directory
            try:
                shutil.rmtree(temp_dir)
                print(f"Cleaned up temporary directory: {temp_dir}")
            except Exception as e:
                print(f"Warning: Failed to clean up {temp_dir}: {e}")
    
    def test_all_packages(self) -> bool:
        """
        Test all matching packages.
        
        Returns:
            True if all tests passed, False otherwise
        """
        # Filter packages by architecture
        matching_packages = self.filter_packages_by_architecture()
        
        if not matching_packages:
            print("\nNo packages to test")
            return True
        
        # Test each package
        print(f"\n{'=' * 70}")
        print(f"Starting tests for {len(matching_packages)} package(s)")
        print(f"{'=' * 70}")
        
        passed = 0
        failed = 0
        
        for i, package in enumerate(matching_packages, 1):
            package_name = package.get('name', 'unknown')
            
            print(f"\n[{i}/{len(matching_packages)}] Testing {package_name}...")
            
            success = self.test_package(package)
            
            self.test_results.append({
                'package': package_name,
                'version': package.get('version', 'unknown'),
                'success': success
            })
            
            if success:
                passed += 1
            else:
                failed += 1
        
        # Print summary
        print(f"\n{'=' * 70}")
        print(f"TEST SUMMARY")
        print(f"{'=' * 70}")
        print(f"Total packages tested: {len(matching_packages)}")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        
        if failed > 0:
            print("\nFailed packages:")
            for result in self.test_results:
                if not result['success']:
                    print(f"  ✗ {result['package']} ({result['version']})")
        
        print(f"\n{'=' * 70}")
        
        return failed == 0


def main():
    """Main entry point."""
    print("=" * 70)
    print("MIP Published Package Testing Script")
    print("=" * 70)
    
    # Check for ARCHITECTURE environment variable
    architecture = os.environ.get('ARCHITECTURE')
    
    if not architecture:
        print("\n✗ Error: ARCHITECTURE environment variable is not set")
        print("  Please set it before running this script, e.g.:")
        print("    export ARCHITECTURE=linux_x86_64")
        print("    python scripts/test_published_packages.py")
        return 1
    
    print(f"\nARCHITECTURE: {architecture}")
    
    # Create tester
    tester = PackageTester(architecture)
    
    # Download index
    if not tester.download_index():
        print("\n✗ Failed to download package index")
        return 1
    
    # Test all packages
    all_passed = tester.test_all_packages()
    
    if all_passed:
        print("\n✓ All tests passed successfully")
        return 0
    else:
        print("\n✗ Some tests failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
