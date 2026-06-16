% Build the FINUFFT MEX (Windows / MSVC).
% compile.m runs with cwd set to the package source root (the full finufft repo).
%
% The channel's default Windows MEX compiler is MinGW-w64, but FINUFFT's
% interpolation code miscompiles there (type-2 transforms hit an access
% violation at runtime). MSVC is MATLAB's native Windows MEX compiler and
% builds FINUFFT + DUCC0 correctly, so — like gptoolbox — we use MSVC for both
% the CMake static-library build and the MEX link (overriding the channel
% default MinGW selected by bundle_one).

fprintf('=== Compiling FINUFFT MEX file (Windows/MSVC) ===\n');

setup_mex_compilers('windows_x86_64', 'msvc');

srcRoot = pwd;
buildDir = fullfile(srcRoot, 'build_mex');
if ~exist(buildDir, 'dir')
    mkdir(buildDir);
end

% Step 1: Build the FINUFFT static library with CMake (Visual Studio / MSVC).
fprintf('Configuring FINUFFT with CMake (Visual Studio / MSVC)...\n');
cfgCmd = sprintf(['cmake -S "%s" -B "%s" -G "Visual Studio 17 2022" -A x64', ...
    ' -DCMAKE_BUILD_TYPE=Release', ...
    ' -DFINUFFT_USE_OPENMP=OFF', ...
    ' -DFINUFFT_USE_DUCC0=ON', ...
    ' -DFINUFFT_STATIC_LINKING=ON', ...
    ' -DFINUFFT_BUILD_TESTS=OFF', ...
    ' -DFINUFFT_BUILD_EXAMPLES=OFF', ...
    ' -DFINUFFT_ENABLE_INSTALL=OFF', ...
    ' -DFINUFFT_ARCH_FLAGS=/arch:AVX2', ...                 % portable ISA, not the build CPU's
    ' -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded', ...      % static CRT (/MT)
    ' -DCMAKE_POLICY_DEFAULT_CMP0091=NEW'], srcRoot, buildDir);
[status, output] = system(cfgCmd, '-echo');
if status ~= 0
    error('CMake configuration failed (exit code %d)', status);
end

fprintf('Building FINUFFT static library...\n');
buildCmd = sprintf('cmake --build "%s" --config Release --target finufft -j%d', ...
    buildDir, feature('numcores'));
[status, output] = system(buildCmd, '-echo');
if status ~= 0
    error('CMake build failed (exit code %d)', status);
end

% Step 2: Locate the static libraries (MSVC puts them under a Release/ subdir).
libFinufft = fullfile(buildDir, 'src', 'Release', 'finufft.lib');
if ~exist(libFinufft, 'file')
    libFinufft = fullfile(buildDir, 'src', 'finufft.lib');
end
libCommon = fullfile(buildDir, 'src', 'common', 'Release', 'finufft_common.lib');
if ~exist(libCommon, 'file')
    libCommon = fullfile(buildDir, 'src', 'common', 'finufft_common.lib');
end
ducc0Path = find_file_recursive(buildDir, 'ducc0.lib');

if ~exist(libFinufft, 'file')
    error('finufft library not found at %s', libFinufft);
end
if ~exist(libCommon, 'file')
    error('finufft_common library not found at %s', libCommon);
end
fprintf('Libraries found:\n  finufft: %s\n  common:  %s\n', libFinufft, libCommon);
if ~isempty(ducc0Path)
    fprintf('  ducc0:   %s\n', ducc0Path);
end

% Step 3: Compile the MEX file with MSVC.
fprintf('Compiling MEX file...\n');
mexArgs = {fullfile(srcRoot, 'matlab', 'finufft.cpp'), ...
    ['-I' fullfile(srcRoot, 'include')], ...
    '-R2018a', '-DR2008OO', ...
    libFinufft, libCommon};
if ~isempty(ducc0Path)
    mexArgs{end+1} = ducc0Path;
end
% Static CRT (/MT) so the .mexw64 bakes in the MSVC C++ runtime and is
% self-contained — the test runner strips the build environment, and MATLAB's
% own (older) msvcp140.dll lacks symbols DUCC0 needs. Appending /MT after the
% mexopts default /MD makes cl.exe warn (D9025) and use /MT; /NODEFAULTLIB
% drops the dynamic-CRT import lib so the link is fully static.
mexArgs{end+1} = 'COMPFLAGS=$COMPFLAGS /O2 /MT';
mexArgs{end+1} = 'LINKFLAGS=$LINKFLAGS /NODEFAULTLIB:msvcrt';
mexArgs{end+1} = '-output';
mexArgs{end+1} = fullfile(srcRoot, 'matlab', 'finufft');
mex(mexArgs{:});

fprintf('=== FINUFFT MEX compilation complete ===\n');


function filepath = find_file_recursive(searchDir, filename)
    result = dir(fullfile(searchDir, '**', filename));
    if ~isempty(result)
        filepath = fullfile(result(1).folder, result(1).name);
    else
        filepath = '';
    end
end
