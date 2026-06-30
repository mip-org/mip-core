# spot

[Spot](https://www.cs.ubc.ca/labs/scl/spot/) is a linear-operator toolbox for MATLAB that enables matrix-free linear algebra. It lets you build, combine, and manipulate abstract linear operators (DFT, wavelets, convolutions, random ensembles, restrictions, …) that behave like matrices — supporting `*`, `'`, `\`, concatenation, and composition — without forming them explicitly.

- **Authors**: Ewout van den Berg and Michael P. Friedlander
- **License**: GPL-3.0
- **Version**: `1.2`
- **Repository**: https://github.com/mpf/spot

## Install

```matlab
mip install spot
mip load spot
```

`mip load` adds the toolbox to the path (the `op*` operator classes, the `@opSpot` base class, and the `+spot` package resolve from there) — equivalent to the upstream `addpath`.

```matlab
F = opDFT(128);            % a matrix-free DFT operator
W = opWavelet(128, 'Daubechies');
A = F * W';                % compose operators
y = A * x;                 % apply without forming a matrix
```

## Architecture matrix

| Architecture | MEX compiled? | Test script |
| --- | --- | --- |
| `linux_x86_64`   | yes | `test_spot.m` |
| `macos_arm64`    | yes | `test_spot.m` |
| `windows_x86_64` | yes | `test_spot.m` |
| any other        | **no** (pure-MATLAB fallback) | `test_spot_any.m` |

The only compiled component is the bundled Rice Wavelet Toolbox under `+spot/+rwt/` — four C MEX (`mdwt`/`midwt`/`mrdwt`/`mirdwt`) that back the wavelet operators (`opWavelet`, `opWavelet2`, `opHaar`). They are built from source by `compile.m`. On the `[any]` fallback no MEX is shipped; the entire operator framework is pure MATLAB and works normally, but the wavelet operators are unavailable.

## Tests

- `test_spot.m` — checks the core operator algebra (`opMatrix`, `opDFT`) and the wavelet operators (orthogonal reconstruction and a redundant transform), exercising all four RWT MEX.
- `test_spot_any.m` — the core operator-algebra checks only.
