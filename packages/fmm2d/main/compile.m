function compile()

% Compile MEX files for fmm2d
% compile.m runs with cwd set to the package source root

% Add Homebrew path so that gfortran can be found on macOS
setenv('PATH', ['/opt/homebrew/bin:' getenv('PATH')]);

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

if ~ismac()
    % Bundle runtime-library deps (libgfortran, libgomp, ...) next to each MEX.
    mexFiles = dir(fullfile('matlab', '*.mex*'));
    for i = 1:numel(mexFiles)
        bundle_runtime_libs(fullfile(mexFiles(i).folder, mexFiles(i).name));
    end
end

fprintf('fmm2d MEX compilation completed.\n');

end
