function copy_and_sanitize_lib(sourceLib, destDir)
%COPY_AND_SANITIZE_LIB   Copy a dynamic library and rewrite its identity.
%
% Copies <sourceLib> into <destDir>, then rewrites the copy's SONAME
% (Linux) or install_name (macOS) to a basename-only form and sets its
% rpath to $ORIGIN / @loader_path so it can find sibling libraries when
% loaded from the bundle.

persistent copy_and_sanitize_lib_

if isempty(copy_and_sanitize_lib_)
    switch computer('arch')
        case 'glnxa64'
            copy_and_sanitize_lib_ = @copy_and_sanitize_lib_linux;
        case {'maca64', 'maci64'}
            copy_and_sanitize_lib_ = @copy_and_sanitize_lib_macos;
        case 'win64'
            error('mip:copyAndSanitizeLib:windowsUnsupported', ...
                  'Windows is not yet supported.');
        otherwise
            error('mip:copyAndSanitizeLib:unsupportedArch', ...
                  'Unsupported architecture.');
    end
end

copy_and_sanitize_lib_(sourceLib, destDir);

end

function copy_and_sanitize_lib_linux(sourceLib, destDir)

    cmd = sprintf('cp -Lf %s %s\n', sourceLib, destDir);
    system_echo(cmd);

    [~, lib_name, lib_ext] = fileparts(sourceLib);
    lib = [lib_name lib_ext];
    local_lib = fullfile(destDir, lib);

    cmd = sprintf('patchelf --set-soname %s          %s', lib, local_lib);
    system_echo(cmd);

    cmd = sprintf('patchelf --set-rpath ''$ORIGIN'' %s', local_lib);
    system_echo(cmd);
end

function copy_and_sanitize_lib_macos(sourceLib, destDir)

    cmd = sprintf('cp -Lf %s %s', sourceLib, destDir);
    system_echo(cmd);

    [~, lib_name, lib_ext] = fileparts(sourceLib);
    lib = [lib_name lib_ext];
    local_lib = fullfile(destDir, lib);

    cmd = sprintf('install_name_tool -id @rpath/%s %s', lib, local_lib);
    system_echo(cmd);

    cmd = sprintf('install_name_tool -add_rpath @loader_path %s', local_lib);
    system_echo(cmd);

end
