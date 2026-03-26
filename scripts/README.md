# MIP Channel Build Scripts

Scripts for building MATLAB packages (.mhl files) from YAML specifications and uploading them to GitHub Releases.

## Scripts Overview

1. **`prepare_packages.py`** — Reads YAML specs, downloads/clones code, computes paths, creates load/unload scripts, generates metadata
2. **`build_packages.py`** — Runs shell-based build scripts (e.g., emscripten/wasm builds)
3. **`compile_packages.m`** — Compiles packages that require MATLAB compilation
4. **`bundle_packages.py`** — Zips `.dir` directories into `.mhl` files
5. **`upload_packages.py`** — Uploads `.mhl` files as GitHub Release assets
6. **`assemble_index.py`** — Assembles package index from release assets
7. **`delete_packages.py`** — Lists or deletes packages from releases
8. **`test_published_packages.py`** — Tests all published packages from the package index

## Requirements

### Python Dependencies
```bash
pip install requests pyyaml
```

### Environment Variables

- `BUILD_ARCHITECTURE` — Target architecture (e.g., `linux_x86_64`, `macos_arm64`, `any`)
- `GH_TOKEN` — GitHub token for release uploads (automatic in GitHub Actions)

## Build Pipeline

```
prepare_packages.py → build_packages.py → compile_packages.m → bundle_packages.py → upload_packages.py → assemble_index.py
```

Each step reads from and writes to the `build/` directory:
- `build/prepared/` — `.dir` directories with prepared package contents
- `build/bundled/` — `.mhl` and `.mip.json` files ready for upload
- `build/gh-pages/` — `index.json` and `packages.html` for GitHub Pages
