function compile()

% Compile MEX files for fmm2d
% compile.m runs with cwd set to the package source root

% Add Homebrew paths so gfortran is found on macOS. Homebrew's prefix differs
% by arch: /opt/homebrew on Apple Silicon (macos_arm64), /usr/local on Intel
% (macos_x86_64). Prepend both so the build works on either Mac.
setenv('PATH', ['/opt/homebrew/bin:/usr/local/bin:' getenv('PATH')]);

fprintf('Compiling fmm2d MEX files...\n');

% Set up gfortran compiler. The shared library extension differs by OS:
% .dylib on macOS, .so on Linux.
if ismac
    libgfortran_name = 'libgfortran.dylib';
else
    libgfortran_name = 'libgfortran.so';
end

make_inc = {
    ['FDIR=$$(dirname `gfortran --print-file-name ' libgfortran_name '`)']
    'MFLAGS+=-L${FDIR}'
    'OMPFLAGS=-fopenmp';
    'OMPLIBS=-lgomp';
    'FFLAGS=-fPIC -O3 -funroll-loops -std=legacy -w';
    ['MEX=' fullfile(matlabroot, 'bin', 'mex')]
};
writelines(make_inc, 'make.inc');

% Make the static and dynamic libraries
status = system('make lib');
if status ~= 0
    error('fmm2d:makeLibFailed', 'make lib failed with exit code %d', status);
end

% Build the MEX file
status = system('make matlab');
if status ~= 0
    error('fmm2d:makeMatlabFailed', 'make matlab failed with exit code %d', status);
end

fprintf('fmm2d MEX compilation completed.\n');

end
