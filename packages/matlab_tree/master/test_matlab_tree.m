% Test script for matlab_tree.

fprintf('Testing tree class is on the path...\n');
assert(~isempty(which('tree')), 'tree class is not on the MATLAB path');

fprintf('Testing construction with root content...\n');
t = tree('root');
assert(strcmp(t.get(1), 'root'), 'Root node content mismatch');
assert(t.nnodes() == 1, 'Freshly built tree should have 1 node');

fprintf('Testing addnode and parent/child relationships...\n');
[t, idA] = t.addnode(1, 'A');
[t, idB] = t.addnode(1, 'B');
[t, idAa] = t.addnode(idA, 'A.a');
[t, idAb] = t.addnode(idA, 'A.b');

assert(t.nnodes() == 5, sprintf('Expected 5 nodes, got %d', t.nnodes()));
assert(t.getparent(idAa) == idA, 'Parent of A.a should be A');
assert(t.getparent(idB) == 1, 'Parent of B should be root');

kids = t.getchildren(idA);
assert(isequal(sort(kids(:).'), sort([idAa idAb])), ...
    'Children of A should be {A.a, A.b}');

fprintf('Testing isleaf and findleaves...\n');
assert(~t.isleaf(idA), 'Node A should not be a leaf');
assert(t.isleaf(idAa), 'Node A.a should be a leaf');

leaves = sort(t.findleaves());
assert(isequal(leaves(:).', sort([idB idAa idAb])), ...
    'findleaves returned unexpected set');

fprintf('Testing siblings...\n');
sibs = t.getsiblings(idAa);
assert(ismember(idAb, sibs), 'A.b should be a sibling of A.a');

fprintf('Testing depth and iterators...\n');
assert(t.depth() == 2, sprintf('Expected depth 2, got %d', t.depth()));
dfs = t.depthfirstiterator();
bfs = t.breadthfirstiterator();
assert(numel(dfs) == t.nnodes(), 'DFS iterator should visit every node');
assert(numel(bfs) == t.nnodes(), 'BFS iterator should visit every node');
assert(bfs(1) == 1, 'BFS should start at the root');

fprintf('Testing set updates node content...\n');
t = t.set(idB, 'B-new');
assert(strcmp(t.get(idB), 'B-new'), 'set did not update node content');

fprintf('SUCCESS\n');
