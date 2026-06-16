% Channel post-install test for Tensor Toolbox (MEX-enabled architectures).
% Exercises core tensor algebra plus the bundled L-BFGS-B MEX.

fprintf('=== Testing Tensor Toolbox ===\n');

assert(~isempty(which('tensor')), 'tensor class is not on the path');
assert(~isempty(which('cp_als')), 'cp_als is not on the path');
assert(~isempty(which('lbfgsb')), 'lbfgsb wrapper is not on the path');

% --- Core tensor algebra (pure MATLAB) ---
A = reshape(1:24, [2 3 4]);
T = tensor(A);
assert(abs(norm(T) - norm(A(:))) < 1e-10, 'tensor Frobenius norm mismatch');

v = (1:3)';
Tv = double(ttv(T, v, 2));                       % contract mode 2
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

% --- L-BFGS-B MEX: minimize a smooth convex function ---
f = @(x) sum((x - 3).^2);
g = @(x) 2 * (x - 3);
opts = struct('x0', zeros(4, 1), 'printEvery', 0);
[xb, fb] = lbfgsb({f, g}, -inf(4, 1), inf(4, 1), opts);
assert(fb < 1e-8 && max(abs(xb - 3)) < 1e-4, 'lbfgsb did not converge');
fprintf('  L-BFGS-B optimization OK\n');

% Confirm the MEX was loaded (channel all-MEX-exercised gate).
[~, loadedMex] = inmem;
assert(any(strcmp(loadedMex, 'lbfgsb_wrapper')), ...
    'lbfgsb_wrapper MEX was not exercised');

fprintf('=== Tensor Toolbox test passed ===\n');
