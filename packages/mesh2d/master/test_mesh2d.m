% Channel post-install test for MESH2D (pure MATLAB).
% Generates an unstructured triangular mesh of a simple domain and checks it.
% The inpoly dependency supplies the point-in-polygon kernel.

fprintf('=== Testing MESH2D ===\n');

mip load inpoly
assert(~isempty(which('refine2')), 'refine2 is not on the path');
assert(~isempty(which('smooth2')), 'smooth2 is not on the path');
assert(~isempty(which('inpoly2')), 'inpoly dependency (inpoly2) not on the path');

% Mesh the unit square.
node = [0 0; 1 0; 1 1; 0 1];
edge = [1 2; 2 3; 3 4; 4 1];
opts.kind = 'delaunay';

[vert, etri, tria, tnum] = refine2(node, edge, [], opts, 0.10);  %#ok<ASGLU>
assert(size(vert, 2) == 2 && size(tria, 2) >= 3, 'unexpected mesh array shapes');
assert(size(tria, 1) > 0 && size(vert, 1) >= 4, 'mesh is empty');

% Triangle indices must reference valid vertices, and vertices lie in [0,1]^2.
assert(all(tria(:, 1:3) >= 1, 'all') && max(tria(:, 1:3), [], 'all') <= size(vert, 1), ...
    'triangle indices out of range');
assert(all(vert(:) >= -1e-9) && all(vert(:) <= 1 + 1e-9), ...
    'mesh vertices fall outside the domain');

% All triangles must have non-zero (here, positive) area.
v1 = vert(tria(:, 1), :); v2 = vert(tria(:, 2), :); v3 = vert(tria(:, 3), :);
area2 = (v2(:,1) - v1(:,1)) .* (v3(:,2) - v1(:,2)) - ...
        (v3(:,1) - v1(:,1)) .* (v2(:,2) - v1(:,2));
assert(all(abs(area2) > 0), 'degenerate (zero-area) triangle in mesh');
fprintf('  refine2 meshed the unit square (%d verts, %d tris)\n', ...
    size(vert, 1), size(tria, 1));

[vert2, etri2, tria2, tnum2] = smooth2(vert, etri, tria, tnum);  %#ok<ASGLU>
assert(size(tria2, 1) > 0, 'smooth2 produced an empty mesh');
fprintf('  smooth2 OK (%d verts, %d tris)\n', size(vert2, 1), size(tria2, 1));

fprintf('=== MESH2D test passed ===\n');
