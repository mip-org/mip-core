# find_tria

[FINDTRIA](https://github.com/dengwirda/find-tria) performs fast spatial queries for collections of d-simplexes — locating the simplexes (triangles, tetrahedra, …) that intersect a set of query points. It supports non-conforming, non-convex, and overlapping collections, and is a fast, general alternative to MATLAB's built-in point-location routines.

- **Author**: Darren Engwirda
- **License**: Custom — free for private, research, and institutional use; commercial use by arrangement with the author (see `LICENSE.md`)
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/dengwirda/find-tria

## Install

```matlab
mip install find_tria
mip load find_tria
mip load aabb_tree
```

`find_tria` depends on [`aabb_tree`](../../aabb_tree) for the underlying spatial-query backend; it is installed automatically and must be loaded alongside `find_tria`.

```matlab
[tp, tj] = findtria(pp, tt, pj);   % locate query points pj in triangulation (pp, tt)
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. The upstream repository vendors a trimmed copy of AABB-TREE; this package drops it and uses the channel's [`aabb_tree`](../../aabb_tree) package instead (declared as a dependency).

## Tests

`test_find_tria_channel.m` locates query points within a small triangulation and checks that interior points map to the correct triangle and exterior points are reported as unenclosed.
