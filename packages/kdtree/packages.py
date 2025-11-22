#!/usr/bin/env python3
import os
import shutil
import subprocess

class KdtreePackage:
    def __init__(self):
        self.name = "kdtree"
        self.description = "This library provides a minimalist implementation of a kd-tree data structure."
        self.version = "latest"
        self.build_number = 3
        self.dependencies = []
        self.homepage = "https://github.com/taiya/kdtree"
        self.repository = "https://github.com/taiya/kdtree"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        # Clone the repository
        repository_url = self.repository
        clone_dir = "kdtree_clone"
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

        # Copy toolbox directory to kdtree directory
        toolbox_src = os.path.join(clone_dir, "toolbox")
        kdtree_dir = os.path.join(mhl_dir, "kdtree")
        print(f'Copying toolbox directory to kdtree...')
        shutil.copytree(toolbox_src, kdtree_dir)

        # Clean up clone directory
        print(f"Cleaning up {clone_dir}...")
        shutil.rmtree(clone_dir)

        # Create setup.m
        setup_m_path = os.path.join(mhl_dir, "setup.m")
        print("Creating setup.m...")
        with open(setup_m_path, 'w') as f:
            f.write("% Add kdtree to the MATLAB path\n")
            f.write("kdtree_path = fullfile(fileparts(mfilename('fullpath')), 'kdtree');\n")
            f.write("addpath(kdtree_path);\n")

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
        self.exposed_symbols = self._collect_kdtree_symbols(kdtree_dir)

    def _collect_kdtree_symbols(self, toolbox_dir):
        """
        Collect exposed symbols from kdtree toolbox directory.
        Includes both .m and .cpp files.
        
        Args:
            toolbox_dir: The toolbox directory to scan
        
        Returns:
            List of symbol names
        """
        symbols = []
        
        if not os.path.exists(toolbox_dir):
            return symbols
        
        items = os.listdir(toolbox_dir)
        
        for item in sorted(items):
            item_path = os.path.join(toolbox_dir, item)
            
            if os.path.isfile(item_path):
                # Add .m files
                if item.endswith('.m'):
                    symbols.append(item[:-2])  # Remove .m extension
                # Add .cpp files
                elif item.endswith('.cpp'):
                    symbols.append(item[:-4])  # Remove .cpp extension
        
        return symbols

packages = [KdtreePackage()]
