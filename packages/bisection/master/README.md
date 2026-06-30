# bisection

[BISECTION](https://www.mathworks.com/matlabcentral/fileexchange/28150) is a fast, robust, and simple-to-use root-finding method that operates on n-dimensional array inputs. Because it is fully vectorized it can solve many independent root-finding problems at once — much faster than calling `fzero` in a loop — and supports non-zero targets, tolerances, and bound-respecting evaluation.

- **Author**: Sky Sartorius
- **License**: BSD-3-Clause
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/sky-s/bisection

## Install

```matlab
mip install --channel mip-org/dev bisection
mip load bisection
```

Usage:

```matlab
x = bisection(@(x) x.^2 - 2, 0, 2);            % single root -> sqrt(2)
X = bisection(@(x) x.^2, [0 0 0], [3 3 3], [2 3 4]);  % solve x^2 = [2 3 4] at once
```

See the `+bisection` package (`bisection.example1`, `bisection.example2`) for worked examples.

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code.

## Tests

`test_bisection.m` finds a scalar root and a vector of independent roots, checking both against the analytic answers.
