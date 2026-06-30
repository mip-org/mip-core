# disk_conformal_map

[Disk Conformal Map](https://github.com/garyptchoi/disk-conformal-map) conformally (angle-preservingly) maps a simply-connected open triangle mesh (disk topology) onto the unit disk, using the fast method of Choi & Lui. It is used for texture mapping, surface registration, and mechanical engineering.

- **Author**: Gary Pui-Tung Choi
- **License**: Apache-2.0
- **Repository**: https://github.com/garyptchoi/disk-conformal-map

## Install

```matlab
mip install disk_conformal_map
mip load disk_conformal_map
```

Usage:

```matlab
% v: nv x 3 vertex coordinates, f: nf x 3 triangulation of a disk-topology mesh
map = disk_conformal_map(v, f);    % nv x 2 coordinates on the unit disk

% optionally reduce area distortion while staying conformal (extension):
map = mobius_area_correction_disk(v, f, map);
```

The input must be a simply-connected open mesh with no unreferenced/non-manifold vertices and no valence-1 boundary vertices.

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. The core solver lives in `mfile/` and the Mobius area-correction and remeshing extensions in `extension/`; both are placed on the path.

## Tests

`test_disk_conformal_map.m` builds a curved disk-topology mesh (a lifted polar grid), conformally maps it to the unit disk, verifies nothing leaves the disk and the boundary lands on the unit circle, and checks the angle distortion is small. The test is display-free. The Mobius area-correction extension is shipped but not exercised in the test, as it requires the MATLAB Optimization Toolbox.
