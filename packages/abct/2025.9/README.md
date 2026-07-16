# abct

**abct** is a MATLAB (and Python) toolbox for unsupervised learning, network
science, and imaging/network neuroscience, by Mika Rubinov. It provides three
variants of global residualization; the Loyvain and co-Loyvain methods (for
_k_-means, _k_-modularity, or spectral clustering of data or network inputs);
binary and weighted canonical and co-neighbor components; m-UMAP embeddings;
degree centralities (first, second, and residual); dispersion centralities
(squared coefficient of variation, _k_-participation coefficient); and network
shrinkage.

- Upstream: <https://github.com/mikarubi/abct> — project page
  <https://abct.rubinovlab.net>
- Reference: Rubinov M. *Unifying equivalences across unsupervised learning,
  network science, and imaging/network neuroscience.* arXiv, 2025,
  [doi:10.48550/arXiv.2508.10045](https://doi.org/10.48550/arXiv.2508.10045).
- License: MIT. Author: Mika Rubinov (Vanderbilt University).
- Version: `2025.9`, pinned to the upstream release tag of the same name.

## Install

```matlab
mip install --channel mip-org/labs abct
mip load abct
```

## What is shipped

The MATLAB toolbox only — the folder `abct-matlab/abct/` from the upstream
repo. `mip load abct` puts its root on the path, which makes the public
functions available directly:

`degree`, `dispersion`, `residualn`, `shrinkage`, `louvains`, `loyvain`,
`coloyvain`, `canoncov`, `kneighbor`, `kneicomp`, `mumap`

(the `+muma` and `+loyv` namespaces beneath the root are discovered by MATLAB
automatically). Requires MATLAB R2024a or later.

## What is not shipped

- The Python toolbox (`abct-python/`) and the documentation/example trees — the
  interactive Colab notebooks and Human Connectome Project example data — are
  not part of this package. See the upstream repo for those.
- A few functions have optional code paths that need MathWorks add-on toolboxes
  or an external library, and only on specific arguments:
  - `kneighbor` with `method="indirect"` — Statistics and Machine Learning
    Toolbox.
  - `mumap` with `solver="trustregions"` — [Manopt](https://www.manopt.org/);
    with `solver="adam"` — Deep Learning Toolbox; with `gpu=true` — Parallel
    Computing Toolbox.

  The default paths through these functions, and everything else in the
  toolbox, are pure MATLAB.

## Tests

`test_abct.m` exercises the toolbox-free core — `degree`, `dispersion`,
`residualn`, `shrinkage`, and `louvains` (recovering two communities from a
two-clique network) — using only base MATLAB, so it runs on the channel's
base-only CI.
