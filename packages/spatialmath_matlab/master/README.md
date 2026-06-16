# spatialmath_matlab

[Spatial Math Toolbox](https://github.com/petercorke/spatialmath-matlab) provides MATLAB functions and classes to represent 2D and 3D orientation and pose — rotation matrices, rigid-body transformations, quaternions, twists, and spatial 6-vectors — along with conversions, interpolation, and visualization. It underpins the Robotics Toolbox for MATLAB.

- **Author**: Peter Corke
- **License**: MIT
- **Repository**: https://github.com/petercorke/spatialmath-matlab

## Install

```matlab
mip install --channel mip-org/dev spatialmath_matlab
mip load spatialmath_matlab
```

Usage:

```matlab
R = rotx(0.2);                 % SO(3) rotation matrix
T = SE3(1,2,3) * SE3.Rx(0.5);  % rigid-body transform as an SE3 object
q = UnitQuaternion(R);         % unit quaternion from a rotation matrix
rpy = tr2rpy(R);               % roll-pitch-yaw angles
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. The toolbox is flat: all functions and classes live at the root, which is placed on the path.

## Tests

`test_spatialmath_matlab_channel.m` exercises the core math: it verifies `rotx`/`roty`/`rotz` produce valid SO(3) matrices, round-trips RPY angles and SO(3) matrix exp/log (`trexp`/`trlog`), and checks the `SE3` and `UnitQuaternion` classes (composition, inverse, quaternion↔matrix). The test is display-free (no plotting).
