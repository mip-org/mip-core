# MIP channel

A MIP package channel. Builds run one (package, architecture) at a time. They are triggered automatically on push to `main`, daily via a scheduled probe, or manually via a GitHub issue.

## Auto-build on push

Pushes to `main` run the `push-build.yml` workflow, which diffs the push and dispatches `build-package.yml` once per `(package, architecture)` pair affected by the change.

A file affects `packages/<name>/<version>` iff its path lies inside that directory. Each affected package expands to every arch declared in its `mip.yaml`, intersected with the channel's supported arches (`any`, `linux_x86_64`, `macos_arm64`, `windows_x86_64`). Recipe-only packages (no channel-side `mip.yaml`) expand to all four.

Changes outside `packages/` (workflows, README) do not trigger any builds. Deleted packages are skipped. The skip-if-unchanged logic still applies — pushes that don't change a package's source hash short-circuit at the prepare step.

## Scheduled rebuild

Daily at 06:00 UTC, `scheduled-build.yml` probes every (package, architecture) pair in the channel by running `mip-channel prepare` for each. A pair "needs rebuilding" iff its `.mhl` is missing on GitHub Releases or its source hash no longer matches — typically because an upstream git branch (e.g. `master`, `main`) advanced. Pairs that need rebuilding are dispatched to `build-package.yml`.

The workflow can also be invoked manually:

```bash
gh workflow run scheduled-build.yml
```

## Submitting a build

Open an issue. The title must start with `Build` (case-insensitive). The body lists one or more build lines:

```
<name>@<release> <architecture>
```

Multiple architectures on one line dispatch multiple builds for that package. Multiple lines dispatch multiple packages. Lines without a package reference are ignored.

Example body:

```
foo@1.0.0 any
bar@2.0 linux_x86_64 macos_arm64
```

Within ~30s the request bot replies with the list of `(package, architecture)` pairs it parsed (or an error list). If an admin — anyone with write access on the repo — opened the issue, the builds dispatch automatically. Otherwise an admin replies `approve` on its own line to dispatch.

### Architecture keywords

- `any` — pure MATLAB; runs on ubuntu.
- `linux_x86_64`, `macos_arm64`, `windows_x86_64` — native; run on the matching OS.
- `all` — expand to every arch declared in the package's `mip.yaml` (intersected with the four above). A package with no channel-side `mip.yaml` cannot expand `all`.

A build for an architecture the package does not declare exits cleanly with nothing to do.

### Building every package in one go

Replace the package reference with the literal keyword `all-packages` to fan out across the channel:

```
all-packages linux_x86_64
all-packages all
```

`all-packages` must be the first token of the line (after any leading whitespace).

### Skip-if-unchanged and `force`

By default, a build that would produce a `.mhl` matching what is already published (same source hash, same metadata) short-circuits. Re-submitting the same issue is therefore a no-op.

To rebuild anyway, append `force` to a build line:

```
foo@1.0.0 linux_x86_64 force
```

`force` applies only to the line it is on.

### Approval

Builds dispatch automatically when an admin — anyone with write access on the repo — opens the build issue. For an issue opened by anyone else, builds dispatch only when an admin replies with `approve` on its own line; emoji reactions and `approve` embedded in prose do not count.

### Editing an issue

Editing a submitted issue does not re-validate. To change anything, open a new issue.

## Submitting a package from another channel

To propose a package that lives in a **different** channel for inclusion here,
open an issue whose title is:

```
submit <owner>/<channel>/<name>@<release>
```

This names the package release `packages/<name>/<release>` in the source repo
`<owner>/mip-<channel>`. For example `submit mip-org/staging/fmm2d@main`
proposes `packages/fmm2d/main` from `mip-org/mip-staging`. The body is free-form.

The bot replies confirming the package exists in the source repo and lists its
declared architectures. Then an admin (anyone with write access) drives it:

- Comment `build` (on its own line) to run **test builds** for every declared
  architecture. Each runs the full build-and-test pipeline but publishes
  nothing — the resulting `.mhl` is uploaded as a workflow artifact you can
  download and `mip install` locally to test. The issue stays open.
- Comment `accept` (on its own line) to **promote** the package: its folder is
  copied into this channel's `packages/` on `main` and the normal publishing
  builds are dispatched. The issue is then closed.

## Direct dispatch

The same effect from the command line:

```bash
gh workflow run build-package.yml \
  -f package_path=packages/<name>/<version> \
  -f architecture=<arch> \
  -f force=false
```

Regenerate the channel index without rebuilding:

```bash
gh workflow run assemble-index.yml
```
