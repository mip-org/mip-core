# robotics_toolbox_matlab

[Robotics Toolbox for MATLAB](https://petercorke.com/toolboxes/robotics-toolbox/) (Peter Corke) provides tools for serial-link manipulator kinematics and dynamics, trajectory generation, and mobile robotics. It includes the `SerialLink` class, analytic and numeric inverse kinematics, recursive Newton-Euler dynamics, the manipulator Jacobian, and a large library of standard robot models (Puma 560, etc.).

- **Author**: Peter Corke
- **License**: LGPL-2.1
- **Version**: `10.4`
- **Repository**: https://github.com/petercorke/robotics-toolbox-matlab

## Install

```matlab
mip install robotics_toolbox_matlab
mip load robotics_toolbox_matlab
```

This pulls in the [spatialmath_matlab](../../spatialmath_matlab) dependency automatically.

Usage:

```matlab
mdl_puma560;            % creates the p560 SerialLink model and standard poses
T   = p560.fkine(qn);   % forward kinematics -> SE3 pose
q   = p560.ikine6s(T);  % analytic inverse kinematics
tau = p560.rne(qn, zeros(1,6), zeros(1,6));   % inverse dynamics (gravity load)
```

## Architecture

Pure MATLAB — a single `[any]` build. The toolbox ships an optional `frne` MEX
accelerator for recursive Newton-Euler dynamics, but it is **not** compiled here:
the `SerialLink` class automatically falls back to its M-file RNE implementation
when the MEX is absent (`p560.fast` is `false`), so all dynamics functions work
unchanged. The large HTML docs and the Simulink/hardware-interface/Octave
directories are excluded from the package.

## Tests

`test_robotics_toolbox_matlab_channel.m` builds the Puma 560 model and verifies
forward kinematics (valid SE(3) pose), the 6×6 Jacobian, inverse dynamics via the
M-file RNE (non-zero gravity load on the shoulder/elbow), and analytic inverse
kinematics (`ikine6s` recovers a reachable pose). The test is display-free.
