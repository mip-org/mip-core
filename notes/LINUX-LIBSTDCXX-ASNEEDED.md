# Linux MEX link failure: gcc-toolset's split `libstdc++` vs. `-Wl,--as-needed`

## Symptom

After switching the Linux build to **gcc-toolset-10** (see [MATLAB-GCC.md](MATLAB-GCC.md)),
linking a MEX file fails with a wall of undefined references — all originating *inside*
gcc-toolset's `libstdc++_nonshared.a`:

```
/usr/bin/ld: .../gcc-toolset-10/.../libstdc++_nonshared.a(fs_ops.o):
    in function `__gnu_cxx::stdio_filebuf<char>::~stdio_filebuf()':
  undefined reference to `vtable for std::basic_filebuf<char, std::char_traits<char> >'
  undefined reference to `std::__basic_file<char>::~__basic_file()'
  undefined reference to `std::locale::~locale()'
  undefined reference to `__cxa_begin_catch'
collect2: error: ld returned 1 exit status
```

This first surfaced on `fmm2d` — a **pure Fortran/C** package with *no C++ source* — which
made it especially confusing: nothing in the package uses `std::filesystem` (the `fs_*.o`
members) or iostreams, yet those objects are dragged into the link.

## How gcc-toolset splits `libstdc++`

RHEL's gcc-toolset (a Software Collection) lets you build with a newer compiler while keeping
the binary's runtime dependency on the **frozen base-system** `libstdc++.so.6`. It does this by
replacing `libstdc++.so` with a GNU ld **linker script**:

```
/* GNU ld script
   Use the shared library, but some functions are only in
   the static library, so try that secondarily.  */
