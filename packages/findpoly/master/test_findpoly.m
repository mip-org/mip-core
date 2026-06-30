% Channel post-install test for FINDPOLY (pure MATLAB).
% Locates query points within a collection of polygons. The aabb-tree and
% inpoly dependencies supply the spatial-query backend and point-in-polygon
% kernel respectively.

fprintf('=== Testing FINDPOLY ===\n');

mip load aabb-tree
mip load inpoly
assert(~isempty(which('findpoly')), 'findpoly is not on the path');
assert(~isempty(which('maketree')), 'aabb-tree dependency (maketree) not on the path');
assert(~isempty(which('inpoly2')), 'inpoly dependency (inpoly2) not on the path');

% Two disjoint unit squares (cell-array polygon collection).
PP = { [0 0; 1 0; 1 1; 0 1], [2 0; 3 0; 3 1; 2 1] };
EE = { [1 2; 2 3; 3 4; 4 1], [1 2; 2 3; 3 4; 4 1] };
PJ = [0.5 0.5;   % inside polygon 1
      2.5 0.5;   % inside polygon 2
      5.0 5.0];  % outside both

[ip, ix] = findpoly(PP, EE, PJ);
res = nan(size(ip, 1), 1);
in = ip(:, 1) > 0;
res(in) = ix(ip(in, 1));        % single-match index (per findpoly docs)

assert(res(1) == 1, 'point 1 should be in polygon 1, got %g', res(1));
assert(res(2) == 2, 'point 2 should be in polygon 2, got %g', res(2));
assert(isnan(res(3)), 'point 3 should be outside all polygons');
fprintf('  point-in-polygon-collection queries OK\n');

fprintf('=== FINDPOLY test passed ===\n');
