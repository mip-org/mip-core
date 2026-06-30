# nurbs

The [NURBS toolbox](https://octave.sourceforge.io/nurbs/) provides functions for the construction and manipulation of Non-Uniform Rational B-Splines (NURBS) — curves, surfaces, and volumes — including evaluation, knot insertion, degree elevation, and differentiation.

- **Authors**: Mark Spink, Daniel Claxton, Carlo de Falco, Rafael Vázquez
- **License**: GPL-3.0
- **Version**: `1.4.4`
- **Homepage**: https://octave.sourceforge.io/nurbs/

## Install

```matlab
mip install --channel mip-org/dev nurbs
mip load nurbs
```

Usage:

```matlab
crv = nrbcirc(1);                 % NURBS unit circle
p   = nrbeval(crv, linspace(0,1,100));
srf = nrb4surf([0 0],[1 0],[0 1],[1 1]);
```

This toolbox is also the spatial-geometry dependency of the [`geopdes`](../../geopdes) isogeometric-analysis package in this channel.

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. (The upstream `src/` `.cc` files are Octave-only `.oct` accelerators; the toolbox ships a pure-MATLAB `.m` implementation of each, which is what MATLAB uses.)

## Tests

`test_nurbs.m` builds a NURBS unit circle and a bilinear surface patch and checks that evaluated points are geometrically correct.
