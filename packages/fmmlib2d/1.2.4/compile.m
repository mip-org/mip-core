% Compile fmmlib2d MEX file.
% compile.m runs with cwd set to the package source root.
%
% The upstream matlab/fmm2d.c is a pre-generated mwrap gateway; we compile
% the Fortran library sources under src/ to object files, then link them
% with fmm2d.c into a MEX file placed next to the .m shims in matlab/.
% The Fortran/OpenMP runtime (libgfortran, libquadmath, libgomp) is made
% self-contained per platform: statically linked on macOS (Homebrew ships
% the .a archives), and dynamically linked on Linux (the ubi8 build container
% has no static archives), where the build pipeline then vendors the .so files
% next to the MEX automatically (mip.build.bundle_mex_libs). OpenMP is enabled
% (-fopenmp); d2tstrcr_omp.f parallelizes the tree build.

fprintf('=== Compiling fmmlib2d MEX file ===\n');

srcRoot = pwd;
fSrcDir = fullfile(srcRoot, 'src');
matlabDir = fullfile(srcRoot, 'matlab');

if ismac
    setenv('PATH', ['/opt/homebrew/bin:/usr/local/bin:' getenv('PATH')]);
end

if isunix && ~ismac
    origLdPath = getenv('LD_LIBRARY_PATH');
    setenv('LD_LIBRARY_PATH', '');
    restoreLdPath = onCleanup(@() setenv('LD_LIBRARY_PATH', origLdPath));
end

fSources = { ...
    'hfmm2dpart.f', 'hfmm2drouts.f', 'd2tstrcr_omp.f', 'd2mtreeplot.f', ...
    'h2dterms.f', 'helmrouts2d.f', 'cdjseval2d.f', 'hank103.f', ...
    'prini.f', 'cfmm2dpart.f', 'zfmm2dpart.f', 'lfmm2dpart.f', ...
    'rfmm2dpart.f', 'lfmm2drouts.f', 'l2dterms.f', 'laprouts2d.f'};

buildDir = fullfile(srcRoot, 'build_mex');
if ~exist(buildDir, 'dir')
    mkdir(buildDir);
end

fflags = '-O3 -fPIC -std=legacy -funroll-loops -fopenmp -w';

objs = cell(1, numel(fSources));
for i = 1:numel(fSources)
    srcFile = fullfile(fSrcDir, fSources{i});
    if ~exist(srcFile, 'file')
        error('fmmlib2d: missing Fortran source %s', srcFile);
    end
    [~, base] = fileparts(srcFile);
    objFile = fullfile(buildDir, [base '.o']);
    cmd = sprintf('gfortran %s -c "%s" -o "%s"', fflags, srcFile, objFile);
    fprintf('%s\n', cmd);
    [status, output] = system(cmd);
    fprintf('%s', output);
    if status ~= 0
        error('fmmlib2d: gfortran failed for %s (exit %d)', srcFile, status);
    end
    objs{i} = objFile;
end

mexGateway = fullfile(matlabDir, 'fmm2d.c');

mexArgs = {'-largeArrayDims', mexGateway};
for i = 1:numel(objs)
    mexArgs{end+1} = objs{i}; %#ok<AGROW>
end

if ismac
    % Homebrew gfortran ships static archives (libgfortran.a / libquadmath.a
    % / libgomp.a), so bake the Fortran/OpenMP runtime into the MEX; libc++
    % and the system runtime come from the OS. libgomp is listed last so the
    % Fortran objects' GOMP_* references resolve against it.
    libgfortran_a = strtrim(run_cmd('gfortran --print-file-name=libgfortran.a'));
    libquadmath_a = strtrim(run_cmd('gfortran --print-file-name=libquadmath.a'));
    libgomp_a = strtrim(run_cmd('gfortran --print-file-name=libgomp.a'));
    fprintf('libgfortran: %s\n', libgfortran_a);
    fprintf('libquadmath: %s\n', libquadmath_a);
    fprintf('libgomp: %s\n', libgomp_a);
    mexArgs{end+1} = libgfortran_a;
    mexArgs{end+1} = libquadmath_a;
    mexArgs{end+1} = libgomp_a;
else
    % Linux: the ubi8 build container provides only the shared libgfortran /
    % libgomp (no static archives), so link them dynamically; the build
    % pipeline then vendors the .so files next to the MEX with an $ORIGIN
    % RPATH (mip.build.bundle_mex_libs). This is the channel's standard
    % self-containment path on Linux. Resolve the runtime dir from the shared
    % libgfortran so -L points at the system gcc, not MATLAB's bundled libs.
    % Only libgfortran/libgomp are required (the FMM code uses no quad
    % precision, so libquadmath is not linked). The workflow's strip-then-
    % test gate is the backstop: it deletes the toolchain and reruns the test
    % against the bundle, so any missing runtime dep fails the build instead
    % of shipping a MEX that won't load.
    fdir = fileparts(strtrim(run_cmd('gfortran --print-file-name=libgfortran.so')));
    fprintf('gfortran runtime dir: %s\n', fdir);
    mexArgs{end+1} = ['-L' fdir];
    mexArgs{end+1} = '-lgfortran';
    mexArgs{end+1} = '-lgomp';
end

mexArgs{end+1} = '-output';
mexArgs{end+1} = fullfile(matlabDir, 'fmm2d');

mex(mexArgs{:});

fprintf('=== fmmlib2d MEX compilation complete ===\n');


function out = run_cmd(cmd)
    [status, out] = system(cmd);
    if status ~= 0
        error('fmmlib2d: command failed (%d): %s\n%s', status, cmd, out);
    end
end
