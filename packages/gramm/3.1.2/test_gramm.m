% Channel post-install test for gramm (pure MATLAB).
% Builds a gramm figure and draws it (headless) to exercise the pipeline.

fprintf('=== Testing gramm ===\n');

assert(~isempty(which('gramm')), 'gramm is not on the path');

% Keep figures invisible (and clean up) for headless execution.
set(0, 'DefaultFigureVisible', 'off');
cleanup = onCleanup(@() set(0, 'DefaultFigureVisible', 'on'));

% Build a simple grouped scatter + line plot.
x = 1:20;
y = (1:20).^2;
c = repmat([1 2], 1, 10);
g = gramm('x', x, 'y', y, 'color', c);
g.geom_point();
g.geom_line();

f = figure('Visible', 'off');
g.draw();
closeFig = onCleanup(@() close(f));

assert(isa(g, 'gramm'), 'gramm did not return a gramm object');
assert(~isempty(g.facet_axes_handles), 'gramm produced no axes');
assert(~isempty(g.results), 'gramm produced no draw results');
assert(isfield(g.results, 'geom_point_handle'), 'gramm did not draw the point geom');

fprintf('  gramm build + draw OK\n');

fprintf('=== gramm test passed ===\n');
