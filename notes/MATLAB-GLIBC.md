# MATLAB MEX, `glibc`, and build-host compatibility

This is a companion to `MATLAB-GCC.md`. That note explains how to keep a Linux
MEX binary compatible with MATLAB's bundled `libstdc++`/`libgfortran` by
controlling the **GCC version** you compile with. This note covers the *other*
compatibility axis — `glibc` — which is determined by the **build host**, not by
MATLAB or by the GCC version, and which `MATLAB-GCC.md` does not address.

## TL;DR

A Linux MEX binary links against two unrelated sets of system libraries:

| Axis | Libraries | Pinned by | Covered by |
|---|---|---|---|
| **MATLAB runtime ABI** | `libstdc++` (GLIBCXX), `libgfortran` | the **GCC version** you compile *with* | `MATLAB-GCC.md` |
| **System ABI** | `glibc` (`libc.so.6`, `libm`, `libdl`, the dynamic loader `ld-linux`) | the **glibc on the build host** | this note |

`glibc` is **backward compatible but not forward compatible**: a binary built
against new glibc requires symbol versions that old glibc does not contain.
Therefore **build on the oldest glibc you want to support.** Build-low/run-high
works; build-high/run-low fails at load time.

The MATLAB version has **zero** influence on the glibc floor. Choosing R2022a
fixes the `libstdc++`/`libgfortran` axis and does nothing for glibc.

## The failure that motivated this note

`fmm2d.mexa64`, built on a GitHub `ubuntu-latest` runner (Ubuntu 24.04,
glibc 2.39) with MATLAB R2022a, failed to load on a Rocky Linux 8.10
workstation (glibc 2.28):

