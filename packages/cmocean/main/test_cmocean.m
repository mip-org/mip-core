% Test script for cmocean.

fprintf('Testing cmocean is on the path...\n');
assert(exist('cmocean', 'file') == 2, 'cmocean is not on the MATLAB path');

fprintf('Testing default colormap size...\n');
cmap = cmocean('thermal');
assert(isequal(size(cmap), [256 3]), ...
    sprintf('Expected 256x3 colormap, got %dx%d', size(cmap, 1), size(cmap, 2)));
assert(all(cmap(:) >= 0 & cmap(:) <= 1), ...
    'Colormap entries must lie in [0, 1]');

fprintf('Testing custom level count...\n');
cmap64 = cmocean('haline', 64);
assert(isequal(size(cmap64), [64 3]), ...
    sprintf('Expected 64x3 colormap, got %dx%d', size(cmap64, 1), size(cmap64, 2)));

fprintf('Testing reversed colormap...\n');
cmapFwd = cmocean('balance');
cmapRev = cmocean('-balance');
assert(isequal(cmapFwd, flipud(cmapRev)), ...
    'Reversed colormap should equal flipud of the forward colormap');

fprintf('Testing diverging colormap name...\n');
cmapDiv = cmocean('curl', 32);
assert(isequal(size(cmapDiv), [32 3]), ...
    'Diverging colormap did not return requested size');

fprintf('SUCCESS\n');
