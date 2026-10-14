% Check shapes whose minimal bounding objects are known exactly.

fprintf('=== Testing minboundsuite ===\n');

assert(~isempty(which('minboundcircle')), 'minboundcircle is not on the path');
assert(~isempty(which('minboundrect')), 'minboundrect is not on the path');

% Points on a circle, plus interior points: the minimal enclosing circle is
% that circle.
rng(0);
t = 2*pi*rand(50, 1);
x = 2 + 3*cos(t);
y = -1 + 3*sin(t);
r = 3*sqrt(rand(200, 1));
s = 2*pi*rand(200, 1);
x = [x; 2 + r.*cos(s)];
y = [y; -1 + r.*sin(s)];
[center, radius] = minboundcircle(x, y);
assert(norm(center - [2 -1]) < 1e-8, 'minboundcircle center is wrong');
assert(abs(radius - 3) < 1e-8, 'minboundcircle radius is wrong');
fprintf('  minboundcircle OK\n');

% A rotated 4-by-1 rectangle sampled on its boundary and interior: the
% minimal-area bounding rectangle has area 4.
theta = pi/7;
R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
u = 4*rand(300, 1);
v = rand(300, 1);
corners = [0 0; 4 0; 4 1; 0 1];
P = [corners; u v] * R.';
[~, ~, area] = minboundrect(P(:,1), P(:,2));
assert(abs(area - 4) < 1e-8, 'minboundrect area is wrong: %g', area);
fprintf('  minboundrect OK\n');

fprintf('=== minboundsuite test passed ===\n');
