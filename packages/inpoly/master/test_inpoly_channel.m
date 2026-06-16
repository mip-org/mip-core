% Channel post-install test for INPOLY (pure MATLAB on MATLAB).
% Checks point-in-polygon classification against a known polygon.

fprintf('=== Testing INPOLY ===\n');

assert(~isempty(which('inpoly2')), 'inpoly2 is not on the path');

% Unit-square polygon; classify a handful of query points.
node = [0 0; 1 0; 1 1; 0 1];
vert = [0.5 0.5;    % inside
        2.0 2.0;    % outside
        0.1 0.9;    % inside
       -1.0 0.5;    % outside
        0.99 0.5];  % inside (near edge)
expected = logical([1; 0; 1; 0; 1]);

stat = inpoly2(vert, node);
assert(isequal(stat(:), expected), ...
    'inpoly2 classification mismatch: got %s', mat2str(stat(:)'));
fprintf('  point-in-polygon classification OK\n');

% Consistency against MATLAB's built-in inpolygon on a random query set.
rng(0);
P = rand(500, 2) * 2 - 0.5;   % span [-0.5, 1.5]^2 so ~1/4 fall inside
ref = inpolygon(P(:,1), P(:,2), [node(:,1); node(1,1)], [node(:,2); node(1,2)]);
got = inpoly2(P, node);
% Allow tiny disagreement only exactly on the boundary (measure-zero here).
assert(isequal(logical(got(:)), logical(ref(:))), ...
    'inpoly2 disagrees with inpolygon on %d of %d points', ...
    nnz(logical(got(:)) ~= logical(ref(:))), numel(ref));
fprintf('  agrees with built-in inpolygon (500 points)\n');

fprintf('=== INPOLY test passed ===\n');
