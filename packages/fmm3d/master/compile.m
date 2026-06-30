function compile()

% Compile the fmm3d MEX files (Linux/macOS).
% compile.m runs with cwd set to the package source root.
%
% Drives the upstream makefile to compile the Fortran sources under src/ into
% the static library lib-static/libfmm3d.a, then links the two checked-in
% mwrap gateways into MEX files placed next to the .m wrappers in matlab/:
%   fmm3d         - the modern API (lfmm3d/hfmm3d/stfmm3d/emfmm3d, *3ddir)
%   fmm3d_legacy  - the legacy CMCL API (lfmm3dpart/hfmm3dpart, *partdirect)
%
% We override the makefile's default FFLAGS *and* CFLAGS to drop -march=native
% (channel builds target a generic CPU of the platform). CFLAGS must be
% overridden too because the makefile bakes it into the mex command line via
% MFLAGS="CFLAGS=$(CFLAGS)" -- the default carries -march=native there as well.
% OpenMP is on by the makefile default. The Fortran/OpenMP runtime
% (libgfortran, libgomp) is linked dynamically; `mip bundle` then vendors those
% next to each .mex* with a relative RPATH (mip.build.bundle_runtime_libs), so
% the shipped MEX is self-contained.

% Add Homebrew path so gfortran is found on macOS.
setenv('PATH', ['/opt/homebrew/bin:' getenv('PATH')]);

fprintf('Compiling fmm3d MEX files...\n');

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
    'CFLAGS=-fPIC -O3 -funroll-loops -std=gnu17'
    ['MEX=' fullfile(matlabroot, 'bin', 'mex')]
};
writelines(make_inc, 'make.inc');

% Build the static library and both MEX gateways. The `matlab` target depends
% on the static library, so this also compiles src/ as needed.
status = system('make matlab');
if status ~= 0
    error('fmm3d:makeMatlabFailed', 'make matlab failed with exit code %d', status);
end

fprintf('fmm3d MEX compilation completed.\n');

end
