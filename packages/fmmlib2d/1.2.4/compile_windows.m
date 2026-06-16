function compile_windows()

% Build the fmmlib2d MEX (Windows). cwd is the package source root.
%
% Compile the upstream Fortran in src/ with gfortran, then link the mwrap
% gateway matlab/fmm2d.c against the objects. The MinGW-w64 toolchain is
% selected by setup_mex_compilers, so here we just call gfortran and an
% unadorned mex(). mingw64.xml links -static, so the .mexw64 bakes in
% libgfortran/libquadmath/libgomp and needs no bundling. OpenMP is enabled.
% See notes/MATLAB-MINGW.md.

fprintf('=== Compiling fmmlib2d MEX file (Windows/MinGW-w64) ===\n');

srcRoot = pwd;
fSrcDir = fullfile(srcRoot, 'src');
matlabDir = fullfile(srcRoot, 'matlab');

fSources = { ...
    'hfmm2dpart.f', 'hfmm2drouts.f', 'd2tstrcr_omp.f', 'd2mtreeplot.f', ...
    'h2dterms.f', 'helmrouts2d.f', 'cdjseval2d.f', 'hank103.f', ...
    'prini.f', 'cfmm2dpart.f', 'zfmm2dpart.f', 'lfmm2dpart.f', ...
    'rfmm2dpart.f', 'lfmm2drouts.f', 'l2dterms.f', 'laprouts2d.f'};

buildDir = fullfile(srcRoot, 'build_mex');
if ~exist(buildDir, 'dir')
    mkdir(buildDir);
end

fflags = '-O3 -std=legacy -funroll-loops -fopenmp -w';

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

% Directory holding libgfortran.a / libquadmath.a / libgomp.a, for -L.
[s, fdir] = system('gfortran -print-file-name=libgfortran.a');
if s ~= 0
    error('fmmlib2d: could not locate gfortran runtime libraries');
end
fdir = fileparts(strtrim(fdir));
fprintf('gfortran runtime dir: %s\n', fdir);

% -DMWF77_UNDERSCORE1 selects gfortran's single-trailing-underscore symbol
% mangling for the mwrap gateway.
mexArgs = {'-largeArrayDims', '-DMWF77_UNDERSCORE1', mexGateway};
for i = 1:numel(objs)
    mexArgs{end+1} = objs{i}; %#ok<AGROW>
end
mexArgs{end+1} = ['-L' fdir];
mexArgs{end+1} = '-lgfortran';
mexArgs{end+1} = '-lquadmath';
mexArgs{end+1} = '-lgomp';
mexArgs{end+1} = '-output';
mexArgs{end+1} = fullfile(matlabDir, 'fmm2d');

mex(mexArgs{:});

fprintf('=== fmmlib2d MEX compilation complete ===\n');

end
