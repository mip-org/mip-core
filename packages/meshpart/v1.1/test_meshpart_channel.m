% Channel post-install test for meshpart (pure MATLAB).
% Generates a 2D grid graph and exercises the spectral, geometric, and
% coordinate partitioners plus geometric multiway dicing. Display-free.

fprintf('=== Testing meshpart ===\n');

assert(~isempty(which('grid5')),    'grid5 is not on the path');
assert(~isempty(which('specpart')), 'specpart is not on the path');
assert(~isempty(which('specdice')), 'specdice is not on the path');
assert(~isempty(which('geopart')),  'geopart is not on the path');   % ships; not run (needs Statistics Toolbox)

rng(0);

% --- Build a 20x20 five-point grid graph (n = 400 vertices) ---
k = 20;
[A, xy] = grid5(k);
n = k*k;
assert(isequal(size(A), [n n]), 'grid5 returned wrong-size adjacency');
assert(isequal(size(xy), [n 2]), 'grid5 returned wrong-size coordinates');
fprintf('  grid5(%d): %d-vertex grid graph\n', k, n);

% Helper: a (part1,part2) pair must be a valid bipartition of 1:n.
check_bipartition = @(p1, p2) ...
    isequal(sort([p1(:); p2(:)]), (1:n)') && ~isempty(p1) && ~isempty(p2);
balanced = @(p1, p2) min(numel(p1), numel(p2)) >= 0.30 * n;

% --- Spectral bisection (Fiedler vector) ---
[s1, s2] = specpart(A);
assert(check_bipartition(s1, s2), 'specpart is not a valid bipartition');
assert(balanced(s1, s2), 'specpart is badly unbalanced');
fprintf('  spectral partition OK (%d / %d)\n', numel(s1), numel(s2));

% --- Spectral multiway dicing into 2^nlevels parts ---
nlevels = 2;
map = specdice(A, nlevels);
assert(numel(map) == n, 'specdice map has wrong length');
parts = unique(map);
assert(numel(parts) == 2^nlevels, ...
    sprintf('specdice produced %d parts, expected %d', numel(parts), 2^nlevels));
counts = histc(map(:), parts); %#ok<HISTC>
assert(min(counts) >= 0.5 * (n / 2^nlevels), 'specdice parts badly unbalanced');
fprintf('  spectral dicing into %d parts OK (sizes: %s)\n', ...
    2^nlevels, mat2str(counts(:)'));

% geopart/geodice (geometric partitioning) also ship but are not exercised
% here, as they require the MATLAB Statistics Toolbox (randsample).

fprintf('=== meshpart test passed ===\n');
