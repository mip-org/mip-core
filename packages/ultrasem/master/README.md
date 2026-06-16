# ultrasem

[ultraSEM](https://github.com/danfortunato/ultraSEM) is a MATLAB implementation of an ultraspherical spectral element method for solving partial differential equations on unstructured polygonal (and curved) domains. It combines high-order ultraspherical spectral discretizations on each element with a hierarchical Poincaré–Steklov (HPS) merge to assemble and solve the global system.

- **Authors**: Dan Fortunato, Nick Hale, Alex Townsend
- **License**: MIT
- **Version**: `master` (no upstream release tags)
- **Repository**: https://github.com/danfortunato/ultraSEM

## Install

```matlab
mip install --channel mip-org/dev ultrasem
mip load ultrasem
```

`mip load` adds the toolbox to the path (the `@ultraSEM` class and the `+ultraSEM` / `+util` packages resolve from there) — equivalent to the upstream `addpath(ultraSEMroot)`.

```matlab
D = ultraSEM.rectangle([-1 1 -1 1]);   % a domain
S = ultraSEM(D, {1,0,1}, -1, 21);      % (u_xx + u_yy + u) = -1, degree 21
u = S \ 0;                             % solve with zero Dirichlet data
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. The toolbox is self-contained (the spectral helpers it needs, e.g. `chebpts2`/`clenshaw`, are bundled in `+util`), so it does not require Chebfun.

## Tests

`test_ultrasem_channel.m` solves a Helmholtz-type PDE on the unit square and checks the centre value against a reference solution (from CHEBOP2).
