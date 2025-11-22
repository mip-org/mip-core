# Build and Upload Packages Script

This directory contains the `build_and_upload_packages.py` script that builds MATLAB packages (.mhl files) and uploads them to a Cloudflare R2 bucket.

## Overview

The script:
1. Scans all directories in `packages/`
2. Dynamically loads the `Package` class from each `package.py`
3. Generates .mhl filenames in the format: `[name]-[version]-[matlab_tag]-[abi_tag]-[platform_tag].mhl`
4. Checks if packages already exist in the cloud bucket
5. Builds only changed or new packages
6. Uploads built packages and metadata to Cloudflare R2

## Requirements

### Python Dependencies
```bash
pip install boto3 requests
pip install -e mip_build_helpers
```

### Environment Variables

The script requires the following environment variables for Cloudflare R2 access:

- `AWS_ACCESS_KEY_ID` - Your Cloudflare R2 access key ID
- `AWS_SECRET_ACCESS_KEY` - Your Cloudflare R2 secret access key
- `AWS_ENDPOINT_URL` - Your Cloudflare R2 endpoint URL (format: `https://[account-id].r2.cloudflarestorage.com`)

## Usage

### Basic Usage
```bash
python scripts/build_and_upload_packages.py
```

This will:
- Check each package against the cloud bucket
- Skip packages that haven't changed
- Build and upload only new or modified packages

### Command Line Options

#### Dry Run Mode
```bash
python scripts/build_and_upload_packages.py --dry-run
```
Simulates the build process without actually building or uploading anything. Useful for testing.

#### Force Rebuild
```bash
python scripts/build_and_upload_packages.py --force
```
Forces rebuilding of all packages, even if they already exist in the bucket with matching metadata.

#### Don't Keep Working Directories
```bash
python scripts/build_and_upload_packages.py --no-keep-dirs
```
Cleans up temporary working directories after build. By default, directories are kept for inspection.

### Combining Options
```bash
python scripts/build_and_upload_packages.py --force --dry-run
```

## How It Works

### Smart Caching

Before building a package, the script:
1. Generates the expected .mhl filename
2. Checks if `[filename].mip.json` exists at `https://mip-packages.neurosift.app/packages/core/`
3. Compares metadata fields: `name`, `description`, `version`, `build_number`, `dependencies`, `homepage`, `repository`
4. Skips build if all fields match

### Build Process

For each package that needs building:
1. Creates a temporary working directory (kept by default for inspection)
2. Creates `mhl_build` subdirectory
3. Calls `package.build(mhl_build_dir)`
4. Generates `mip.json` with full metadata including:
   - Core package info (name, description, version, etc.)
   - Build metadata (timestamp, build_duration)
   - Platform tags (matlab_tag, abi_tag, platform_tag)
   - Exposed symbols list
5. ZIPs the `mhl_build` directory into a `.mhl` file
6. Uploads both the `.mhl` file and `.mip.json` to R2

### Error Handling

- The script aborts on the first package build failure
- Temporary directories are kept by default to help debug failures
- Full stack traces are printed for debugging

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
        self.build_number = 0
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

## Output

### Successful Build
```
Starting package build process...
Found 1 package(s)

Processing package: chebfun
  MHL filename: chebfun-latest-any-none-any.mhl
  Package not found in bucket
  Working directory: /tmp/mip_build_chebfun_xyz123
  Building package...
  Build completed in 12.34 seconds
  Creating mip.json...
  Creating .mhl file...
  Uploading to R2...
  Uploaded to s3://mip-packages/packages/core/chebfun-latest-any-none-any.mhl
  Uploaded to s3://mip-packages/packages/core/chebfun-latest-any-none-any.mhl.mip.json
  Successfully built and uploaded chebfun-latest-any-none-any.mhl

============================================================
Working directories kept for inspection:
  /tmp/mip_build_chebfun_xyz123
============================================================

✓ All packages processed successfully
```

### Cached Package (No Rebuild)
```
Processing package: chebfun
  MHL filename: chebfun-latest-any-none-any.mhl
  Package exists with matching metadata
  Skipping - package already up to date
```
