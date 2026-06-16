# Channel MEX compiler configs (`mexopts/`) vs stock — what differs and why

An index of how the channel's custom mexopts XMLs diverge from the MathWorks
**stock** files, with the reasoning. The thorny items each have their own
deep-dive note (linked); this catalogs *everything* and points there for detail.

## Layout & stock baselines

| File(s) | Build MATLAB | Stock baseline diffed against |
|---|---|---|
| `linux_x86_64/{gcc,g++}.xml` | R2022a (glibc floor — see [MATLAB-GLIBC.md](MATLAB-GLIBC.md)) | R2022a `gcc_glnxa64.xml` / `g++_glnxa64.xml` |
| `macos_arm64/{clang,clang++}.xml` | R2023b | R2023b `maca64` `clang_maca64.xml` / `clang++_maca64.xml` |
| `macos_{arm64,x86_64}/{gcc,g++}.xml` | R2023b | GNU toolchain for the **Fortran** packages (fmm2d/fmmlib2d/sedumi) — see [MACOS-DEPLOYMENT-TARGET.md](MACOS-DEPLOYMENT-TARGET.md) |
| Windows | — | Stock MinGW, no custom XML — see [MATLAB-MINGW.md](MATLAB-MINGW.md) |

A framing caveat: **the Linux files are structurally derived from a *newer* MATLAB
template than R2022a** (`CMDLINE100/200`, `Version="$GCC_VERSION"`,
`LinkerExecutable`/`LinkerFlags` in `<Details>`, inlined `-DMATLAB_MEX_FILE`). So a chunk
of the diff against R2022a stock is **template-version drift, not deliberate flag
choices** — ignore those when reasoning about behavior.

## Cross-cutting policies (all files)

| Change vs stock | Why |
|---|---|
| `-O3 -DNDEBUG` (stock: `-O2 -DNDEBUG`) | Perf, channel-wide — kept deliberately over stock `-O2` (decision settled; both platforms stay consistent). `-O3` targets the baseline ISA (it does **not** imply `-march=native`), so it adds no portability/SIGILL hazard; and the CMake-built deps are already `-O3` (Release), so this keeps the MEX TUs consistent with them. |
| No `-std=` (stock pins one: c++11 Linux / c++14 macOS) | The C++ standard is a **per-package** concern — packages set `CMAKE_CXX_STANDARD` or their own `mex()` flags. Pinning the oldest standard channel-wide would break modern deps; pinning a modern one could break genuinely old code. Stay out of it. |
| mex-only: dropped `<client>` engine + mbuild blocks (and the vars only they used — `MWCPPLIB` on Linux, the `MATLABMEX` indirection) | The channel builds **mex** files, never `mbuild` standalones or engine apps. |
| Predictable arithmetic: `-fwrapv` + `-ffp-contract=off` | Defined signed overflow + no FMA contraction → reproducible FP across machines. *Already stock on macOS R2023b; a custom addition on Linux R2022a.* |
| `<env INCLUDE>` kept / restored to match stock | **Inert** — gcc/clang ignore the `INCLUDE` env var (they read `CPATH`/`CPLUS_INCLUDE_PATH`); the value is a semicolon-separated MSVC-style list. Kept only for stock alignment. Linux `g++` points it at `$GCC_VERSION` (was a dangling `$VER`, fixed); macOS `clang++` was re-added from stock (all its vars — `$XCODE_DIR`/`$CLANG_VERSION`/`$ISYSROOT` — resolve). C configs (`gcc`/`clang`) have no `<env INCLUDE>`, matching stock. |

## Linux `gcc.xml` / `g++.xml` vs R2022a stock

| Change | Why |
|---|---|
| `-z noexecstack` (LDFLAGS) | Non-executable stack: silences the binutils ≥ 2.39 "missing `.note.GNU-stack` implies executable stack" warning and guarantees a clean `dlopen` on hardened (SELinux) systems. Inherited from the newer template; R2022a stock lacks it. |
| `-Wl,--as-needed` (LDFLAGS) | Trims unused `NEEDED` libraries. R2022a stock lacks it. **Interacts badly** with gcc-toolset's split `libstdc++` → next row. |
| `gcc` only: `-lstdc++` guarded as `-Wl,--push-state,--no-as-needed -lstdc++ -Wl,--pop-state` | Keeps base `libstdc++.so.6` in the link so gcc-toolset's `libstdc++_nonshared.a` doesn't drag in unresolved iostream/filesystem symbols. Full analysis: **[LINUX-LIBSTDCXX-ASNEEDED.md](LINUX-LIBSTDCXX-ASNEEDED.md)**. Only C (`gcc`) needs it — `g++` has no explicit `-lstdc++` (the driver adds the runtime). |
| `-Wl,--no-undefined` (LDFLAGS) | Fail the link on unresolved symbols rather than deferring to load time. |
| `g++` LINKLIBS adds `-lMatlabEngine` | Benign — `--as-needed` drops it when a mex doesn't reference it. |
| Dropped `-std=c++11` from `SETENV` CXXFLAGS | Cross-cutting per-package-standard policy (above). |

