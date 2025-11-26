# Build and Upload Packages Scripts

This directory contains scripts for building MATLAB packages (.mhl files) and uploading them to a Cloudflare R2 bucket.

## Scripts Overview

The build and upload process has been split into multiple scripts for flexibility:

1. **`prepare_packages.py`** - Builds packages into `.dir` directories
2. **`compile_packages.m`** - Compiles packages that require MATLAB compilation
3. **`bundle_and_upload_packages.py`** - Zips `.dir` directories and uploads to R2
4. **`assemble_index.py`** - Assembles package index from R2 bucket

This separation allows for:
- Building packages once and uploading multiple times
- Inspecting built packages before upload
- Running builds and uploads at different times or on different machines
- Rebuilding the index independently from package uploads

## Requirements

### Python Dependencies
```bash
pip install boto3 requests
pip install -e mip_build_helpers
```

### Environment Variables

The upload script requires the following environment variables for Cloudflare R2 access:

- `AWS_ACCESS_KEY_ID` - Your Cloudflare R2 access key ID
- `AWS_SECRET_ACCESS_KEY` - Your Cloudflare R2 secret access key
- `AWS_ENDPOINT_URL` - Your Cloudflare R2 endpoint URL (format: `https://[account-id].r2.cloudflarestorage.com`)

## Usage

### Two-Step Process (Recommended)

#### Step 1: Prepare Packages
```bash
python scripts/prepare_packages.py
```

This will:
- Check each package against the cloud bucket
- Skip packages that haven't changed (unless `--force` is used)
- Build packages into `build/prepared/[wheel_name].dir` directories
- Each `.dir` contains the built package contents and a `mip.json` metadata file

##### Step 2: Compile Packages (MATLAB)
```bash
matlab -batch "cd scripts; compile_packages"
```

This will:
- Find all `.dir` directories with `compile.m` files
- Execute compilation for packages that require it
- Update `mip.json` with compilation duration

#### Step 3: Bundle and Upload
```bash
python scripts/bundle_and_upload_packages.py
```

This will:
- Find all `.dir` directories in `build/prepared/`
- Zip each into a `.mhl` file
- Upload both `.mhl` and `.mip.json` files to R2

#### Step 4: Assemble Package Index
```bash
python scripts/assemble_index.py
```

This will:
- List all `.mhl.mip.json` files in the R2 bucket
- Download each `.mip.json` file
- Assemble them into a consolidated `index.json`
- Save to `build/gh-pages/index.json` for GitHub Pages deployment

## Command Line Options

### prepare_packages.py

#### Dry Run Mode
```bash
python scripts/prepare_packages.py --dry-run
```
Simulates the build process without actually building anything.

#### Force Rebuild
```bash
python scripts/prepare_packages.py --force
```
Forces rebuilding of all packages, even if they already exist in the bucket with matching metadata.

#### Custom Output Directory
```bash
python scripts/prepare_packages.py --output-dir /path/to/output
```
Specifies where to create the `.dir` directories (default: `build/prepared`).

### bundle_and_upload_packages.py

#### Dry Run Mode
```bash
python scripts/bundle_and_upload_packages.py --dry-run
```
Simulates the upload process without actually uploading anything.

#### Custom Input Directory
```bash
python scripts/bundle_and_upload_packages.py --input-dir /path/to/prepared
```
Specifies where to find the `.dir` directories (default: `build/prepared`).

## How It Works

### Step 1: Package Preparation

#### Smart Caching

Before building a package, the script:
1. Generates the expected .mhl filename
2. Checks if `[filename].mip.json` exists at `https://mip-packages.neurosift.app/core/packages/`
3. Compares metadata fields: `name`, `description`, `version`, `build_number`, `dependencies`, `homepage`, `repository`
4. Skips build if all fields match

#### Build Process

For each package that needs building:
1. Creates a `[wheel_name].dir` directory in `build/prepared/`
2. Calls `package.build(dir_path)` to populate the directory
3. Generates `mip.json` with full metadata including:
   - Core package info (name, description, version, etc.)
   - Build metadata (timestamp, prepare duration, compile duration)
   - Platform tags (matlab_tag, abi_tag, platform_tag)
   - Exposed symbols list

The `.dir` directories are kept for inspection and can be processed later by the upload script.

### Step 2: Compilation (MATLAB)

For packages that require compilation:
1. Finds `.dir` directories containing `compile.m` files
2. Executes the `compile.m` script in each directory
3. Updates `mip.json` with compilation duration

### Step 3: Bundle and Upload

For each `.dir` directory:
1. Reads the `mip.json` metadata file
2. Creates a `.mhl` file by zipping the directory contents
3. Creates a standalone `[filename].mip.json` file
4. Uploads both files to Cloudflare R2

### Step 4: Index Assembly

