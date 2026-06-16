% Compile Manopt MEX files.
% compile.m runs with cwd set to the package source root.

fprintf('=== Compiling Manopt MEX files ===\n');

toolsDir = fullfile(pwd, 'manopt', 'tools');

% Two small sparse-matrix helpers used by sparseentries.m /
% replacesparseentries.m (e.g. for fixed-rank manifolds). Upstream documents
% building each with `mex <file>.c -largeArrayDims`. They land back in
% manopt/tools/ where the wrappers expect them.
sources = {'spmaskmult.c', 'setsparseentries.c'};

for i = 1:numel(sources)
    fprintf('  [%d/%d] %s\n', i, numel(sources), sources{i});
    mex('-largeArrayDims', '-outdir', toolsDir, fullfile(toolsDir, sources{i}));
end

fprintf('=== Manopt MEX compilation complete ===\n');
