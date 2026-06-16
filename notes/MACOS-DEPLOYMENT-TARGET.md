# macOS deployment floor: it's the Homebrew bottles, not `-mmacosx-version-min`

The macOS analogue of `MATLAB-GLIBC.md`. On Linux the build host's **glibc** sets the
floor; on macOS the floor is set by the **Homebrew bottles we statically link**, which
track the **CI runner's macOS** — *not* by the `-mmacosx-version-min` we pass. This note
records why, with the experiments that established it.

## TL;DR

- Pin the `macos_arm64` runner to **`macos-14`** (oldest arm64 runner Homebrew bottles
  exist for). It gives the lowest achievable floor (macOS 14) and freezes drift.
  `macos-latest` is a moving target (macOS 15 today → floor 15+, climbing) — the same
  trap as `ubuntu-latest` in `MATLAB-GLIBC.md`.
- Set the macOS mexopts `MACOSX_DEPLOYMENT_TARGET=14.0` to **match the bottle**. This is
  for honesty + keeping the version-min warning meaningful — **not** a runtime gate.
- There is **no clean "minimum macOS" gate** for a MEX: `dyld` does not enforce `minos`
  at `dlopen`. Real compatibility is symbol-level, decided by the bottle's build target.

## Three findings

### 1. The SDK / `-mmacosx-version-min` is *not* the constraint

A new SDK can target an old OS via the deployment target. Verified: on SDK **26.2**, a
bundle built `-mmacosx-version-min=11.0` stamps `minos 11.0` cleanly, no warning. So the
toolchain is happy to *aim* at 11.0 — that's not where the floor comes from.

### 2. The real floor = statically-linked Homebrew bottles (runner's macOS)

macOS packages statically link prebuilt Homebrew `.a` libraries, and Homebrew bottles
are built per-macOS and only down to **macOS 14** for arm64. Their objects carry the
bottle's `minos`. What's linked:

| Path | statically-linked bottles | floor source |
|---|---|---|
| **clang** (gptoolbox) | `libgmp.a`, `libmpfr.a` (CGAL/Boost are header-only → no floor) | the brew gmp/mpfr bottle |
| **gcc/gfortran** (fmm2d, fmmlib2d, sedumi) | Homebrew GCC runtime: `libstdc++.a`, `libgfortran.a`, `libquadmath.a` (via `-static-libstdc++ -static-libgcc -static-libgfortran -static-libquadmath`) | the Homebrew GCC bottle |

