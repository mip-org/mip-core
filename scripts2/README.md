# Build and Upload Packages Scripts (YAML-Based)

This directory contains scripts for building MATLAB packages (.mhl files) from YAML specifications and uploading them to a Cloudflare R2 bucket.

## Key Differences from scripts/

- **YAML-based**: Packages are defined in `packages2/` using declarative `prepare.yaml` files
- **No mip_build_helpers dependency**: All functionality is self-contained
- **Explicit path computation**: All paths (including recursive) are computed during prepare
- **Simple & focused**: Only works with packages2/ directory

## Scripts Overview

The build and upload process consists of multiple scripts:

1. **`prepare_packages.py`** - Reads YAML specs, downloads/clones code, computes paths, creates load/unload scripts
2. **`compile_packages.m`** - Compiles packages that require MATLAB compilation (checks YAML for compile_script)
3. **`bundle_and_upload_packages.py`** - Zips `.dir` directories and uploads to R2
4. **`assemble_index.py`** - Assembles package index from R2 bucket

## Requirements

### Python Dependencies
```bash
pip install boto3 requests pyyaml
```

### Environment Variables

The upload script requires the following environment variables for Cloudflare R2 access:

- `AWS_ACCESS_KEY_ID` - Your Cloudflare R2 access key ID
- `AWS_SECRET_ACCESS_KEY` - Your Cloudflare R2 secret access key
- `AWS_ENDPOINT_URL` - Your Cloudflare R2 endpoint URL (format: `https://[account-id].r2.cloudflarestorage.com`)

Optional:
- `BUILD_TYPE` - Type of build to prepare (default: `standard`)

## Usage

### Step 1: Prepare Packages
```bash
python scripts2/prepare_packages.py
```

This will:
- Scan `packages2/` for `prepare.yaml` files
- Check BUILD_TYPE environment variable (defaults to `standard`)
- Skip packages that don't match BUILD_TYPE
- Download or clone source code based on YAML specifications
- Compute all paths (including recursive paths with exclusions)
- Collect exposed symbols from all paths
- Create `load_package.m` and `unload_package.m` scripts
- Generate `mip.json` metadata
- Output: `.dir` directories in `build/prepared/`

#### Command Line Options

**Dry Run Mode**
```bash
python scripts2/prepare_packages.py --dry-run
```

**Force Rebuild**
```bash
python scripts2/prepare_packages.py --force
```

**Custom Output Directory**
```bash
python scripts2/prepare_packages.py --output-dir /path/to/output
```

### Step 2: Compile Packages (MATLAB)
```bash
matlab -batch "cd scripts2; compile_packages"
```

This will:
- Find all `.dir` directories in `build/prepared/`
- Read corresponding `prepare.yaml` files from `packages2/`
- Check if BUILD_TYPE matches and if `compile_script` is specified
- Execute compilation for matching packages
- Update `mip.json` with compilation duration

### Step 3: Bundle and Upload
```bash
python scripts2/bundle_and_upload_packages.py
```

Same as scripts/bundle_and_upload_packages.py

### Step 4: Assemble Package Index
```bash
python scripts2/assemble_index.py
```

Same as scripts/assemble_index.py

## YAML Package Specification

Each package in `packages2/` has a `prepare.yaml` file:

```yaml
name: package-name
description: "Package description"
version: "1.0.0"
build_number: 30
dependencies: []
homepage: "https://..."
repository: "https://..."
license: "License-Type"

# Optional: file extensions to scan for symbols
symbol_extensions: [".m"]  # or [".m", ".c", ".cpp"]

# Optional: usage examples
usage_examples:
  - |
    mip load package-name
    % example code

prepare:
  # Option 1: Download and extract zip
  download_zip:
    url: "https://..."
    destination: "subdirectory"
  
  # Option 2: Clone git repository
  clone_git:
    url: "https://..."
    destination: "subdirectory"
  
  # Define paths to add to MATLAB path
  addpaths:
    - path: "subdirectory"
    - path: "subdirectory/tools"
    # Recursive with exclusions:
    - path: "subdirectory"
      recursive: true
      exclude: ["test", "paper"]

builds:
  - build_type: standard
    matlab_tag: any
    abi_tag: none
    platform_tag: any
    # Optional: specify compilation script
    compile_script: compile.m
```

