#!/usr/bin/env python3
import os
import subprocess
import tempfile
import pytest
from pathlib import Path


def test_surfacefun_installation_and_execution():
    """Test surfacefun package installation and MATLAB script execution."""
    
    # Create a temporary directory for MIP_DIR
    with tempfile.TemporaryDirectory() as tmp_dir:
        # Set MIP_DIR environment variable
        env = os.environ.copy()
        env['MIP_DIR'] = tmp_dir
        
        print(f"MIP_DIR set to: {tmp_dir}")
        
        # Run mip install surfacefun
        print("Running: mip install surfacefun")
        result = subprocess.run(
            ['mip', 'install', 'surfacefun'],
            env=env,
            capture_output=True,
            text=True
        )
        
        print(f"mip install stdout:\n{result.stdout}")
        if result.stderr:
            print(f"mip install stderr:\n{result.stderr}")
        
        assert result.returncode == 0, f"mip install failed with return code {result.returncode}"
        
        # Check that required directories were created
        chebfun_dir = Path(tmp_dir) / 'packages' / 'chebfun'
        surfacefun_dir = Path(tmp_dir) / 'packages' / 'surfacefun'
        
        assert chebfun_dir.exists(), f"chebfun directory not found at {chebfun_dir}"
        assert chebfun_dir.is_dir(), f"{chebfun_dir} is not a directory"
        print(f"✓ chebfun directory verified at {chebfun_dir}")
        
        assert surfacefun_dir.exists(), f"surfacefun directory not found at {surfacefun_dir}"
        assert surfacefun_dir.is_dir(), f"{surfacefun_dir} is not a directory"
        print(f"✓ surfacefun directory verified at {surfacefun_dir}")
        
        # Create the MATLAB test script
        matlab_script = Path(tmp_dir) / 'test_hodge_decomposition.m'
        matlab_code = """
mip_dir = getenv('MIP_DIR');
addpath(fullfile(mip_dir, 'matlab'));
% verify that MIP_DIR/matlab exists
if ~isfolder(fullfile(mip_dir, 'matlab'))
    error('MIP_DIR/matlab does not exist');
end

mip.import('surfacefun')

% Construct a toroidal mesh
p = 16; nu = 16; nv = 48;
dom = surfacemesh.torus(p+1, nu, nv);

% Make a random smooth tangential vector field
rng(0)
gx = randnfun3(10, boundingbox(dom));
gy = randnfun3(10, boundingbox(dom));
gz = randnfun3(10, boundingbox(dom));
g = cross([0 1 1], surfacefunv(@(x,y,z) gx(x,y,z), ...
                               @(x,y,z) gy(x,y,z), ...
                               @(x,y,z) gz(x,y,z), dom));
vn = normal(dom);
f = -cross(vn, vn, g);

% Compute the Hodge decomposition
tic
[u, v, w] = hodge(f);
toc

x = norm(div(w));
assert(x < 1e-6, 'Divergence-free component is not divergence-free');

y = norm(div(cross(vn, w)));
assert(y < 1e-6, 'Curl-free component is not curl-free');

disp('✓ Hodge decomposition test passed');
"""
        
        with open(matlab_script, 'w') as f:
            f.write(matlab_code)
        
        print(f"Created MATLAB script at {matlab_script}")
        
        # Run the MATLAB script
        print("Running MATLAB script...")
        result = subprocess.run(
            ['matlab', '-batch', f"cd('{tmp_dir}'); run('{matlab_script.name}')"],
            env=env,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        print(f"MATLAB stdout:\n{result.stdout}")
        if result.stderr:
            print(f"MATLAB stderr:\n{result.stderr}")
        
        assert result.returncode == 0, f"MATLAB script failed with return code {result.returncode}"
        
        print("✓ Test completed successfully")


if __name__ == '__main__':
    test_surfacefun_installation_and_execution()
