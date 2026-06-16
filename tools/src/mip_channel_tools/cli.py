"""Single entry point for the MIP channel tooling.

Exposes one CLI with a subcommand per workflow helper. Each helper module
registers its own subparser via a `register(subparsers)` function and sets
`func` (an `args -> int|None` callable) as the subparser default.
"""

import argparse

from . import (
    affected,
    build_request,
    index,
    package_setup,
    prepare,
    scheduled,
    upload,
)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="mip-channel",
        description="Build, index, and release tooling for MIP package channels.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare.register(subparsers)
    package_setup.register(subparsers)
    upload.register(subparsers)
    index.register(subparsers)
    build_request.register(subparsers)
    affected.register(subparsers)
    scheduled.register(subparsers)

    args = parser.parse_args(argv)
    return args.func(args) or 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
