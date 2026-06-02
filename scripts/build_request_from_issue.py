#!/usr/bin/env python3
"""Validate or apply a build request described in a GitHub issue.

The issue's job is just to **trigger builds** of packages already present
in this channel under `packages/<name>/<version>/`. The workflow does not
clone, copy, or commit anything — it only dispatches the per-package build
workflow on approval.

Free-form input. Each non-empty line of the body (or title) may contain:

  1. A package path `packages/<name>/<version>` (bare or inside a GitHub
     URL — only the path portion is used) OR the keyword `all-packages`
     to mean "every package in this channel".
  2. One or more architecture keywords:
     `any`, `linux_x86_64`, `macos_arm64`, `windows_x86_64`, or `all`.
  3. Optionally, the keyword `force` to rebuild even if a matching .mhl
     is already published with the same source hash. Applies only to
     dispatches from the same line.

`all` expands to every supported architecture declared in the package's
`mip.yaml` (intersected with the channel's supported arch list above).
If the channel has no local `mip.yaml` for the package (e.g. recipe-only
packages), `all` expands to every supported arch.

`all-packages <arch>` dispatches every channel package (those with a
`packages/<name>/<version>/recipe.yaml`) for the given arch. A specific
arch (e.g. `linux_x86_64`) only emits packages whose mip.yaml declares
that arch; `all` emits each package's full declared set. Recipe-only
packages (no channel-side mip.yaml) are treated as supporting every arch.

A line with a path or `all-packages` but no arch is an error. Lines
with neither are ignored (free-form context). Multiple paths on the
same line is an error.

Subcommands:

    validate --output-file PATH [--title-file PATH] [--repo-root DIR]
        Render the comment to post on issue-open. Confirms each named
        package folder exists in this repo.

    apply --dispatch-file PATH [--errors-file PATH] [--repo-root DIR]
        Re-parse the issue and write one TSV row per dispatch
        (`<package_path>\\t<architecture>`) to --dispatch-file.
"""

import argparse
import os
import re
import sys
from pathlib import Path

import yaml


PACKAGE_PATH_RE = re.compile(
    r"\bpackages/[A-Za-z0-9._+\-]+/[A-Za-z0-9._+\-]+"
)

SUPPORTED_ARCHITECTURES = (
    "any", "linux_x86_64", "macos_arm64", "windows_x86_64",
)

ALL_KEYWORD = "all"
VALID_ARCH_KEYWORDS = SUPPORTED_ARCHITECTURES + (ALL_KEYWORD,)

ARCH_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(a) for a in VALID_ARCH_KEYWORDS) + r")\b"
)

FORCE_RE = re.compile(r"\bforce\b", re.IGNORECASE)

ALL_PACKAGES_RE = re.compile(r"^all[-_]packages\b", re.IGNORECASE)

URL_RE = re.compile(
    r"https://github\.com/[^/\s]+/[^/\s]+/tree/[^/\s]+/[^\s)]+"
)

PATH_FORMAT_HINT = "    packages/<name>/<version>"


def get_effective_body():
    """Title + body, joined; lets users put the request in the title."""
    body = os.environ.get("ISSUE_BODY", "")
    title = os.environ.get("ISSUE_TITLE", "")
    if title.strip():
        return title + "\n\n" + body
    return body


def list_all_packages(repo_root):
    """Sorted list of every `packages/<name>/<version>` with a recipe.yaml."""
    pkgs = []
    pkgs_dir = repo_root / 'packages'
    if not pkgs_dir.is_dir():
        return pkgs
    for name_dir in sorted(pkgs_dir.iterdir()):
        if not name_dir.is_dir() or name_dir.name.startswith('.'):
            continue
        for ver_dir in sorted(name_dir.iterdir()):
            if not ver_dir.is_dir() or ver_dir.name.startswith('.'):
                continue
            if (ver_dir / 'recipe.yaml').is_file():
                pkgs.append(f"packages/{name_dir.name}/{ver_dir.name}")
    return pkgs


