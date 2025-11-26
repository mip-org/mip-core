#!/usr/bin/env python3
import os
import shutil
from mip_build_helpers import download_and_extract_zip, create_load_and_unload_scripts, collect_exposed_symbols_top_level


class GUILayoutToolboxPackage:
    def __init__(self):
        self.name = "gui-layout-toolbox"
        self.description = "Layout manager for MATLAB graphical user interfaces"
        self.version = "2.4.2"
        self.build_number = 10
        self.dependencies = []
        self.homepage = "https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox"
        self.repository = ""
        self.license = "BSD-2-Clause"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # Filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        # Is this permalink to the zip file? Not sure.
        zip_url = "https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/e5af5a78-4a80-11e4-9553-005056977bd0/27611476-c814-450a-b0cb-76c2101f96ed/packages/zip"
        download_and_extract_zip(url=zip_url)

        # copy layout directory to mhl_dir
        layout_source = "layout"
        layout_dest = os.path.join(mhl_dir, "layout")
        shutil.copytree(layout_source, layout_dest)

        # Copy license.txt
        license_source = "license.txt"
        license_dest = os.path.join(mhl_dir, "license.txt")
        if not os.path.exists(license_source):
            raise RuntimeError(f"license.txt not found at {license_source}")
        shutil.copyfile(license_source, license_dest)

        create_load_and_unload_scripts(mhl_dir, "layout")

        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(mhl_dir + "/layout")


class HungarianAlgorithmForLinearAssignmentProblemsPackage:
    def __init__(self):
        self.name = "hungarian-algorithm-for-linear-assignment-problems"
        self.description = "Hungarian Algorithm for Linear Assignment Problems (V2.3)"
        self.version = "1.4.0.0"
        self.build_number = 10
        self.dependencies = []
        self.homepage = "https://www.mathworks.com/matlabcentral/fileexchange/20652-hungarian-algorithm-for-linear-assignment-problems-v2-3"
        self.repository = ""
        self.license = "BSD-2-Clause"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"
        self.usage_examples = [
            """mip load hungarian-algorithm-for-linear-assignment-problems
costMat = [4 2 8; 2 4 6; 8 6 4];
[assignment, cost] = munkres(costMat);
disp(assignment);"""
        ]

        # Filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        zip_url = "https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/submissions/20652/versions/5/download/zip"
        download_and_extract_zip(url=zip_url)
        # copy licence.txt to mhl_dir
        license_source = "license.txt"
        license_dest = os.path.join(mhl_dir, "license.txt")
        if not os.path.exists(license_source):
            raise RuntimeError(f"license.txt not found at {license_source}")
        shutil.copyfile(license_source, license_dest)

        # copy munkres.m to package/ subdirectory of mhl_dir
        munkres_source = "munkres.m"
        if not os.path.exists(munkres_source):
            raise RuntimeError(f"munkres.m not found at {munkres_source}")
        package_dir = os.path.join(mhl_dir, "package")
        os.makedirs(package_dir, exist_ok=True)
        munkres_dest = os.path.join(package_dir, "munkres.m")
        shutil.copyfile(munkres_source, munkres_dest)

        create_load_and_unload_scripts(mhl_dir, "package")

        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(package_dir)


# https://www.mathworks.com/matlabcentral/fileexchange/53593-hatchfill2
class Hatchfill2Package:
    def __init__(self):
        self.name = "hatchfill2"
        self.description = "Fills an area with hatching or speckling"
        self.version = "3.0.0.0"
        self.build_number = 10
        self.dependencies = []
        self.homepage = "https://www.mathworks.com/matlabcentral/fileexchange/53593-hatchfill2"
        self.repository = ""
        self.license = "BSD-2-Clause"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"

        # Filled in during prepare
        self.exposed_symbols = []
    
    def prepare(self, mhl_dir: str):
        zip_url = "https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/submissions/53593/versions/10/download/zip"
        download_and_extract_zip(url=zip_url)

        # Copy license.txt
        license_source = "license.txt"
        license_dest = os.path.join(mhl_dir, "license.txt")
        if not os.path.exists(license_source):
            raise RuntimeError(f"license.txt not found at {license_source}")
        shutil.copyfile(license_source, license_dest)

        # copy hatchfill2.m, hatchfill2_demo.m and hatchfill2_demo_data.mat to mhl_dir
        for filename in ["hatchfill2.m", "hatchfill2_demo.m", "hatchfill2_demo_data.mat"]:
            source_path = filename
            dest_path = os.path.join(mhl_dir, filename)
            if not os.path.exists(source_path):
                raise RuntimeError(f"{filename} not found at {source_path}")
            shutil.copyfile(source_path, dest_path)

        create_load_and_unload_scripts(mhl_dir, "hatchfill2")

        print("Collecting exposed symbols...")
        self.exposed_symbols = collect_exposed_symbols_top_level(mhl_dir)



if os.environ.get('BUILD_TYPE') == 'standard':
    packages = [GUILayoutToolboxPackage(), HungarianAlgorithmForLinearAssignmentProblemsPackage()]
else:
    packages = []