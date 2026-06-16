% Test script for export_fig package.

rng('default');

%% Public entry points are on the path
fprintf('Testing export_fig path entries...\n');
assert(exist('export_fig', 'file') == 2, 'export_fig is not on the MATLAB path');
assert(exist('crop_borders', 'file') == 2, 'crop_borders is not on the MATLAB path');
assert(exist('print2array', 'file') == 2, 'print2array is not on the MATLAB path');

%% crop_borders: deterministic, pure-array border auto-cropping
fprintf('Testing crop_borders...\n');
% White canvas with a black interior block at rows 11-20, cols 16-35.
A = uint8(255 * ones(40, 50, 3));
A(11:20, 16:35, :) = 0;
bcol = [255; 255; 255];               % white background colour
B = crop_borders(A, bcol);
% Auto-cropping should tightly bound the black block (10 rows x 20 cols).
assert(size(B, 1) == 10 && size(B, 2) == 20, ...
    sprintf('crop_borders size wrong: got %dx%d, expected 10x20', size(B,1), size(B,2)));
assert(all(B(:) == 0), 'cropped region should be entirely black');

%% End-to-end: export an invisible figure to PNG and read it back
fprintf('Testing PNG export...\n');
fig = figure('Visible', 'off', 'Color', 'w');
cleanupFig = onCleanup(@() ishghandle(fig) && (close(fig) || true));
ax = axes('Parent', fig);
plot(ax, 1:10, (1:10).^2, 'b-', 'LineWidth', 2);
title(ax, 'export\_fig smoke test');

tmpDir = tempname;
mkdir(tmpDir);
cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));
pngFile = fullfile(tmpDir, 'smoke.png');

export_fig(pngFile, '-png', '-nocrop', '-r100', fig);

assert(exist(pngFile, 'file') == 2, ...
    sprintf('export_fig did not produce %s', pngFile));
img = imread(pngFile);
assert(ndims(img) == 3 && size(img, 3) == 3, 'exported PNG should be RGB');
assert(size(img, 1) > 50 && size(img, 2) > 50, ...
    sprintf('exported PNG dimensions too small: %dx%d', size(img,1), size(img,2)));
% A rendered plot must contain more than a single flat colour.
assert(numel(unique(img(:))) > 1, 'exported PNG appears to be blank');

fprintf('SUCCESS\n');
