"""Channel configuration helpers.

Derives the GitHub repo from the environment ($GITHUB_REPOSITORY in CI)
or from the git remote origin URL.  No configuration file needed.
"""

import os
import subprocess


def get_github_repo():
    """Return the GitHub owner/repo string (e.g. 'mip-org/mip-core').

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
    if url.endswith('.git'):
        url = url[:-4]
    if '://' in url:
        return '/'.join(url.split('/')[-2:])
    else:
        return url.split(':')[-1]


def get_base_url(release_tag):
    """Get the download base URL for a given release tag (name-version)."""
    return f"https://github.com/{get_github_repo()}/releases/download/{release_tag}"


def release_tag_from_mhl(mhl_filename):
    """Extract the release tag (name-version) from an .mhl filename.

    Filename format: {name}-{version}-{architecture}.mhl

    A canonical package name may contain '-' (e.g. 'foo-bar'), but '-'
    is the field separator in the filename, so the name is always
    encoded with '_' in the filename (e.g. 'foo_bar-1.0-any.mhl').
    The last hyphen therefore separates version from architecture, and
    the remainder is the release tag '{name-as-underscores}-{version}'.
    """
    basename = mhl_filename
    if basename.endswith('.mip.json'):
        basename = basename[:-9]
    if basename.endswith('.mhl'):
        basename = basename[:-4]

    # Split on last hyphen to get architecture, rest is name-version
    last_hyphen = basename.rfind('-')
    if last_hyphen == -1:
        return basename
    return basename[:last_hyphen]
