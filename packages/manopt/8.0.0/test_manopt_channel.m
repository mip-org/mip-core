% Channel post-install test for Manopt (MEX-enabled architectures).

fprintf('=== Testing Manopt ===\n');

assert(~isempty(which('spherefactory')), 'Manopt is not on the path');

% Core: maximize the Rayleigh quotient on the unit sphere with trust-regions.
% The optimum equals the largest eigenvalue of A; the minimizer is the
% corresponding (unit-norm) eigenvector.
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
fprintf('  Sphere optimization OK\n');

% Exercise the two MEX helpers through their wrappers, with correctness checks.
M = sparse([1 0 2; 0 3 0; 4 0 5]);
L = randn(3, 2);
R = randn(3, 2);
xEntries = sparseentries(M, L, R);            % -> spmaskmult
[I, J] = find(M);
LR = L * R.';
expected = LR(sub2ind(size(M), I, J));
assert(max(abs(xEntries(:) - expected(:))) < 1e-10, 'spmaskmult result mismatch');

vals = (1:nnz(M))';
Lreplaced = replacesparseentries(M, vals);    % -> setsparseentries
assert(isequal(nonzeros(Lreplaced), vals), 'setsparseentries result mismatch');
fprintf('  MEX helpers (spmaskmult, setsparseentries) OK\n');

% Confirm both MEX were loaded (channel all-MEX-exercised gate).
[~, loadedMex] = inmem;
for nm = {'spmaskmult', 'setsparseentries'}
    assert(any(strcmp(loadedMex, nm{1})), 'MEX %s was not exercised', nm{1});
end

fprintf('=== Manopt test passed ===\n');