```
Invalid MEX-file 'fmm2d.mexa64': /lib64/libc.so.6:
version `GLIBC_2.32' not found (required by fmm2d.mexa64)
```

Inspecting the binary's versioned symbol requirements:

```console
$ objdump -T fmm2d.mexa64 | grep -o 'GLIBC_[0-9.]*' | sort -V -u | tail
GLIBC_2.32
GLIBC_2.34
GLIBC_2.35
GLIBC_2.36
GLIBC_2.38
```

The specific symbols that exceed glibc 2.28:

| Symbol | Version | Origin |
|---|---|---|
| `__libc_single_threaded` | `GLIBC_2.32` | linked against new glibc |
| `__libc_start_main` | `GLIBC_2.34` | pthreads merged into libc in 2.34 — alone walls off anything < 2.34 |
| `_dl_find_object` | `GLIBC_2.35` | linked against new glibc |
| `arc4random` | `GLIBC_2.36` | linked against new glibc |
| `__isoc23_sscanf` | `GLIBC_2.38` | `<stdio.h>` on glibc ≥ 2.38 redirects `sscanf` at compile time |
| `__isoc23_strtoul` | `GLIBC_2.38` | `<stdlib.h>` on glibc ≥ 2.38 redirects `strtoul` at compile time |

The `__isoc23_*` redirects are the smoking gun. glibc 2.38 headers rewrite
`sscanf`/`strtoul` calls into their C23 variants at **compile** time, so their
presence proves `mex` compiled `fmm2d.c` against glibc 2.38+ headers — i.e. the
runner was Ubuntu 24.04, almost certainly from `runs-on: ubuntu-latest`, which
migrated from 22.04 to 24.04 in early 2025.

**Diagnosis.** The GCC-pinning strategy in `MATLAB-GCC.md` is correct and was
working as intended — nothing in this failure is a `GLIBCXX` or `libgfortran`
mismatch, and the binary loads fine in R2022a+ from MATLAB's standpoint. The
mistake was controlling the MATLAB/GCC version but never pinning the runner's
glibc: `ubuntu-latest` silently slid from 22.04 to 24.04 and raised the glibc
floor out from under an otherwise-correct build.

## Why the usual mitigations don't help

- **Pinning the MATLAB version (R2022a).** Sets the `libstdc++`/`libgfortran`
  floor only. No effect on glibc.
- **Pinning the GCC version (e.g. GCC 10, per `MATLAB-GCC.md`).** Controls which
  GLIBCXX/libgfortran symbols are emitted. It does **not** control glibc symbol
  versions — those come from the C library and headers installed on the host. A
  modern glibc emits `__isoc23_*` and `__libc_start_main@GLIBC_2.34` regardless
  of which GCC drives the compile.
- **Bundling `libgfortran.so.5` / `libgomp.so.1` next to the MEX.** Addresses the
  libgfortran/GLIBCXX axis only. It can never substitute for glibc — the dynamic
  loader resolves `libc.so.6` before any `RPATH` you set takes effect. (In the
  failing build, the *bundled* `libgfortran.so.5` itself required `GLIBC_2.38`,
  so it carried the same defect.)

## The fix: build inside an old-glibc container — one MATLAB runs in

Pin the **build host's glibc** to the oldest you intend to support. No bare
GitHub runner is old enough anymore (the lowest available, `ubuntu-22.04`, is
glibc 2.35), so a container is mandatory.

Because the MEX *link* step needs MATLAB's `mex`, the container must be a base
MATLAB itself runs in — which rules out the generic `manylinux` images. Use a
MathWorks-supported base instead. MathWorks publishes official dependency images
(`mathworks/matlab-deps`) and supports these Linux bases per release:

| Build container | glibc | MATLAB-supported base? | Reaches Rocky/RHEL 8 (2.28)? |
|---|---|---|---|
| `ubuntu-latest` (24.04) | 2.39 | yes | ❌ |
| `ubuntu-22.04` | 2.35 | yes | ❌ |
| `ubuntu-20.04` | 2.31 | yes (retired by GitHub in 2025) | ❌ |
| **`mathworks/matlab-deps:<release>-ubi8`** (RHEL 8) | **2.28** | **yes** | ✅ exact match |
| `manylinux2014` (CentOS 7) | 2.17 | **no** — MATLAB ships no UBI7/CentOS7 base | ✅, but see below |

**Recommended target: `ubi8` / glibc 2.28.** It is the *oldest* glibc MathWorks
supports for MATLAB containers, and it matches the Flatiron RHEL/Rocky 8 fleet
exactly — the actual deployment target. Building on glibc 2.28 also makes the
`__isoc23_*`, `arc4random`, `_dl_find_object`, and `__libc_single_threaded`
symbols vanish entirely: the 2.28 headers never declare them, and
`__libc_start_main` resolves to its pre-2.34 node. You cannot *accidentally*
require a too-new symbol, because the symbol does not exist in the image.

glibc **2.17** (manylinux2014 / CentOS 7) would reach even older systems. MATLAB
R2022a's stated minimum *is* glibc 2.17 — it would run there — but two things
make 2.17 impractical regardless. First, MathWorks publishes no CentOS 7 / UBI 7
`matlab-deps` base, so you'd hand-roll the image. Second, and decisively for CI:
the GitHub Actions runner injects its own **Node** to run JS actions
(`checkout`, `setup-matlab`, `run-command`, `upload-artifact`), and Node ≥ 18
requires **glibc ≥ 2.28**. The last Node to run on glibc 2.17 was Node 16, now
removed from the runners — so those actions can't even start their interpreter
in a 2.17 container, and there's no flag to substitute a Node that can. Reaching
2.17 therefore means abandoning the MATLAB/GitHub actions entirely: build the MEX
*without* `mex` (copy the `extern/include` headers and `libmx`/`libmex` import
libraries into a manylinux2014 container and link by hand), clone and upload by
hand, etc. That is far more work for compatibility the Flatiron fleet (Rocky 8,
glibc 2.28) does not need. **2.28 is the right floor** — and not by coincidence:
it is simultaneously the deployment target and the lowest glibc the modern
Actions runner's Node can execute on.

Combine both axes inside the `ubi8` container:

- **glibc axis:** compile and link inside the `ubi8` (glibc 2.28) container.
- **MATLAB axis:** UBI 8's stock **GCC 8.5** is ideal — it is exactly the version
  `MATLAB-GCC.md` recommends (GCC 8 → loads in R2020b+), and it produces
  `libgfortran.so.5` / `GLIBCXX 3.4.25`, both within R2022a's bundled versions.
  No `gcc-toolset` needed.

(The repo ships `make.inc.manylinux`, so the container intent was present — but
the CI job wasn't using a container at all.)

## Implementing it: run the MathWorks action *inside* the container

A common misconception is that the free MathWorks MATLAB GitHub Action only works
on GitHub-hosted images, not in Docker. It does not. A GitHub Actions
`container:` job runs your chosen image **on** a GitHub-hosted runner — the runner
stays GitHub-hosted (so it remains free for public repos), but every step
executes *inside* the container. `setup-matlab` is built for this (it has an
`install-system-dependencies` input and documents the `mathworks/matlab-deps`
images), and the free public-repo licensing is performed by the
`run-command`/`run-tests`/`run-build` action — independent of the runner image —
so it still applies inside the container.

```yaml
name: Build fmm2d MEX (Linux, broad compatibility)
on: [push, workflow_dispatch]

