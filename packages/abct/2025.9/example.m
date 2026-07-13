% Minimal end-to-end example for abct.
%
%   mip install --channel mip-org/labs abct
%   mip load abct

% Build a network with two clear communities: two 4-node cliques joined by a
% single weak edge.
clique = ones(4) - eye(4);
W = blkdiag(clique, clique);
W(4, 5) = 0.1; W(5, 4) = 0.1;

% Degree and dispersion centralities.
d  = degree(W);          % first degree (row sums)
d2 = degree(W, "second");% second degree (row sums of squares)
cv = dispersion(W);      % squared coefficient of variation

% Global residualization (degree correction) and network shrinkage.
Wr = residualn(W, "degree");
Ws = shrinkage((W + W') / 2);

% Louvain modularity maximization recovers the two communities.
[M, Q] = louvains(W);
fprintf('Communities found: %d   (modularity Q = %.4f)\n', numel(unique(M)), Q);
disp('Module assignment:'); disp(M');
