# cvx

[CVX](https://cvxr.com/cvx) is a MATLAB-based modeling system for disciplined convex programming (DCP). It turns MATLAB into a modeling language, letting constraints and objectives be specified using standard MATLAB syntax and then handing the problem to an underlying cone solver.

- **Authors**: CVX Research, Inc. (Michael Grant, Stephen Boyd)
- **License**: GPL-2.0 (the redistributable core)
- **Version**: `2.2.2`
- **Repository**: https://github.com/cvxr/CVX

## Install

```matlab
mip install cvx
mip load cvx
mip load sedumi
```

CVX requires a cone solver. This package depends on [`sedumi`](../../sedumi), which is installed automatically and supplies CVX's solver back-end. Both `cvx` and `sedumi` must be loaded.

After loading, run `cvx_setup` once to detect the solver and register CVX's preferences:

```matlab
cvx_setup
```

`cvx_setup` finds the mip-installed sedumi on the path, selects it as the default solver, and saves the choice to your MATLAB preferences. You can then build and solve models:

```matlab
cvx_begin
    variable x(2)
    minimize( sum(x) )
    subject to
        x >= 1
cvx_end
```

## Why the git source, not the release bundle

The upstream `cvx.zip` / `cvx.tgz` release archives bundle full copies of SeDuMi and SDPT3 plus pre-compiled MEX files. This package instead sources the [cvxr/CVX](https://github.com/cvxr/CVX) git tree (tag `2.2.2`), which contains the CVX core without bundled solvers or prebuilt binaries, and:

- builds CVX's two MEX helpers from source, and
- uses the channel's own [`sedumi`](../../sedumi) package as the solver (via mip's dependency mechanism) rather than a vendored copy.

This keeps the channel free of prebuilt binaries and avoids shipping a second, duplicate copy of sedumi.

## Architecture matrix

| Architecture | MEX compiled? | Solver |
| --- | --- | --- |
| `linux_x86_64`   | yes | sedumi (dependency) |
| `macos_arm64`    | yes | sedumi (dependency) |
| `windows_x86_64` | yes | sedumi (dependency) |

CVX's two MEX helpers (`cvx_eliminate_mex`, `cvx_bcompress_mex`) are pure C and build with a direct `mex` call on every supported architecture (see `compile.m`). They are produced into `lib/`, where `cvx_version()` expects them. There is no pure-MATLAB fallback build: CVX treats the MEX files as required and needs a compiled solver, so the package is only built for the three architectures that also have a `sedumi` build.

## Static linking

The two MEX helpers link only the MATLAB runtime plus the OS C/math libraries; any compiler runtime dependency is statically resolved by the channel's bundling step, so the `.mex*` files are portable across end-user systems.

## Tests

`test_cvx_channel.m` loads the sedumi dependency, runs `cvx_setup`, solves a small linear program and checks the optimum, and force-loads both MEX helpers so the channel's all-MEX-exercised gate confirms each binary loads on the target machine.
