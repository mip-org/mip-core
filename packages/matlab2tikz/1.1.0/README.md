# matlab2tikz

[matlab2tikz](https://github.com/matlab2tikz/matlab2tikz) converts native MATLAB figures into TikZ/Pgfplots source that can be embedded directly in LaTeX documents, preserving 2D and most 3D plots without rasterisation.

- **Author**: Nico Schlömer and contributors
- **License**: BSD-2-Clause
- **Version**: 1.1.0
- **Repository**: https://github.com/matlab2tikz/matlab2tikz

## Install

```matlab
mip install --channel mip-org/dev matlab2tikz
mip load matlab2tikz
```

## What is shipped

The bundle contains the contents of the upstream `src/` folder, added to the MATLAB path. The main entry points are:

- `matlab2tikz` — convert the current (or a specified) figure to a `.tex` file
- `cleanfigure` — remove plot elements that do not survive the LaTeX conversion cleanly
- `figure2dot` — export a figure's object graph as a Graphviz `.dot` file

Helper functions under `src/private/` are discovered automatically by MATLAB and do not need an explicit `addpath`.

## What is not shipped

- The upstream `test/` tree (headless and graphical regression suites, output artefacts, hash tables) is not part of the bundle. See the upstream repository for the full test harness.
- The `src/dev/` directory (contributor-only whitespace tooling) is removed.
- Assets under `logos/` are also omitted.

Using `matlab2tikz` additionally requires a LaTeX installation with recent versions of TikZ/PGF, Pgfplots, and amsmath — see the [upstream README](https://github.com/matlab2tikz/matlab2tikz/blob/master/README.md) for details.

## Tests

`test_matlab2tikz.m` checks that `matlab2tikz`, `cleanfigure`, and `figure2dot` are on the path, and then runs an end-to-end conversion of a small invisible figure, asserting that the emitted `.tex` file contains the expected `tikzpicture` and `axis` environments.
