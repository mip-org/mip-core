#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import clone_repository_and_remove_git, collect_exposed_symbols_with_extensions, create_load_m_and_unload_m

class KdtreePackage:
    def __init__(self):
        self.name = "kdtree"
        self.description = "This library provides a minimalist implementation of a kd-tree data structure."
        self.version = "unspecified"
        self.build_number = 3
        self.dependencies = []
        self.homepage = "https://github.com/taiya/kdtree"
        self.repository = "https://github.com/taiya/kdtree"
        self.license = "unspecified"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        # Clone the repository
        repository_url = self.repository
        clone_dir = "kdtree_clone"
        clone_repository_and_remove_git(repository_url, clone_dir)

        # Copy toolbox directory to kdtree directory
        toolbox_src = os.path.join(clone_dir, "toolbox")
        kdtree_dir = os.path.join(mhl_dir, "kdtree")
        print(f'Copying toolbox directory to kdtree...')
        shutil.copytree(toolbox_src, kdtree_dir)

        # Clean up clone directory
        print(f"Cleaning up {clone_dir}...")
        shutil.rmtree(clone_dir)

        # Create load.m
        create_load_m_and_unload_m(mhl_dir, "kdtree")

        # Copy compile_kdtree.m to the mhl directory
        package_dir = os.path.dirname(os.path.abspath(__file__))
        compile_kdtree_src = os.path.join(package_dir, "compile_kdtree.m")
        compile_kdtree_dest = os.path.join(mhl_dir, "compile_kdtree.m")
        print("Copying compile_kdtree.m...")
        shutil.copy(compile_kdtree_src, compile_kdtree_dest)

        # Create compile.m that calls compile_kdtree
        compile_m_path = os.path.join(mhl_dir, "compile.m")
        print("Creating compile.m...")
        with open(compile_m_path, 'w') as f:
            f.write("% Compile kdtree package\n")
            f.write("compile_kdtree;\n")

        # Collect exposed symbols from kdtree directory (including both .m and .cpp files)
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_with_extensions(kdtree_dir, ['.m', '.cpp'])

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [KdtreePackage()]
else:
    packages = []
