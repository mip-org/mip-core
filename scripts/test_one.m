% Install, load and test a single bundled .mhl with `mip`.
%
% Usage (from repo root, after addpath('mip'); addpath('scripts')):
%   test_one
%
% Expects exactly one .mhl under build/bundled/ (the one produced by
% bundle_one). Runs:
%   mip install <mhl>
%   mip load    <name>
%   mip test    <name>
% Errors are raised on any failure so the workflow step fails.
%
% After `mip test`, enforces issue #16: every MEX shipped in the package (for
% this architecture) must have been invoked by the test_script. `mip test` runs
% the test_script in this same MATLAB session, so a MEX that was loaded shows up
% in `inmem`; any built-but-never-loaded MEX means the test left it un-exercised
% and we fail the build. No-op for pure-MATLAB packages (no .mex* files).

fprintf('=== test_one ===\n');

setenv('MIP_CONFIRM', 'y');

bundled_dir = fullfile(pwd, 'build', 'bundled');
files = dir(fullfile(bundled_dir, '*.mhl'));
if isempty(files)
    error('mip:noMhl', 'No .mhl files in %s', bundled_dir);
end
if numel(files) > 1
    names = strjoin({files.name}, ', ');
    error('mip:multipleMhl', ...
        'test_one expects exactly one .mhl, found: %s', names);
end

mhl_path = fullfile(files(1).folder, files(1).name);
mip_json_path = [mhl_path '.mip.json'];
info = jsondecode(fileread(mip_json_path));
pkg_name = info.name;

fprintf('Testing: %s (package: %s)\n', files(1).name, pkg_name);

% Install the .mhl as if it came from THIS channel, so dependencies resolve
% from the channel being built rather than the default mip-org/core. In CI,
% repo 'owner/mip-<chan>' maps to channel 'owner/<chan>' (mip's index_url
% convention). Locally (no GITHUB_REPOSITORY) fall back to the default.
installArgs = {mhl_path};
repo = getenv('GITHUB_REPOSITORY');
if ~isempty(repo)
    parts = strsplit(repo, '/');
    if numel(parts) == 2
        channel = sprintf('%s/%s', parts{1}, regexprep(parts{2}, '^mip-', ''));
        fprintf('Resolving dependencies from channel: %s\n', channel);
        installArgs = {'--channel', channel, mhl_path};
    end
end

mip('install', installArgs{:});
mip('load', pkg_name);
mip('test', pkg_name);
assert_all_mex_exercised(pkg_name);
% Uninstalling 'mip' itself is a particularly tricky case (it removes the
% running package), so skip it as part of the package build test.
if strcmp(pkg_name, 'mip')
    fprintf('Skipping uninstall for package "mip".\n');
else
    mip('uninstall', pkg_name);
end

fprintf('OK: %s\n', pkg_name);


function assert_all_mex_exercised(pkg_name)
% issue #16: fail if the test_script left any shipped MEX un-exercised. A MEX
% appears in `inmem` only once it has been invoked, so (built \ loaded) is the
% set the test never ran. Resolve the bare name to an fqn at the boundary,
% then ask mip.build.list_mex for the shipped MEX (scoped to the package's own
% source dir, so dependencies' MEX don't count). No-op when the package ships
% no MEX (pure-MATLAB / `any`).
    r = mip.resolve.resolve_to_installed(pkg_name);
    built = mip.build.list_mex(r.fqn);
    if isempty(built)
        return
    end

    [~, loadedPaths] = inmem('-completenames');
    loaded = cell(size(loadedPaths));
    for i = 1:numel(loadedPaths)
        [~, loaded{i}] = fileparts(loadedPaths{i});
    end

    missing = setdiff(built, loaded);
    if ~isempty(missing)
        error('mip:test:mexNotExercised', ...
            ['Test script for "%s" did not exercise every shipped MEX.\n' ...
             'Un-exercised (built but never loaded): %s'], ...
            pkg_name, strjoin(missing, ', '));
    end
    fprintf('Coverage: all %d shipped MEX exercised by the test.\n', numel(built));
end
