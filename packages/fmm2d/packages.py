#!/usr/bin/env python3
import os
import shutil
import subprocess
from mip_build_helpers import get_current_platform_tag, clone_repository_and_remove_git, collect_exposed_symbols_with_extensions, create_load_m_and_unload_m

class Fmm2dPackage:
    def __init__(self, *, platform_tag: str):
        self.name = "fmm2d"
        self.description = "Flatiron Institute Fast Multipole Methods in 2D"
        self.version = "unspecified"
        self.build_number = 1
        self.dependencies = []
        self.homepage = "https://github.com/flatironinstitute/fmm2d"
        self.repository = "https://github.com/flatironinstitute/fmm2d"
        self.license = "Apache-2.0"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = platform_tag

        # The following are filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        if self.platform_tag != 'linux_x86_64':
            raise RuntimeError(f"Fmm2dPackage can only be built on linux_x86_64, current platform is {platform_tag}")

        # Clone the repository
        repository_url = self.repository
        clone_dir = "fmm2d_clone"
        clone_repository_and_remove_git(repository_url, clone_dir)

        # Copy LICENSE file
        license_source = os.path.join(clone_dir, "LICENSE")
        license_dest = os.path.join(mhl_dir, "LICENSE")
        if not os.path.exists(license_source):
            raise RuntimeError(f"LICENSE file not found in the cloned repository at {license_source}")
        shutil.copyfile(license_source, license_dest)

        # Modify makefile to replace -march=native with -march=x86-64
        print("Modifying makefile to use -march=x86-64...")
        makefile_path = os.path.join(clone_dir, "makefile")
        if not os.path.exists(makefile_path):
            raise RuntimeError(f"makefile not found at {makefile_path}")
        
        with open(makefile_path, 'r') as f:
            makefile_content = f.read()
        
        if '-march=native' not in makefile_content:
            raise RuntimeError("Could not find '-march=native' in makefile")
        
        modified_content = makefile_content.replace('-march=native', '-march=x86-64')
        
        with open(makefile_path, 'w') as f:
            f.write(modified_content)
        
        print("makefile modified successfully")

        # Run 'make matlab' in the cloned directory
        print("Running 'make matlab'...")
        subprocess.run(
            ["make", "matlab"],
            cwd=clone_dir,
            check=True
        )

        # Check if matlab/ directory was created
        matlab_dir = os.path.join(clone_dir, "matlab")
        if not os.path.exists(matlab_dir):
            raise RuntimeError(f"Expected {matlab_dir} to be created by 'make matlab'")

        # Copy matlab directory to fmm2d directory in mhl_dir
        fmm2d_dir = os.path.join(mhl_dir, "fmm2d")
        print(f'Copying matlab/ directory to fmm2d/...')
        shutil.copytree(matlab_dir, fmm2d_dir)

        # Clean up clone directory
        print(f"Cleaning up {clone_dir}...")
        shutil.rmtree(clone_dir)

        # Create load.m
        create_load_m_and_unload_m(mhl_dir, "fmm2d")

        # Collect exposed symbols from fmm2d directory (including .m and .c files)
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_with_extensions(fmm2d_dir, ['.m', '.c'])

# The "make matlab" command is not going to work in the github actions runner
# So we only include this package when the BUILD_TYPE is linux_workstation

platform_tag = get_current_platform_tag()

if os.environ.get('BUILD_TYPE') == 'linux_workstation' and platform_tag == 'linux_x86_64':
    packages = [Fmm2dPackage(platform_tag=platform_tag)]
else:
    packages = []
