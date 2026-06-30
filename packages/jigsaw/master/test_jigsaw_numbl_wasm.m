% Channel post-install test for JIGSAW on the numbl_wasm architecture.
%
% Exercises all three entry points through the WASM kernel:
%   * jigsaw — mesh a square domain from a geometry file.
%   * tripod — restricted Delaunay tessellation of an initial point set.
%   * marche — gradient-limit a mesh-size function in place.
%
% Mirrors the native channel test but avoids `which` (unsupported in numbl) and
% relies on the numbl initjig override (genpath-free). Inputs are written with
% savemsh and read back inside the .m overrides via loadmsh, so the file-based
% OPTS contract is exercised end-to-end.

fprintf('=== Testing JIGSAW (numbl_wasm) ===\n');

initjig;   % numbl override: loads JIGSAW global constants (no genpath)

td = tempname;
mkdir(td);
cleanup = onCleanup(@() rmdir(td, 's'));

% ---------------------------------------------------------------- JIGSAW
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
xy = mesh.point.coord(:, 1:2);
assert(all(xy(:) >= -1e-6) && all(xy(:) <= 9 + 1e-6), ...
    'mesh vertices fall outside the domain');
ti = mesh.tria3.index(:, 1:3);
assert(all(ti(:) >= 1) && max(ti(:)) <= nvert, 'triangle indices out of range');
fprintf('  jigsaw meshed the square (%d points, %d triangles)\n', nvert, ntria);

% ---------------------------------------------------------------- TRIPOD
clear topts;
topts.geom_file = fullfile(td, 'tri-geom.msh');
topts.init_file = fullfile(td, 'tri-init.msh');
topts.jcfg_file = fullfile(td, 'tri.jig');
topts.mesh_file = fullfile(td, 'tri-mesh.msh');

tgeom.mshID = 'EUCLIDEAN-MESH';
tgeom.point.coord = [0 0 0; 1 0 0; 1 1 0; 0 1 0];
tgeom.edge2.index = [1 2 0; 2 3 0; 3 4 0; 4 1 0];
savemsh(topts.geom_file, tgeom);

tinit.mshID = 'EUCLIDEAN-MESH';
tinit.point.coord = [0 0 0; 1 0 0; 1 1 0; 0 1 0; ...
                     .5 0 0; 1 .5 0; .5 1 0; 0 .5 0; .3 .3 0];
savemsh(topts.init_file, tinit);

topts.mesh_dims = 2;
tmesh = tripod(topts);

assert(isstruct(tmesh) && isfield(tmesh, 'tria3'), ...
    'tripod did not return a tessellation');
ntt = size(tmesh.tria3.index, 1);
assert(ntt > 0, 'tripod produced no triangles');
fprintf('  tripod tessellated %d points into %d triangles\n', ...
    size(tmesh.point.coord, 1), ntt);

% ---------------------------------------------------------------- MARCHE
clear mopts;
mopts.hfun_file = fullfile(td, 'spac.msh');
mopts.jcfg_file = fullfile(td, 'spac.jig');

hfun.mshID = 'EUCLIDEAN-MESH';
hfun.point.coord = [0 0 0; 1 0 0; 1 1 0; 0 1 0; .5 .5 0];
hfun.tria3.index = [1 2 5 0; 2 3 5 0; 3 4 5 4; 4 1 5 0];
hfun.value = [2; 2; 2; 2; 1];
hfun.slope = 0.10 * ones(5, 1);    % gradient limit per vertex
savemsh(mopts.hfun_file, hfun);

hlim = marche(mopts);

assert(isstruct(hlim) && isfield(hlim, 'value'), ...
    'marche did not return an hfun struct');
assert(numel(hlim.value) == 5, 'marche changed the value count');
assert(all(isfinite(hlim.value(:))) && all(hlim.value(:) > 0), ...
    'marche produced invalid spacing values');
% Gradient-limiting can only lower interior peaks relative to neighbours; the
% corner values (2) must not increase.
assert(max(hlim.value(:)) <= 2 + 1e-6, 'marche increased the spacing maximum');
fprintf('  marche limited the spacing function (max |dh/dx| = %g)\n', hfun.slope(1));

fprintf('=== JIGSAW numbl_wasm test passed ===\n');
