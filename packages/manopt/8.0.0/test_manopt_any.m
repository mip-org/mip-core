% Channel post-install test for Manopt (pure-MATLAB `any` build).
% No MEX is shipped here, so this exercises only the pure-MATLAB core.

fprintf('=== Testing Manopt (pure-MATLAB) ===\n');

assert(~isempty(which('spherefactory')), 'Manopt is not on the path');

% Maximize the Rayleigh quotient on the unit sphere with trust-regions.
n = 100;
A = randn(n); A = 0.5 * (A + A');
problem.M = spherefactory(n);
problem.cost  = @(x) -x' * (A * x);
problem.egrad = @(x) -2 * (A * x);
opts.verbosity = 0;
[x, xcost] = trustregions(problem, [], opts);
assert(abs(norm(x) - 1) < 1e-6, 'solution is not on the unit sphere');
assert(abs(-xcost - max(eig(A))) < 1e-4, ...
    'trust-regions did not recover the dominant eigenvalue');

fprintf('=== Manopt (pure-MATLAB) test passed ===\n');
