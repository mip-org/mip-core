% Minimal end-to-end example for fmm3d: a 3D Laplace (electrostatic) FMM.
%
% mip install --channel mip-org/staging fmm3d
% mip load fmm3d

rng('default');

% N random source points in the unit cube, each carrying a charge.
ns = 40000;
srcinfo.sources = rand(3, ns);
srcinfo.charges = rand(1, ns);

eps = 1e-5;   % requested relative precision
pg  = 2;      % evaluate potential (1) and gradient (2) at the sources

U = lfmm3d(eps, srcinfo, pg);

fprintf('Evaluated Laplace potential + gradient at %d sources (eps=%g).\n', ns, eps);
disp('First few potentials:');
disp(U.pot(1:5));
disp('Gradient at the first source:');
disp(U.grad(:, 1));
