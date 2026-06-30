# find_poly

[FINDPOLY](https://github.com/dengwirda/find-poly) performs fast point-in-polygon queries for collections of polygons — returning, for each query point, the set of polygons that enclose it. It supports general (non-convex, multiply-connected, overlapping) polygon collections.

- **Author**: Darren Engwirda
- **License**: Custom — free for private, research, and institutional use; commercial use by arrangement with the author (see `LICENSE.md`)
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/dengwirda/find-poly

## Install

```matlab
mip install find_poly
mip load find_poly
mip load aabb_tree
mip load inpoly
```

`find_poly` depends on [`aabb_tree`](../../aabb_tree) (spatial-query backend) and [`inpoly`](../../inpoly) (point-in-polygon kernel); both are installed automatically and must be loaded alongside `find_poly`.

```matlab
PP = { [0 0;1 0;1 1;0 1] };       % cell array of polygon vertices
EE = { [1 2;2 3;3 4;4 1] };       % cell array of polygon edges
[ip, ix] = findpoly(PP, EE, pj);  % locate query points pj
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. The upstream repository vendors trimmed copies of AABB-TREE and INPOLY; this package drops them and uses the channel's [`aabb_tree`](../../aabb_tree) and [`inpoly`](../../inpoly) packages instead (declared as dependencies).

## Tests

`test_find_poly_channel.m` locates query points within a collection of disjoint polygons and checks that interior points map to the correct polygon and exterior points are reported as unenclosed.
