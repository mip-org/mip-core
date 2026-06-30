% Channel post-install test for robotics-toolbox (pure MATLAB).
% Builds the Puma 560 model and exercises kinematics, dynamics (M-file RNE),
% the Jacobian, and inverse kinematics. Depends on spatialmath. Display-free.

fprintf('=== Testing robotics-toolbox ===\n');

assert(~isempty(which('SerialLink')),  'SerialLink class is not on the path');
assert(~isempty(which('mdl_puma560')), 'robot models are not on the path');
assert(~isempty(which('SE3')),         'spatialmath (SE3) dependency is not available');

% --- Build the classic Puma 560 6-axis manipulator (creates p560) ---
mdl_puma560;
assert(exist('p560', 'var') == 1, 'mdl_puma560 did not create p560');
assert(p560.n == 6, 'Puma 560 should have 6 joints');
assert(~p560.fast, 'expected M-file RNE (no frne MEX in this build)');
fprintf('  built Puma 560 (n=%d, RNE via M-file)\n', p560.n);

% --- Forward kinematics returns a valid SE(3) pose ---
T = p560.fkine(qz);                 % qz: zero-angle pose (set by mdl_puma560)
M = T.double();
assert(isequal(size(M), [4 4]), 'fkine did not return a 4x4 transform');
assert(norm(M(1:3,1:3) * M(1:3,1:3)' - eye(3)) < 1e-9, 'fkine rotation not orthonormal');
fprintf('  forward kinematics OK\n');

% --- Manipulator Jacobian is 6 x n ---
J = p560.jacob0(qr);                % qr: ready pose
assert(isequal(size(J), [6 6]), 'jacob0 did not return a 6x6 Jacobian');
fprintf('  Jacobian OK\n');

% --- Inverse dynamics (recursive Newton-Euler, M-file path) ---
tau = p560.rne(qn, zeros(1,6), zeros(1,6));   % gravity load at pose qn
assert(isequal(size(tau), [1 6]) && all(isfinite(tau)), 'rne returned bad torque');
% Gravity must load the shoulder/elbow joints (joints 2 and 3) for the Puma.
assert(max(abs(tau(2:3))) > 1, 'gravity torque unexpectedly small');
fprintf('  inverse dynamics (RNE) OK\n');

% --- Inverse kinematics recovers a reachable pose ---
Tgoal = p560.fkine(qn);
qsol = p560.ikine6s(Tgoal);                   % analytic IK for spherical wrist
Tcheck = p560.fkine(qsol);
assert(norm(Tcheck.double() - Tgoal.double()) < 1e-6, 'ikine6s did not recover the pose');
fprintf('  inverse kinematics OK\n');

fprintf('=== robotics-toolbox test passed ===\n');
