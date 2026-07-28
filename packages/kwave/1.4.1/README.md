# kwave (k-Wave)

**k-Wave** is an open-source MATLAB toolbox for the time-domain simulation of
acoustic and ultrasound wave fields in 1D, 2D, and 3D (including axisymmetric
and elastic media), and for photoacoustic image reconstruction. The simulation
functions are based on a k-space pseudospectral method, which needs fewer grid
points per wavelength than finite-difference schemes. By Bradley Treeby, Ben
Cox, and contributors (University College London).

- Upstream: <https://github.com/ucl-bug/k-wave> — project site
  <http://www.k-wave.org>
- License: LGPL-3.0-or-later (`LICENSE.txt`, plus the full GPL/LGPL text under
  `license/`). k-Wave is copyleft: redistribution — including this bundle — is
  permitted provided the full source and license travel with it, which they do.
- Version: `1.4.1`, from the upstream release tag `v1.4.1`.

## Install

```matlab
mip install --channel mip-org/staging kwave
mip load kwave
```

## What is shipped

The k-Wave MATLAB toolbox (the repo's `k-Wave/` folder). `mip load kwave` puts
it on the path, which is exactly k-Wave's own install step ("add the `k-Wave`
folder to the MATLAB path"). All simulation and utility functions
(`kspaceFirstOrder1D/2D/3D`, `pstdElastic2D/3D`, `kWaveGrid`, `kWaveArray`,
`makeDisc`, `makeCartCircle`, `getWin`, …) are then callable, and the
`private/` helpers are discovered automatically.

The bundled `info.xml` and `helpfiles/` provide the in-browser documentation:
after loading, open **Supplemental Software → k-Wave Toolbox** in the MATLAB
help browser.

Optional directories are kept off the default path and can be added at load
time:

```matlab
mip load kwave --with examples   % the k-Wave example scripts
mip load kwave --with tests      % the regression/testing suite
```

## What is not shipped

- **The accelerated C++/CUDA solvers.** k-Wave offers optional
  `kspaceFirstOrder-OMP` / `-CUDA` binaries that run large simulations faster
  than the MATLAB code. These are **not part of the MATLAB toolbox** and are not
  in the upstream repo (`k-Wave/binaries/` ships empty). To use them, download
  the binaries for your platform from
  [k-wave.org/download.php](http://www.k-wave.org/download.php) and place them
  in the loaded package's `k-Wave/binaries/` folder (find it with
  `cd(getkWavePath)`), then call the `...C`/`...G` function variants. The
  pure-MATLAB solvers in this bundle work on their own without them.

## Tests

`test_kwave.m` runs in base MATLAB: it checks core utilities (`makeDisc`,
`getWin`, `db2neper`/`neper2db`) and then runs a tiny headless
`kspaceFirstOrder2D` initial-value problem end to end, asserting the recorded
sensor data has the expected shape and is finite.
