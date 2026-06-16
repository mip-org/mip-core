% Channel post-install test for hm-toolbox (pure MATLAB).
% Builds HODLR and HSS representations of a rank-structured matrix and checks
% that matrix-vector products and linear solves match the dense reference.

fprintf('=== Testing hm-toolbox ===\n');

assert(~isempty(which('hodlr')), 'hodlr is not on the path');
assert(~isempty(which('hss')), 'hss is not on the path');

% A smooth-kernel matrix (HODLR/HSS-compressible) plus a diagonal shift so it
% is also well-conditioned (the kernel alone is numerically singular).
n = 256;
x = linspace(0, 1, n)';
K = 1 ./ (1 + 100 * (x - x').^2);
A = K + n * eye(n);
v = randn(n, 1);
b = A * v;

H = hodlr(A);
assert(isa(H, 'hodlr'), 'hodlr did not return an hodlr object');
assert(norm(H * v - A * v) / norm(A * v) < 1e-8, 'HODLR matvec inaccurate');
assert(norm(H \ b - v) / norm(v) < 1e-8, 'HODLR solve inaccurate');
fprintf('  HODLR matvec + solve OK\n');

S = hss(A);
assert(isa(S, 'hss'), 'hss did not return an hss object');
assert(norm(S * v - A * v) / norm(A * v) < 1e-8, 'HSS matvec inaccurate');
assert(norm(S \ b - v) / norm(v) < 1e-8, 'HSS solve inaccurate');
fprintf('  HSS matvec + solve OK\n');

fprintf('=== hm-toolbox test passed ===\n');
