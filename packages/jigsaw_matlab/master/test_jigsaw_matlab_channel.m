% Channel post-install test for JIGSAW (MATLAB interface + C++ backend).
% Generates a 2-D mesh of a square domain by invoking the compiled backend.

fprintf('=== Testing JIGSAW ===\n');

assert(~isempty(which('jigsaw')), 'jigsaw is not on the path');
assert(~isempty(which('initjig')), 'initjig is not on the path');

initjig;   % set JIGSAW global constants (and add tools/ + parse/ to the path)

% Work in a temp directory (the installed package dir may be read-only).
td = tempname;
mkdir(td);
cleanup = onCleanup(@() rmdir(td, 's'));

opts.geom_file = fullfile(td, 'box-geom.msh');
opts.jcfg_file = fullfile(td, 'box.jig');
opts.mesh_file = fullfile(td, 'box-mesh.msh');

geom.mshID = 'EUCLIDEAN-MESH';
geom.point.coord = [0 0 0; 9 0 0; 9 9 0; 0 9 0];
geom.edge2.index = [1 2 0; 2 3 0; 3 4 0; 4 1 0];
savemsh(opts.geom_file, geom);

opts.hfun_hmax = 0.10;
opts.mesh_dims = 2;
opts.optm_qlim = 0.95;

mesh = jigsaw(opts);

assert(isstruct(mesh) && isfield(mesh, 'point') && isfield(mesh, 'tria3'), ...
    'jigsaw did not return a mesh struct');
nvert = size(mesh.point.coord, 1);
ntria = size(mesh.tria3.index, 1);
assert(nvert >= 4 && ntria > 0, 'jigsaw produced an empty mesh');

% Mesh vertices must lie within the [0,9]^2 domain.
xy = mesh.point.coord(:, 1:2);
assert(all(xy(:) >= -1e-6) && all(xy(:) <= 9 + 1e-6), ...
    'mesh vertices fall outside the domain');
% Triangle indices must be valid.
ti = mesh.tria3.index(:, 1:3);
assert(all(ti(:) >= 1) && max(ti(:)) <= nvert, 'triangle indices out of range');

fprintf('  JIGSAW meshed the square (%d points, %d triangles)\n', nvert, ntria);

fprintf('=== JIGSAW test passed ===\n');
