% Add Homebrew path so that gfortran can be found below
setenv('PATH', ['/opt/homebrew/bin:' getenv('PATH')])

% Compile MEX files for fmm2d
fprintf('Compiling fmm2d MEX files...\n');

% Get the fmm2d directory
fmm2droot = fullfile(fileparts(mfilename('fullpath')), 'fmm2d');

% Change to kdtree directory
orig = pwd;
cd(fmm2droot);

% Set up gfortran compiler
make_inc = {
    'FDIR=$$(dirname `gfortran --print-file-name libgfortran.dylib`)'
    'MFLAGS+=-L${FDIR}'
    'OMPFLAGS=-fopenmp';
    'OMPLIBS=-lgomp';
    'FFLAGS=-fPIC -O3 -funroll-loops -std=legacy -w';
    ['MEX=' fullfile(matlabroot, 'bin', 'mex')]
};
writelines(make_inc, 'make.inc');

% Make the static and dynamic libraries
!make lib

% Build the MEX file using the static library
!make matlab

% Return to original directory
cd(orig);
