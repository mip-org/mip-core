#!/usr/bin/env python3
"""
Helper functions for building MATLAB package (.mhl) files.
"""
import os
import json
import subprocess
import shutil
import requests
import zipfile


def clone_repository_and_remove_git(repository_url, clone_dir):
    """
    Clone a git repository and automatically remove all .git directories.
    
    This is useful for package preparation where we want the source code
    but don't need the git history, reducing package size.
    
    Args:
        repository_url: The URL of the git repository to clone
        clone_dir: The directory name to clone into
    """
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


def download_and_extract_zip(url, extract_dir="."):
    """
    Download a ZIP file from a URL and extract it.
    
    Args:
        url: The URL to download the ZIP file from
        extract_dir: The directory to extract the contents to (default: ".")
    
    Returns:
        None
    """
    download_file = "temp_download.zip"
    
    print(f'Downloading {url}...')
    response = requests.get(url)
    response.raise_for_status()
    
    with open(download_file, 'wb') as f:
        f.write(response.content)
    print('Download complete.')
    
    print("Extracting downloaded zip...")
    with zipfile.ZipFile(download_file, 'r') as zip_ref:
        zip_ref.extractall(extract_dir)
    
    # Clean up the downloaded file
    os.remove(download_file)

def _extract_symbol_name(item_name):
    """Extract the symbol name from a file or directory name.
    
    Examples:
        'filename.m' → 'filename'
        '+packagename' → 'packagename'
        '@classname' → 'classname'
    
    Args:
        item_name: The file or directory name
    
    Returns:
        The extracted symbol name
    """
    # Remove .m extension if present
    if item_name.endswith('.m'):
        item_name = item_name[:-2]
    
    # Remove + or @ prefix if present
    if item_name.startswith('+') or item_name.startswith('@'):
        item_name = item_name[1:]
    
    return item_name


def collect_exposed_symbols_with_extensions(package_dir, extensions=None):
    """
    Collect exposed symbols from a directory, including files with specified extensions.
    
    This is useful for packages that expose MEX files (.c, .cpp) in addition to .m files.
    
    Args:
        package_dir: The directory to scan
        extensions: List of file extensions to include (e.g., ['.m', '.c', '.cpp'])
                   If None, defaults to ['.m']
    
    Returns:
        List of symbol names
    """
    if extensions is None:
        extensions = ['.m']
    
    symbols = []
    
    if not os.path.exists(package_dir):
        return symbols
    
    items = os.listdir(package_dir)
    
    for item in sorted(items):
        item_path = os.path.join(package_dir, item)
        
        if os.path.isfile(item_path):
            # Check if file has one of the specified extensions
            for ext in extensions:
                if item.endswith(ext):
                    # Remove the extension
                    symbols.append(item[:-len(ext)])
                    break
        elif os.path.isdir(item_path) and (item.startswith('+') or item.startswith('@')):
            # Add package or class directory (without + or @)
            symbols.append(item[1:])
    
    return symbols

def collect_exposed_symbols_top_level(package_dir, base_path="."):
    """
    Collect exposed symbols from the top level of a directory.
    
    Finds:
    - All .m files at the top level
    - All directories starting with '+' (packages)
    - All directories starting with '@' (classes)
    
    Args:
        package_dir: The directory to scan
        base_path: The base path to prepend to symbol names (default: ".")
    
    Returns:
        List of relative paths to exposed symbols
    """
    symbols = []
    
    if not os.path.exists(package_dir):
        return symbols
    
    items = os.listdir(package_dir)
    
    for item in sorted(items):
        item_path = os.path.join(package_dir, item)
        
        if item.endswith('.m') and os.path.isfile(item_path):
            # Add .m file (extract symbol name only)
            symbols.append(_extract_symbol_name(item))
        elif os.path.isdir(item_path) and (item.startswith('+') or item.startswith('@')):
            # Add package or class directory (extract symbol name only)
            symbols.append(_extract_symbol_name(item))
    
    return symbols


