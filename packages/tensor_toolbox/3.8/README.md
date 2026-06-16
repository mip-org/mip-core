# tensor_toolbox

The [Tensor Toolbox for MATLAB](https://www.tensortoolbox.org) provides classes and algorithms for dense, sparse, and decomposed N-way arrays (tensors), including CP, Tucker, and related decompositions.

- **Authors**: Brett W. Bader, Tamara G. Kolda, and the Tensor Toolbox contributors (Sandia National Labs & MathSci.ai)
- **License**: BSD-2-Clause
- **Version**: `3.8`
- **Repository**: https://gitlab.com/tensors/tensor_toolbox
- **Website**: https://www.tensortoolbox.org

## Install

```matlab
mip install --channel mip-org/dev tensor_toolbox
mip load tensor_toolbox
```

`mip load` puts the toolbox root on the path (the `@tensor`, `@sptensor`, `@ktensor`, `@ttensor`, … class folders resolve from there) plus the two bundled optimization libraries under `libraries/`. No further setup is needed:

```matlab
X = tensor(rand(10, 11, 12));
M = cp_als(X, 3);          % rank-3 CP decomposition
```

## Architecture matrix

| Architecture | MEX compiled? | Test script |
| --- | --- | --- |
| `linux_x86_64`   | yes | `test_tensor_toolbox_channel.m` |
| `macos_arm64`    | yes | `test_tensor_toolbox_channel.m` |
| `windows_x86_64` | yes | `test_tensor_toolbox_channel.m` |
| any other        | **no** (pure-MATLAB fallback) | `test_tensor_toolbox_any.m` |

The only compiled component is `lbfgsb_wrapper` — Stephen Becker's [L-BFGS-B-C](https://github.com/stephenbeckr/L-BFGS-B-C), bundled under `libraries/lbfgsb/`. It is self-contained (it ships its own `miniCBLAS`, so it needs no external BLAS) and is built from source by `compile.m`. It backs the L-BFGS-B option of the optimization-based methods (`tt_opt_lbfgsb`, and `cp_opt` / `gcp_opt` when run with the `lbfgsb` solver).

On the `[any]` fallback no MEX is shipped (the bundling pipeline strips the prebuilt `.mex*` files). The entire tensor algebra and most algorithms are pure MATLAB and work normally; only the L-BFGS-B solver option is unavailable (other optimizers such as `tt_opt_fminunc`, `tt_opt_fmincon`, and `tt_opt_adam` remain available).

## Tests

- `test_tensor_toolbox_channel.m` — checks core tensor algebra (Frobenius norm, tensor-times-vector, a CP-ALS recovery) and exercises the L-BFGS-B MEX on a smooth convex problem.
- `test_tensor_toolbox_any.m` — the core tensor-algebra checks only.