def arches_from_mip_yaml(pkg_dir):
    """Arches declared in mip.yaml, intersected with SUPPORTED_ARCHITECTURES.

    Returns a list ordered by SUPPORTED_ARCHITECTURES. If mip.yaml is
    missing in the channel (recipe-only package), returns the full
    SUPPORTED_ARCHITECTURES list — `all` then dispatches each, and per-arch
    prepare exits silently for arches the upstream mip.yaml doesn't list.
    """
    mip_yaml = pkg_dir / "mip.yaml"
    if not mip_yaml.is_file():
        return list(SUPPORTED_ARCHITECTURES)
    with open(mip_yaml) as f:
        config = yaml.safe_load(f) or {}
    declared = set()
    for build in (config.get("builds") or []):
        for a in (build.get("architectures") or []):
            declared.add(a)
    return [a for a in SUPPORTED_ARCHITECTURES if a in declared]


def parse_issue(body, repo_root):
    """Return (entries, errors).

    entries: list of dicts with keys {package_path, name, version, architecture}.
    errors: list of human-readable error strings (markdown bullet bodies).
    """
    body = body.replace("\r", "")
    body = URL_RE.sub(" ", body)

    entries = []
    errors = []

    for line_num, raw_line in enumerate(body.split("\n"), 1):
        line = raw_line.strip()
        if not line:
            continue

        if ALL_PACKAGES_RE.match(line):
            # Anchored at start-of-line because the phrase is too prose-like
            # to safely match anywhere. Strip it before arch detection so
            # `all-packages` doesn't bleed into ARCH_RE (the hyphen is a
            # word boundary, so a naive `\ball\b` would match inside
            # `all-packages`).
            line_residual = ALL_PACKAGES_RE.sub("", line, count=1)
            line_archs = list(dict.fromkeys(ARCH_RE.findall(line_residual)))
            force = bool(FORCE_RE.search(line_residual))

            if not line_archs:
                valid = ", ".join(f"`{a}`" for a in VALID_ARCH_KEYWORDS)
                errors.append(
                    f"- Line {line_num}: `all-packages` has no architecture. "
                    f"Add one of: {valid}."
                )
                continue

            for pkg_path in list_all_packages(repo_root):
                pkg_folder = repo_root / pkg_path
                pkg_arches = arches_from_mip_yaml(pkg_folder)
                expanded = []
                for arch in line_archs:
                    if arch == ALL_KEYWORD:
                        expanded.extend(pkg_arches)
                    elif arch in pkg_arches:
                        expanded.append(arch)
                    # else: package doesn't declare this arch — skip silently
                parts = pkg_path.split("/")
                name, version = parts[1], parts[2]
                for arch in expanded:
                    entries.append({
                        "package_path": pkg_path,
                        "name": name,
                        "version": version,
                        "architecture": arch,
                        "force": force,
                    })
            continue

        paths = list(dict.fromkeys(PACKAGE_PATH_RE.findall(line)))
        if not paths:
            continue

        if len(paths) > 1:
            joined = ", ".join(f"`{p}`" for p in paths)
            errors.append(
                f"- Line {line_num} has multiple package paths "
                f"({joined}); put one per line."
            )
            continue

        package_path = paths[0]
        line_for_keywords = PACKAGE_PATH_RE.sub(" ", line)
        line_archs = list(dict.fromkeys(ARCH_RE.findall(line_for_keywords)))
        force = bool(FORCE_RE.search(line_for_keywords))

        if not line_archs:
            valid = ", ".join(f"`{a}`" for a in VALID_ARCH_KEYWORDS)
            errors.append(
                f"- Line {line_num}: `{package_path}` has no architecture. "
                f"Add one of: {valid}."
            )
            continue

        folder = repo_root / package_path
        if not folder.is_dir():
            errors.append(
                f"- `{package_path}` does not exist in this channel."
            )
            continue

        parts = package_path.split("/")
        name, version = parts[1], parts[2]

        expanded = []
        for arch in line_archs:
            if arch == ALL_KEYWORD:
                pkg_arches = arches_from_mip_yaml(folder)
                if not pkg_arches:
                    errors.append(
                        f"- `{package_path}` declares no supported "
                        f"architectures; cannot expand `all`."
                    )
                    continue
                expanded.extend(pkg_arches)
            else:
                expanded.append(arch)

        for arch in expanded:
            entries.append({
                "package_path": package_path,
                "name": name,
                "version": version,
                "architecture": arch,
                "force": force,
            })

    if not entries and not errors:
        errors.append(
            "- No package path found. Include at least one line of the form:"
            f"\n\n{PATH_FORMAT_HINT} <architecture>"
        )

    # Dedupe by (path, arch); if any duplicate set force=true, the merged
    # entry is force=true (force is monotonic — easier to opt-in once).
    merged = {}
    order = []
    for e in entries:
        key = (e["package_path"], e["architecture"])
        if key in merged:
            merged[key]["force"] = merged[key]["force"] or e["force"]
        else:
            merged[key] = e
            order.append(key)
    deduped = [merged[k] for k in order]

    return deduped, errors


