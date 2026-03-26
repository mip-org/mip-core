"""Channel configuration helpers.

Derives the GitHub repo from the environment ($GITHUB_REPOSITORY in CI)
or from the git remote origin URL.  No configuration file needed.
"""

import os
import subprocess


def get_github_repo():
    """Return the GitHub owner/repo string (e.g. 'mip-org/mip-example').

    Resolution order:
      1. $GITHUB_REPOSITORY  (always set in GitHub Actions)
      2. Parse the 'origin' remote URL via git
    """
    repo = os.environ.get('GITHUB_REPOSITORY')
    if repo:
        return repo

    # Fallback: parse git remote
    result = subprocess.run(
        ['git', 'remote', 'get-url', 'origin'],
        capture_output=True, text=True, check=True
    )
    url = result.stdout.strip()
    # Handle both HTTPS and SSH URLs
    # https://github.com/owner/repo.git  ->  owner/repo
    # git@github.com:owner/repo.git      ->  owner/repo
    if url.endswith('.git'):
        url = url[:-4]
    if '://' in url:
        # HTTPS
        return '/'.join(url.split('/')[-2:])
    else:
        # SSH  (git@github.com:owner/repo)
        return url.split(':')[-1]


def get_base_url(release_tag):
    """Get the download base URL for a given release tag (name-version)."""
    return f"https://github.com/{get_github_repo()}/releases/download/{release_tag}"


def release_tag_from_mhl(mhl_filename):
    """Extract the release tag (name-version) from an .mhl filename.

    Filename format: {name}-{version}-{architecture}.mhl
    Package names use underscores, never hyphens (enforced by prepare_packages.py),
    so the first hyphen separates name from version, and the second separates
    version from architecture.

    Returns: "{name}-{version}" string suitable as a GitHub release tag.
    """
    # Strip .mhl or .mhl.mip.json suffix
    basename = mhl_filename
    if basename.endswith('.mip.json'):
        basename = basename[:-9]  # remove .mip.json
    if basename.endswith('.mhl'):
        basename = basename[:-4]  # remove .mhl

    # Split: name-version-architecture
    parts = basename.split('-')
    # parts[0] = name, parts[1] = version, parts[2:] = architecture
    return f"{parts[0]}-{parts[1]}"
