% Channel post-install test for JIGSAW(GEO).
% This package is an examples + datasets companion to jigsaw. The test
% confirms the jigsaw dependency is available and that the bundled
% geographic datasets load via JIGSAW's mesh I/O.

fprintf('=== Testing JIGSAW(GEO) ===\n');

mip load jigsaw
assert(~isempty(which('example')), 'example.m (JIGSAW-GEO) is not on the path');
assert(~isempty(which('jigsaw')), 'jigsaw dependency (jigsaw) not on the path');
assert(~isempty(which('loadmsh')), 'jigsaw dependency (loadmsh) not on the path');

initjig;   % JIGSAW global constants

% Load the bundled example datasets via JIGSAW's reader.
root = fileparts(which('example'));
files = {'aust.msh', 'us48.msh', 'topo.msh'};
for k = 1:numel(files)
    fpath = fullfile(root, 'files', files{k});
    assert(exist(fpath, 'file') == 2, 'missing bundled dataset: %s', files{k});
    m = loadmsh(fpath);
    assert(isstruct(m) && isfield(m, 'mshID'), 'failed to load %s', files{k});
    assert(isfield(m, 'point') && ~isempty(m.point.coord), ...
        'dataset %s has no point data', files{k});
    fprintf('  loaded %s (%s, %d points)\n', files{k}, m.mshID, size(m.point.coord, 1));
end

fprintf('=== JIGSAW(GEO) test passed ===\n');
