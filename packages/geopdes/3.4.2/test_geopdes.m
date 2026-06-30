% Channel post-install test for GeoPDEs (pure MATLAB).
% Runs a minimal isogeometric-analysis pipeline (geometry -> mesh -> space ->
% operator) and checks the assembled mass matrix. The nurbs dependency supplies
% the spline geometry.

fprintf('=== Testing GeoPDEs ===\n');

mip load nurbs
assert(~isempty(which('msh_cartesian')), 'geopdes (msh_cartesian) not on the path');
assert(~isempty(which('sp_nurbs')), 'geopdes (sp_nurbs) not on the path');
assert(~isempty(which('nrb4surf')), 'nurbs dependency (nrb4surf) not on the path');

% Unit-square geometry, refined to a quadratic B-spline space.
nrb = nrb4surf([0 0], [1 0], [0 1], [1 1]);
degree = [2 2]; nsub = [4 4]; regularity = [1 1]; nquad = [3 3];

degelev = max(degree - (nrb.order - 1), 0);
nrb = nrbdegelev(nrb, degelev);
[~, zeta, nknots] = kntrefine(nrb.knots, nsub - 1, nrb.order - 1, regularity);
nrb = nrbkntins(nrb, nknots);

geometry = geo_load(nrb);
rule = msh_gauss_nodes(nquad);
[qn, qw] = msh_set_quad_nodes(zeta, rule);
msh = msh_cartesian(zeta, qn, qw, geometry);
space = sp_nurbs(geometry.nurbs, msh);

mass = op_u_v_tp(space, space, msh);
assert(size(mass, 1) == space.ndof && size(mass, 2) == space.ndof, ...
    'mass matrix has the wrong size');

% NURBS form a partition of unity, so the total mass equals the domain area (1).
area = full(sum(mass(:)));
assert(abs(area - 1) < 1e-10, 'assembled mass does not match domain area: %.6f', area);
% Mass matrix must be symmetric.
assert(norm(mass - mass', 1) < 1e-12, 'mass matrix is not symmetric');

fprintf('  IGA mass-matrix assembly OK (ndof = %d, total mass = %.10f)\n', ...
    space.ndof, area);

fprintf('=== GeoPDEs test passed ===\n');
