% Compile CVX MEX files.
% compile.m runs with cwd set to the package source root.

fprintf('=== Compiling CVX MEX files ===\n');

srcRoot = pwd;
libDir = fullfile(srcRoot, 'lib');

% CVX ships two pure-C MEX helpers used by the presolver
% (cvx_eliminate_mex, cvx_bcompress_mex). The upstream release archives
% bundle them precompiled; the cvxr/CVX git tree does not, so we build them
% from source here. cvx_version() looks for the binaries directly in lib/,
% so that is where they land.
%
% These sources were written for an older compiler era (upstream ships them
% precompiled with GCC 9). Under a newer optimizing GCC, -O2 miscompiles them
% and corrupts the heap at runtime (intermittent MEX segfaults during a solve).
% -fno-strict-aliasing and -fwrapv disable the optimizer assumptions
% responsible; -std=gnu17 keeps the K&R-style (unprototyped) declarations
% valid (mirrors the sedumi recipe).
flags = {'-O', '-largeArrayDims', ...
         'CFLAGS=$CFLAGS -std=gnu17 -fno-strict-aliasing -fwrapv'};
sources = {'cvx_eliminate_mex.c', 'cvx_bcompress_mex.c'};

for i = 1:numel(sources)
    fprintf('  [%d/%d] %s\n', i, numel(sources), sources{i});
    mex(flags{:}, '-outdir', libDir, fullfile(libDir, sources{i}));
end

fprintf('=== CVX MEX compilation complete ===\n');
