% Compile JIGSAW's C++ backend via CMake.
% compile.m runs with cwd set to the package source root.
%
% JIGSAW's MATLAB interface drives a set of standalone C++ executables
% (jigsaw / tripod / marche) plus a shared library, built from the bundled
% source under external/jigsaw. The interface invokes external/jigsaw/bin/jigsaw
% via system(). We build with the C++ runtime statically linked so the backend
% is portable across end-user systems and does not depend on MATLAB's (older)
% bundled libstdc++ when launched from within MATLAB.

fprintf('=== Compiling JIGSAW C++ backend ===\n');

% MATLAB injects its own (older) libstdc++/libcurl onto the dynamic-library
% path, which breaks cmake and the system compiler when invoked via system().
% Clear it for the duration of the build (restored on exit).
origLd   = getenv('LD_LIBRARY_PATH');
origDyld = getenv('DYLD_LIBRARY_PATH');
setenv('LD_LIBRARY_PATH', '');
setenv('DYLD_LIBRARY_PATH', '');
restoreLd = onCleanup(@() restore_lib_path(origLd, origDyld)); %#ok<NASGU>

here  = pwd;
jdir  = fullfile(here, 'external', 'jigsaw');
bdir  = fullfile(jdir, 'build');

if exist(bdir, 'dir')
    rmdir(bdir, 's');
end

if ispc
    linkFlags = '';
    extraCfg  = ' -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded';   % static MSVC CRT
else
    % Both the Linux and macOS builders use GCC (system gcc on Linux, Homebrew
    % gcc on macOS), so the backend would otherwise link GCC's libstdc++/libgcc
    % dynamically and fail to start under MATLAB's (older) bundled libstdc++.
    linkFlags = '-static-libstdc++ -static-libgcc';
    extraCfg  = '';
end

% Use cmake -S/-B so no directory changes are needed.
cfgCmd = sprintf(['cmake -S "%s" -B "%s" -DCMAKE_BUILD_TYPE=Release ', ...
    '-DCMAKE_EXE_LINKER_FLAGS="%s" -DCMAKE_SHARED_LINKER_FLAGS="%s"%s'], ...
    jdir, bdir, linkFlags, linkFlags, extraCfg);
fprintf('  %s\n', cfgCmd);
[st, out] = system(cfgCmd, '-echo');
if st ~= 0
    error('mip:jigsaw:cmakeConfigure', 'CMake configure failed:\n%s', out);
end

buildCmd = sprintf('cmake --build "%s" --config Release --target install', bdir);
[st, out] = system(buildCmd, '-echo');
if st ~= 0
    error('mip:jigsaw:cmakeBuild', 'CMake build failed:\n%s', out);
end

rmdir(bdir, 's');

% Sanity check: the jigsaw executable must have been produced.
exe = fullfile(jdir, 'bin', 'jigsaw');
if ispc, exe = [exe, '.exe']; end
if ~exist(exe, 'file')
    error('mip:jigsaw:noBinary', 'JIGSAW executable not found at %s', exe);
end

fprintf('=== JIGSAW backend compiled ===\n');


function restore_lib_path(origLd, origDyld)
    setenv('LD_LIBRARY_PATH', origLd);
    setenv('DYLD_LIBRARY_PATH', origDyld);
end
