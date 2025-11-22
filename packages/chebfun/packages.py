#!/usr/bin/env python3
import requests
import os
import zipfile
import shutil
from mip_build_helpers import collect_exposed_symbols_top_level

class ChebfunPackage:
    def __init__(self):
        self.name = "chebfun"
        self.description = "Chebfun is an open-source software system for numerical computing with functions."
        self.version = "latest"
        self.build_number = 3
        self.dependencies = []
        self.homepage = "https://github.com/chebfun/chebfun"
        self.repository = "https://github.com/chebfun/chebfun"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    def prepare(self, mhl_dir: str):
        url = "https://github.com/chebfun/chebfun/archive/master.zip"
        download_file = "chebfun_download.zip"

        print(f'Downloading {url}...')
        response = requests.get(url)
        response.raise_for_status()

        with open(download_file, 'wb') as f:
            f.write(response.content)
        print('Download complete.')

        print("Extracting downloaded zip...")
        with zipfile.ZipFile(download_file, 'r') as zip_ref:
            zip_ref.extractall(".")
        
        # Make the mhl structure directory
        chebfun_dir = os.path.join(mhl_dir, "chebfun")
        print(f'Moving chebfun-master to chebfun...')
        shutil.move("chebfun-master", chebfun_dir)

        setup_m_path = os.path.join(mhl_dir, "setup.m")
        print("Creating setup.m...")
        with open(setup_m_path, 'w') as f:
            f.write("% Add chebfun to the MATLAB path\n")
            f.write("chebfun_path = fullfile(fileparts(mfilename('fullpath')), 'chebfun');\n")
            f.write("addpath(chebfun_path);\n")

        # Collect exposed symbols
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(chebfun_dir, "chebfun")

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [ChebfunPackage()]
else:
    packages = []