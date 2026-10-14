# minboundsuite

[A suite of minimal bounding objects](https://www.mathworks.com/matlabcentral/fileexchange/34767-a-suite-of-minimal-bounding-objects)
computes the smallest enclosing circle, sphere, rectangle, parallelogram,
triangle, quadrilateral, and semicircle of a set of points, plus the largest
inscribed circle and sphere of a convex hull.

- **Author**: John D'Errico
- **License**: BSD-2-Clause
- **Version**: `1.2.0`
- **Website**: https://www.mathworks.com/matlabcentral/fileexchange/34767-a-suite-of-minimal-bounding-objects

## Install

```matlab
mip install minboundsuite
mip load minboundsuite
```

```matlab
[center, radius] = minboundcircle(randn(100,1), randn(100,1));
```

## Source

The suite is distributed on MATLAB File Exchange. This package fetches the
versioned 1.2.0 zip from the MathWorks add-on registry, which unpacks into a
top-level `MinBoundSuite/` folder (placed on the path) alongside the license.
`MinBoundSuite/` also holds a demo, `minbounddemo.m`, and the documentation
`MinBound.pdf`.

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code.

## Tests

`test_minboundsuite.m` checks `minboundcircle` on points sampled from a known
circle and `minboundrect` on a rotated rectangle, where the exact answers are
known.
