#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_multiple_paths, clone_repository_and_remove_git, create_load_m_and_unload_m

class SurfacefunPackage:
    def __init__(self):
        self.name = "surfacefun"
        self.description = "Surfacefun is a MATLAB package for numerically computing with functions on surfaces with high-order accuracy."
        self.version = "unspecified"
        self.build_number = 3
        self.dependencies = ["chebfun"]
        self.homepage = "https://github.com/danfortunato/surfacefun"
        self.repository = "https://github.com/danfortunato/surfacefun"
        self.license = "unspecified"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    def prepare(self, mhl_dir: str):
        # Clone the repository
        repository_url = self.repository
        clone_dir = "surfacefun_clone"
        clone_repository_and_remove_git(repository_url, clone_dir)

        # Make the mhl structure directory
        surfacefun_dir = os.path.join(mhl_dir, "surfacefun")
        print(f'Moving surfacefun_clone to surfacefun...')
        shutil.move(clone_dir, surfacefun_dir)

        create_load_m_and_unload_m(mhl_dir, "surfacefun", subdirs=['tools'])
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
