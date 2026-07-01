% Example usage of surfacefun: solve a Laplace-Beltrami problem on a sphere.
%
% mip install --channel mip-org/staging surfacefun
% mip load surfacefun

% Build a high-order mesh of the unit sphere.
n = 16;
dom = surfacemesh.sphere(n, 2);

% A spherical harmonic Y_lm satisfies lap(Y_lm) = -l*(l+1)*Y_lm, giving a
% problem with a known solution.
l = 3; m = 2;
Y = spherefun.sphharm(l, m);
sol = surfacefun(@(x,y,z) Y(x,y,z), dom);
f = -l*(l+1)*sol;

% Solve lap(u) = f with the fast direct solver.
pdo = [];
pdo.lap = 1;
L = surfaceop(dom, pdo, f);
L.rankdef = true;  % Laplace-Beltrami on a closed surface is rank deficient
u = L.solve();

fprintf('Relative error: %g\n', norm(u - sol) / norm(sol));

plot(u)
axis equal
colorbar
title('Solution of the Laplace-Beltrami problem')
