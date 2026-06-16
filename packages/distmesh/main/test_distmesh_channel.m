% Channel post-install test for DistMesh (pure MATLAB).
% Generates a 2-D mesh of the unit disc and checks the result.

fprintf('=== Testing DistMesh ===\n');

assert(~isempty(which('distmesh2d')), 'distmesh2d is not on the path');
assert(~isempty(which('huniform')), 'huniform is not on the path');

% distmesh2d plots each iteration; keep figures invisible and clean up.
set(0, 'DefaultFigureVisible', 'off');
cleanup = onCleanup(@() set(0, 'DefaultFigureVisible', 'on'));

% Uniform mesh of the unit disc: fd is the signed distance to the circle.
fd = @(p) sqrt(sum(p.^2, 2)) - 1;
[p, t] = distmesh2d(fd, @huniform, 0.2, [-1 -1; 1 1], []);
close all;

assert(size(p, 2) == 2 && size(t, 2) == 3, 'unexpected mesh array shapes');
assert(size(p, 1) > 20 && size(t, 1) > 20, 'mesh is implausibly small');

% Triangle indices must reference valid vertices.
assert(all(t(:) >= 1) && max(t(:)) <= size(p, 1), 'triangle indices out of range');

% All vertices must lie on/inside the unit disc (allow a small meshing tol).
r = sqrt(sum(p.^2, 2));
assert(max(r) < 1 + 1e-2, 'mesh vertices fall outside the unit disc (max r = %.4f)', max(r));

% All triangles must have non-zero area.
v1 = p(t(:,1), :); v2 = p(t(:,2), :); v3 = p(t(:,3), :);
area2 = (v2(:,1)-v1(:,1)).*(v3(:,2)-v1(:,2)) - (v3(:,1)-v1(:,1)).*(v2(:,2)-v1(:,2));
assert(all(abs(area2) > 0), 'degenerate (zero-area) triangle in mesh');

fprintf('  distmesh2d meshed the unit disc (%d points, %d triangles)\n', ...
    size(p, 1), size(t, 1));

fprintf('=== DistMesh test passed ===\n');
