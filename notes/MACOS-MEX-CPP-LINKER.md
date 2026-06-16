# macOS MEX, the C++ MEX API export list, and `-ld_classic`

Why the channel's macOS `clang++.xml` (and `g++.xml`) pass `-ld_classic`, and what
to do when Apple removes it.

## TL;DR

- A C++ MEX file is either **classic** (`void mexFunction(...)`, the C Matrix API)
  or **C++ MEX API** (a `matlab::mex::Function` class via `#include "mexAdapter.hpp"`).
- The C++ MEX API needs three adapter symbols — `mexCreateMexFunction`,
  `mexDestroyMexFunction`, `mexFunctionAdapter` — **exported**. The mexopts do this
  with `LINKEXPORTCPP`:
  `-Wl,-U,<sym> … -Wl,-exported_symbols_list,"…/cppMexFunction.map"`.
- R2023b applies `LINKEXPORTCPP` **unconditionally** to every C++ build. For a
  *classic* MEX (which does not define those symbols) it relies on the `-U`
  ("allow undefined") flags to let the export list tolerate the missing symbols.
- Apple's **new linker** (`ld-prime`, default since Xcode 15) **no longer honors
  `-U` for that case**: you cannot name an undefined symbol in an
  `-exported_symbols_list`, and `-U` does not exempt it. So an unmodified R2023b
  `clang++.xml` **fails to build a classic MEX** on a current Xcode:
  `Undefined symbols: _mexCreateMexFunction … referenced from <initial-undefines>`.
  (Confirmed: pristine R2023b stock `clang++_maca64.xml` fails the same way — this is
  not something the channel introduced.)
- `-ld_classic` forces the **old** linker (`ld-classic`), which still honors `-U`, so
  one static `LINKEXPORTCPP` works for both classic and C++ API MEX. That is what
  `g++.xml` already does, and what `clang++.xml` now does too — so the channel matches
  stock's full C++ support from a single mexopts.

## Why not the alternatives

- **`-Wl,-undefined,dynamic_lookup`** — does not help. `dynamic_lookup` relaxes
  undefined *imports* (resolved at load); `cppMexFunction.map` is an *export* list,
  and you cannot export a symbol the binary does not define. Different axis; the build
  still fails.
- **Dropping `LINKEXPORTCPP`** — builds classic MEX fine, but a C++ MEX API MEX then
  links without exporting the adapter symbols (the `-exported_symbols_list
  mexFunction.map` allowlist hides them despite their `visibility("default")`), so
  MATLAB calls the empty `mexFunction` stub instead of the class → runtime
  "One or more output arguments not assigned."

## How newer MATLAB fixed it — by changing `mex`, not the linker

R2025b and R2026a took a different route, and it is the reason they need no
`-ld_classic`: they **removed `$LINKEXPORTCPP` from the default link** in their
mexopts and moved the decision into the **`mex` driver**, which applies
`cppMexFunction.map` **conditionally** — only for a C++ MEX API build.

The trigger is **symbol-based**, verified empirically: `mex` compiles the source,
inspects the resulting object, and if the C++ adapter symbols are **defined** it does
a **second link** that adds `cppMexFunction.map` to export them. A classic MEX (no
such symbols) gets a single link without the cpp map, so it never hits the
new-linker error. Evidence: a classic `.cpp` → 1 link, no cpp map; a `mexAdapter.hpp`
`.cpp` → 2 links, cpp map on the 2nd; and a `.cpp` that *defines the adapter symbols
directly without including `mexAdapter.hpp`* also → 2 links + cpp map — which rules
out "detects the `#include`" and confirms "detects the defined symbols."

In R2026a the `LINKEXPORTCPP` variable still carries the `-U` flags, but they are now
**vestigial**: the map is applied only when the symbols are defined, so there is
nothing undefined to allow — and the new linker ignores `-U` for that purpose anyway.
The `-U` is a fingerprint of the old unconditional design (it sits on the three
adapter symbols, *not* on `_mexFunction`, which every MEX defines).

R2023b's `mex` driver has **no** such post-compile inspection / conditional relink, so
a single R2023b mexopts cannot serve both classic and C++ API on the new linker.
`-ld_classic` (the old linker, where `-U` works) is how we keep R2023b's unconditional
`LINKEXPORTCPP` working for both — until the build MATLAB moves forward.

## When to drop `-ld_classic`

`-ld_classic` is deprecated — `ld` warns it "will be removed in a future release."
Drop it when either happens:

1. **The macOS build MATLAB moves to R2025b+.** Then the `mex` driver applies
   `cppMexFunction.map` conditionally, so remove `LINKEXPORTCPP` from the static
   mexopts entirely (match R2025b/R2026a stock) and `-ld_classic` is no longer needed.
2. **Apple removes `-ld_classic`** first. Forced off the old linker: bump the build
   MATLAB to R2025b+ (preferred), or, staying on R2023b, drop `LINKEXPORTCPP` from the
   mexopts and have any C++-MEX-API package add the adapter exports at its own `mex()`
   call — where the symbols are defined, so the export list resolves cleanly on the new
   linker, no `-ld_classic`.

The channel currently builds only classic `mexFunction` MEX, so option (2)'s fallback
(drop `LINKEXPORTCPP`) would cost nothing today; `-ld_classic` is kept only to match
stock's C++ API support in a single static XML.
