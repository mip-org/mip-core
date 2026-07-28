# wec-sim

[WEC-Sim](https://wec-sim.github.io/WEC-Sim/) (Wave Energy Converter SIMulator) is an open-source code for simulating wave energy converters, developed by NREL and Sandia National Laboratories.

- **Authors**: National Renewable Energy Laboratory and Sandia National Laboratories
- **License**: Apache-2.0
- **Version**: 7.1.0
- **Repository**: https://github.com/WEC-Sim/WEC-Sim

## Install

```matlab
mip install --channel mip-org/staging wec-sim
mip load wec-sim
```

## Requirements

Loading the package and using the pure-MATLAB layer (classes, BEMIO, etc.)
requires only MATLAB. **Running simulations requires Simulink, Simscape, and
Simscape Multibody**, which mip cannot install.

`mip load wec-sim` puts `source/` and all its subdirectories on the path,
mirroring upstream's `addWecSimSource.m`. That script additionally runs
`set_param(0, 'ErrorIfLoadNewModel', 'off')` to allow opening models saved by
newer Simulink versions; run that yourself if you need it.

## What is shipped

The `source/` tree: WEC-Sim classes (`simulationClass`, `waveClass`,
`bodyClass`, ...), the `wecSim` entry point, BEMIO, and the Simulink block
libraries (`WECSim_Lib*.slx`, MOST).

## What is not shipped

To keep the bundle small (the upstream checkout is ~650 MB; the code is
~8 MB), these upstream directories are removed:

- `examples/` — the RM3 and OSWEC example cases (~350 MB)
- `tutorials/` and `docs/`
- `tests/`

Get them from the [upstream repository](https://github.com/WEC-Sim/WEC-Sim)
or the [WEC-Sim_Applications](https://github.com/WEC-Sim/WEC-Sim_Applications)
repo.

## Tests

`test_wec_sim.m` is a smoke test of the pure-MATLAB surface: path setup
(including the `.slx` library directories) and instantiation of
`simulationClass` and `waveClass`. It does not run a simulation, so it needs
no Simulink.
