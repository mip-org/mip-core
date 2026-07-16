% Test script for abct (mip-org/labs).
%
% Exercises the toolbox-free core of Mika Rubinov's abct toolbox using only
% base MATLAB (no add-on toolboxes), so it runs on the channel's base-only CI:
% degree/dispersion centralities, global residualization, network shrinkage,
% and Louvain modularity maximization.
rng('default');

% A small symmetric, non-negative network (zero diagonal).
W = [0 1 2; ...
     1 0 3; ...
     2 3 0];

% --- degree ---------------------------------------------------------------
% First degree = row sum; second degree = row sum of squares.
fprintf('Testing degree...\n');
assert(isequal(degree(W),           [3; 4;  5]),  'degree(first) mismatch');
assert(isequal(degree(W, "first"),  [3; 4;  5]),  'degree(first) mismatch');
assert(isequal(degree(W, "second"), [5; 10; 13]), 'degree(second) mismatch');

% --- dispersion (squared coefficient of variation) -----------------------
fprintf('Testing dispersion...\n');
D = dispersion(W);              % default type "coefvar2"
assert(max(abs(D - [2/3; 7/8; 14/25])) < 1e-12, 'dispersion(coefvar2) mismatch');

% --- residualn (global residualization) ----------------------------------
% Degree correction of an all-ones matrix leaves the zero matrix.
fprintf('Testing residualn...\n');
R = residualn(ones(4), "degree");
assert(max(abs(R(:))) < 1e-12, 'residualn(degree) of ones should be ~0');

% --- shrinkage ------------------------------------------------------------
% shrinkage "despikes" a dominant peak in the eigenspectrum, so give it a
% matrix with a clear rank-one spike plus small symmetric noise. Structural
% checks: output stays symmetric, real, finite, same size.
fprintf('Testing shrinkage...\n');
n = 12;
g = (1:n)' / n;
A = 0.02 * randn(n);
S = g * g' + (A + A') / 2;          % dominant first eigenvalue + noise
Xs = shrinkage(S);
assert(isequal(size(Xs), [n n]), 'shrinkage changed matrix size');
assert(all(isfinite(Xs(:))),     'shrinkage produced non-finite values');
assert(norm(Xs - Xs', 'fro') < 1e-9, 'shrinkage output not symmetric');

% --- louvains (modularity maximization) -----------------------------------
% Two disconnected 4-cliques must be recovered as two communities.
fprintf('Testing louvains...\n');
clique = ones(4) - eye(4);
W2 = blkdiag(clique, clique);        % 8x8, two disconnected 4-cliques
[M, Q] = louvains(W2);
assert(numel(unique(M)) == 2, 'louvains should recover 2 communities');
assert(Q > 0,                 'louvains modularity should be positive');

fprintf('SUCCESS\n');
