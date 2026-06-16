# MATLAB, GCC, `libstdc++`, and `libgfortran` compatibility

Different versions of MATLAB support different versions of GCC when compiling MEX files on Linux.
MATLAB has online documentation that states which versions of GCC compilers are supported by each MATLAB version (see https://www.mathworks.com/support/requirements/supported-compilers-linux.html).
However, MATLAB ships and links against its own versions of `libstdc++` and `libgfortran`, which may not actually support the compiler versions claimed in the online documentation.

Below, we enumerate what version of `libstdc++` MATLAB actually ships with, and therefore what GCC versions are actually supported by MATLAB. The relevant MATLAB libraries are stored in `$MATLAB_ROOT/sys/os/glnxa64/`.

| MATLAB | *claims to support* | GCC   | *but ships with* | `libstdc++` | *which supports* | GCC    | *or older* |
| ------ | ------------------- | ----- | ---------------- | ----------- | ---------------- | ------ | ---------- |
| R2025b |                     | 13.x  |                  | 6.0.30      |                  | 12.1.0 |            |
| R2025a |                     | 13.x  |                  | 6.0.30      |                  | 12.1.0 |            |
| R2024b |                     | 13.x  |                  | 6.0.30      |                  | 12.1.0 |            |
| R2024a |                     | 12.x  |                  | 6.0.28      |                  | 10.1.0 |            |
| R2023b |                     | 11.x  |                  | 6.0.28      |                  | 10.1.0 |            |
| R2023a |                     | 10.x  |                  | 6.0.28      |                  | 10.1.0 |            |
| R2022b |                     | 10.x  |                  | 6.0.28      |                  | 10.1.0 |            |
| R2022a |                     | 10.x  |                  | 6.0.28      |                  | 10.1.0 |            |
| R2021b |                     | 9.x   |                  | 6.0.25      |                  | 8.1.0  |            |
| R2021a |                     | 9.x   |                  | 6.0.25      |                  | 8.1.0  |            |
| R2020b |                     | 9.x   |                  | 6.0.25      |                  | 8.1.0  |            |
| R2020a |                     | 6.3.x |                  | 6.0.22      |                  | 6.1.0  |            |

The story for Fortran compilation is better. MATLAB's online documentation correctly states which `gfortran` versions are compatible with the version of `libgfortran` shipped with MATLAB.

| MATLAB | GCC   | `libgfortran` |
| ------ | ----- | ------------- |
| R2025b | 10.x  | 5.0.0         |
| R2025a | 10.x  | 5.0.0         |
| R2024b | 10.x  | 5.0.0         |
| R2024a | 10.x  | 5.0.0         |
| R2023b | 10.x  | 5.0.0         |
| R2023a | 10.x  | 5.0.0         |
| R2022b | 10.x  | 5.0.0         |
| R2022a | 10.x  | 5.0.0         |
| R2021b | 8.x   | 5.0.0         |
| R2021a | 8.x   | 5.0.0         |
| R2020b | 8.x   | 5.0.0         |
| R2020a | 6.3.x | 3.0.0         |

The upshot *for this axis* is that compiling our MEX binaries on Linux with GCC 8
keeps their `libstdc++`/`libgfortran` requirements within what MATLAB R2020b and
newer ship. **But this is only one of three compatibility axes, and not the one
that sets the floor** — see the next section.

## The three compatibility axes — and which one sets the floor

A Linux MEX must satisfy **three** independent compatibility axes. The
lowest-reaching one wins:

| Axis | Libraries / mechanism | Pinned by | Direction |
|---|---|---|---|
| **System ABI** | `glibc` (`libc`, `libm`, `ld-linux`) | the **build host's glibc** | backward-compatible — build low, run high (see `MATLAB-GLIBC.md`) |
| **Compiler runtime ABI** | `libstdc++` (GLIBCXX), `libgfortran` | the **GCC version** you compile with | backward-compatible — old symbols resolve against newer libs (this note) |
| **MEX API** | `libmx`/`libmex`/`libmat`/`MatlabDataArray` + the MEX-file-version stamp | the **MATLAB release you link `mex` against** | **forward-compatible only** — runs on its build release and *newer*, never older |

The first two axes are backward-compatible: build low, run high. The **MEX-API
axis is the odd one out — it is forward-compatible only.** `mex` links the MEX
against the build MATLAB's `libmx`/`libmex` and stamps it with that release's
MEX-file version via the `c_exportsmexfileversion.map` version-script (it appears
as `LINKEXPORTVER` in every mexopts file, stock and custom). An older `libmex`
loading a higher-stamped MEX rejects it outright ("built with a newer version of
MATLAB"), and any `libmx`/`MatlabDataArray` symbols added in later releases
simply do not resolve on an older `libmex`.

**Consequence: the real floor is the build MATLAB, not the GCC version.** The
effective minimum supported release is `max(libstdc++ axis, MEX-API axis)`.
Building with GCC 8 keeps the libstdc++ axis reachable down to R2020b — but if
you link `mex` on R2022a, the MEX-API axis walls off everything older, so the
binary will **not** load on R2020b regardless. The GCC-8 headroom below the build
MATLAB is unused. To actually support an older release you must *build* on it (the
GCC-8 pin permits this on the libstdc++ axis), not merely compile with an old GCC.

This also settles what to test. Because the floor is the build MATLAB and CI's
strip-test already runs there, the build MATLAB's own `libstdc++` is the relevant
ceiling: any GCC-version regression that overshoots it (e.g. GCC ≥ 11 against
R2022a's GLIBCXX_3.4.28) fails to load in that test and turns the build red. A
*second* test on the newest MATLAB would add forward-compatibility assurance for
the MEX-API axis, but the floor itself is already gated by the build-MATLAB test.
(This is also why statically linking `libstdc++` is defensive rather than
required — see `MEX-RUNTIME-LIBS.md`.)

## Runtime workaround: `LD_PRELOAD`

The tables above describe the problem at **build** time — keep the compiled
`GLIBCXX` requirement within what MATLAB's bundled `libstdc++` provides. The CI
builds solve this structurally by pinning GCC 8.5 in the `ubi8` container
(`GLIBCXX 3.4.25`, within every MATLAB ≥ R2020b — see `MATLAB-GLIBC.md`). But on
a local workstation you often compile with the host's *current* g++ (13, 14, …),
which emits a newer `GLIBCXX` node than your MATLAB's `libstdc++` contains. The
load then fails with, e.g.:

```
Invalid MEX-file '.../foo.mexa64':
.../sys/os/glnxa64/libstdc++.so.6: version `GLIBCXX_3.4.32' not found
```

### Why MATLAB's old `libstdc++` wins

MATLAB ships its own `libstdc++.so.6` in `$MATLABROOT/sys/os/glnxa64/` and places
that directory on `LD_LIBRARY_PATH` before launch. The dynamic loader searches
`LD_LIBRARY_PATH` **before** a binary's own RPATH/RUNPATH, so MATLAB's copy
shadows the (newer) system one in `/lib/x86_64-linux-gnu/` — even though the
system copy has the symbol your MEX needs. (This is the same precedence rule that
makes `libgfortran` bundling pointless inside MATLAB — see
`MEX-RUNTIME-LIBS.md`.)

### What `LD_PRELOAD` fixes

```console
$ LD_PRELOAD=/lib/x86_64-linux-gnu/libstdc++.so.6 \
    /usr/local/MATLAB/R2025b/bin/matlab
```

`LD_PRELOAD` maps the named library **first**, ahead of everything on
`LD_LIBRARY_PATH`. Because `libstdc++.so.6` is *forward* compatible (a newer
`6.0.x` satisfies every symbol an older one does — see the note at the top of the
correspondence table), the system copy serves both MATLAB's own needs and your
MEX's newer `GLIBCXX_3.4.3x` requirement. The missing symbol resolves and the MEX
loads.

### Caveats and scope

- **Local dev only.** This is an escape hatch for binaries built with a too-new
  g++ on your own machine. Anything we *ship* must instead be built within the
  ABI floor (GCC 8.5 / `ubi8`) so end users need no `LD_PRELOAD`.
- **Forward compat is the load-bearing fact.** Preloading a *newer* libstdc++
  works; preloading an older one would break MATLAB itself. Only ever preload the
  system copy when it is newer than MATLAB's.
- **`libstdc++` only.** This does nothing for the `glibc` axis — `libc.so.6` is
  resolved before any preload of a higher-level lib helps, and glibc is not
  forward compatible anyway (see `MATLAB-GLIBC.md`). If the failure names
  `GLIBC_2.xx` rather than `GLIBCXX_3.4.xx`, `LD_PRELOAD` is the wrong tool.
- **Find the version a MEX needs:**
  ```console
  $ objdump -T foo.mexa64 | grep -o 'GLIBCXX_[0-9.]*' | sort -V -u | tail -1
  ```
  Compare against your MATLAB's bundled max in the table above.

## GCC, GLIBCXX, and libstdc++ correspondence

The following table lists the version correspondence between GCC, `GLIBCXX`, `libstdc++`, and `libgfortran` (see https://gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html). Missing entries indicate unknown version numbers.

Note: Major versions of `libstdc++` are forward compatibile. For example, `libstdc++.so.6.0.0` (corresponding to GCC 3.4.0) is compatible with `libstdc++.so.6.0.34` (corresponding to GCC 16.1.0).

| GCC    | `GLIBCXX` | `libstdc++` | `libgfortran` |
| ------ | --------- | ----------- | ------------- |
| 3.0.0  |           | 3.0.0       |               |
| 3.0.1  |           | 3.0.1       |               |
| 3.0.2  |           | 3.0.2       |               |
| 3.0.3  |           | 3.0.3       |               |
| 3.0.4  |           | 3.0.4       |               |
| 3.1.0  | 3.1       | 4.0.0       |               |
| 3.1.1  | 3.1       | 4.0.1       |               |
| 3.2.0  | 3.2       | 5.0.0       |               |
| 3.2.1  | 3.2.1     | 5.0.1       |               |
| 3.2.2  | 3.2.2     | 5.0.2       |               |
| 3.2.3  | 3.2.2     | 5.0.3       |               |
| 3.3.0  | 3.2.2     | 5.0.4       |               |
| 3.3.1  | 3.2.3     | 5.0.5       |               |
| 3.3.2  | 3.2.3     |             |               |
| 3.3.3  | 3.2.3     |             |               |
| 3.4.0  | 3.4       | 6.0.0       |               |
| 3.4.1  | 3.4.1     | 6.0.1       |               |
| 3.4.2  | 3.4.2     | 6.0.2       |               |
| 3.4.3  | 3.4.3     | 6.0.3       |               |
| 4.0.0  | 3.4.4     | 6.0.4       |               |
| 4.0.1  | 3.4.5     | 6.0.5       |               |
| 4.0.2  | 3.4.6     | 6.0.6       |               |
| 4.0.3  | 3.4.7     | 6.0.7       |               |
| 4.1.0  |           | 6.0.7       |               |
| 4.1.1  | 3.4.8     | 6.0.8       |               |
| 4.2.0  | 3.4.9     | 6.0.9       |               |
| 4.2.1  |           | 6.0.9       |               |
| 4.2.2  |           | 6.0.9       |               |
| 4.3.0  | 3.4.10    | 6.0.10      | 3.0.0         |
| 4.4.0  | 3.4.11    | 6.0.11      |               |
| 4.4.1  | 3.4.12    | 6.0.12      |               |
| 4.4.2  | 3.4.13    | 6.0.13      |               |
| 4.5.0  | 3.4.14    | 6.0.14      |               |
| 4.6.0  | 3.4.15    | 6.0.15      |               |
| 4.6.1  | 3.4.16    | 6.0.16      |               |
| 4.7.0  | 3.4.17    | 6.0.17      |               |
| 4.8.0  | 3.4.18    | 6.0.18      |               |
| 4.8.3  | 3.4.19    | 6.0.19      |               |
| 4.9.0  | 3.4.20    | 6.0.20      |               |
| 5.1.0  | 3.4.21    | 6.0.21      |               |
| 6.1.0  | 3.4.22    | 6.0.22      |               |
| 7.1.0  | 3.4.23    | 6.0.23      | 4.0.0         |
| 7.2.0  | 3.4.24    | 6.0.24      |               |
| 8.1.0  | 3.4.25    | 6.0.25      | 5.0.0         |
| 9.1.0  | 3.4.26    | 6.0.26      |               |
| 9.2.0  | 3.4.27    | 6.0.27      |               |
| 9.3.0  | 3.4.28    | 6.0.28      |               |
| 10.1.0 | 3.4.28    | 6.0.28      |               |
| 11.1.0 | 3.4.29    | 6.0.29      |               |
| 12.1.0 | 3.4.30    | 6.0.30      |               |
| 13.1.0 | 3.4.31    | 6.0.31      |               |
| 13.2.0 | 3.4.32    | 6.0.32      |               |
| 14.1.0 | 3.4.33    | 6.0.33      |               |
| 15.1.0 | 3.4.34    | 6.0.34      |               |
| 16.1.0 | 3.4.34    | 6.0.34      |               |
