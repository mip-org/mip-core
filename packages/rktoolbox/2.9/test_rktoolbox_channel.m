% Channel post-install test for the Rational Krylov Toolbox (pure MATLAB).
% Builds a rational Arnoldi decomposition and checks the defining relation.

fprintf('=== Testing RKToolbox ===\n');

assert(~isempty(which('rat_krylov')), 'rat_krylov is not on the path');
assert(~isempty(which('rkfun')), 'rkfun is not on the path');

% Rational Arnoldi: for A, starting vector b, and poles xi, rat_krylov returns
% an orthonormal V and (upper-Hessenberg) pencil (H, K) with  A*V*K = V*H.
N = 100;
A = gallery('tridiag', N);          % symmetric positive definite
b = ones(N, 1);
xi = [-1, 1i, -1i, 3, inf, 2];      % mix of finite and infinite poles

[V, K, H] = rat_krylov(A, b, xi);

relRes = norm(A * V * K - V * H) / norm(V * H);
assert(relRes < 1e-10, 'rational Arnoldi relation residual too large: %g', relRes);

orthErr = norm(V' * V - eye(size(V, 2)));
assert(orthErr < 1e-10, 'rational Krylov basis not orthonormal: %g', orthErr);

fprintf('  rat_krylov OK (relation residual %.1e, orthonormality %.1e)\n', ...
    relRes, orthErr);

fprintf('=== RKToolbox test passed ===\n');
