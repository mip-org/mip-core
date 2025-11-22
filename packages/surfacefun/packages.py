#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_multiple_paths

class SurfacefunPackage:
    def __init__(self):
        self.name = "surfacefun"
        self.description = "Surfacefun is a MATLAB package for numerically computing with functions on surfaces with high-order accuracy."
        self.version = "latest"
        self.build_number = 3
        self.dependencies = ["chebfun"]
        self.homepage = "https://github.com/danfortunato/surfacefun"
        self.repository = "https://github.com/danfortunato/surfacefun"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    def prepare(self, mhl_dir: str):
        # Clone the repository
        import subprocess

        repository_url = self.repository
        clone_dir = "surfacefun_clone"
        print(f'Cloning {repository_url}...')
        subprocess.run(
            ["git", "clone", repository_url, clone_dir],
            check=True
        )

        # Remove .git directories to reduce size
        print("Removing .git directories...")
        for root, dirs, files in os.walk(clone_dir):
            if ".git" in dirs:
                git_dir = os.path.join(root, ".git")
                shutil.rmtree(git_dir)
                dirs.remove(".git")

        # Make the mhl structure directory
        surfacefun_dir = os.path.join(mhl_dir, "surfacefun")
        print(f'Moving surfacefun_clone to surfacefun...')
        shutil.move(clone_dir, surfacefun_dir)

        setup_m_path = os.path.join(mhl_dir, "setup.m")
        print("Creating setup.m...")
        with open(setup_m_path, 'w') as f:
            f.write("% Add surfacefun to the MATLAB path and run setup\n")
            f.write("surfacefun_path = fullfile(fileparts(mfilename('fullpath')), 'surfacefun');\n")
            f.write("addpath(surfacefun_path);\n")
            # add surfacefun/tools to the path
            f.write("tools_path = fullfile(surfacefun_path, 'tools');\n")
            f.write("addpath(tools_path);\n")
        # Collect exposed symbols
        print("Collecting exposed symbols...")
        
        tools_dir = os.path.join(surfacefun_dir, "tools")
        self.exposed_symbols = collect_exposed_symbols_multiple_paths(
            [surfacefun_dir, tools_dir],
            ["surfacefun", "surfacefun/tools"]
        )

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [SurfacefunPackage()]
else:
    packages = []
