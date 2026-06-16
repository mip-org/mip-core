% Channel post-install test for the NURBS toolbox (pure MATLAB).
% Builds and evaluates a NURBS curve and surface.

fprintf('=== Testing NURBS ===\n');

assert(~isempty(which('nrbmak')), 'nrbmak is not on the path');
assert(~isempty(which('nrbeval')), 'nrbeval is not on the path');

% A NURBS representation of the unit circle: every evaluated point must lie
% exactly on the circle (this exercises the rational weights).
crv = nrbcirc(1);
p = nrbeval(crv, linspace(0, 1, 13));
r = sqrt(sum(p(1:2, :).^2, 1));
assert(max(abs(r - 1)) < 1e-10, 'NURBS circle points are not on the unit circle');
fprintf('  NURBS circle OK (radii within %.1e of 1)\n', max(abs(r - 1)));

% A bilinear NURBS patch over the unit square; check its midpoint.
srf = nrb4surf([0 0], [1 0], [0 1], [1 1]);
ps = nrbeval(srf, {0.5, 0.5});
assert(norm(ps(:) - [0.5; 0.5; 0]) < 1e-12, 'NURBS surface midpoint mismatch');
fprintf('  NURBS surface OK\n');

fprintf('=== NURBS test passed ===\n');