INPUT ( libstdc++.so.6  -lstdc++_nonshared )
```

- `libstdc++.so.6` — the base-system shared lib (on RHEL 8, GCC 8.5 / `GLIBCXX_3.4.25`),
  the **primary, dynamic** source for the bulk of symbols.
- `libstdc++_nonshared.a` — a **static** archive supplying only the *newer* symbols the base
  `.so.6` lacks. It is the **secondary** fallback.

The `.so`-before-`.a` order is deliberate and correct for normal linking: ld resolves
everything it can dynamically against the base `.so.6`, then pulls from the static archive only
for the genuine gaps. (Reversing it would greedily static-link symbols that *are* in the shared
lib, bloating the binary and defeating the "depend on the stable base lib" goal.) The design
assumes the shared lib **stays in the link** — which it always does under normal linking.

## Root cause

The channel's `gcc`/`g++` mexopts added `-Wl,--as-needed` (stock MATLAB R2022a mexopts do
**not** have it). `--as-needed` keeps a shared library only if, *at the point it is encountered*,
there is an unresolved symbol it satisfies. Tracing the actual link with `ld -Map` (member
extraction reasons) revealed the exact chain:

1. MATLAB's **`libmx.so`** (linked via the mexopts' `-lmx`) references
   `std::__cxx11::basic_string<char>::swap` / `::_M_replace` — ordinary `std::string` symbols,
   **nothing to do with filesystem**. These are *not* exported by the base RHEL 8
   `libstdc++.so.6` (6.0.25); gcc-toolset supplies them, and they physically live (as weak
   defs) inside the **filesystem** translation units `fs_ops.o` / `fs_path80.o` of
   `libstdc++_nonshared.a`.
2. When the `-lstdc++` script is processed, `libstdc++.so.6` is evaluated **first**, under
   `--as-needed`. At that moment nothing pending requires it (the Fortran/C objects don't
   reference `libstdc++`, and `swap` isn't in it anyway), so it is **dropped**.
3. The static `libstdc++_nonshared.a` is evaluated **next** (immune to `--as-needed`) and pulls
   `fs_ops.o` to provide `swap`. Now `fs_ops.o` is a regular object in the link, with **hard**
   undefined references to `std::basic_filebuf` / `std::locale` / `__basic_file` — which *are*
   in `libstdc++.so.6`, but it was dropped one step earlier in the same script.
4. → undefined references → link fails.

So it was never about `std::filesystem`. It is: `libmx` needs a `std::string` symbol that only
the static half provides → that half is archived inside filesystem objects → pulling them needs
iostream symbols from the shared half → `--as-needed` already dropped the shared half.

This is a confirmed, isolated result. Toggling the **single** `-Wl,--as-needed` token in an
otherwise byte-identical mexopts file flips it:

| mexopts (identical except one token) | link | `fs_ops.o` pulled |
| ------------------------------------ | ---- | ----------------- |
| `--as-needed` present                | FAIL | yes               |
| `--as-needed` removed                | OK   | no                |

(Reproduced in the CI container image — ubi8 + gcc-toolset-10 + R2022a — via `mex -f <mexopts>`
plus `-Wl,-Map`.)

## Why reordering `-lstdc++` does NOT fix it

A natural idea is "put `-lstdc++` after its consumers (`-lmx`) so `--as-needed` keeps the shared
lib." It does not work: tested empirically, placing `-lstdc++` *only* after `-lmx -lmex -lmat`
fails identically. The harmful ordering (`.so.6` before `nonshared.a`) lives **inside the
linker script**, not on the command line. Moving the `-lstdc++` token slides the whole script —
both halves together — so `.so.6` is always evaluated *before* `fs_ops.o` exists to create the
need for it.

## Fix

Keep the base `libstdc++.so.6` in the link unconditionally so it is present when the static
half reaches back for `basic_filebuf` et al. The committed fix **guards** `-lstdc++` in the
Linux `gcc` mexopts:

```
LINKLIBS="… -lm -Wl,--push-state,--no-as-needed -lstdc++ -Wl,--pop-state"
```

`--no-as-needed` forces `libstdc++.so.6` to be a `NEEDED` entry regardless of position, so
`libmx`'s `std::string` symbols resolve **dynamically at runtime** and `fs_ops.o` is **never
extracted at all** — the `.mexa64` stays lean. `--as-needed` still trims other libraries.

**Both** the C (`gcc`) and C++ (`g++`) mexopts need the guard. The same `LINKLIBS` tail is
applied to each.

### The C++ (`g++`) path needs it too — and was missed at first

The original fix guarded only the **C** (`gcc`) mexopts, on the reasoning that the **C++**
(`g++`) mexopts carry no explicit `-lstdc++` (the `g++` driver appends the runtime itself, so
there was seemingly nothing to guard). That reasoning is wrong. The driver appends its
`-lstdc++` at the **end** of the link line, and the `-Wl,--as-needed` token in the mexopts'
`LDFLAGS` is **sticky** — still in effect when that driver-added `-lstdc++` is processed. So the
base `libstdc++.so.6` inside the split-lib script gets `--as-needed`-dropped by the *identical*
mechanism, and a C++ MEX that drags the static half out (e.g. by using `std::filesystem`) hits
the same wall of undefined references.

This surfaced on **gptoolbox's `bone_visible`** — the first C++ MEX in the channel to use
`std::filesystem` (`recursive_directory_iterator`, pulling `fs_dir.o`/`fs_ops.o` out of
`libstdc++_nonshared.a`). The MEX before it in the same compile run (`aabb`, `angle_derivatives`)
linked fine: they never touch `std::filesystem`, so nothing forces the static half out and the
`--as-needed`-dropped shared half is never missed.

The original repro was a **pure C/Fortran** package (`fmm2d`), which only ever exercises the
`gcc` link path — so the `gcc`-only guard looked complete. The root cause is identical on both
paths; gptoolbox was simply the first C++ consumer to reach it.

### Alternatives considered

- **Drop `-Wl,--as-needed` entirely** — matches stock R2022a, also fixes it. The only cost is
  every MEX gains a `NEEDED libstdc++.so.6` (and `libgfortran`/`libgomp`) even when unused —
  harmless, since those are MATLAB-provided (`linux_skip_set`, so the bundler skips them). A
  perfectly reasonable choice; the guard was preferred to retain `--as-needed`'s trimming for
  other libraries.
- **List `-lstdc++` twice** (`… -lstdc++ -lstdc++`) — *works* (the second occurrence's `.so.6`
  is evaluated after `fs_ops.o` introduces the `basic_filebuf` need, so `--as-needed` keeps it),
  but it is **strictly worse**: `fs_ops.o`/`fs_dir.o`/`fs_path80.o` are still statically pulled
  into the binary (dead `std::filesystem` code), and "why is `-lstdc++` listed twice?" is
  opaque to any future reader. Rejected.

## See also

- [MATLAB-GCC.md](MATLAB-GCC.md) — why the build uses gcc-toolset-10 and the `GLIBCXX` floor.
- `.github/workflows/build-package.yml` — the Linux toolchain step (installs gcc-toolset-10 and
  symlinks it into `/usr/bin` so MATLAB's `mex` detection finds it).