jobs:
  build-linux-mex:
    runs-on: ubuntu-latest                        # GitHub-hosted runner (free for public repos)
    container: mathworks/matlab-deps:r2022a-ubi8  # but steps run in this glibc-2.28 image
    steps:
      - uses: actions/checkout@v4

      - name: Install build toolchain (UBI8 GCC 8.5; links against glibc 2.28)
        run: dnf install -y gcc gcc-c++ gcc-gfortran make binutils

      - uses: matlab-actions/setup-matlab@v2
        with:
          release: R2022a
          install-system-dependencies: false      # already baked into the matlab-deps image

      - name: Compile MEX (auto-licensed for public repo)
        uses: matlab-actions/run-command@v2
        with:
          command: compile

      - name: Gate the glibc floor (fail if anything newer than 2.28 is required)
        run: |
          MAX=$(objdump -T matlab/fmm2d.mexa64 | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -V | tail -1)
          echo "Highest GLIBC required: GLIBC_$MAX"
          [ "$(printf '%s\n2.28\n' "$MAX" | sort -V | tail -1)" = "2.28" ] \
            || { echo "::error::MEX requires GLIBC_$MAX (> 2.28)"; exit 1; }

      - uses: actions/upload-artifact@v4
        with: { name: fmm2d-linux-mexa64, path: matlab/fmm2d.mexa64 }
```

Two things to verify when adopting this:

1. **`mex` under the free public license.** The `setup-matlab` README warns that
   public-repo batch licensing "does not support external language interfaces,
   including MATLAB Engine APIs for ... C, C++, and Fortran." That clause is about
   the *MATLAB Engine* (calling *into* MATLAB from a C/Fortran program), not about
   `mex` *building* a MEX — which is core MATLAB and is what many public repos
   build in CI. Smoke-test it; if it is ever blocked, request a free **MATLAB
   batch licensing token** (MATLAB Batch Licensing Pilot) and map it to
   `MLM_LICENSE_TOKEN`.
2. **`objdump` availability.** The gate needs `binutils` in the container (added
   above); otherwise use `readelf -V`.

## How to verify a build before shipping it

```console
# Highest glibc symbol the binary requires — must be ≤ your target floor:
$ objdump -T fmm2d.mexa64 | grep -o 'GLIBC_[0-9.]*' | sort -V -u | tail -1
GLIBC_2.28

# Any GLIBCXX requirement — must be satisfiable by MATLAB's bundled libstdc++:
$ objdump -T fmm2d.mexa64 | grep -o 'GLIBCXX_[0-9.]*' | sort -V -u | tail -1
```

Add the first check as a CI gate so a runner-image bump can never silently raise
the glibc floor again.

## Background: why glibc symbol versioning works this way

glibc uses **symbol versioning**. When the linker resolves `sscanf`, it binds to
the specific versioned node present on the build host (`sscanf@GLIBC_2.2.5`,
`__isoc23_sscanf@GLIBC_2.38`, etc.). New glibc keeps all old version nodes
(backward compatible), so old binaries keep working on new systems. But an old
glibc has never heard of a node added later, so the loader reports
`version 'GLIBC_2.xx' not found` — which is exactly this failure. The only
reliable way to bound the highest node a binary references is to build where
those nodes don't exist yet: an old glibc.
