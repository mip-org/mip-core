# MATLAB + MinGW-w64 on Windows

Why the Windows build installs a specific MinGW-w64 toolchain instead of
using the GitHub runner's stock GCC, and why the Windows MATLAB floor is
R2023a.

## The compiler MATLAB certifies is release-specific

MATLAB compiles Windows MEX files with MinGW-w64, but each MATLAB release
certifies one specific GCC version (the "Supported and Compatible
Compilers" page). When `mex` builds a MEX through `mingw64.xml` and the
located compiler's version doesn't match, it prints:

> Warning: You are using an unsupported version of MinGW Compiler.

The relevant rows (Windows MinGW-w64):

| MATLAB        | Certified MinGW-w64 |
| ------------- | ------------------- |
| R2026a+       | 14.2 (8.1, 6.3)     |
| R2024a–R2025b | 8.1                 |
| R2023a–R2023b | **8.1** (and 6.3)   |
| R2018b–R2022b | 6.3                 |
| R2017b–R2018a | 5.3                 |
| R2016b–R2017a | 4.9.2               |

(MathWorks only *certifies* the MinGW add-on for Fortran from R2024a on.
That column is irrelevant here: only the C gateway goes through `mex` and
emits the warning; the `.f` sources are compiled by calling `gfortran`
directly, outside `mex`. The MinGW-w64 distributions ship gfortran
regardless.)

## Why we install 8.1.0 ourselves

The GitHub `windows` runner ships only a modern GCC (~15.x). MATLAB's
`mingw64.xml` *accepts* it but flags it unsupported — and older MATLAB mex
configs (R2022a and earlier) reject modern GCC outright. That rejection is
the sole reason the Windows build was originally pinned to R2023b.

Installing the certified **8.1.0** build removes both problems: the warning
disappears, and the modern-GCC blocker is gone, so the floor can drop to
the oldest MATLAB that certifies 8.1.0.

Integration is just the documented self-installed-MinGW hook — set the
`MW_MINGW64_LOC` environment variable to the MinGW root. `mingw64.xml`
(shipped in `matlabroot\bin\win64\mexopts`) reads it. **No support-package
install and no XML editing.** Caveat from the MathWorks docs: the install
path must contain no spaces (we use `C:\mingw810`).

This is centralized in `scripts/setup_mex_compilers.m` (called by
`bundle_one` before any package compile script), mirroring the
`gcc.xml` setup on Linux/macOS: on `windows_x86_64` it reads
`MW_MINGW64_LOC` (falling back to `C:\mingw64` for local builds), puts the
MinGW `bin` first on `PATH`, and selects it as the session MEX compiler via
`mex -setup:mingw64.xml C`. Per-package `compile_windows.m` scripts then
just call `gfortran`/`mingw32-make` and an unadorned `mex()` — they no
longer set `MW_MINGW64_LOC`/`PATH` or pass `-f mingw64.xml`.

Toolchain variant: `x86_64-8.1.0-release-posix-seh-rt_v6-rev0` — POSIX
threads, SEH exceptions, rt_v6 — the variant the MathWorks support package
uses. The MEX links `-static` (via `mingw64.xml`), so libgfortran/libgomp/
libquadmath are baked in and the `.mexw64` has no MinGW runtime DLL
dependency; no runtime-library bundling is needed on Windows (unlike Linux,
see MEX-RUNTIME-LIBS.md).

## Why R2023a, not R2023b

Both certify 8.1.0. Following the channel's oldest-reasonable-release
principle (an older MEX has wider forward compatibility — see the
per-arch `release:` choices in `build-package.yml`), R2023a is the oldest
release that certifies 8.1.0, so it is the Windows floor. R2022b and older
certify only 6.3.

## No `-fallow-argument-mismatch`

The Windows `compile_windows.m` scripts do **not** pass
`-fallow-argument-mismatch`. That flag exists only on gfortran >= 10, where
legacy rank/type argument mismatches became hard errors; it downgrades them
back to warnings. The certified MinGW is gfortran 8, which predates GCC 10,
so the mismatches are warnings already (silenced by `-w`) and the flag is
neither needed nor recognized. This matches `compile.m`, which omits it for
the Linux GCC 8.5 build. (Consequence: building locally with a modern stock
MinGW >= 10 would fail on those mismatches — use the certified 8.1.0.)
