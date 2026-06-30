# gramm

[gramm](https://github.com/piermorel/gramm) is a data-visualization toolbox for MATLAB that implements a "grammar of graphics" (inspired by R's ggplot2). It makes it easy to produce publication-quality, grouped, and faceted plots — scatter, line, bar, histogram, density, and statistical layers — from a concise, declarative description.

- **Author**: Pierre Morel
- **License**: MIT
- **Version**: `3.1.2`
- **Repository**: https://github.com/piermorel/gramm

## Install

```matlab
mip install --channel mip-org/dev gramm
mip load gramm
```

`mip load` puts the `@gramm` class on the path (equivalent to adding the upstream `gramm/` folder).

```matlab
g = gramm('x', x, 'y', y, 'color', grp);
g.geom_point();
g.stat_glm();        % statistical layers, faceting, etc.
g.draw();
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. Only the toolbox `gramm/` directory (the `@gramm` class and its docs) is packaged; the repository's large `sample_data/`, `images/`, and `paper/` directories are not included.

> Some statistical layers (e.g. `stat_glm`) use functions from MATLAB's Statistics and Machine Learning Toolbox; the core plotting layers do not require it.

## Tests

`test_gramm.m` builds a grouped scatter+line gramm figure and draws it (with figures kept invisible), checking that the object renders axes and draw results.
