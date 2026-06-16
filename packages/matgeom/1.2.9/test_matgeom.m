% Test script for matgeom package.

rng('default');

%% Test polygonArea on a unit square
fprintf('Testing polygonArea...\n');
square = [0 0; 1 0; 1 1; 0 1];
a = polygonArea(square);
assert(abs(a - 1) < 1e-12, ...
    sprintf('polygonArea unit square returned %g, expected 1', a));

%% Test circleToPolygon approximates pi*r^2 as N grows
fprintf('Testing circleToPolygon + polygonArea...\n');
r = 2.5;
poly = circleToPolygon([0 0 r], 1024);
a = polygonArea(poly);
assert(abs(a - pi*r^2) < 1e-3, ...
    sprintf('circle area approx error too large: %g', abs(a - pi*r^2)));

%% Test createLine + distancePointLine
fprintf('Testing createLine + distancePointLine...\n');
L = createLine([0 0], [1 0]);   % x-axis
d = distancePointLine([3 4], L);
assert(abs(d - 4) < 1e-12, ...
    sprintf('distancePointLine returned %g, expected 4', d));

%% Test boundingBox
fprintf('Testing boundingBox...\n');
pts = [1 2; 3 -1; -2 5; 4 0];
bb = boundingBox(pts);
assert(isequal(bb, [-2 4 -1 5]), ...
    'boundingBox did not return expected [xmin xmax ymin ymax]');

%% Test 3D: createPlane + distancePointPlane
fprintf('Testing createPlane + distancePointPlane...\n');
plane = createPlane([0 0 0], [0 0 1]);   % xy-plane
d = distancePointPlane([1 2 3], plane);
assert(abs(abs(d) - 3) < 1e-12, ...
    sprintf('distancePointPlane returned %g, expected +/-3', d));

%% Test mesh: createCube + meshVolume + meshSurfaceArea
fprintf('Testing createCube + meshVolume + meshSurfaceArea...\n');
[v, f] = createCube();
vol = meshVolume(v, f);
assert(abs(abs(vol) - 1) < 1e-12, ...
    sprintf('meshVolume unit cube returned %g, expected +/-1', vol));
sa = meshSurfaceArea(v, f);
assert(abs(sa - 6) < 1e-12, ...
    sprintf('meshSurfaceArea unit cube returned %g, expected 6', sa));

fprintf('SUCCESS\n');
