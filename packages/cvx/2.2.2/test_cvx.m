% Channel post-install test for CVX.
% Runs after the package and its sedumi dependency have been installed.

fprintf('=== Testing CVX ===\n');

% CVX needs a solver. Bring the sedumi dependency onto the path.
mip load sedumi
assert(~isempty(which('sedumi')), 'sedumi dependency is not on the path');

cvxRoot = fileparts(which('cvx_setup'));
assert(~isempty(cvxRoot), 'cvx_setup not found on the path');

% Configure CVX: this verifies the freshly built MEX files, detects the
% sedumi solver, and runs CVX's own self-test model.
origDir = pwd;
cd(cvxRoot);
cvx_setup
cd(origDir);

% Solve a tiny LP and check the optimum (min sum(x) s.t. x >= 1 -> 2).
cvx_begin quiet
    variable x(2)
    minimize( sum(x) )
    subject to
        x >= 1;
cvx_end
assert(strcmp(cvx_status, 'Solved'), ...
    'CVX did not solve the test LP (status: %s)', cvx_status);
assert(abs(cvx_optval - 2) < 1e-6, 'Unexpected optimum: %g', cvx_optval);
fprintf('  LP solved: cvx_optval = %g\n', cvx_optval);

% Solving routes through CVX's presolver (@cvxprob/eliminate.m), which
% exercises both shipped MEX helpers. Confirm they were loaded so the
% channel's all-MEX-exercised gate is satisfied.
[~, loadedMex] = inmem;
for nm = {'cvx_eliminate_mex', 'cvx_bcompress_mex'}
    assert(any(strcmp(loadedMex, nm{1})), ...
        'MEX %s was not exercised by the test', nm{1});
end

fprintf('=== CVX test passed ===\n');
