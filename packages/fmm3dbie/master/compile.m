function compile()

% Compile the fmm3dbie MEX file (Linux/macOS).
% compile.m runs with cwd set to the package source root.
%
% Drives the upstream makefile's `matlab` target, which:
%   1. builds the vendored FMM3D submodule into FMM3D/lib-static/libfmm3d.a
%      (STATICLIBFMM copies our make.inc into FMM3D and runs its makefile),
%   2. compiles fmm3dbie's own src/ Fortran and merges FMM3D's objects into the
%      static MEX library lib-static/libfmm3dbie_matlab.a, then
%   3. links the checked-in mwrap gateway matlab/fmm3dbie_routs.c against it,
%      producing the single MEX placed next to the .m wrappers: fmm3dbie_routs.
%
% We override the makefile's FFLAGS/FFLAGS2/CFLAGS to drop -march=native
% (channel builds target a generic CPU of the platform); the makefile still
% appends -fopenmp and -J .mod/ to FFLAGS after including make.inc. OpenMP is
% on by default. fmm3dbie links BLAS/LAPACK via the makefile default
% MLBLAS=-lmwblas -lmwlapack (MATLAB's own), so no external BLAS is needed.
% The Fortran/OpenMP runtime (libgfortran, libgomp) is linked dynamically;
% `mip bundle` then vendors those next to the .mex* with a relative RPATH
% (mip.build.bundle_runtime_libs), so the shipped MEX is self-contained.

% Add Homebrew path so gfortran is found on macOS.
setenv('PATH', ['/opt/homebrew/bin:' getenv('PATH')]);

fprintf('Compiling fmm3dbie MEX file...\n');

% The shared-library extension for locating the gfortran runtime dir differs
% by OS: .dylib on macOS, .so on Linux.
if ismac
    libgfortran_name = 'libgfortran.dylib';
else
    libgfortran_name = 'libgfortran.so';
end

make_inc = {
    ['FDIR=$$(dirname `gfortran --print-file-name ' libgfortran_name '`)']
    'MFLAGS+=-L${FDIR}'
    'OMPFLAGS=-fopenmp'
    'OMPLIBS=-lgomp'
    'FFLAGS=-fPIC -O3 -funroll-loops -std=legacy -w'
    'FFLAGS2=-fPIC -std=legacy -w'
    'CFLAGS=-fPIC -O3 -funroll-loops -std=gnu17'
    ['MEX=' fullfile(matlabroot, 'bin', 'mex')]
};
writelines(make_inc, 'make.inc');

% The Fortran module dirs (-J .mod/) must exist for both builds.
system('mkdir -p .mod FMM3D/.mod lib-static lib FMM3D/lib-static FMM3D/lib');

% Build the static libraries and the MEX gateway.
status = system('make matlab');
if status ~= 0
    error('fmm3dbie:makeMatlabFailed', 'make matlab failed with exit code %d', status);
end

fprintf('fmm3dbie MEX compilation completed.\n');

end
