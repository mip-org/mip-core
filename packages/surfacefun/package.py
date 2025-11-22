#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_multiple_paths

class Package:
    def __init__(self):
        self.name = "surfacefun"
        self.description = "Surfacefun is a MATLAB package for numerically computing with functions on surfaces with high-order accuracy."
        self.version = "latest"
        self.build_number = 0
        self.dependencies = ["chebfun"]
        self.homepage = "https://github.com/danfortunato/surfacefun"
        self.repository = "https://github.com/danfortunato/surfacefun"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during build
        self.exposed_symbols = []
    def build(self, mhl_dir: str):
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
            f.write("setup_file = fullfile(surfacefun_path, 'setup.m');\n")
            f.write("if exist(setup_file, 'file')\n")
            f.write("    run(setup_file);\n")
            f.write("end\n")
        # Collect exposed symbols
        print("Collecting exposed symbols...")
        
        tools_dir = os.path.join(surfacefun_dir, "tools")
        self.exposed_symbols = collect_exposed_symbols_multiple_paths(
            [surfacefun_dir, tools_dir],
            ["surfacefun", "surfacefun/tools"]
        )
