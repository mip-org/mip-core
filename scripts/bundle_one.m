% Bundle a single prepared package directory using `mip bundle`.
%
% Usage (from repo root, after addpath('mip'); addpath('scripts')):
%   bundle_one
%
% Expects:
%   - exactly one directory under build/prepared/ (the one written by
%     scripts/prepare_one.py)
%   - $BUILD_ARCHITECTURE set to the target architecture
%
% Produces: build/bundled/<name>-<version>-<arch>.mhl (+ .mip.json)

fprintf('=== bundle_one ===\n');

preparedDir = fullfile(pwd, 'build', 'prepared');
outputDir = fullfile(pwd, 'build', 'bundled');

architecture = getenv('BUILD_ARCHITECTURE');
if isempty(architecture)
    error('mip:missingArchitecture', ...
        'Environment variable BUILD_ARCHITECTURE is not set');
end

if ~exist(preparedDir, 'dir')
    error('mip:noPrepared', ...
        'No prepared directory at %s', preparedDir);
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

items = dir(preparedDir);
items = items(~startsWith({items.name}, '.') & [items.isdir]);
if isempty(items)
    error('mip:noPreparedSubdir', ...
        'build/prepared/ contains no package subdirectory');
end
if numel(items) > 1
    names = strjoin({items.name}, ', ');
    error('mip:multiplePrepared', ...
        'bundle_one expects exactly one prepared dir, found: %s', names);
end

pkgDir = fullfile(preparedDir, items(1).name);
if ~exist(fullfile(pkgDir, 'mip.yaml'), 'file')
    error('mip:noMipYaml', 'No mip.yaml in %s', pkgDir);
end

fprintf('Setting up MEX compilers...\n');
setup_mex_compilers(architecture);

fprintf('Bundling: %s (arch=%s)\n', items(1).name, architecture);
mip.bundle(pkgDir, '--output', outputDir, '--arch', architecture);
fprintf('Bundle OK\n');