## macOS `clang.xml` / `clang++.xml` vs R2023b stock

| Change | Why |
|---|---|
| `MACOSX_DEPLOYMENT_TARGET` 11.0 → 14.0 | Matches the `macos-14` CI runner's Homebrew bottles. **Not a runtime gate** — `dyld` doesn't enforce `minos` at `dlopen`; the real floor is the statically-linked bottles. Full analysis: **[MACOS-DEPLOYMENT-TARGET.md](MACOS-DEPLOYMENT-TARGET.md)** (commit `ce807e7`). |
| `clang++` only: `-ld_classic` | Forces Apple's old linker so R2023b's unconditional `LINKEXPORTCPP` (the C++ MEX API adapter export list) links for both classic and C++-API mex. Full analysis + **removal trigger**: **[MACOS-MEX-CPP-LINKER.md](MACOS-MEX-CPP-LINKER.md)** (commit `59d346f`). C `clang.xml` doesn't need it. ⚠️ `-ld_classic` is Apple-deprecated — see *Open decisions*. |
| `-Wl,-dead_strip_dylibs` (LDFLAGS) | Drops unreferenced dylib load commands; also makes dropping `-framework Cocoa` safe. |
| `clang++`: dropped `-framework Cocoa` | Not needed for non-GUI mex; safe under `-dead_strip_dylibs`. A Cocoa/AppKit package would add it itself. |
| `clang++`: dropped `-fobjc-arc` | Only relevant to Obj-C++ (`.mm`); irrelevant to C++ mex. |
| Dropped redundant `-fPIC` / `-pthread` / `-fno-omit-frame-pointer` | All default or no-op on macOS (code is always PIC). Commits `1e23eb3`, `4d6ae7c`, `f19ccb8`. |
| Dropped `XCODE_AGREED_VERSION` + `DEVELOPER_DIR_CHECK` locationFinder validators | Avoid headless `mex -setup` failures in CI (the Xcode-license check is a classic CI blocker). Trade-off: loses a friendly diagnostic for human users. |
| `maca64` hardcoded → `$ARCH` (`LDEXT`, the export maps, `-L` paths) | Arch-portable mexopts. |

`-fwrapv` / `-ffp-contract=off` are **already in stock R2023b** here (not custom). Note also
`-w` was removed from the macOS `g++.xml` (GNU/Fortran path) to keep the `version-min`
mismatch warning visible — see [MACOS-MEX-CPP-LINKER.md](MACOS-MEX-CPP-LINKER.md) /
[MACOS-DEPLOYMENT-TARGET.md](MACOS-DEPLOYMENT-TARGET.md).

## Open decisions

- **Dropping `-ld_classic`** when the macOS build MATLAB reaches R2025b+ (their `mex` driver
  applies the C++ export map conditionally) or when Apple removes the flag. Trigger and
  fallback documented in [MACOS-MEX-CPP-LINKER.md](MACOS-MEX-CPP-LINKER.md) §"When to drop".

## See also

- [LINUX-LIBSTDCXX-ASNEEDED.md](LINUX-LIBSTDCXX-ASNEEDED.md) — the `--as-needed` + gcc-toolset `libstdc++` guard.
- [MACOS-DEPLOYMENT-TARGET.md](MACOS-DEPLOYMENT-TARGET.md) — the real macOS compatibility floor.
- [MACOS-MEX-CPP-LINKER.md](MACOS-MEX-CPP-LINKER.md) — `-ld_classic` and the C++ MEX API export list.
- [MATLAB-GCC.md](MATLAB-GCC.md) / [MATLAB-GLIBC.md](MATLAB-GLIBC.md) — why Linux builds on gcc-toolset / old glibc.
- [MEX-RUNTIME-LIBS.md](MEX-RUNTIME-LIBS.md) — which runtime libs the bundler skips (why `-lMatlabEngine` etc. are harmless).
- [MATLAB-MINGW.md](MATLAB-MINGW.md) — Windows toolchain (no custom XML).