def render_validation_comment(entries, errors):
    if errors or not entries:
        lines = ["The issue is not formatted correctly."]
        lines += ["", "Errors:"] + errors
        lines += [
            "",
            "Edit the issue body or open a new one. Each build line "
            "should look like:",
            "",
            "    packages/<name>/<version> <arch>",
            "",
            "Valid architectures: "
            + ", ".join(f"`{a}`" for a in VALID_ARCH_KEYWORDS) + ".",
        ]
        return "\n".join(lines) + "\n"

    n = len(entries)
    if n == 1:
        e = entries[0]
        suffix = ", force" if e["force"] else ""
        header = (
            f"Detected build request: "
            f"`{e['name']}@{e['version']} ({e['architecture']}{suffix})`"
        )
    else:
        header = f"Detected {n} build dispatches:"
    lines = [header, ""]
    for e in entries:
        suffix = ", force" if e["force"] else ""
        lines.append(
            f"- `{e['package_path']}` ({e['architecture']}{suffix})"
        )
    lines += [
        "",
        "An admin (anyone with write access on this repo) can approve "
        "this request by replying with `approve` on its own line. On "
        "approval, `build-package.yml` will be dispatched once per "
        "(package, architecture) pair listed above — no files in this "
        "repo are copied or modified.",
    ]
    return "\n".join(lines) + "\n"


def canonical_title(entries):
    """Canonical title rewrite — only for single-entry requests."""
    if len(entries) != 1:
        return None
    e = entries[0]
    suffix = ", force" if e["force"] else ""
    return f"Build: `{e['package_path']}` ({e['architecture']}{suffix})"


def cmd_validate(args):
    body = get_effective_body()
    repo_root = Path(args.repo_root).resolve()
    entries, errors = parse_issue(body, repo_root)
    Path(args.output_file).write_text(
        render_validation_comment(entries, errors)
    )
    if args.title_file:
        title = canonical_title(entries) or ""
        Path(args.title_file).write_text(title + ("\n" if title else ""))
    return 0


def cmd_apply(args):
    body = get_effective_body()
    repo_root = Path(args.repo_root).resolve()
    entries, errors = parse_issue(body, repo_root)
    if not entries:
        Path(args.dispatch_file).write_text("")
        if args.errors_file:
            Path(args.errors_file).write_text(
                "\n".join(errors) + ("\n" if errors else "")
            )
        return 1
    rows = [
        f"{e['package_path']}\t{e['architecture']}\t"
        f"{'true' if e['force'] else 'false'}\n"
        for e in entries
    ]
    Path(args.dispatch_file).write_text("".join(rows))
    if args.errors_file:
        Path(args.errors_file).write_text(
            "\n".join(errors) + ("\n" if errors else "")
        )
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="mode", required=True)

    v = sub.add_parser("validate")
    v.add_argument("--output-file", required=True)
    v.add_argument("--title-file", default=None)
    v.add_argument("--repo-root", default=".")
    v.set_defaults(func=cmd_validate)

    a = sub.add_parser("apply")
    a.add_argument("--dispatch-file", required=True)
    a.add_argument("--errors-file", default=None)
    a.add_argument("--repo-root", default=".")
    a.set_defaults(func=cmd_apply)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
