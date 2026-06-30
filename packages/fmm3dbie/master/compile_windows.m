function compile_windows()

% Build the fmm3dbie MEX file (Windows / MinGW-w64). cwd is the package source
% root.
%
% We cannot use the makefile's `matlab` target directly: its FMM3D dependency
% (STATICLIBFMM) shells out to a hardcoded `cd FMM3D && make ...` -- there is no
% `make` on the MinGW runner, only `mingw32-make` -- and its default MEXLIBS
% carries -ldl/-lm, which do not exist on Windows. Instead we drive the build in
% three explicit steps (mingw32-make never invokes a nested `make`), then link
% the gateway with mex() for full control.
%
% Windows follows the upstream make.inc.windows.* convention: -fno-underscoring
% Fortran + -DMWF77_UNDERSCORE0 gateway -- note this is the OPPOSITE ABI from the
% Linux/macOS build (default underscoring + MWF77_UNDERSCORE1). The whole build
% (vendored FMM3D, fmm3dbie objects, gateway) uses that one ABI so symbols
% match. BLAS/LAPACK resolve to MATLAB's -lmwblas/-lmwlapack. The MinGW-w64
% toolchain is selected by setup_mex_compilers; mingw64.xml links -static, so
% the .mexw64 bakes in libgfortran/libquadmath/libgomp and needs no runtime
% bundling. See notes/MATLAB-MINGW.md.

fprintf('Compiling fmm3dbie MEX file (Windows/MinGW-w64)...\n');

% Windows build config (mirrors make.inc.windows.mexci; it already omits
% -march=native). -fno-underscoring matches -DMWF77_UNDERSCORE0 in the link.
make_inc = {
    'CC=gcc'
    'CXX=g++'
    'FC=gfortran'
    'FFLAGS=-fPIC -O3 -funroll-loops -std=legacy -fno-underscoring -w'
    'FFLAGS2=-fPIC -std=legacy -fno-underscoring -w'
    'CFLAGS=-fPIC -O3 -funroll-loops -std=gnu17 -w'
    'OMPFLAGS=-fopenmp'
    'OMPLIBS=-lgomp'
};
writelines(make_inc, 'make.inc');

% Module-output (-J .mod/) and archive dirs must exist for both libraries.
for d = {'.mod', fullfile('FMM3D', '.mod'), 'lib-static', 'lib', ...
         fullfile('FMM3D', 'lib-static'), fullfile('FMM3D', 'lib')}
    if ~exist(d{1}, 'dir'); mkdir(d{1}); end
end

% Step 1: build the vendored FMM3D static library. Its makefile's libfmm3d.a
% rule runs under bare mingw32-make (the fmm3d package builds it the same way).
% Copy our make.inc in so FMM3D compiles with the same -fno-underscoring ABI.
copyfile('make.inc', fullfile('FMM3D', 'make.inc'));
status = system('mingw32-make -C FMM3D libfmm3d.a');
if status ~= 0
    error('fmm3dbie:fmm3dLibFailed', ...
        'building FMM3D/libfmm3d.a failed with exit code %d', status);
end
% MinGW ar (invoked from the makefile's sh recipes) wants forward slashes.
lfmm = strrep(fullfile(pwd, 'FMM3D', 'lib-static', 'libfmm3d.a'), '\', '/');

% Step 2: build fmm3dbie's MATLAB static library, merging in FMM3D's objects.
% Drive MSTATICLIBFMM3DBIE directly (bypassing STATICLIBFMM and its hardcoded
% `make`), passing the FMM3D archive it expects via LFMMSTATICLIB. No -j: the
% multiscale-mesher Fortran modules must compile in the makefile's listed order.
status = system(sprintf( ...
    'mingw32-make MSTATICLIBFMM3DBIE LFMMSTATICLIB="%s"', lfmm));
if status ~= 0
    error('fmm3dbie:matlabLibFailed', ...
        'building libfmm3dbie_matlab.a failed with exit code %d', status);
end
staticLib = fullfile('lib-static', 'libfmm3dbie_matlab.a');

% Step 3: link the mwrap gateway into the MEX.
%   -DMWF77_UNDERSCORE0  match the -fno-underscoring Fortran ABI above.
%   -Dint64_t=int64_T    the gateway is mwrap -i8 (uses int64_t) but never
%                        includes <stdint.h>; MinGW-w64 8.1.0 does not resolve
%                        int64_t through the MATLAB header chain, so map it to
%                        MATLAB's int64_T (defined by tmwtypes.h). See fmm3d.
[s, fdir] = system('gfortran -print-file-name=libgfortran.a');
if s ~= 0
    error('fmm3dbie:gfortran', 'could not locate gfortran runtime libraries');
end
fdir = fileparts(strtrim(fdir));

mex('-compatibleArrayDims', '-DMWF77_UNDERSCORE0', '-D_OPENMP', ...
    '-Dint64_t=int64_T', ...
    fullfile('matlab', 'fmm3dbie_routs.c'), staticLib, ...
    ['-L' fdir], '-lgfortran', '-lquadmath', '-lgomp', '-lmwblas', '-lmwlapack', ...
    '-outdir', 'matlab', '-output', 'fmm3dbie_routs');

fprintf('fmm3dbie MEX compilation completed.\n');

end
