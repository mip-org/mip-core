% SDPT3 Example: Max-cut SDP relaxation
%
% Computes an upper bound on the maximum cut of a graph using
% semidefinite programming. The SDP relaxation is:
%
%   maximize  (1/4) * sum_{(i,j) in E} w_ij * (1 - X_ij)
%   subject to  diag(X) = e,  X >= 0  (positive semidefinite)
%
% This is equivalent to:
%   minimize  tr(C * X)   where C = -(diag(B*e) - B) / 4
%   subject to  diag(X) = e,  X >= 0

mip load sdpt3;

% --- Build a small graph with known structure ---
% Complete bipartite graph K_{3,3}: max cut = 9
% Adjacency matrix: edges between {1,2,3} and {4,5,6}
n = 6;
B = zeros(n, n);
B(1:3, 4:6) = 1;
B(4:6, 1:3) = 1;

% --- Formulate the SDP ---
blk = cell(1, 2);
blk{1,1} = 's'; blk{1,2} = n;

e = ones(n, 1);
C = cell(1, 1);
C{1} = -(spdiags(B * e, 0, n, n) - B) / 4;

% Constraint matrices: diag(X) = e
AA = cell(1, n);
for k = 1:n
    AA{1, k} = sparse(k, k, 1, n, n);
end
At = svec(blk, AA, ones(size(blk, 1), 1));
b = ones(n, 1);

% --- Solve ---
OPTIONS.printlevel = 0;  % suppress iteration output
[obj, X, y, Z, info] = sqlp(blk, At, C, b, OPTIONS);

% --- Check results ---
cut_bound = -obj(1);
fprintf('Max-cut SDP bound: %.6f\n', cut_bound);
fprintf('Solver iterations: %d\n', info.iter);
fprintf('Termination code:  %d (0 = optimal)\n', info.termcode);

% For K_{3,3}, the SDP relaxation is tight: max cut = 9
assert(abs(cut_bound - 9.0) < 1e-4, 'Cut bound should be 9 for K_{3,3}');
assert(info.termcode == 0, 'Solver should converge');

fprintf('\nAll checks passed.\n');