## How It Works

### Package Preparation (prepare_packages.py)

1. **Scan packages2/** - Find all directories with `prepare.yaml`
2. **Filter by BUILD_TYPE** - Only process packages with matching builds
3. **Download/Clone** - Based on YAML specification
4. **Compute Paths** - All paths computed upfront, including recursive
5. **Collect Symbols** - Scan all computed paths for exposed symbols
6. **Create Scripts** - Generate `load_package.m` and `unload_package.m`
7. **Generate Metadata** - Create `mip.json` with all package info

### Compilation (compile_packages.m)

1. **Find .dir directories** - In `build/prepared/`
2. **Read YAML** - From `packages2/{package_name}/prepare.yaml`
3. **Check BUILD_TYPE** - Only compile if matches
4. **Check compile_script** - Only if specified in matching build
5. **Execute** - Run the compile script
6. **Update Metadata** - Add compilation duration to `mip.json`

### Key Features

- **Explicit Paths**: All MATLAB paths computed during prepare, not at load time
- **Recursive Directories**: FLAM-style recursive path generation with exclusions
- **Symbol Collection**: Configurable file extensions per package
- **Build Filtering**: Only build packages matching BUILD_TYPE
- **Platform Aware**: Can specify platform requirements in YAML

## Example Output

### Prepare Packages
```
Starting package preparation process...
Found 10 package(s)
Output directory: /path/to/build/prepared
BUILD_TYPE: standard

Processing package: chebfun
  Wheel name: chebfun-unspecified-any-none-any
  Package not found in bucket
  Output directory: /path/to/build/prepared/chebfun-unspecified-any-none-any.dir
  Preparing package...
  Downloading https://github.com/chebfun/chebfun/archive/master.zip...
  Download complete.
  Extracting to chebfun-master...
  Computed 1 path(s)
  Collected 234 exposed symbol(s)
  Prepare completed in 5.23 seconds
  Creating mip.json...
  Successfully prepared chebfun-unspecified-any-none-any.dir

✓ All packages prepared successfully
```

### Compile Packages
```
Starting package compilation process...
Prepared packages directory: /path/to/build/prepared
BUILD_TYPE: standard
Found 10 .dir package(s)

kdtree-unspecified-any-none-any: Found compile.m - compiling...
  Running compile.m...
  Compilation completed in 2.34 seconds
  Updated mip.json with compile_duration: 2.34s

Packages requiring compilation: 1

✓ All packages compiled successfully
```

## Directory Structure

After running prepare:

```
build/
└── prepared/
    ├── chebfun-unspecified-any-none-any.dir/
    │   ├── chebfun-master/
    │   ├── load_package.m
    │   ├── unload_package.m
    │   └── mip.json
    ├── kdtree-unspecified-any-none-any.dir/
    │   ├── kdtree/
    │   ├── compile.m
    │   ├── load_package.m
    │   ├── unload_package.m
    │   └── mip.json
    └── ...
```

## Migrating from scripts/

The main differences:

1. **Package Definition**: Create `packages2/{name}/prepare.yaml` instead of `packages/{name}/packages.py`
2. **No Python Classes**: YAML declarative format instead of Python Package classes
3. **No Build Helpers**: All functionality is self-contained in scripts2/
4. **Explicit Paths**: All paths computed during prepare, stored in load_package.m
5. **Symbol Extensions**: Specified in YAML at package level

## GitHub Actions Integration

The repository can use GitHub Actions to automate the build and upload process. The workflow would:
- Set BUILD_TYPE environment variable
- Run prepare_packages.py
- Run compile_packages.m (if MATLAB available)
- Run bundle_and_upload_packages.py
- Run assemble_index.py

Repository secrets needed:
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_ENDPOINT_URL`