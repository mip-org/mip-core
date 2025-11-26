#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_recursive, clone_repository_and_remove_git, create_load_m_and_unload_m

class FLAMPackage:
    def __init__(self):
        self.name = "FLAM"
        self.description = "Fast Linear Algebra in MATLAB (FLAM) - A library for hierarchical matrices and fast direct solvers."
        self.version = "unspecified"
        self.build_number = 1
        self.dependencies = []
        self.homepage = "https://github.com/klho/FLAM"
        self.repository = "https://github.com/klho/FLAM"
        self.license = "GPL-3.0"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        # Clone the repository
        repository_url = self.repository
        clone_dir = "FLAM"
        clone_repository_and_remove_git(repository_url, clone_dir)

        # Move FLAM to FLAM in the mhl directory
        flam_dir = os.path.join(mhl_dir, "FLAM")
        print(f'Moving FLAM to FLAM...')
        shutil.move(clone_dir, flam_dir)

        # Copy LICENSE file
        license_source = os.path.join(flam_dir, "LICENSE")
        license_dest = os.path.join(mhl_dir, "LICENSE")
        if not os.path.exists(license_source):
            raise RuntimeError(f"LICENSE file not found in the cloned repository at {license_source}")
        shutil.copyfile(license_source, license_dest)

        # Create load.m file
        create_load_m_and_unload_m(mhl_dir, "FLAM", add_all_subdirs=True)

        # Collect exposed symbols recursively (excluding test and paper directories)
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_recursive(
            flam_dir, 
            "FLAM", 
            exclude_dirs=['test', 'paper']
        )

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [FLAMPackage()]
else:
    packages = []
