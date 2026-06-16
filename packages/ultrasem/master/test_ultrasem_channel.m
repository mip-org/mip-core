% Channel post-install test for ultraSEM (pure MATLAB).
% Solves a PDE on the unit square and checks the solution against a reference
% value (from CHEBOP2, per the upstream test_square test).

fprintf('=== Testing ultraSEM ===\n');

assert(~isempty(which('ultraSEM')), 'ultraSEM is not on the path');
assert(~isempty(which('ultraSEMroot')), 'ultraSEMroot is not on the path');

% (u_xx + u_yy + u) = -1 on [-1,1]^2, homogeneous Dirichlet BCs.
D   = ultraSEM.rectangle([-1 1 -1 1]);
op  = {1, 0, 1};
rhs = -1;
n   = 21;

S   = ultraSEM(D, op, rhs, n);
sol = S \ 0;                       % zero boundary data
u0  = feval(sol, 0, 0);            % solution value at the centre

trueSol = 0.376530496242783;       % reference (CHEBOP2)
err = abs(u0 - trueSol);
assert(err < 1e-6, 'ultraSEM solution off by %g (u0 = %.15f)', err, u0);

fprintf('  PDE solve OK (u(0,0) = %.12f, err = %.2e)\n', u0, err);

fprintf('=== ultraSEM test passed ===\n');
