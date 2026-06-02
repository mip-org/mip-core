#!/usr/bin/env python3
"""Map a list of changed files to (package_path, architecture) dispatches.

Given a newline-delimited list of paths that changed in a push, emit one TSV
row per build to dispatch: `<package_path>\t<architecture>`. A file affects
package `packages/<name>/<version>` if its path starts with that prefix.
Each affected package is expanded to every architecture declared in its
`mip.yaml` (intersected with the channel's SUPPORTED_ARCHITECTURES). Recipe-
only packages (no channel-side mip.yaml) expand to every supported arch.

Packages whose `recipe.yaml` no longer exists at HEAD (deletions) are
silently skipped.
"""

import argparse
import sys
from pathlib import Path

from build_request_from_issue import arches_from_mip_yaml


def affected_packages(changed_files, repo_root):
    """Return the sorted list of `packages/<name>/<version>` prefixes touched."""
    pkgs = set()
    for raw in changed_files:
        path = raw.strip()
        if not path:
            continue
        parts = path.split("/")
        if len(parts) < 3 or parts[0] != "packages":
            continue
        pkg_path = f"packages/{parts[1]}/{parts[2]}"
        if (repo_root / pkg_path / "recipe.yaml").is_file():
            pkgs.add(pkg_path)
    return sorted(pkgs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--changed-files", required=True,
                    help="Path to a file with one changed path per line.")
    ap.add_argument("--dispatch-file", required=True,
                    help="Output TSV: <package_path>\\t<architecture>.")
    ap.add_argument("--repo-root", default=".",
                    help="Repo root (default: cwd).")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()

    with open(args.changed_files) as f:
        changed = f.readlines()

    rows = []
    for pkg_path in affected_packages(changed, repo_root):
        for arch in arches_from_mip_yaml(repo_root / pkg_path):
            rows.append(f"{pkg_path}\t{arch}")

    with open(args.dispatch_file, "w") as f:
        for row in rows:
            f.write(row + "\n")

    print(f"Affected dispatches: {len(rows)}", file=sys.stderr)
    for row in rows:
        print(f"  {row}", file=sys.stderr)


if __name__ == "__main__":
    main()
