% Compile FINUFFT MEX file
% compile.m runs with cwd set to the package source root (the full finufft repo)

fprintf('=== Compiling FINUFFT MEX file ===\n');

srcRoot = pwd;
buildDir = fullfile(srcRoot, 'build_mex');

% Step 1: Build FINUFFT static libraries using CMake
fprintf('Configuring FINUFFT with CMake...\n');
if ~exist(buildDir, 'dir')
    mkdir(buildDir);
end

% Use FFTW instead of DUCC0 on macOS ARM64 (Apple Clang crashes compiling ducc0 templates)
use_fftw = ismac && strcmp(computer('arch'), 'maca64');
if use_fftw
    ducc0_flag = 'OFF';
else
    ducc0_flag = 'ON';
end

cmakeArgs = { ...
    sprintf('cmake "%s" -B "%s"', srcRoot, buildDir), ...
    ' -DCMAKE_BUILD_TYPE=Release', ...
    ' -DFINUFFT_USE_OPENMP=OFF', ...
    sprintf(' -DFINUFFT_USE_DUCC0=%s', ducc0_flag), ...
    ' -DFINUFFT_STATIC_LINKING=ON', ...
    ' -DFINUFFT_BUILD_TESTS=OFF', ...
    ' -DFINUFFT_BUILD_EXAMPLES=OFF', ...
    ' -DFINUFFT_ENABLE_INSTALL=OFF'};

if use_fftw
    cmakeArgs{end+1} = ' -DCMAKE_PREFIX_PATH=/opt/homebrew';
end

if ispc
    % On Windows with MSVC, must use dynamic runtime (/MD) to match MATLAB's MEX
    cmakeArgs{end+1} = ' -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL';
    cmakeArgs{end+1} = ' -DCMAKE_POLICY_DEFAULT_CMP0091=NEW';
else
    cmakeArgs{end+1} = ' -DCMAKE_C_FLAGS="-fPIC"';
    cmakeArgs{end+1} = ' -DCMAKE_CXX_FLAGS="-fPIC"';
end

cmakeCmd = strjoin(cmakeArgs, '');

[status, output] = system(cmakeCmd);
fprintf('%s', output);
if status ~= 0
    error('CMake configuration failed (exit code %d)', status);
end

% Build static library
fprintf('Building FINUFFT static library...\n');
nproc = maxNumCompThreads;
buildCmd = sprintf('cmake --build "%s" --config Release --target finufft -j%d', buildDir, nproc);
[status, output] = system(buildCmd);
fprintf('%s', output);
if status ~= 0
    error('CMake build failed (exit code %d)', status);
end

% Step 2: Find static libraries
if ispc
    % MSVC puts libs under a Release/ subdirectory
    libFinufft = fullfile(buildDir, 'src', 'Release', 'finufft.lib');
    if ~exist(libFinufft, 'file')
        libFinufft = fullfile(buildDir, 'src', 'finufft.lib');
    end
    libCommon = fullfile(buildDir, 'src', 'common', 'Release', 'finufft_common.lib');
    if ~exist(libCommon, 'file')
        libCommon = fullfile(buildDir, 'src', 'common', 'finufft_common.lib');
    end
else
    libFinufft = fullfile(buildDir, 'src', 'libfinufft.a');
    libCommon = fullfile(buildDir, 'src', 'common', 'libfinufft_common.a');
end

if ~exist(libFinufft, 'file')
    error('finufft library not found at %s', libFinufft);
end
if ~exist(libCommon, 'file')
    error('finufft_common library not found at %s', libCommon);
end

% Find ducc0 library
if ispc
    ducc0Path = find_file_recursive(buildDir, 'ducc0.lib');
else
    ducc0Path = find_file_recursive(buildDir, 'libducc0.a');
end

fprintf('Libraries found:\n');
fprintf('  finufft: %s\n', libFinufft);
fprintf('  common:  %s\n', libCommon);
if ~isempty(ducc0Path)
    fprintf('  ducc0:   %s\n', ducc0Path);
end

% Step 3: Compile MEX file
fprintf('Compiling MEX file...\n');

mexSrc = fullfile(srcRoot, 'matlab', 'finufft.cpp');
includeDir = fullfile(srcRoot, 'include');

mexArgs = {mexSrc, ...
    ['-I' includeDir], ...
    '-R2018a', ...
    '-DR2008OO', ...
    libFinufft, libCommon};

if ~isempty(ducc0Path)
    mexArgs{end+1} = ducc0Path;
end

% Platform-specific flags
if ispc
    mexArgs{end+1} = 'COMPFLAGS=$COMPFLAGS /O2';
elseif isunix && ~ismac
    mexArgs{end+1} = 'LDFLAGS=$LDFLAGS -static-libstdc++ -static-libgcc';
end

% Link FFTW when not using DUCC0
if use_fftw
    mexArgs{end+1} = '-L/opt/homebrew/lib';
    mexArgs{end+1} = '-lfftw3';
    mexArgs{end+1} = '-lfftw3f';
end

% Output MEX file into the matlab/ directory (which is on the addpath)
mexArgs{end+1} = '-output';
mexArgs{end+1} = fullfile(srcRoot, 'matlab', 'finufft');

mex(mexArgs{:});

fprintf('=== FINUFFT MEX compilation complete ===\n');


function filepath = find_file_recursive(searchDir, filename)
    % Find a file by name recursively under searchDir
    result = dir(fullfile(searchDir, '**', filename));
    if ~isempty(result)
        filepath = fullfile(result(1).folder, result(1).name);
    else
        filepath = '';
    end
end
