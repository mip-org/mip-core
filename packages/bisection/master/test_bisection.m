% Channel post-install test for BISECTION (pure MATLAB).
% Finds scalar and vectorized roots and checks accuracy.

fprintf('=== Testing BISECTION ===\n');

assert(~isempty(which('bisection')), 'bisection is not on the path');

% Scalar root: x^2 - 2 = 0 on [0, 2] -> sqrt(2).
x = bisection(@(x) x.^2 - 2, 0, 2);
assert(abs(x - sqrt(2)) < 1e-6, 'scalar root inaccurate: %.8f', x);
fprintf('  scalar root OK (%.6f)\n', x);

% Vectorized: solve x^2 = [2 3 4] simultaneously (its key feature).
X = bisection(@(x) x.^2, [0 0 0], [3 3 3], [2 3 4]);
expected = sqrt([2 3 4]);
assert(max(abs(X - expected)) < 1e-6, 'vectorized roots inaccurate: %s', mat2str(X));
fprintf('  vectorized roots OK (%s)\n', mat2str(X, 5));

fprintf('=== BISECTION test passed ===\n');
