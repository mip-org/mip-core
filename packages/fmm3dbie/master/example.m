% Minimal end-to-end example for fmm3dbie: solve an exterior Laplace Dirichlet
% boundary integral equation on the unit sphere and check the solution at an
% off-surface target against the known field of an interior point source.
%
% mip install --channel mip-org/staging fmm3dbie
% mip load fmm3dbie

rng('default');

% Triangulated unit sphere (a surfer object).
S = geometries.sphere(1, 2, [0;0;0], 4, 1);
[~, ~, ~, ~, ~, wts] = extract_arrays(S);

eps = 1e-7;                 % requested precision
dpars = [1.0, 1.0];         % combined-field (single + double layer) representation

% Boundary data: trace of the potential of a point charge inside the sphere.
src.r = [0.3; 0.5; 0.1];
rhs   = lap3d.kern(src, S, 's');

% Solve for the layer-potential density, then evaluate at an exterior target.
sigma = lap3d.dirichlet.solver(S, rhs, eps, dpars);

targ.r = [1.3; -5.2; 0.1];
dat    = lap3d.kern(S, targ.r, 'c', dpars(1), dpars(2));
pot    = dat * (sigma .* wts);
pot_ex = lap3d.kern(src, targ, 's');

fprintf('Solved Laplace Dirichlet BVP on the sphere (%d nodes, eps=%g).\n', ...
    numel(wts), eps);
fprintf('Potential at exterior target: %.8f (exact %.8f, rel. err %.2e)\n', ...
    pot, pot_ex, abs(pot - pot_ex)/abs(pot_ex));
