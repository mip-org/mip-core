% Channel post-install test for AABB-TREE (pure MATLAB).
% Builds an aabb-tree over a collection of boxes and checks its defining
% property: every input object is contained in exactly one tree node.

fprintf('=== Testing AABB-TREE ===\n');

assert(~isempty(which('maketree')), 'maketree is not on the path');
assert(~isempty(which('queryset')), 'queryset is not on the path');

rng(0);
n = 300;
c = rand(n, 2);
r = 0.01 + 0.03 * rand(n, 2);
boxes = [c - r, c + r];          % [xmin ymin xmax ymax] per object

tr = maketree(boxes);
assert(isstruct(tr) && all(isfield(tr, {'xx', 'ii', 'll'})), ...
    'maketree did not return a valid tree struct');

% Each of the n objects must appear in exactly one node's item list.
items = sort(vertcat(tr.ll{:}));
assert(isequal(items(:)', 1:n), ...
    'aabb-tree did not partition the objects uniquely');

% Every node box must enclose the boxes of the items it holds.
for k = 1:numel(tr.ll)
    idx = tr.ll{k};
    if isempty(idx), continue; end
    nodeBox = tr.xx(k, :);
    assert(all(boxes(idx, 1) >= nodeBox(1) - 1e-12) && ...
           all(boxes(idx, 2) >= nodeBox(2) - 1e-12) && ...
           all(boxes(idx, 3) <= nodeBox(3) + 1e-12) && ...
           all(boxes(idx, 4) <= nodeBox(4) + 1e-12), ...
           'node %d does not enclose its items', k);
end
fprintf('  aabb-tree built and verified (%d objects, %d nodes)\n', n, numel(tr.ll));

fprintf('=== AABB-TREE test passed ===\n');
