# MEX runtime-library bundling and why it is non-recursive

A companion to `MATLAB-GCC.md` and `MATLAB-GLIBC.md`. Those notes explain which
symbol versions (`libstdc++`/`libgfortran` ABI, `glibc` floor) a Linux MEX may
require. This note covers the next question: of the shared libraries a MEX
actually pulls in, which ones we **ship** next to it and which we leave to be
resolved at runtime — and the one design decision in
`scripts/bundle_runtime_libs.m` that most often looks like a bug but is not:
**bundling is deliberately non-recursive.**

## TL;DR

- `bundle_runtime_libs.m` scans only the **MEX's own** `NEEDED` entries, copies
  the non-system, non-MATLAB ones next to the MEX, and sets an `$ORIGIN` RPATH.
  It does **not** recurse into the `NEEDED` entries of the libs it copies.
- A bundled lib's own transitive dependencies are expected to be satisfied at
  runtime by the **OS** or by **MATLAB**, because the package only ever loads
  inside MATLAB, which puts its `sys/os/glnxa64` runtime libs on
  `LD_LIBRARY_PATH`.
- So we never ship `libquadmath`, `libz`, etc., even though `libgfortran.so.5`
  hard-`NEEDED`s them. Adding recursion would start bundling those — redundant
  copies of libs MATLAB already provides, the exact ABI hazard the skip-set
  guards against for `libstdc++`/`libgcc_s`.

## Three tiers of runtime library

A MEX's `NEEDED` list (and the `NEEDED` lists of its dependencies) falls into
three tiers:

| Tier | Examples | Who provides it at runtime | Do we bundle it? |
|---|---|---|---|
| **OS-guaranteed** | `libc.so.6`, `libm.so.6`, `libpthread.so.0`, `libdl.so.2`, `ld-linux-x86-64.so.2` | the end-user's OS | No — in `linux_skip_set` |
| **MATLAB-provided** | `libgfortran.so.5`, `libstdc++.so.6`, `libgcc_s.so.1`, `libquadmath.so.0`, `libz.so.1` | MATLAB's `sys/os/glnxa64` (on `LD_LIBRARY_PATH`) | No — MATLAB resolves it |
| **Must-bundle** | `libgomp.so.1` (MATLAB does **not** ship it), plus any genuinely third-party `.so` | nothing, unless we ship it | **Yes** — this is what bundling is for |

Two different mechanisms keep MATLAB-provided libs out of the bundle:

- Libs that are **direct** `NEEDED`s of the MEX (`libgfortran.so.5`,
  `libstdc++.so.6`, `libgcc_s.so.1`) are listed explicitly in `linux_skip_set`.
- Libs that are only **transitive** (`libquadmath.so.0`, `libz.so.1` —
  `NEEDED` by `libgfortran`, not by the MEX) are never reached, because the
  scan is non-recursive.

The critical distinction is `libgomp`: Linux MATLAB ships `libgfortran` but
**not** `libgomp`, so libgomp is the one runtime lib we genuinely must bundle
for OpenMP packages. (Verified directly against the Linux MATLAB install.)

## Why we can lean on MATLAB for the transitive deps

The package only ever runs inside MATLAB, and MATLAB ships its own
`libgfortran`, `libquadmath`, `libstdc++`, `libgcc_s`, `libz`, … in
`$MATLABROOT/sys/os/glnxa64/`, which it places on `LD_LIBRARY_PATH`. (It does
**not** ship `libgomp` — see below.) The build toolchain is pinned (`ubi8`
GCC 8.5 / R2022a) precisely so the compiled code's `libgfortran`/`libstdc++`
symbol-version requirements stay **within** what those MATLAB copies provide —
see `MATLAB-GCC.md` and the "pins the … ABI axis" comment in `build-package.yml`.

