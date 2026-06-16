% compile.m — compile SPM MEX files via the upstream Makefile system.
% Runs with cwd set to the package source root.
%
% SPM's src/Makefile builds every MEX file at the repo root, recurses
% into SUBDIRS (@file_array/private, @gifti/private, @xmltree/private,
% toolbox/FieldMap) via its own subdir Makefiles, and then a separate
% `make external` pass builds fieldtrip and bemcp. Per SPM's upstream
% compilation docs (https://www.fil.ion.ucl.ac.uk/spm/docs/development/compilation/),
% the full sequence from src/ is:
%
%   make distclean
%   make && make install
%   make external-distclean
%   make external && make external-install
%
% On Linux we patch Makefile.var to append -static-libstdc++ / -static-libgcc
% to MEXOPTS so the two C++ MEX files (spm_mesh_dist, spm_mesh_geodesic)
% do not pull in a specific libstdc++ version at load time. macOS libc++
% is OS-provided and Apple Clang does not accept -static-libstdc++.
% Windows is handled by the [any] fallback build (no MEX compiled).

fprintf('=== Compiling SPM MEX files ===\n');

% MATLAB on Linux injects its own libcurl/libssl into LD_LIBRARY_PATH,
% which can break system tools invoked from make (curl, etc.). Clear it
% for the duration of the build and restore on exit.
if isunix && ~ismac
    origLdPath = getenv('LD_LIBRARY_PATH');
    setenv('LD_LIBRARY_PATH', '');
    restoreLdPath = onCleanup(@() setenv('LD_LIBRARY_PATH', origLdPath));
end

srcRoot = pwd;
srcDir = fullfile(srcRoot, 'src');
if ~exist(srcDir, 'dir')
    error('src/ directory not found at %s', srcDir);
end

mexBin = fullfile(matlabroot, 'bin', 'mex');
if ~exist(mexBin, 'file')
    error('mex binary not found at %s', mexBin);
end

if isunix && ~ismac
    makeVarPath = fullfile(srcDir, 'Makefile.var');
    fid = fopen(makeVarPath, 'r'); text = fread(fid, '*char')'; fclose(fid);
    marker = 'MEXOPTS      = -O -largeArrayDims';
    if ~contains(text, marker)
        error(['Could not locate expected MEXOPTS line in Makefile.var. ' ...
               'Upstream layout may have changed — update the patch in compile.m.']);
    end
    injection = [newline 'MEXOPTS      += LDFLAGS=''$$LDFLAGS -static-libstdc++ -static-libgcc'''];
    text = strrep(text, marker, [marker injection]);
    fid = fopen(makeVarPath, 'w'); fwrite(fid, text); fclose(fid);
    fprintf('Patched Makefile.var with static libstdc++/libgcc linker flags.\n');
end

makeArgs = sprintf('MEXBIN="%s"', mexBin);
if ismac && strcmp(computer('arch'), 'maca64')
    makeArgs = [makeArgs ' PLATFORM=arm64'];
end
jflag = sprintf('-j%d', maxNumCompThreads);

targets = {'distclean', 'external-distclean', ...
           'all', 'install', ...
           'external', 'external-install'};
for k = 1:numel(targets)
    cmd = sprintf('make -C "%s" %s %s %s', srcDir, makeArgs, jflag, targets{k});
    fprintf('>>> %s\n', cmd);
    [status, output] = system(cmd);
    fprintf('%s', output);
    if status ~= 0
        error('make %s failed (exit code %d)', targets{k}, status);
    end
end

fprintf('=== SPM MEX compilation complete ===\n');
