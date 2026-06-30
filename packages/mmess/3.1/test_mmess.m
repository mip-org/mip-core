% Channel post-install test for M-M.E.S.S. (pure MATLAB).
% Solves a Lyapunov equation with the high-level solver and checks the residual.

fprintf('=== Testing M-M.E.S.S. ===\n');

assert(~isempty(which('mess_lyap')), 'mess_lyap is not on the path');
assert(~isempty(which('mess_path')), 'mess_path is not on the path');

% Continuous-time Lyapunov equation  A X + X A^T + B B^T = 0, with A symmetric
% negative definite (hence stable). mess_lyap returns a low-rank factor Z with
% X = Z*Z'.
n = 60;
A = -gallery('tridiag', n);
B = randn(n, 2);

Z = mess_lyap(A, B);
X = Z * Z';
res = norm(A * X + X * A' + B * B', 'fro') / norm(B * B', 'fro');
assert(res < 1e-8, 'Lyapunov residual too large: %g', res);
fprintf('  mess_lyap solved Lyapunov equation (rel residual = %.2e)\n', res);

fprintf('=== M-M.E.S.S. test passed ===\n');
