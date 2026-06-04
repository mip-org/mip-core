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

fprintf('=== test_one ===\n');

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
mip('uninstall', pkg_name);

fprintf('OK: %s\n', pkg_name);