After all packages are uploaded:
1. Lists all `.mhl.mip.json` files in the R2 bucket using boto3
2. Downloads each `.mip.json` file one at a time
3. Ensures each has an `mhl_url` field (for backwards compatibility)
4. Assembles all metadata into a consolidated `index.json`
5. Saves to `build/gh-pages/index.json` for GitHub Pages deployment

This approach ensures the index reflects the true state of the bucket, regardless of which packages were rebuilt in the current run.

### Error Handling

- Both scripts abort on the first failure
- Full stack traces are printed for debugging
- The prepare script cleans up failed `.dir` directories
- The bundle script uses temporary directories that are automatically cleaned up

## GitHub Actions Integration

The repository includes a GitHub Actions workflow (`.github/workflows/build-and-upload-packages.yml`) that:
- Triggers on pushes to `main` that affect packages, scripts, or build helpers
- Can be manually triggered with an optional force rebuild
- Requires three repository secrets to be configured:
  - `R2_ACCESS_KEY_ID`
  - `R2_SECRET_ACCESS_KEY`
  - `R2_ENDPOINT_URL`

### Setting Up GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Add the three required secrets with your Cloudflare R2 credentials

### Manual Workflow Trigger

You can manually trigger the workflow from the Actions tab:
1. Go to Actions → Build and Upload Packages
2. Click "Run workflow"
3. Optionally check "Force rebuild all packages"

## Package Structure

Each package directory should contain a `package.py` file with a `Package` class:

```python
class Package:
    def __init__(self):
        self.name = "package-name"
        self.description = "Package description"
        self.version = "1.0.0"
        self.build_number = 10
        self.dependencies = []
        self.homepage = "https://example.com"
        self.repository = "https://github.com/user/repo"
        self.matlab_tag = "any"
        self.abi_tag = "none"
        self.platform_tag = "any"
        self.exposed_symbols = []  # Filled during build
    
    def build(self, mhl_dir: str):
        # Build logic here
        # Populate mhl_dir with package contents
        # Set self.exposed_symbols
        pass
```

## Output Examples

### Step 1: Package Preparation

```
Starting package preparation process...
Found 3 package(s)
Output directory: /path/to/build/prepared

Processing package: chebfun
  Wheel name: chebfun-1.0.0-R2023b-mip1-any
  Package not found in bucket
  Output directory: /path/to/build/prepared/chebfun-1.0.0-R2023b-mip1-any.dir
  Building package...
  Build completed in 12.34 seconds
  Creating mip.json...
  Successfully prepared chebfun-1.0.0-R2023b-mip1-any.dir

✓ All packages prepared successfully
```

### Step 3: Bundle and Upload

```
Starting package bundle and upload process...
Found 3 .dir package(s)
Input directory: /path/to/build/prepared

Processing: chebfun-1.0.0-R2023b-mip1-any.dir
  MHL filename: chebfun-1.0.0-R2023b-mip1-any.mhl
  Creating .mhl file...
  Uploading to R2...
  Uploaded to s3://mip-packages/core/packages/chebfun-1.0.0-R2023b-mip1-any.mhl
  Uploaded to s3://mip-packages/core/packages/chebfun-1.0.0-R2023b-mip1-any.mhl.mip.json
  Successfully bundled and uploaded chebfun-1.0.0-R2023b-mip1-any.mhl

✓ All packages bundled and uploaded successfully
```

### Step 4: Assemble Index

```
Starting index assembly process...
Listing packages in s3://mip-packages/core/packages/
  Found 5 .mip.json file(s)

Downloading package metadata...
  [1/5] chebfun-1.0.0-R2023b-mip1-any.mhl.mip.json
  [2/5] export_fig-1.0.0-R2023b-mip1-any.mhl.mip.json
  [3/5] kdtree-1.0.0-R2023b-mip1-any.mhl.mip.json
  [4/5] surfacefun-1.0.0-R2023b-mip1-any.mhl.mip.json
  [5/5] another-package-1.0.0-R2023b-mip1-any.mhl.mip.json

Successfully downloaded 5 package metadata file(s)

✓ Created index.json with 5 package(s)
  Saved to: /path/to/build/gh-pages/index.json
  This will be deployed to GitHub Pages

✓ Index assembled successfully
```

### Cached Package (No Rebuild)

```
Processing package: chebfun
  Wheel name: chebfun-1.0.0-R2023b-mip1-any
  Package exists with matching metadata
  Skipping - package already up to date
```

## Directory Structure

After running the prepare script:

```
build/
└── prepared/
    ├── chebfun-1.0.0-R2023b-mip1-any.dir/
    │   ├── mip.json
    │   └── [package contents]
    ├── export_fig-1.0.0-R2023b-mip1-any.dir/
    │   ├── mip.json
    │   └── [package contents]
    └── surfacefun-1.0.0-R2023b-mip1-any.dir/
        ├── mip.json
        └── [package contents]
```
