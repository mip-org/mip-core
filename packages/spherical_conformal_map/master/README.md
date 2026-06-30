# spherical_conformal_map

[Spherical Conformal Map](https://github.com/garyptchoi/spherical-conformal-map) conformally (angle-preservingly) maps a genus-0 closed triangle mesh onto the unit sphere, using the linear FLASH method. It is widely used for human brain mapping, texture mapping, surface registration, and cardiac mapping.

- **Author**: Gary Pui-Tung Choi
- **License**: Apache-2.0
- **Repository**: https://github.com/garyptchoi/spherical-conformal-map

## Install

```matlab
mip install spherical_conformal_map
mip load spherical_conformal_map
```

Usage:

```matlab
% v: nv x 3 vertex coordinates, f: nf x 3 triangulation of a genus-0 closed mesh
map = spherical_conformal_map(v, f);           % map onto the unit sphere

% optionally reduce area distortion while staying conformal (extension):
map = mobius_area_correction_spherical(v, f, map);
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. The core solver lives in `mfile/` and the Mobius area-correction extension in `extension/`; both are placed on the path.

## Tests

`test_spherical_conformal_map_channel.m` builds a genus-0 ellipsoid mesh (convex hull of points on a sphere), conformally maps it to the unit sphere, verifies every mapped vertex lands on the sphere, and checks the angle distortion is small. The test is display-free (it does not call the plotting/histogram helpers). The Mobius area-correction extension is shipped but not exercised in the test, as it requires the MATLAB Optimization Toolbox.