A subtlety that makes skipping `libgfortran` not just safe but *necessary*: the
dynamic loader searches `LD_LIBRARY_PATH` **before** a binary's own `$ORIGIN`
RPATH (RUNPATH). MATLAB's library directory is on `LD_LIBRARY_PATH`, so MATLAB's
`libgfortran` is loaded regardless of what we bundle — a bundled copy would be
**shadowed**, never used, and could not even serve as a newer-version fallback
(MATLAB's would still win and a too-old MATLAB would fail anyway). So we don't
ship one; we list it in `linux_skip_set` and let MATLAB resolve it, along with
its own transitive deps (`libquadmath`, `libz`).

`libgomp` is the exception that proves the rule. Linux MATLAB does **not** ship
it, so it is not on MATLAB's `LD_LIBRARY_PATH`; with the system copy stripped at
test time, the only copy left is the one we bundle, reached via the MEX's
`$ORIGIN` RPATH. That is why `libgomp.so.1` is deliberately **absent** from
`linux_skip_set`.

## The strip-then-test gate is the proof (and its scope)

`build-package.yml` deletes the entire compiler/runtime toolchain
(`libgfortran`/`libgomp`/`libquadmath` are purged and `ldconfig` is refreshed;
"Verify strip" fails the build if any remain on the linker path) and then reruns
the package's test against the bundled `.mhl`. A MEX that needs an unbundled,
non-MATLAB library fails to load → the build goes red → nothing ships.

Note the scope: the test runs **inside MATLAB**, so the gate proves
self-containment relative to *a machine that has MATLAB* — which is exactly the
deployment target. It does **not** prove independence from MATLAB's own runtime
libs, and it is not meant to.

## Worked example: fmmlib2d 1.2.4

The MEX's dependency graph (`objdump -p`, `linux_x86_64`):

```
fmm2d.mexa64       NEEDED libgfortran.so.5, libgomp.so.1, libmx.so, libmex.so, libm, libpthread, libc, ld-linux
libgfortran.so.5   NEEDED libquadmath.so.0, libz.so.1, libm, libgcc_s, libc
libgomp.so.1       NEEDED libdl, libpthread, libc
```

Classification of the MEX's two non-system direct `NEEDED`s:

- `libgfortran.so.5` → **skipped** (`linux_skip_set`); MATLAB ships it and
  resolves it via `LD_LIBRARY_PATH`, dragging in its own transitive deps
  (`libquadmath.so.0`, `libz.so.1`) too.
- `libgomp.so.1` → **bundled**; MATLAB does not ship it, so it is copied next to
  the MEX with an `$ORIGIN` RPATH.

So the bundle ships exactly one runtime lib: `libgomp.so.1`. The post-strip test
(system `libgfortran`/`libgomp`/`libquadmath` all purged from the host) passes at
~1e-16 relative error because it runs inside MATLAB: `libgfortran` and its
transitive deps come from MATLAB, and `libgomp` comes from the bundle.

> Historical note: earlier builds also bundled `libgfortran.so.5`. That copy was
> dead weight — shadowed at runtime by MATLAB's via `LD_LIBRARY_PATH` precedence
> — and was dropped by adding `libgfortran.so.5` to `linux_skip_set`.

## When recursion *would* be needed, and how to add it safely

Recursion is only correct for a transitive dependency that is **neither
OS-guaranteed nor MATLAB-provided** — a genuinely third-party `.so` pulled in by
something we bundle. If such a package appears:

1. First extend `linux_skip_set` / `macos_skip_patterns` to exclude the
   MATLAB/OS libs that would otherwise be swept in (`libquadmath.so.0`,
   `libz.so.1`, …). Otherwise recursion will start shipping redundant copies of
   libs MATLAB already provides and risk ABI clashes with MATLAB's own.
2. Then make `bundle_linux` walk each copied lib's `NEEDED` entries to a
   fixpoint. The per-lib `$ORIGIN` RPATH stamping is already handled by
   `copy_and_sanitize_lib`, so the libs would find their siblings in the bundle
   directory — recursion is the only missing piece.

Until then, the non-recursive scan is the correct behavior; do not "fix" it.
