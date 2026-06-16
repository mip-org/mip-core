#!/usr/bin/env python3
"""Probe every (package, arch) in the channel; emit pairs that need rebuilding.

For each channel package and each of its declared, channel-supported arches,
run `mip-channel prepare`. If prepare produces a `build/prepared/<...>/`
directory, that pair needs a rebuild (its `.mhl` is missing or has a stale
source hash). If it exits cleanly with no output, the pair is up to date.

Output (--dispatch-file) is one TSV row per pair that needs rebuilding:

    <package_path>\t<architecture>

Failures of prepare itself (e.g. transient git/network errors) are
recorded in the summary and cause the command to exit non-zero, but the
dispatch file still lists every pair that was successfully determined
to need a build.
"""

import shutil
import subprocess
import sys
from pathlib import Path

from .build_request import (
    arches_from_mip_yaml,
    list_all_packages,
)


def probe_pair(repo_root, pkg_path, arch, probe_dir):
    """Run prepare for one (pkg, arch). Returns (needs_build, error_or_None)."""
    if probe_dir.exists():
        shutil.rmtree(probe_dir)
    probe_dir.mkdir(parents=True)

    cmd = [
        sys.executable, "-m", "mip_channel_tools", "prepare",
        "--package-path", pkg_path,
        "--architecture", arch,
        "--output-dir", str(probe_dir),
    ]
    result = subprocess.run(cmd, cwd=str(repo_root))
    if result.returncode != 0:
        return False, f"prepare exited {result.returncode}"

    # prepare writes "<name>-<version>/" into the output dir on success,
    # and nothing on a clean "already up to date" / "arch not declared" exit.
    # _temp_* dirs are cleaned by prepare in its finally block.
    entries = [e for e in probe_dir.iterdir() if not e.name.startswith("_temp_")]
    return bool(entries), None


def run(args):
    repo_root = Path(args.repo_root).resolve()
    probe_dir = repo_root / "build" / "scheduled-probe"

    needs = []
    summary = []
    failed_pairs = []

    for pkg_path in list_all_packages(repo_root):
        archs = arches_from_mip_yaml(repo_root / pkg_path)
        for arch in archs:
            print(f"\n=== Probing {pkg_path} ({arch}) ===", flush=True)
            needs_build, err = probe_pair(repo_root, pkg_path, arch, probe_dir)
            if err:
                summary.append(
                    f"- `{pkg_path}` (`{arch}`) — prepare failed: {err}")
                failed_pairs.append((pkg_path, arch))
                continue
            if needs_build:
                needs.append(f"{pkg_path}\t{arch}")
                summary.append(f"- `{pkg_path}` (`{arch}`) — **needs build**")
            else:
                summary.append(f"- `{pkg_path}` (`{arch}`) — up to date")

    if probe_dir.exists():
        shutil.rmtree(probe_dir)

    with open(args.dispatch_file, "w") as f:
        for row in needs:
            f.write(row + "\n")

    if args.summary_file:
        with open(args.summary_file, "w") as f:
            f.write("\n".join(summary) + "\n")

    print(f"\nNeeds build: {len(needs)}", file=sys.stderr)
    print(f"Prepare failures: {len(failed_pairs)}", file=sys.stderr)

    return 1 if failed_pairs else 0


def register(subparsers):
    ap = subparsers.add_parser(
        "scheduled-check",
        help="Probe all (package, arch) pairs; emit those needing a rebuild.")
    ap.add_argument("--dispatch-file", required=True,
                    help="Output TSV: <package_path>\\t<architecture>.")
    ap.add_argument("--summary-file",
                    help="Optional markdown summary path (one bullet per pair).")
    ap.add_argument("--repo-root", default=".")
    ap.set_defaults(func=run)
