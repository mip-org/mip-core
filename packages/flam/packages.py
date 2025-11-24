#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_recursive, clone_repository_and_remove_git, create_setup_m

class FlamPackage:
    def __init__(self):
        self.name = "flam"
        self.description = "Fast Linear Algebra in MATLAB (FLAM) - A library for hierarchical matrices and fast direct solvers."
        self.version = "unspecified"
        self.build_number = 1
        self.dependencies = []
        self.homepage = "https://github.com/klho/FLAM"
        self.repository = "https://github.com/klho/FLAM"
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

        # Move FLAM to flam in the mhl directory (lowercase for consistency)
        flam_dir = os.path.join(mhl_dir, "flam")
        print(f'Moving FLAM to flam...')
        shutil.move(clone_dir, flam_dir)

        # Create setup.m file
        create_setup_m(mhl_dir, "flam", run_startup=True)

        # Collect exposed symbols recursively (excluding test and paper directories)
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_recursive(
            flam_dir, 
            "flam", 
            exclude_dirs=['test', 'paper']
        )

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [FlamPackage()]
else:
    packages = []
