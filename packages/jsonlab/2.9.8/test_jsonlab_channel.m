% Channel post-install test for JSONLab (pure MATLAB).
% Round-trips MATLAB data through JSON and binary JSON (BJData).

fprintf('=== Testing JSONLab ===\n');

assert(~isempty(which('savejson')), 'savejson is not on the path');
assert(~isempty(which('loadjson')), 'loadjson is not on the path');
assert(~isempty(which('savebj')), 'savebj is not on the path');

s = struct();
s.name = 'abc';
s.vals = [1 2 3; 4 5 6];
s.nested = struct('flag', true, 'scalar', 3.14159);
s.list = {1, 'two', [3 3 3]};

% --- Text JSON round-trip ---
js = savejson('', s);
assert(ischar(js) && ~isempty(js), 'savejson produced no output');
s2 = loadjson(js);
assert(isequal(s.vals, s2.vals), 'JSON round-trip changed numeric array');
assert(strcmp(s.name, s2.name), 'JSON round-trip changed string field');
assert(s2.nested.flag == true && abs(s2.nested.scalar - pi) < 1e-4, ...
    'JSON round-trip changed nested struct');
fprintf('  JSON round-trip OK\n');

% --- Binary JSON (BJData) round-trip ---
% numbl does not support the binary JSON path (savebj/loadbj). It relies on
% MATLAB integer classes (uint8/uint16/uint32 and typecast) for byte-level
% packing, and numbl does not track integer classes (e.g. uint32(x) is a
% double there, isinteger is false). The text JSON path above works under
% numbl; skip the binary round-trip when running under numbl.
if exist('isnumbl', 'builtin') == 5 && isnumbl()
    fprintf('  binary-JSON round-trip SKIPPED (not supported under numbl)\n');
else
    bj = savebj('', s);
    s3 = loadbj(bj);
    assert(isequal(s.vals, s3.vals), 'BJData round-trip changed numeric array');
    assert(strcmp(s.name, s3.name), 'BJData round-trip changed string field');
    fprintf('  binary-JSON round-trip OK\n');
end

fprintf('=== JSONLab test passed ===\n');
