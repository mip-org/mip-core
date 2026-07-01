% Test script for surfacefun.
rng('default');

% Quadrature on the unit sphere.
fprintf('Testing surfacemesh.sphere and surfacefun quadrature...\n');
n = 12;
dom = surfacemesh.sphere(n, 2);
area = surfacearea(dom);
assert(abs(area - 4*pi) < 1e-8, ...
    sprintf('sphere surface area = %.15g, expected 4*pi', area));

f = surfacefun(@(x,y,z) x.^2 + y.^2 + z.^2, dom);  % identically 1 on the unit sphere
assert(abs(integral2(f) - 4*pi) < 1e-8, ...
    'integral2 of the constant 1 over the unit sphere should be 4*pi');
assert(abs(mean2(f) - 1) < 1e-8, 'mean2 of the constant 1 should be 1');
assert(abs(norm(f) - sqrt(4*pi)) < 1e-8, ...
    'L2 norm of the constant 1 over the unit sphere should be sqrt(4*pi)');

% Spherical harmonics are eigenfunctions of the Laplace-Beltrami operator:
% lap(Y_lm) = -l*(l+1)*Y_lm. spherefun.sphharm comes from chebfun (dependency).
fprintf('Testing surface differentiation...\n');
l = 3; m = 2;
Y = spherefun.sphharm(l, m);
sol = surfacefun(@(x,y,z) Y(x,y,z), dom);
f = -l*(l+1)*sol;
err = norm(lap(sol) - f) / norm(f);
assert(err < 1e-6, sprintf('lap eigenfunction relative error = %g', err));

fprintf('Testing surfacefunv (grad/div)...\n');
v = grad(sol);
err = norm(div(v) - f) / norm(f);
assert(err < 1e-6, sprintf('div(grad) eigenfunction relative error = %g', err));

% Solve the Laplace-Beltrami problem lap(u) = f on the sphere and compare
% with the known solution. The problem is rank deficient on a closed
% surface; rankdef = true imposes the mean-zero condition.
fprintf('Testing surfaceop Laplace-Beltrami solve...\n');
pdo = [];
pdo.lap = 1;
L = surfaceop(dom, pdo, f);
L.rankdef = true;
build(L);
u = L.solve();
err = norm(u - sol) / norm(sol);
assert(err < 1e-6, sprintf('surfaceop solve relative error = %g', err));

fprintf('SUCCESS\n');
