% Compile PIVlab's MEX files. All are small, self-contained C89 sources, so
% the same plain mex() calls work with gcc (Linux/macOS) and MinGW (Windows).
%
% 1) +plot/fastLICFunction.c -- fast Line Integral Convolution renderer used
%    by the LIC visualization (plot.LIC). Built into +plot/ so the compiled
%    MEX shadows the fastLICFunction.m autocompile shim.
% 2) The four minFunc helpers (mcholC, lbfgsC, lbfgsAddC, lbfgsProdC) that
%    upstream's OptimizationSolvers/minFunc/mexAll.m builds, used by the
%    wOFV (wavelet-based optical flow) optimizer. Built into the compiled/
%    dir where minFunc expects them.

fprintf('Compiling +plot/fastLICFunction.c...\n');
mex('-outdir', '+plot', fullfile('+plot', 'fastLICFunction.c'));

minfunc_dir = fullfile('OptimizationSolvers', 'minFunc', 'minFunc');
out_dir = fullfile(minfunc_dir, 'compiled');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
% The minFunc sources predate the 64-bit array-dims API: they pass int[]
% where the default API wants mwSize[] (a hard error on modern compilers),
% so build them with the 32-bit-dims API they were written for.
sources = {'mcholC.c', 'lbfgsC.c', 'lbfgsAddC.c', 'lbfgsProdC.c'};
for i = 1:numel(sources)
    fprintf('Compiling minFunc %s...\n', sources{i});
    mex('-compatibleArrayDims', '-outdir', out_dir, ...
        fullfile(minfunc_dir, 'mex', sources{i}));
end

fprintf('PIVlab MEX compilation done.\n');
