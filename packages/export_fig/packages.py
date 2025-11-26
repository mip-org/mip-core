#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_top_level, download_and_extract_zip, create_load_and_unload_scripts

class ExportFigPackage:
    def __init__(self):
        self.name = "export_fig"
        self.description = "A toolbox for exporting figures from MATLAB to standard image and document formats nicely."
        self.version = "3.54"
        self.build_number = 10
        self.dependencies = []
        self.homepage = "https://github.com/altmany/export_fig"
        self.repository = "https://github.com/altmany/export_fig"
        self.license = "BSD-3-Clause"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    def prepare(self, mhl_dir: str):
        download_url = f"https://github.com/altmany/export_fig/archive/refs/tags/v{self.version}.zip"
        download_and_extract_zip(download_url)

        # Make the mhl structure directory
        export_fig_dir = os.path.join(mhl_dir, "export_fig")
        print(f'Moving export_fig-{self.version} to export_fig...')
        shutil.move(f"export_fig-{self.version}", export_fig_dir)

        create_load_and_unload_scripts(mhl_dir, "export_fig")
        # Collect exposed symbols
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(export_fig_dir, "export_fig")

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [ExportFigPackage()]
else:
    packages = []
