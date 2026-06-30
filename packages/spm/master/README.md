# spm

[SPM](https://www.fil.ion.ucl.ac.uk/spm/) (Statistical Parametric Mapping) is a MATLAB toolbox for the analysis of brain imaging data sequences — fMRI, PET, SPECT, EEG and MEG — developed at the Wellcome Centre for Human Neuroimaging, UCL Queen Square Institute of Neurology.

- **Authors**: Karl Friston, John Ashburner, and the SPM development team
- **License**: GPL-2.0
- **Version**: `master` (upstream `main` branch — no tagged releases on GitHub)
- **Repository**: https://github.com/spm/spm

## Install

```matlab
mip install spm
mip load spm
```

After loading, initialize SPM and let it add its sub-directories (toolboxes, `matlabbatch`, `config`, `external/fieldtrip`, `external/bemcp`, …) to the MATLAB path:

```matlab
spm('fmri')    % or 'eeg', 'pet', etc.
```

`mip load` only places the SPM root on the path — SPM manages its own internal sub-paths through `spm()`, matching the standard upstream install flow.

## What is shipped

The full upstream SPM source tree is bundled, including all data files (`tpm/`, `canonical/`, `rend/`, `EEGtemplates/`, `spm_dicom_dict.mat`, …), the `matlabbatch` job manager, the `config/` batch definitions, every `toolbox/*` directory, and the bundled externals under `external/fieldtrip` and `external/bemcp`. Only the upstream `tests/` directory (integration and regression tests aimed at SPM developers) is dropped at package-prepare time to reduce bundle size.

## Architecture matrix

| Architecture | MEX compiled? | Test script |
| --- | --- | --- |
| `linux_x86_64`   | yes | `test_spm_mex.m` |
| `macos_arm64`    | yes | `test_spm_mex.m` |
| `windows_x86_64` | yes | `test_spm_mex.m` |
| any other        | **no** (pure-MATLAB fallback) | `test_spm.m` |

On the three compiled architectures, every MEX file in the upstream source tree is rebuilt from source. That covers the ~30 MEX files at the SPM root, the sub-directory MEX files under `@file_array/private/`, `@gifti/private/`, `@xmltree/private/`, and `toolbox/FieldMap/`, plus the external `fieldtrip` and `bemcp` MEX layers. On Linux/macOS this is driven through SPM's own `src/Makefile` system (`compile.m`); on Windows, where the Makefile's Unix-shell assumptions don't hold, `compile_windows.m` reproduces the identical compilations as direct `mex` calls (including the `spm_vol_utils` static archive and the fieldtrip `external-install` layout).

On architectures that fall through to the `[any]` build, **no MEX binaries are shipped** — the mip bundling pipeline strips pre-existing `.mex*` files from the source tree before building. The pure-MATLAB layer of SPM still loads and runs, but any function that requires a compiled MEX (e.g. `spm_bsplinc`, `spm_diffeo`, `spm_field`, most of `spm_mesh_*`) will error when called.

## Static linking

On Linux, `compile.m` patches `src/Makefile.var` to append `-static-libstdc++ -static-libgcc` to `MEXOPTS` so the two C++ MEX files (`spm_mesh_dist`, `spm_mesh_geodesic`) do not depend on a specific end-user libstdc++ ABI. The remaining SPM MEX files are pure C and only link the OS-provided `libc` / `libm` plus MATLAB's own `libmx` / `libmex`.

macOS `libc++` is OS-provided; Apple Clang does not accept `-static-libstdc++`, so no patch is needed there.

On Windows, the MinGW-w64 toolchain is selected via MATLAB's `mingw64.xml`, which links the runtime statically, so the `.mexw64` files carry no MinGW runtime DLL dependency. The static `spm_vol_utils` archive is built with MinGW `ar`, matching the upstream MINGW64 build.

## Tests

Two post-install test scripts are shipped:

- `test_spm_mex.m` — run on MEX-enabled architectures. Checks the pure-MATLAB layer plus three MEX entry points for correct behaviour — `spm_bsplinc` (MEX-only, no MATLAB fallback — catches a missing/broken build loudly), `spm_cat`, and `spm_jsonread` — and then force-loads every shipped MEX (a dynamic sweep that invokes each binary once from its own directory) so the channel's all-MEX-exercised gate confirms every binary loads on the target machine.
- `test_spm.m` — run on the `[any]` fallback. Exercises only the pure-MATLAB layer (`spm_file`, `spm_str_manip`, `spm_platform`) so the build doesn't error on architectures without MEX.

## Upstream compilation reference

The `compile.m` script mirrors the upstream build recipe documented at
<https://www.fil.ion.ucl.ac.uk/spm/docs/development/compilation/>:

```bash
cd src
make distclean
make && make install
make external-distclean
make external && make external-install
```

with additions for (a) pointing `MEXBIN` at `$(matlabroot)/bin/mex` since `mex` is not on the CI runner's `PATH` by default, (b) `PLATFORM=arm64` on Apple Silicon, and (c) the Linux static-libstdc++ patch described above.
