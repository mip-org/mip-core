% Test script for kdtree package

%% Test kdtree_build and kdtree_delete
fprintf('Testing kdtree_build / kdtree_delete...\n');
points = rand(100, 3);
tree = kdtree_build(points);
assert(~isempty(tree), 'kdtree_build returned empty');
kdtree_delete(tree);

%% Test kdtree_nearest_neighbor
fprintf('Testing kdtree_nearest_neighbor...\n');
points = [0 0; 1 0; 0 1; 1 1];
tree = kdtree_build(points);
query = [0.1 0.1; 0.9 0.9];
[idxs, dsts] = kdtree_nearest_neighbor(tree, query);
assert(idxs(1) == 1, 'Expected nearest neighbor index 1 for query [0.1, 0.1]');
assert(idxs(2) == 4, 'Expected nearest neighbor index 4 for query [0.9, 0.9]');
assert(all(dsts >= 0), 'Distances should be non-negative');
kdtree_delete(tree);

%% Test kdtree_k_nearest_neighbors
fprintf('Testing kdtree_k_nearest_neighbors...\n');
points = [0 0; 1 0; 0 1; 1 1; 0.5 0.5];
tree = kdtree_build(points);
query = [0.5; 0.5]; % column vector for single query point
idxs = kdtree_k_nearest_neighbors(tree, query, 3);
assert(length(idxs) == 3, 'Expected 3 nearest neighbors');
assert(idxs(1) == 5, 'Closest point to [0.5,0.5] should be point 5');
kdtree_delete(tree);

%% Test kdtree_range_query
fprintf('Testing kdtree_range_query...\n');
points = [0 0; 1 0; 0 1; 1 1; 0.5 0.5];
tree = kdtree_build(points);
range = [0.4 0.6; 0.4 0.6]; % 2x2 matrix: [xmin xmax; ymin ymax]
idxs = kdtree_range_query(tree, range);
assert(ismember(5, idxs), 'Point [0.5,0.5] should be in range [0.4,0.6]x[0.4,0.6]');
assert(~ismember(1, idxs), 'Point [0,0] should not be in range');
kdtree_delete(tree);

%% Test kdtree_ball_query
fprintf('Testing kdtree_ball_query...\n');
points = [0 0; 1 0; 0 1; 1 1; 0.5 0.5];
tree = kdtree_build(points);
[idxs, distances] = kdtree_ball_query(tree, [0.5; 0.5], 0.1);
assert(ismember(5, idxs), 'Point [0.5,0.5] should be within radius 0.1 of query');
assert(all(distances <= 0.1), 'All returned distances should be <= radius');
kdtree_delete(tree);

fprintf('SUCCESS\n');
