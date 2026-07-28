# pivlab

[PIVlab](https://www.pivlab.de) is a particle image velocimetry (PIV) tool
for MATLAB with a full GUI: image preprocessing, FFT-based PIV analysis,
wavelet-based optical flow velocimetry (wOFV), vector validation,
postprocessing, and visualization. It is developed by William Thielicke and
is among the most widely cited PIV tools in research.

- **Author**: William Thielicke (with contributors)
- **License**: MIT
- **Version**: 3.12.001
- **Repository**: https://github.com/Shrediquette/PIVlab

## Install

```matlab
mip install --channel mip-org/staging pivlab
mip load pivlab
```

Start the GUI with `PIVlab_GUI`, or use the `piv.*`, `preproc.*`,
`postproc.*`, ... namespaces directly from scripts (see `example.m` and the
`Example_scripts` group below).

## MATLAB toolbox requirements

The channel ships PIVlab as-is; at runtime the PIV engine and the GUI need
the **Image Processing Toolbox** (`padarray`, `fspecial`, `regionprops`, ...).
The wOFV algorithm additionally needs the **Wavelet Toolbox** (`wfilters`)
and, for some options, the Parallel Computing Toolbox. The numerical helpers
(`misc.smoothn`, `misc.inpaint_nans`, minFunc) run on base MATLAB.

## What is shipped

The full PIVlab toolbox: `PIVlab_GUI.m`, the function namespaces
(`+piv`, `+preproc`, `+postproc`, `+plot`, `+import`, `+export`, `+mask`,
`+roi`, `+validate`, `+simulate`, `+wOFV`, ...), the GUI's `images/` and
`help/` folders, the hardware-acquisition MATLAB code, and the bundled
minFunc optimizer (`OptimizationSolvers/minFunc`, on the path so wOFV works
from any folder).

Optional path groups:

- `mip load pivlab --with examples` — `Example_scripts/` (command-line PIV
  workflows without the GUI).
- `mip load pivlab --with tests` — `unittests/` (upstream's
  `runtests`-based tests; these need the Image Processing Toolbox).

### MEX / architecture matrix

Five MEX files are compiled from source and shipped statically linked for
`linux_x86_64`, `macos_arm64`, and `windows_x86_64`:

- `+plot/fastLICFunction` — fast Line Integral Convolution rendering used by
  the LIC visualization.
- `mcholC`, `lbfgsC`, `lbfgsAddC`, `lbfgsProdC` — minFunc's L-BFGS helpers
  used by the wOFV optimizer.

On other architectures the `[any]` fallback installs the pure-MATLAB toolbox
without MEX; everything works except that the LIC tool will try to compile
`fastLICFunction.c` on the fly (upstream behavior, needs a local `mex`
setup), and minFunc must be run with `options.useMex = 0`.

## What is not shipped

- `Example_data/` (~10 MB of demo images; the GUI only used it as a default
  browse folder) and `docs/`/`resources/` (website source and MATLAB-project
  scaffolding, which upstream also excludes from its official toolbox).
- The proprietary vendor binaries for hardware image acquisition:
  `PIVlab_capture_resources/pco_resources/` (PCO camera SDK DLLs) and
  `tycmd.exe`. The acquisition MATLAB code itself is included, but
  controlling PCO/OPTOLUTION cameras, lasers, and synchronizers requires
  these vendor files from the [upstream repository](https://github.com/Shrediquette/PIVlab).
  At GUI startup MATLAB prints a harmless path warning for the removed
  `pco_resources` folder.

## Tests

- `test_pivlab_mex.m` (MEX builds) — layout checks, `misc.inpaint_nans` and
  `misc.smoothn` on synthetic data, every shipped MEX invoked
  (`fastLICFunction` on a rotation field; `lbfgsC`/`lbfgsProdC` checked
  against their pure-MATLAB counterparts; `mcholC` checked by reconstructing
  an SPD matrix; `lbfgsAddC` in-place update), and a minFunc end-to-end run
  on the Rosenbrock function.
- `test_pivlab.m` (`[any]` fallback) — the pure-MATLAB subset of the above.

The PIV engine itself is not exercised on CI because the runners' MATLAB has
no Image Processing Toolbox.
