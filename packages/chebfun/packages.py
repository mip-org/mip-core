#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_top_level, download_and_extract_zip, create_setup_m

class ChebfunPackage:
    def __init__(self):
        self.name = "chebfun"
        self.description = "Chebfun is an open-source software system for numerical computing with functions."
        self.version = "unspecified"
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
        download_and_extract_zip(url)
        
        # Make the mhl structure directory
        chebfun_dir = os.path.join(mhl_dir, "chebfun")
        print(f'Moving chebfun-master to chebfun...')
        shutil.move("chebfun-master", chebfun_dir)

        create_setup_m(mhl_dir, "chebfun")

        # Collect exposed symbols
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(chebfun_dir, "chebfun")

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [ChebfunPackage()]
else:
    packages = []
