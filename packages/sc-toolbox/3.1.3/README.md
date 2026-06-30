# sc-toolbox

The [Schwarz-Christoffel Toolbox](https://tobydriscoll.net/project/sc-toolbox/) computes conformal maps between the unit disk (or half-plane, strip, rectangle, …) and polygonal regions of the complex plane, by Toby Driscoll. It provides classes for polygons and for the various Schwarz-Christoffel map types, along with tools to evaluate, invert, plot, and compose them.

- **Author**: Tobin A. Driscoll
- **License**: BSD-3-Clause
- **Version**: `3.1.3`
- **Repository**: https://github.com/tobydriscoll/sc-toolbox
- **User's guide**: https://tobydriscoll.net/project/sc-toolbox/

## Install

```matlab
mip install sc-toolbox
mip load sc-toolbox
```

`mip load` puts the toolbox on the path; the `@polygon`, `@diskmap`, `@scmap`, … class folders and the `+sctool` package resolve from there. No further setup is needed:

```matlab
p = polygon([-1-1i; 1-1i; 1+1i; -1+1i]);   % unit square
f = diskmap(p);                            % Schwarz-Christoffel map (disk -> square)
w = eval(f, 0.5i);                         % evaluate the map
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code.

## Tests

`test_sc_toolbox.m` builds a disk→square Schwarz-Christoffel map, checks that the conformal centre maps to the polygon centre, and confirms that mapped points lie inside the target polygon.
