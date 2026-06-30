% Channel post-install test for the Schwarz-Christoffel Toolbox (pure MATLAB).
% Builds a disk -> polygon conformal map and checks it.

fprintf('=== Testing SC Toolbox ===\n');

assert(~isempty(which('polygon')), 'polygon is not on the path');
assert(~isempty(which('diskmap')), 'diskmap is not on the path');

% Unit square as a polygon (complex vertex list).
p = polygon([-1-1i; 1-1i; 1+1i; -1+1i]);
assert(length(p) == 4, 'polygon should have 4 vertices');

% Schwarz-Christoffel map from the unit disk onto the square.
f = diskmap(p);
assert(isa(f, 'diskmap'), 'diskmap did not return a diskmap object');

% Evaluate the map at a set of points in the unit disk.
z = [0; 0.5; 0.5i; -0.3 + 0.4i; 0.7 - 0.2i];
w = eval(f, z);

% By symmetry the conformal centre (z = 0) maps to the square's centre (~0).
assert(abs(w(1)) < 1e-3, 'map centre is not at the polygon centre (|w0| = %g)', abs(w(1)));

% Every image must lie inside the square (small tolerance for boundary points).
assert(all(abs(real(w)) <= 1 + 1e-6) && all(abs(imag(w)) <= 1 + 1e-6), ...
    'a mapped point fell outside the target polygon');

fprintf('  disk -> square conformal map OK\n');

fprintf('=== SC Toolbox test passed ===\n');
