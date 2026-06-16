% Channel test for SeDuMi.
% Solves a tiny LP with a known optimum, then a sparse LP with dense columns,
% an SOCP, and an SDP, so that every shipped MEX gets exercised.

fprintf('Testing that sedumi is on the path...\n');
assert(exist('sedumi', 'file') == 2, 'sedumi.m not found on path');

pars = struct('fid', 0);

%% Minimize 2*x1 + 3*x2 subject to x1 + x2 = 1, x >= 0.
% Optimum: x = [1; 0], c'x = 2.
fprintf('Solving small LP...\n');
A = sparse([1, 1]);
b = 1;
c = [2; 3];
K = struct('l', 2);
[x, y, info] = sedumi(A, b, c, K, pars);

assert(info.pinf == 0 && info.dinf == 0, ...
    sprintf('sedumi reported infeasibility (pinf=%d, dinf=%d)', ...
        info.pinf, info.dinf));
assert(info.numerr ~= 2, ...
    'sedumi reported complete numerical failure (numerr == 2)');

cx = c' * x;
by = b' * y;
assert(abs(cx - 2) < 1e-6, ...
    sprintf('primal cost c''x = %g, expected 2', cx));
assert(abs(by - 2) < 1e-6, ...
    sprintf('dual cost b''y = %g, expected 2', by));
assert(abs(x(1) - 1) < 1e-4 && abs(x(2)) < 1e-4, ...
    sprintf('x = [%g; %g], expected [1; 0]', x(1), x(2)));

%% Sparse LP with dense columns (constructed primal/dual feasible).
% The two dense columns (60 nnz) exceed getdense's denf*spquant = 10*5 = 50
% threshold, so SeDuMi's dense-column machinery (dpr1fact & co.) kicks in.
% The identity block guarantees full row rank.
fprintf('Solving sparse LP with dense columns...\n');
rng(0);
m = 60; n = 150;
A = [randn(m, 2), speye(m), sprandn(m, n - m - 2, 0.03)];
x0 = rand(n, 1) + 0.1;
b = A * x0;
y0 = randn(m, 1);
s0 = rand(n, 1) + 0.1;
c = A' * y0 + s0;
K = struct('l', n);
[x, y, info] = sedumi(A, b, c, K, pars);
check_solution(A, b, c, x, y, info, 'sparse LP');

%% SOCP: linear vars + two Lorentz cones.
fprintf('Solving SOCP...\n');
rng(1);
nl = 10; q = [5, 7];
n = nl + sum(q);
m = 12;
A = [speye(m), sprandn(m, n - m, 0.3)];
x0 = [rand(nl, 1) + 0.1; lorentz_point(q)];
b = A * x0;
y0 = randn(m, 1);
s0 = [rand(nl, 1) + 0.1; lorentz_point(q)];
c = A' * y0 + s0;
K = struct('l', nl, 'q', q);
[x, y, info] = sedumi(A, b, c, K, pars);
check_solution(A, b, c, x, y, info, 'SOCP');

%% SDP: one semidefinite block.
fprintf('Solving SDP...\n');
rng(2);
k = 6; m = 8;
A = zeros(m, k * k);
for i = 1:m
    M = sprandn(k, k, 0.5);
    M = (M + M') / 2;
    A(i, :) = M(:)';
end
A = sparse(A);
X0 = eye(k);
b = A * X0(:);
y0 = randn(m, 1);
S0 = eye(k);
c = reshape(S0, [], 1) + A' * y0;
K = struct('s', k);
[x, y, info] = sedumi(A, b, c, K, pars);
check_solution(A, b, c, x, y, info, 'SDP');

fprintf('SUCCESS\n');


function check_solution(A, b, c, x, y, info, name)
% Feasibility, numerical health, and a small duality gap.
    assert(info.pinf == 0 && info.dinf == 0, ...
        sprintf('%s: sedumi reported infeasibility (pinf=%d, dinf=%d)', ...
            name, info.pinf, info.dinf));
    assert(info.numerr ~= 2, ...
        sprintf('%s: complete numerical failure (numerr == 2)', name));
    res = norm(A * x - b) / max(1, norm(b));
    assert(res < 1e-6, sprintf('%s: primal residual %g', name, res));
    gap = abs(c' * x - b' * y) / max(1, abs(b' * y));
    assert(gap < 1e-6, sprintf('%s: duality gap %g', name, gap));
end

function z = lorentz_point(q)
% A strictly interior point of the product of Lorentz cones with sizes q.
    z = [];
    for qi = q
        v = randn(qi - 1, 1);
        z = [z; norm(v) + 1; v]; %#ok<AGROW>
    end
end