def collect_exposed_symbols_recursive(package_dir, base_path=".", exclude_dirs=None):
    """
    Recursively collect exposed symbols from a directory tree.
    
    Finds:
    - All .m files at any depth
    - All directories starting with '+' (packages) at any depth
    - All directories starting with '@' (classes) at any depth
    
    Args:
        package_dir: The root directory to scan recursively
        base_path: The base path to prepend to symbol names (default: ".")
        exclude_dirs: List of directory names to exclude from scanning (default: None)
    
    Returns:
        List of relative paths to exposed symbols
    """
    symbols = []
    
    if not os.path.exists(package_dir):
        return symbols
    
    if exclude_dirs is None:
        exclude_dirs = []
    
    for root, dirs, files in os.walk(package_dir):
        # Remove excluded directories from the dirs list to prevent os.walk from descending into them
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        # Calculate the relative path from package_dir
        rel_root = os.path.relpath(root, package_dir)
        if rel_root == '.':
            current_base = base_path
        else:
            current_base = os.path.join(base_path, rel_root)
        
        # Add .m files (extract symbol name only)
        for file in sorted(files):
            if file.endswith('.m'):
                symbols.append(_extract_symbol_name(file))
        
        # Add package and class directories (extract symbol name only)
        for dir_name in sorted(dirs):
            if dir_name.startswith('+') or dir_name.startswith('@'):
                symbols.append(_extract_symbol_name(dir_name))
    
    return sorted(symbols)


def collect_exposed_symbols_multiple_paths(package_dirs, base_paths):
    """
    Collect exposed symbols from multiple top-level directories.
    
    Args:
        package_dirs: List of directories to scan (each scanned at top level only)
        base_paths: List of base paths corresponding to each directory
    
    Returns:
        List of relative paths to exposed symbols
    """
    symbols = []
    
    for package_dir, base_path in zip(package_dirs, base_paths):
        symbols.extend(collect_exposed_symbols_top_level(package_dir, base_path))
    
    return sorted(symbols)


def create_setup_m(mhl_dir, package_name, subdirs=None, run_startup=False):
    """
    Create a setup.m file that adds package directories to the MATLAB path.
    
    Args:
        mhl_dir: The MHL directory where setup.m will be created
        package_name: The name of the package (used for the main directory)
        subdirs: List of subdirectories to add to path (in addition to main package dir)
                Example: ['tools'] will add both package_name and package_name/tools
                If None, only the main package directory is added
        run_startup: If True, checks for and runs a startup.m file in the package directory
    """
    setup_m_path = os.path.join(mhl_dir, "setup.m")
    print("Creating setup.m...")
    
    with open(setup_m_path, 'w') as f:
        f.write(f"% Add {package_name} to the MATLAB path\n")
        
        # Add main package directory
        f.write(f"{package_name}_path = fullfile(fileparts(mfilename('fullpath')), '{package_name}');\n")
        f.write(f"addpath({package_name}_path);\n")
        
        # Add subdirectories if specified
        if subdirs:
            for subdir in subdirs:
                f.write(f"% Add {package_name}/{subdir} to the path\n")
                f.write(f"{subdir}_path = fullfile({package_name}_path, '{subdir}');\n")
                f.write(f"addpath({subdir}_path);\n")
        
        # Run startup.m if requested
        if run_startup:
            f.write(f"startup_file = fullfile({package_name}_path, 'startup.m');\n")
            f.write("if exist(startup_file, 'file')\n")
            f.write("    run(startup_file);\n")
            f.write("end\n")

def create_mip_json(mip_json_path, package_name=None, dependencies=None, exposed_symbols=None, version=None):
    """
    Create a mip.json file with package name, dependencies, exposed_symbols and version.
    
    Args:
        mip_json_path: Path where the mip.json file should be created
        package_name: Name of the package (default: None)
        dependencies: List of package dependencies (default: [])
        exposed_symbols: List of exposed symbol paths (default: [])
        version: Version of the package (default: None)
    """
    if dependencies is None:
        dependencies = []
    if exposed_symbols is None:
        exposed_symbols = []
    
    mip_config = {
        "dependencies": dependencies,
        "exposed_symbols": exposed_symbols
    }
    
    # Add package name if provided
    if package_name is not None:
        mip_config["package"] = package_name
    
    # Add version if provided
    if version is not None:
        mip_config["version"] = version
    
    with open(mip_json_path, 'w') as f:
        json.dump(mip_config, f, indent=2)
