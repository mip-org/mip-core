import os


def create_load_and_unload_scripts(mhl_dir, package_name, subdirs=None, add_all_subdirs=False):
    """
    Create load_package.m and unload_package.m files that add/remove package directories to/from the MATLAB path.
    
    Args:
        mhl_dir: The MHL directory where load_package.m and unload_package.m will be created
        package_name: The name of the package (used for the main directory)
        subdirs: List of subdirectories to add to path (in addition to main package dir)
                Example: ['tools'] will add both package_name and package_name/tools
                If None, only the main package directory is added
        add_all_subdirs: If True, add all subdirectories under the package directory
                         (should not be used with subdirs argument)
    """
    load_m_path = os.path.join(mhl_dir, "load_package.m")
    unload_m_path = os.path.join(mhl_dir, "unload_package.m")
    print("Creating load_package.m and unload_package.m...")

    if add_all_subdirs:
        if subdirs is not None:
            raise ValueError("Cannot use add_all_subdirs=True with subdirs argument")
        # Determine subdirs automatically as all directories under package_name recursively
        package_dir = os.path.join(mhl_dir, package_name)
        subdirs = []
        for root, dirs, files in os.walk(package_dir):
            rel_root = os.path.relpath(root, package_dir)
            if rel_root != '.':
                subdirs.append(rel_root)

    with open(load_m_path, 'w') as f:
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

    # Create unload_package.m file
    with open(unload_m_path, 'w') as f:
        f.write(f"% Remove {package_name} from the MATLAB path\n")
        
        # Remove subdirectories first (in reverse order for cleanliness)
        if subdirs:
            f.write(f"{package_name}_path = fullfile(fileparts(mfilename('fullpath')), '{package_name}');\n")
            for subdir in reversed(subdirs):
                f.write(f"% Remove {package_name}/{subdir} from the path\n")
                f.write(f"{subdir}_path = fullfile({package_name}_path, '{subdir}');\n")
                f.write(f"rmpath({subdir}_path);\n")
        else:
            # If no subdirs, still need to define package_name_path
            f.write(f"{package_name}_path = fullfile(fileparts(mfilename('fullpath')), '{package_name}');\n")
        
        # Remove main package directory last
        f.write(f"rmpath({package_name}_path);\n")
