function compile()

% Compile fmm2d MEX on Windows using MinGW-w64 (gfortran) + MATLAB's
% built-in mingw64 mex configuration. compile.m runs with cwd set to the
% package source root.
%
% The fmm2d library is Fortran; MATLAB's default Windows C compiler (MSVC)
% cannot link gfortran objects, so the C gateway must be compiled by the
% same MinGW toolchain that builds the static library. MATLAB's
% mingw64.xml links -static, so the resulting .mexw64 carries no MinGW
% runtime DLL dependency (libgfortran/libgomp/... are baked in) and needs
% no runtime-library bundling.

mingw = 'C:\mingw64';                       % GCC 15.x with static libgfortran.a
setenv('MW_MINGW64_LOC', mingw);            % let MATLAB's mingw64.xml find it
setenv('PATH', [fullfile(mingw, 'bin') ';' getenv('PATH')]);

fprintf('Compiling fmm2d MEX files (Windows/MinGW-w64)...\n');

make_inc = {
    'CC=gcc'
    'CXX=g++'
    'FC=gfortran'
    'FFLAGS=-O3 -funroll-loops -std=legacy -fallow-argument-mismatch -w'
    'CFLAGS=-O3 -funroll-loops -w'
    'OMPFLAGS=-fopenmp'
    'OMPLIBS=-lgomp'
};
writelines(make_inc, 'make.inc');

% Build the static library (gfortran). The MEX target needs only this, not
% the shared .dll, so build the static lib explicitly.
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

% Link the MEX with MATLAB's MinGW64 options file (forces MinGW over MSVC).
xml = fullfile(matlabroot, 'bin', 'win64', 'mexopts', 'mingw64.xml');
mex('-f', xml, '-compatibleArrayDims', '-DMWF77_UNDERSCORE1', '-D_OPENMP', ...
    fullfile('matlab', 'fmm2d.c'), fullfile('lib-static', 'libfmm2d.a'), ...
    ['-L' fdir], '-lgfortran', '-lquadmath', '-lgomp', ...
    '-outdir', 'matlab', '-output', 'fmm2d');

fprintf('fmm2d MEX compilation completed.\n');

end
