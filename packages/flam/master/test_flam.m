% Test script for flam (Fast Linear Algebra in MATLAB) package.

rng('default');

%% Interpolative decomposition (ID) of a low-rank matrix
fprintf('Testing id (interpolative decomposition)...\n');
m = 80; n = 60; k = 8;
A = randn(m, k) * randn(k, n);              % exactly rank-k matrix
[sk, rd, T] = id(A, 1e-10);
assert(numel(sk) == k, sprintf('ID rank wrong: got %d, expected %d', numel(sk), k));
% Reconstruct the redundant columns from the skeleton columns.
err = norm(A(:, rd) - A(:, sk) * T) / norm(A);
assert(err < 1e-10, sprintf('ID reconstruction error too large: %g', err));

%% Recursive skeletonization factorization (rskelf): fast direct solver
fprintf('Testing rskelf (multiply and solve)...\n');
% N points on a uniform grid in the unit square.
ns = 8;
[g1, g2] = ndgrid((1:ns) / ns);
x = [g1(:) g2(:)]';
N = size(x, 2);

lambda = 1e-2;                              % diagonal regularization -> SPD
Afun = @(i, j) Afun_(i, j, x, lambda);

% Proxy points on a circle of radius 1.5 around the unit reference box.
p = 32;
theta = (1:p) * 2 * pi / p;
proxy = 1.5 * [cos(theta); sin(theta)];
pxyfun = @(x, slf, nbr, l, ctr) pxyfun_(x, slf, nbr, l, ctr, proxy);

occ = 16;
rank_or_tol = 1e-9;
opts = struct('symm', 's', 'verb', 0);
F = rskelf(Afun, x, occ, rank_or_tol, pxyfun, opts);

% Dense reference matrix.
Afull = Afun(1:N, 1:N);

% Multiply: rskelf_mv(F, v) should match Afull * v.
v = randn(N, 1);
b = Afull * v;
b_rskelf = rskelf_mv(F, v);
mv_err = norm(b - b_rskelf) / norm(b);
fprintf('  rskelf_mv relative error: %5.2e\n', mv_err);
assert(mv_err < 1e-6, sprintf('rskelf_mv error too large: %g', mv_err));

% Solve: rskelf_sv(F, b) should recover v (= Afull \ b).
v_rskelf = rskelf_sv(F, b);
sv_err = norm(v - v_rskelf) / norm(v);
fprintf('  rskelf_sv relative error: %5.2e\n', sv_err);
assert(sv_err < 1e-6, sprintf('rskelf_sv error too large: %g', sv_err));

fprintf('SUCCESS\n');


% Exponential (Ornstein-Uhlenbeck) kernel, a valid SPD covariance.
function K = Kfun_(x, y)
  dx = bsxfun(@minus, x(1, :)', y(1, :));
  dy = bsxfun(@minus, x(2, :)', y(2, :));
  K = exp(-sqrt(dx.^2 + dy.^2));
end

% Submatrix accessor with regularized diagonal.
function A = Afun_(i, j, x, lambda)
  A = Kfun_(x(:, i), x(:, j));
  [I, J] = ndgrid(i, j);
  A(I == J) = 1 + lambda;                   % exp(0) = 1, plus regularization
end

% Proxy interaction for far-field compression.
function [Kpxy, nbr] = pxyfun_(x, slf, nbr, l, ctr, proxy)
  pxy = bsxfun(@plus, proxy .* l, ctr);     % scale and translate proxy points
  Kpxy = Kfun_(pxy, x(:, slf));
  nbr = nbr(sum(bsxfun(@rdivide, bsxfun(@minus, x(:, nbr), ctr), l).^2) < 1.5^2);
end
