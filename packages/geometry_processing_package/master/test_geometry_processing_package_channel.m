% Channel post-install test for geometry-processing-package (pure MATLAB).
% Builds a triangulated disk mesh and exercises io (OFF round-trip), algebra
% (face area, Laplace-Beltrami), and topology (edges, boundary). Display-free.

fprintf('=== Testing geometry-processing-package ===\n');

assert(~isempty(which('read_off')),        'read_off (io) is not on the path');
assert(~isempty(which('face_area')),       'face_area (algebra) is not on the path');
assert(~isempty(which('laplace_beltrami')),'laplace_beltrami (algebra) is not on the path');
assert(~isempty(which('compute_edge')),    'compute_edge (algebra) is not on the path');
assert(~isempty(which('dijkstra')),        'dijkstra (topology) is not on the path');

% --- Build a k x k triangulated grid (a disk-topology mesh with a boundary) ---
k = 9;
[gx, gy] = ndgrid(linspace(-1, 1, k));
x = gx(:); y = gy(:);
face = delaunay(x, y);
z = 0.2 * (x.^2 - y.^2);              % give it some curvature
vertex = [x, y, z];
nv = size(vertex, 1); nf = size(face, 1);
fprintf('  grid mesh: %d vertices, %d faces\n', nv, nf);

% --- io: OFF write/read round-trip ---
tmp = [tempname, '.off'];
cleanup = onCleanup(@() delete(tmp));
write_off(tmp, face, vertex);
[face2, vertex2] = read_off(tmp);
assert(isequal(size(face2), size(face)), 'read_off changed face count');
assert(norm(vertex2 - vertex, 'fro') < 1e-6, 'OFF round-trip changed vertices');
fprintf('  OFF write/read round-trip OK\n');

% --- algebra: face areas ---
fa = face_area(face, vertex);
assert(isequal(size(fa), [nf 1]), 'face_area returned wrong shape');
assert(all(fa > 0), 'face_area produced a non-positive area');
% The grid spans a 2x2 square (projected area 4); curvature only adds area.
assert(sum(fa) > 4 - 1e-6, 'total face area smaller than the projected square');
fprintf('  face_area OK (total %.4f)\n', sum(fa));

% --- algebra: Laplace-Beltrami operator ---
L = laplace_beltrami(face, vertex);
assert(isequal(size(L), [nv nv]), 'laplace_beltrami wrong size');
assert(max(abs(sum(L, 2))) < 1e-8, 'Laplacian rows do not sum to zero');
fprintf('  laplace_beltrami OK (rows sum to zero)\n');

% --- topology: edges (boundary edges flagged with -1) ---
[edge, eif] = compute_edge(face);
assert(size(edge, 2) == 2, 'compute_edge returned wrong shape');
nbd_edges = sum(any(eif == -1, 2));
assert(nbd_edges == 4*(k-1), ...
    sprintf('expected %d boundary edges, got %d', 4*(k-1), nbd_edges));
fprintf('  compute_edge OK (%d edges, %d on boundary)\n', size(edge,1), nbd_edges);

% --- topology: shortest paths over the mesh graph (Dijkstra) ---
[am, ~] = compute_adjacency_matrix(face);
[distance, ~] = dijkstra(am, 1);
assert(numel(distance) == nv, 'dijkstra returned wrong number of distances');
assert(distance(1) == 0, 'distance from source to itself is not zero');
assert(all(isfinite(distance)), 'mesh graph is not fully connected');
fprintf('  dijkstra OK (max hop distance %g)\n', max(distance));

fprintf('=== geometry-processing-package test passed ===\n');
