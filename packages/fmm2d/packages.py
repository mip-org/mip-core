#!/usr/bin/env python3
import os
import shutil
import subprocess
from mip_build_helpers import get_current_platform_tag

class Fmm2dPackage:
    def __init__(self):
        self.name = "fmm2d"
        self.description = "Flatiron Institute Fast Multipole Methods in 2D"
        self.version = "unspecified"
        self.build_number = 1
        self.dependencies = []
        self.homepage = "https://github.com/flatironinstitute/fmm2d"
        self.repository = "https://github.com/flatironinstitute/fmm2d"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        platform_tag = get_current_platform_tag()
        if platform_tag != 'linux_x86_64':
            raise RuntimeError(f"Fmm2dPackage can only be built on linux_x86_64, current platform is {platform_tag}")
        self.platform_tag = platform_tag

        # Clone the repository
        repository_url = self.repository
        clone_dir = "fmm2d_clone"
        print(f'Cloning {repository_url}...')
        subprocess.run(
            ["git", "clone", repository_url, clone_dir],
            check=True
        )

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

        # Remove .git directories to reduce size
        print("Removing .git directories...")
        for root, dirs, files in os.walk(clone_dir):
            if ".git" in dirs:
                git_dir = os.path.join(root, ".git")
                shutil.rmtree(git_dir)
                dirs.remove(".git")

        # Copy matlab directory to fmm2d directory in mhl_dir
        fmm2d_dir = os.path.join(mhl_dir, "fmm2d")
        print(f'Copying matlab/ directory to fmm2d/...')
        shutil.copytree(matlab_dir, fmm2d_dir)

        # Clean up clone directory
        print(f"Cleaning up {clone_dir}...")
        shutil.rmtree(clone_dir)

        # Create setup.m
        setup_m_path = os.path.join(mhl_dir, "setup.m")
        print("Creating setup.m...")
        with open(setup_m_path, 'w') as f:
            f.write("% Add fmm2d to the MATLAB path\n")
            f.write("fmm2d_path = fullfile(fileparts(mfilename('fullpath')), 'fmm2d');\n")
            f.write("addpath(fmm2d_path);\n")

        # Collect exposed symbols from fmm2d directory (including .m and .c files)
        print("Collecting exposed symbols...")
        self.exposed_symbols = self._collect_fmm2d_symbols(fmm2d_dir)

    def _collect_fmm2d_symbols(self, fmm2d_dir):
        """
        Collect exposed symbols from fmm2d directory.
        Includes .m files, .c files, and +/@ directories.
        
        Args:
            fmm2d_dir: The fmm2d directory to scan
        
        Returns:
            List of symbol names
        """
        symbols = []
        
        if not os.path.exists(fmm2d_dir):
            return symbols
        
        items = os.listdir(fmm2d_dir)
        
        for item in sorted(items):
            item_path = os.path.join(fmm2d_dir, item)
            
            if os.path.isfile(item_path):
                # Add .m files
                if item.endswith('.m'):
                    symbols.append(item[:-2])  # Remove .m extension
                # Add .c files
                elif item.endswith('.c'):
                    symbols.append(item[:-2])  # Remove .c extension
            elif os.path.isdir(item_path) and (item.startswith('+') or item.startswith('@')):
                # Add package or class directory (without + or @)
                symbols.append(item[1:])
        
        return symbols

# The "make matlab" command is not going to work in the github actions runner
# So we only include this package when the BUILD_TYPE is linux_workstation

platform_tag = get_current_platform_tag()

if os.environ.get('BUILD_TYPE') == 'linux_workstation' and platform_tag == 'linux_x86_64':
    packages = [Fmm2dPackage()]
else:
    packages = []
