#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_top_level, clone_repository_and_remove_git, create_load_m_and_unload_m

class ChunkiePackage:
    def __init__(self):
        self.name = "chunkie"
        self.description = "A MATLAB library for solving boundary value problems with integral equations"
        self.version = "unspecified"
        self.build_number = 1
        self.dependencies = ["fmm2d", "flam"]
        self.homepage = "https://github.com/fastalgorithms/chunkie"
        self.repository = "https://github.com/fastalgorithms/chunkie"
        self.license = "BSD-3-Clause"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        # Clone the repository
        repository_url = self.repository
        clone_dir = "chunkie_clone"
        clone_repository_and_remove_git(repository_url, clone_dir)

        # Use the chunkie subdirectory inside the cloned directory
        chunkie_source = os.path.join(clone_dir, "chunkie")
        if not os.path.exists(chunkie_source):
            raise RuntimeError(f"Expected chunkie subdirectory not found at {chunkie_source}")

        # Move the chunkie subdirectory to the mhl directory
        chunkie_dir = os.path.join(mhl_dir, "chunkie")
        print(f'Moving chunkie subdirectory to mhl directory...')
        shutil.move(chunkie_source, chunkie_dir)

        # Copy LICENSE.md
        license_source = os.path.join(clone_dir, "LICENSE.md")
        license_dest = os.path.join(mhl_dir, "LICENSE.md")
        if not os.path.exists(license_source):
            raise RuntimeError(f"LICENSE.md not found in the cloned repository at {license_source}")
        shutil.copyfile(license_source, license_dest)

        # Clean up the clone directory
        print(f"Cleaning up {clone_dir}...")
        shutil.rmtree(clone_dir)

        # Create load.m file that just adds the chunkie directory to path
        create_load_m_and_unload_m(mhl_dir, "chunkie")

        # Collect exposed symbols recursively
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(
            chunkie_dir, 
            "chunkie"
        )

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [ChunkiePackage()]
else:
    packages = []
