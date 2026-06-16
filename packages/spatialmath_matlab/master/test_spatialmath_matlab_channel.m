% Channel post-install test for spatialmath-matlab (pure MATLAB).
% Exercises rotation/transform functions and the SE3/SO3/UnitQuaternion classes.
% Display-free (no plotting).

fprintf('=== Testing spatialmath-matlab ===\n');

assert(~isempty(which('rotx')), 'rotx is not on the path');
assert(~isempty(which('SE3')),  'SE3 class is not on the path');
assert(~isempty(which('UnitQuaternion')), 'UnitQuaternion class is not on the path');

tol = 1e-10;

% --- Rotation matrices: orthonormal, det 1 ---
R = rotx(0.3) * roty(-0.4) * rotz(1.1);
assert(norm(R*R' - eye(3)) < tol, 'rotation matrix is not orthonormal');
assert(abs(det(R) - 1) < tol, 'rotation matrix det ~= 1');
fprintf('  rotx/roty/rotz produce a valid SO(3) matrix\n');

% --- RPY round-trip ---
rpy = [0.1, -0.2, 0.3];
assert(norm(tr2rpy(rpy2r(rpy)) - rpy) < tol, 'rpy2r/tr2rpy round-trip failed');
fprintf('  rpy2r/tr2rpy round-trip OK\n');

% --- trexp/trlog (matrix exp/log on SO(3)) ---
w = [0.2, -0.5, 0.7];
assert(norm(vex(trlog(trexp(skew(w)))) - w(:)) < 1e-8, 'trexp/trlog round-trip failed');
fprintf('  trexp/trlog round-trip OK\n');

% --- SE3 class: composition and inverse ---
T = SE3(1, 2, 3) * SE3.Rx(0.5) * SE3.Rz(-0.4);
M = T.double();
assert(isequal(size(M), [4 4]), 'SE3.double() is not 4x4');
assert(norm(M(4,:) - [0 0 0 1]) < tol, 'SE3 bottom row is not [0 0 0 1]');
Tinv = T * T.inv();
assert(norm(Tinv.double() - eye(4)) < tol, 'SE3 inverse failed');
assert(norm(T.t(:) - M(1:3,4)) < tol, 'SE3 translation accessor mismatch');
fprintf('  SE3 composition/inverse OK\n');

% --- UnitQuaternion <-> rotation matrix ---
q = UnitQuaternion(R);
assert(norm(q.R - R) < 1e-9, 'UnitQuaternion -> R round-trip failed');
assert(abs(norm(q.double()) - 1) < tol, 'UnitQuaternion is not unit norm');
fprintf('  UnitQuaternion <-> R round-trip OK\n');

fprintf('=== spatialmath-matlab test passed ===\n');
