#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import collect_exposed_symbols_top_level

class ExportFigPackage:
    def __init__(self):
        self.name = "export_fig"
        self.description = "A toolbox for exporting figures from MATLAB to standard image and document formats nicely."
        self.version = "3.54"
        self.build_number = 3
        self.dependencies = []
        self.homepage = "https://github.com/altmany/export_fig"
        self.repository = "https://github.com/altmany/export_fig"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # The following are filled in during prepare
        self.exposed_symbols = []
    def prepare(self, mhl_dir: str):

        download_file = "export_fig_download.zip"
        download_url = f"https://github.com/altmany/export_fig/archive/refs/tags/v{self.version}.zip"
        print(f'Downloading {download_url}...')
        import requests
        response = requests.get(download_url)
        response.raise_for_status()

        with open(download_file, 'wb') as f:
            f.write(response.content)
        print("Download complete.")

        print("Extracting downloaded zip...")
        import zipfile
        with zipfile.ZipFile(download_file, 'r') as zip_ref:
            zip_ref.extractall(".")

        # Make the mhl structure directory
        export_fig_dir = os.path.join(mhl_dir, "export_fig")
        print(f'Moving export_fig-{self.version} to export_fig...')
        shutil.move(f"export_fig-{self.version}", export_fig_dir)

        setup_m_path = os.path.join(mhl_dir, "setup.m")
        print("Creating setup.m...")
        with open(setup_m_path, 'w') as f:
            f.write("% Add export_fig to the MATLAB path\n")
            f.write(f"export_fig_path = fullfile(fileparts(mfilename('fullpath')), 'export_fig');\n")
            f.write("addpath(export_fig_path);\n")
        # Collect exposed symbols
        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(export_fig_dir, "export_fig")

if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [ExportFigPackage()]
else:
    packages = []