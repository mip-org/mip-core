% compile.m
% Compile FINUFFT MEX file for MIP package distribution.
%
% This script is intended to be run by mip-core's compile_packages.m.
% The working directory is the .dir root, which contains:
%   finufft_src/     - full finufft repo (build_only)
%   finufft_matlab/  - matlab/ subdirectory from finufft

fprintf('=== Compiling FINUFFT MEX file ===\n');

scriptDir = fileparts(mfilename('fullpath'));
finufftSrc = fullfile(scriptDir, 'finufft_src');
finufftMatlab = fullfile(scriptDir, 'finufft_matlab');
buildDir = fullfile(scriptDir, 'build_mex');

% Step 1: Build FINUFFT static libraries using CMake
fprintf('Configuring FINUFFT with CMake...\n');
if ~exist(buildDir, 'dir')
    mkdir(buildDir);
end

cmakeCmd = sprintf([ ...
    'cmake "%s" -B "%s"' ...
    ' -DCMAKE_BUILD_TYPE=Release' ...
    ' -DFINUFFT_USE_OPENMP=OFF' ...
    ' -DFINUFFT_USE_DUCC0=ON' ...
    ' -DFINUFFT_STATIC_LINKING=ON' ...
    ' -DFINUFFT_BUILD_TESTS=OFF' ...
    ' -DFINUFFT_BUILD_EXAMPLES=OFF' ...
    ' -DFINUFFT_ENABLE_INSTALL=OFF' ...
    ' -DCMAKE_C_FLAGS="-fPIC"' ...
    ' -DCMAKE_CXX_FLAGS="-fPIC"'], ...
    finufftSrc, buildDir);

[status, output] = system(cmakeCmd);
fprintf('%s', output);
if status ~= 0
    error('CMake configuration failed (exit code %d)', status);
end

% Build static library
fprintf('Building FINUFFT static library...\n');
nproc = maxNumCompThreads;
buildCmd = sprintf('cmake --build "%s" --target finufft -j%d', buildDir, nproc);
[status, output] = system(buildCmd);
fprintf('%s', output);
if status ~= 0
    error('CMake build failed (exit code %d)', status);
end

% Step 2: Find static libraries
libFinufft = fullfile(buildDir, 'src', 'libfinufft.a');
libCommon = fullfile(buildDir, 'src', 'common', 'libfinufft_common.a');
if ~exist(libFinufft, 'file')
    error('libfinufft.a not found at %s', libFinufft);
end
if ~exist(libCommon, 'file')
    error('libfinufft_common.a not found at %s', libCommon);
end

% Find libducc0.a
[~, ducc0Path] = system(sprintf('find "%s" -name "libducc0.a" -print -quit 2>/dev/null', buildDir));
ducc0Path = strtrim(ducc0Path);

fprintf('Libraries found:\n');
fprintf('  finufft: %s\n', libFinufft);
fprintf('  common:  %s\n', libCommon);
if ~isempty(ducc0Path) && exist(ducc0Path, 'file')
    fprintf('  ducc0:   %s\n', ducc0Path);
end

% Step 3: Compile MEX file
fprintf('Compiling MEX file...\n');

mexSrc = fullfile(finufftMatlab, 'finufft.cpp');
includeDir = fullfile(finufftSrc, 'include');

mexArgs = {mexSrc, ...
    ['-I' includeDir], ...
    '-R2018a', ...
    '-DR2008OO', ...
    libFinufft, libCommon};

if ~isempty(ducc0Path) && exist(ducc0Path, 'file')
    mexArgs{end+1} = ducc0Path;
end

% Platform-specific flags
if isunix && ~ismac
    mexArgs{end+1} = 'LDFLAGS=$LDFLAGS -static-libstdc++ -static-libgcc';
end

% Output MEX file into finufft_matlab/ (which is on the addpath)
mexArgs{end+1} = '-output';
mexArgs{end+1} = fullfile(finufftMatlab, 'finufft');

mex(mexArgs{:});

fprintf('=== FINUFFT MEX compilation complete ===\n');
