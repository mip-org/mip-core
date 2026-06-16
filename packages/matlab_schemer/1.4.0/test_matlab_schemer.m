% Test script for matlab_schemer.
%
% matlab_schemer's public entry points (schemer_import, schemer_export)
% interact with MATLAB preferences and open GUI dialogs by default, so we
% cannot exercise them end-to-end in a headless build. Instead, confirm
% that the two functions are on the path and that the bundled color
% scheme library ships alongside them.

fprintf('Testing matlab_schemer path entries...\n');
assert(exist('schemer_import', 'file') == 2, ...
    'schemer_import is not on the MATLAB path');
assert(exist('schemer_export', 'file') == 2, ...
    'schemer_export is not on the MATLAB path');

fprintf('Testing bundled schemes directory...\n');
pkgRoot = fileparts(which('schemer_import'));
schemesDir = fullfile(pkgRoot, 'schemes');
assert(isfolder(schemesDir), ...
    sprintf('Expected schemes directory at %s', schemesDir));
prfFiles = dir(fullfile(schemesDir, '*.prf'));
assert(~isempty(prfFiles), ...
    'No .prf scheme files found in schemes/ directory');

fprintf('SUCCESS\n');
