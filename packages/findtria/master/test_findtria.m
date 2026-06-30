% Channel post-install test for FINDTRIA (pure MATLAB).
% Locates query points within a triangulation; the aabb-tree dependency
% supplies the underlying spatial-query backend.

fprintf('=== Testing FINDTRIA ===\n');

mip load aabb-tree
assert(~isempty(which('findtria')), 'findtria is not on the path');
assert(~isempty(which('maketree')), 'aabb-tree dependency (maketree) not on the path');

% Two triangles splitting the unit square along the (0,0)-(1,1) diagonal.
pp = [0 0; 1 0; 1 1; 0 1];
tt = [1 2 3; 1 3 4];            % tri 1 = lower-right, tri 2 = upper-left
pj = [0.6 0.3;   % below diagonal -> tri 1
      0.3 0.6;   % above diagonal -> tri 2
      2.0 2.0];  % outside -> none

[tp, tj] = findtria(pp, tt, pj);
ti = nan(size(tp, 1), 1);
in = tp(:, 1) > 0;
ti(in) = tj(tp(in, 1));        % single-match index (per findtria docs)

assert(ti(1) == 1, 'point 1 should be in triangle 1, got %g', ti(1));
assert(ti(2) == 2, 'point 2 should be in triangle 2, got %g', ti(2));
assert(isnan(ti(3)), 'point 3 should be outside the triangulation');
fprintf('  point-in-triangle queries OK\n');

fprintf('=== FINDTRIA test passed ===\n');