Measured `minos` of the bottles on a macOS-15 box (every value tracks the bottle's OS):

```
libgmp.a / libmpfr.a / libopenblas.a   minos 15.0
libstdc++.a / libgfortran.a / libquadmath.a   minos 15.0
libgcc.a / libgcc_eh.a   minos 11.0   (low-level runtime, conservatively built — not the binding constraint)
```

So linking these raises the MEX's real floor to the bottle's macOS, regardless of
`-mmacosx-version-min`. The binding constraint on the GCC path is
`libstdc++`/`libgfortran`/`libquadmath` (15.0 here); `libgcc` being 11.0 is a red herring.

**The clang path is special:** it links the **system** `libc++` from `/usr/lib`
(OS-provided, back-deploys cleanly) — not a bottle. So clang-built MEX dodge the
Homebrew-runtime floor; their only bottle floor is `libgmp`/`libmpfr`, which *are*
buildable from source at an older target (as Linux already does). The **GCC path cannot
escape** the Homebrew GCC runtime floor short of building GCC from source for an old
target — impractical. So the channel-wide floor is the GCC path's = the runner's macOS.

### 3. `dyld` does not enforce `minos` at `dlopen` — the stamp is advisory

MATLAB loads a MEX via `dlopen`. Tested on macOS **15.7.5**, both a `vtool`-patched
bundle (`minos 99.0`) and one **properly built** with `-mmacosx-version-min=26.0`
(stamped `minos 26.0`, a real future OS) → **`dlopen` succeeds**. So a MEX claiming a
newer floor than the host still loads; the `minos` value does not gate it.

Consequence: a too-old-OS user does **not** get a clean "requires macOS N" rejection.
They get a murky **symbol-not-found** failure (or a crash) *if* the bottle's code
references a symbol absent on their OS — and that's driven by the bottle's build target,
not by `MACOSX_DEPLOYMENT_TARGET`. So `MACOSX_DEPLOYMENT_TARGET` is a build-hygiene knob
(truthful stamp + meaningful version-min warning), never a runtime gate.

## What we do, and why

- **Runner pinned to `macos-14`** — the only lever that actually moves the floor. macОS
  14 bottles → MEX works on macOS 14+. `macos-latest` (15) silently makes the real floor
  15+, and drifts up as GitHub bumps the label.
- **`MACOSX_DEPLOYMENT_TARGET=14.0`** — matches the bottle so the stamp is honest and the
  `-mmacosx-version-min` mismatch warning goes quiet *when matched* but still fires if a
  newer (15.0) object sneaks in. (We removed `-w` from `g++.xml` precisely to keep that
  warning visible — see `MACOS-MEX-CPP-LINKER.md` for the `-w`/`-ld_classic` story.)

## Aside: macOS needs no GCC version pin (unlike Linux), and the static-link split

`MATLAB-GCC.md` pins **GCC 8.5 on Linux** so a MEX's `GLIBCXX` stays within MATLAB's
bundled GNU `libstdc++`. **That reasoning is Linux-specific and does not apply on macOS**,
for two independent reasons:

1. **No shared GNU libstdc++.** MATLAB on macOS links **libc++** (`/usr/lib/libc++.1.dylib`
   — confirmed via `otool -L libmx.dylib`), not GNU `libstdc++`. So a GCC-built MEX shares
   no GNU C++ runtime with MATLAB, and the MEX↔MATLAB boundary is the **C** Matrix API
   (`mxArray*`), so no C++ ABI crosses it. There is no `GLIBCXX`-vs-MATLAB constraint → the
   GCC version is free (latest Homebrew GCC is fine). Pinning a GCC version would buy only
   build *reproducibility*, not compatibility — far lower stakes than the runner pin.

2. **The GNU runtime is dynamic on Linux but static on macOS — because of who ships it.**
   On **Linux**, MATLAB ships the GNU runtime (`libstdc++`/`libgcc_s`/`libgfortran` in
   `sys/os/glnxa64`, on `LD_LIBRARY_PATH`; all in `linux_skip_set` — see
   `MEX-RUNTIME-LIBS.md`), so the MEX **dynamic-links all of it and lets MATLAB resolve it**.
   We previously static-linked `libstdc++`/`libgcc` on Linux but dropped it: it was redundant
   defense (the GCC-8.5 pin caps `GLIBCXX` at 3.4.25, within every supported MATLAB's bundled
   `libstdc++`, and the strip-test gate catches any overshoot as a red build), it was
   inconsistent with `libgfortran` — which is *forced* dynamic, since its `.a` is **non-PIC**
   (`R_X86_64_TPOFF32 … recompile with -fPIC`, so it can't go in the shared MEX) — and a
   static GCC runtime puts a second copy of `libstdc++`/the unwinder in the process alongside
   MATLAB's. Dynamic is uniform, matches stock, and is safe given the pin + gate.

   On **macOS**, MATLAB ships **no** GNU runtime (it uses libc++), so the MEX must carry its
   own — and it can, because macOS/arm64 code is always PIC, so every Homebrew `.a`
   (`libstdc++`/`libgcc`/`libgfortran`/`libquadmath`) links into the bundle. That
   self-containment is exactly what plants the deployment-floor coupling above: the static
   archives carry the bottle's `minos`.

   (Orthogonal: Linux *does* statically link the from-source **dependency** libs —
   gmp/mpfr/libccd/… — which must be built `-fPIC` to go in the MEX `.so`, via
   `CMAKE_POSITION_INDEPENDENT_CODE=ON`, the "Linux link fix". Those are the dep libs, not
   the GNU runtime.)

## Going lower than 14, or verifying

- **Below macOS 14 is only feasible on the clang path**, and only by building `gmp`/`mpfr`
  from source at the lower target instead of using brew bottles (the Linux side already
  builds gmp/mpfr from source). It's moot channel-wide while the Fortran packages sit at
  the Homebrew-GCC-runtime floor.
- **Detector:** the `ld: warning: object file … was built for newer macOS version (X)
  than being linked (14.0)` warning flags any bottle/object above the floor. A CI gate
  could assert the shipped MEX's `minos`/symbol requirements, mirroring the Linux glibc
  `objdump` gate — but note `minos` alone is advisory; a symbol-level check is the real
  equivalent.
