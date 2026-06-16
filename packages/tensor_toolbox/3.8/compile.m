% Compile the L-BFGS-B MEX (lbfgsb_wrapper) bundled with Tensor Toolbox.
% compile.m runs with cwd set to the package source root.
%
% This is the only compiled component. It is Stephen Becker's L-BFGS-B-C,
% self-contained (its own miniCBLAS), used by tt_opt_lbfgsb / cp_opt / gcp_opt.
% Mirrors libraries/lbfgsb/Matlab/compile_mex.m: build the wrapper together
% with the L-BFGS-B C sources, landing the binary in the Matlab/ dir where
% lbfgsb.m expects it.

fprintf('=== Compiling Tensor Toolbox MEX (lbfgsb_wrapper) ===\n');

mexDir = fullfile(pwd, 'libraries', 'lbfgsb', 'Matlab');
srcDir = fullfile(pwd, 'libraries', 'lbfgsb', 'src');

srcs = {'lbfgsb.c', 'linesearch.c', 'subalgorithms.c', 'print.c', ...
        'linpack.c', 'miniCBLAS.c', 'timer.c'};
srcPaths = cellfun(@(s) fullfile(srcDir, s), srcs, 'UniformOutput', false);

args = [{fullfile(mexDir, 'lbfgsb_wrapper.c')}, srcPaths, ...
        {'-largeArrayDims', '-UDEBUG', ['-I' srcDir], '-outdir', mexDir}];
if ~ispc
    args = [args, {'-lm'}];   % link libm on Linux/macOS (per compile_mex.m)
end

mex(args{:});

fprintf('=== Tensor Toolbox MEX compilation complete ===\n');
