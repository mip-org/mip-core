% Channel post-install test for Spot (pure-MATLAB `any` build).
% No MEX is shipped here, so this exercises only the pure-MATLAB operator
% algebra; the wavelet operators (which need the RWT MEX) are not tested.

fprintf('=== Testing Spot (pure-MATLAB) ===\n');

assert(~isempty(which('opMatrix')), 'Spot (opMatrix) is not on the path');
assert(~isempty(which('opDFT')), 'Spot (opDFT) is not on the path');

rng(0);
A = randn(8);
M = opMatrix(A);
x = randn(8, 1);
assert(norm(M * x - A * x) < 1e-12, 'opMatrix forward mismatch');
assert(norm(M' * x - A' * x) < 1e-12, 'opMatrix adjoint mismatch');

% Composition and the abstract-operator algebra.
B = randn(8);
P = opMatrix(B) * M;            % represents B*A
assert(norm(P * x - B * (A * x)) < 1e-10, 'operator composition mismatch');

F = opDFT(16);
z = randn(16, 1);
assert(norm(F' * (F * z) - z) < 1e-10, 'opDFT is not unitary (round-trip failed)');

fprintf('  core operator algebra OK\n');

fprintf('=== Spot (pure-MATLAB) test passed ===\n');
