% Channel post-install test for Tensor Toolbox (pure-MATLAB `any` build).
% No MEX is shipped, so this exercises only the pure-MATLAB core. The L-BFGS-B
% optimizer (used by some cp_opt/gcp_opt methods) is unavailable on this build.

fprintf('=== Testing Tensor Toolbox (pure-MATLAB) ===\n');

assert(~isempty(which('tensor')), 'tensor class is not on the path');
assert(~isempty(which('cp_als')), 'cp_als is not on the path');

A = reshape(1:24, [2 3 4]);
T = tensor(A);
assert(abs(norm(T) - norm(A(:))) < 1e-10, 'tensor Frobenius norm mismatch');

v = (1:3)';
Tv = double(ttv(T, v, 2));
ref = squeeze(sum(A .* reshape(v, [1 3 1]), 2));
assert(max(abs(Tv(:) - ref(:))) < 1e-10, 'ttv (tensor-times-vector) mismatch');

rng(1);
R = 3; sz = [8 9 10];
M = ktensor(arrayfun(@(n) rand(n, R), sz, 'UniformOutput', false)');
X = full(M);
Mr = cp_als(X, R, 'printitn', 0, 'maxiters', 200);
fit = 1 - norm(full(Mr) - X) / norm(X);
assert(fit > 0.95, 'cp_als recovery fit too low: %g', fit);
fprintf('  Core tensor algebra OK (cp_als fit = %.4f)\n', fit);

fprintf('=== Tensor Toolbox (pure-MATLAB) test passed ===\n');
