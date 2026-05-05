#!/usr/bin/env python3
"""Validate or apply package additions described in a GitHub issue body.

Reads the issue body from the ISSUE_BODY environment variable, finds URLs of
the form

    https://github.com/<owner>/<repo>/tree/<branch>/<path>

and either validates them (writing a comment-ready Markdown response) or
applies them (cloning each source repository at the given branch and copying
<path> into the current repository at the same relative path). <path> must
lie under packages/.

Subcommands:

    validate --output-file PATH
        Writes a Markdown response intended to be posted as a comment on the
        newly-opened issue. The response either confirms which packages were
        detected, or explains that the body is malformed and asks the user to
        close and re-open the issue.

    apply --report-file PATH --errors-file PATH [--repo-root DIR]
        Clones each source repository and copies the requested folder into
        --repo-root. Writes a Markdown bullet list of successful additions to
        --report-file and any errors to --errors-file.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

URL_RE = re.compile(r"https://github\.com/[^/\s]+/[^/\s]+/tree/[^\s]+")

URL_FORMAT_HINT = (
    "    https://github.com/<owner>/<repo>/tree/<branch>/packages/<name>/<version>"
)


def _parse_url(url):
    if not url.startswith("https://github.com/"):
        return None
    rest = url[len("https://github.com/"):].rstrip("/")
    parts = rest.split("/")
    if len(parts) < 5 or parts[2] != "tree":
        return None
    owner, repo, _, branch = parts[:4]
    path = "/".join(parts[4:])
    if not owner or not repo or not branch or not path:
        return None
    return owner, repo, branch, path


def parse_urls(body):
    """Return (valid_entries, errors).

    Each valid entry is a tuple (url, owner, repo, branch, path). Lines that
    don't contain a conforming URL (one that parses, has a path under
    packages/, and contains no '..') are silently ignored — the body may
    include arbitrary other text. Errors is non-empty only if no conforming
    URL was found at all.
    """
    parsed = []
    for url in URL_RE.findall(body.replace("\r", "")):
        url = url.rstrip("/")
        result = _parse_url(url)
        if result is None:
            continue
        owner, repo, branch, path = result
        if not path.startswith("packages/"):
            continue
        if ".." in path.split("/"):
            continue
        parsed.append((url, owner, repo, branch, path))

    errors = []
    if not parsed:
        errors.append("- No conforming package URLs found in the issue body.")
    return parsed, errors


def render_validation_comment(parsed, errors):
    if errors or not parsed:
        lines = ["The issue body is not formatted correctly."]
        if errors:
            lines += ["", "Errors:"] + errors
        lines += [
            "",
            "The body should list one or more URLs, each on its own line, formatted like:",
            "",
            URL_FORMAT_HINT,
            "",
            "Please close this issue and open a new one with the correct format.",
        ]
        return "\n".join(lines) + "\n"

    lines = ["Thanks for the request. The following packages were detected:", ""]
    for url, _owner, _repo, _branch, path in parsed:
        lines.append(f"- `{path}` from {url}")
    lines += [
        "",
        "An admin will review this request. To approve, an admin should reply "
        "with the word `approve` on its own line (it can appear anywhere within "
        "the comment).",
    ]
    return "\n".join(lines) + "\n"


def apply_entries(parsed, repo_root):
    report = []
    errors = []
    changed = False
    for url, owner, repo, branch, path in parsed:
        with tempfile.TemporaryDirectory() as tmpdir:
            clone_url = f"https://github.com/{owner}/{repo}.git"
            res = subprocess.run(
                ["git", "clone", "--depth", "1", "--branch", branch, clone_url, tmpdir],
                capture_output=True,
                text=True,
            )
            if res.returncode != 0:
                err_lines = (res.stderr or res.stdout).strip().splitlines()
                err_msg = err_lines[-1] if err_lines else "git clone failed"
                errors.append(f"- Failed to clone `{owner}/{repo}@{branch}`: {err_msg}")
                continue

            src = Path(tmpdir) / path
            if not src.is_dir():
                errors.append(f"- Path `{path}` not found in `{owner}/{repo}@{branch}`.")
                continue

            dest = repo_root / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.exists():
                shutil.rmtree(dest)
            shutil.copytree(src, dest)
            report.append(f"- Added `{path}` from {url}")
            changed = True
    return report, errors, changed


def cmd_validate(args):
    body = os.environ.get("ISSUE_BODY", "")
    parsed, errors = parse_urls(body)
    Path(args.output_file).write_text(render_validation_comment(parsed, errors))
    return 0


def cmd_apply(args):
    body = os.environ.get("ISSUE_BODY", "")
    repo_root = Path(args.repo_root).resolve()
    parsed, parse_errors = parse_urls(body)
    report, apply_errors, changed = apply_entries(parsed, repo_root)
    errors = parse_errors + apply_errors

    Path(args.report_file).write_text("\n".join(report) + ("\n" if report else ""))
    Path(args.errors_file).write_text("\n".join(errors) + ("\n" if errors else ""))
    print(f"changed={'true' if changed else 'false'}")
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="mode", required=True)

    v = sub.add_parser("validate", help="Write a Markdown comment validating the issue body.")
    v.add_argument("--output-file", required=True)
    v.set_defaults(func=cmd_validate)

    a = sub.add_parser("apply", help="Clone and copy each requested package folder.")
    a.add_argument("--report-file", required=True)
    a.add_argument("--errors-file", required=True)
    a.add_argument("--repo-root", default=".")
    a.set_defaults(func=cmd_apply)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
