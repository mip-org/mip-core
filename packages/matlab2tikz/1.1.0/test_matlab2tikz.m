% Test script for matlab2tikz package.

rng('default');

%% Confirm the public entry points are on the path
fprintf('Testing matlab2tikz path entries...\n');
assert(exist('matlab2tikz', 'file') == 2, ...
    'matlab2tikz is not on the MATLAB path');
assert(exist('cleanfigure', 'file') == 2, ...
    'cleanfigure is not on the MATLAB path');
assert(exist('figure2dot', 'file') == 2, ...
    'figure2dot is not on the MATLAB path');

%% Convert a small invisible figure and check the emitted .tex file
fprintf('Testing end-to-end figure conversion...\n');
fig = figure('Visible', 'off');
cleanupFig = onCleanup(@() close(fig));

plot(1:10, (1:10).^2);
title('matlab2tikz smoke test');
xlabel('x');
ylabel('x^2');

tmpDir = tempname;
mkdir(tmpDir);
cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));
texFile = fullfile(tmpDir, 'smoke.tex');

matlab2tikz(texFile, ...
    'figurehandle', fig, ...
    'showInfo', false, ...
    'checkForUpdates', false);

assert(exist(texFile, 'file') == 2, ...
    sprintf('matlab2tikz did not produce %s', texFile));

contents = fileread(texFile);
assert(contains(contents, '\begin{tikzpicture}'), ...
    'Output file does not contain a tikzpicture environment');
assert(contains(contents, '\begin{axis}'), ...
    'Output file does not contain a pgfplots axis environment');

fprintf('SUCCESS\n');
