% Pure-MATLAB smoke test for SPM.
%
% Exercises a handful of pure-MATLAB entry points to confirm the package
% is on the path. No MEX functions are called — this script runs on the
% [any] fallback build.

rng('default');

fprintf('Testing that spm.m is on the path...\n');
assert(~isempty(which('spm')), 'spm.m is not on the MATLAB path');

fprintf('Testing spm_file...\n');
b = spm_file('/tmp/foo.txt', 'basename');
assert(strcmp(b, 'foo'), ...
    sprintf('spm_file basename returned "%s", expected "foo"', b));
e = spm_file('/tmp/foo.txt', 'ext');
assert(strcmp(e, 'txt'), ...
    sprintf('spm_file ext returned "%s", expected "txt"', e));

fprintf('Testing spm_str_manip...\n');
s = spm_str_manip('/tmp/foo.txt', 't');
assert(strcmp(s, 'foo.txt'), ...
    sprintf('spm_str_manip ''t'' returned "%s", expected "foo.txt"', s));

fprintf('Testing spm_platform...\n');
ext = spm_platform('mexext');
assert(ischar(ext) && startsWith(ext, 'mex'), ...
    sprintf('spm_platform(''mexext'') returned "%s", expected something starting with "mex"', ext));

fprintf('SUCCESS\n');
