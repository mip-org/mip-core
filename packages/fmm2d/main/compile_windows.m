function compile()

% Build the fmm2d MEX (Windows). cwd is the package source root.
%
% The MinGW-w64 toolchain is selected by setup_mex_compilers, so here we
% just call gfortran/mingw32-make and an unadorned mex(). mingw64.xml links
% -static, so the .mexw64 bakes in libgfortran/libgomp/... and needs no
% runtime-library bundling. See notes/MATLAB-MINGW.md.

fprintf('Compiling fmm2d MEX files (Windows/MinGW-w64)...\n');

make_inc = {
    'CC=gcc'
    'CXX=g++'
    'FC=gfortran'
    'FFLAGS=-O3 -funroll-loops -std=legacy -w'
    'CFLAGS=-O3 -funroll-loops -w'
    'OMPFLAGS=-fopenmp'
    'OMPLIBS=-lgomp'
};
writelines(make_inc, 'make.inc');

% The MEX needs only the static library, not the shared .dll.
status = system('mingw32-make libfmm2d.a');
if status ~= 0
    error('fmm2d:makeLibFailed', 'mingw32-make libfmm2d.a failed with exit code %d', status);
end

% Directory holding libgfortran.a / libquadmath.a / libgomp.a, for -L.
[s, fdir] = system('gfortran -print-file-name=libgfortran.a');
if s ~= 0
    error('fmm2d:gfortran', 'could not locate gfortran runtime libraries');
end
fdir = fileparts(strtrim(fdir));

mex('-compatibleArrayDims', '-DMWF77_UNDERSCORE1', '-D_OPENMP', ...
    fullfile('matlab', 'fmm2d.c'), fullfile('lib-static', 'libfmm2d.a'), ...
    ['-L' fdir], '-lgfortran', '-lquadmath', '-lgomp', ...
    '-outdir', 'matlab', '-output', 'fmm2d');

fprintf('fmm2d MEX compilation completed.\n');

end
