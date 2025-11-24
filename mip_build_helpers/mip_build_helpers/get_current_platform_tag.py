import platform


def get_current_platform_tag():
    """Detect the current platform and return the corresponding MIP platform tag
    
    Returns:
        str: Platform tag (e.g., 'linux_x86_64', 'macosx_11_0_arm64', 'win_amd64')
    """
    system = platform.system()
    machine = platform.machine().lower()
    
    # Normalize machine architecture names
    if machine in ('x86_64', 'amd64'):
        machine = 'x86_64'
    elif machine in ('aarch64', 'arm64'):
        machine = 'aarch64' if system == 'Linux' else 'arm64'
    elif machine in ('i386', 'i686'):
        machine = 'i686'
    
    if system == 'Linux':
        if machine == 'x86_64':
            return 'linux_x86_64'
        elif machine == 'aarch64':
            return 'linux_aarch64'
        elif machine == 'i686':
            return 'linux_i686'
        else:
            return f'linux_{machine}'
    
    elif system == 'Darwin':  # macOS
        if machine == 'x86_64':
            return 'macosx_10_9_x86_64'
        elif machine == 'arm64':
            return 'macosx_11_0_arm64'
        else:
            return f'macosx_10_9_{machine}'
    
    elif system == 'Windows':
        if machine == 'x86_64':
            return 'win_amd64'
        elif machine == 'arm64':
            return 'win_arm64'
        elif machine == 'i686':
            return 'win32'
        else:
            return f'win_{machine}'
    
    else:
        # Unknown platform - return a generic tag
        return f'{system.lower()}_{machine}'