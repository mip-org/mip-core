# aabb-tree

[AABB-TREE](https://github.com/dengwirda/aabb-tree) provides d-dimensional axis-aligned bounding-box (AABB) tree construction and search for collections of spatial objects — useful for efficient spatial queries such as intersection tests between collections of objects.

- **Author**: Darren Engwirda
- **License**: Custom — free for private, research, and institutional use; commercial use by arrangement with the author (see `LICENSE.md`)
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/dengwirda/aabb-tree

## Install

```matlab
mip install aabb-tree
mip load aabb-tree
```

Usage:

```matlab
boxes = [xmin ymin xmax ymax];   % one row per object
tr = maketree(boxes);            % build the AABB-tree
[qi, qp, qj] = queryset(tr, ...) % spatial queries
```

This package is the spatial-query base used by several other dengwirda toolboxes in this channel (`findtria`, `findpoly`, `mesh2d`), which declare it as a dependency.

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code.

## Tests

`test_aabb_tree.m` builds an AABB-tree over a random collection of boxes and verifies the tree's defining properties: each object is contained in exactly one node, and every node encloses the objects it holds.
