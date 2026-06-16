% MEX-enabled smoke test for SPM.
%
% Exercises the pure-MATLAB layer plus a handful of compiled MEX
% functions so that a broken build/link is caught by `mip test` rather
% than surfacing later in user code.

rng('default');

%% --- Pure MATLAB -------------------------------------------------------

fprintf('Testing that spm.m is on the path...\n');
assert(~isempty(which('spm')), 'spm.m is not on the MATLAB path');

fprintf('Testing spm_file...\n');
b = spm_file('/tmp/foo.txt', 'basename');
assert(strcmp(b, 'foo'), ...
    sprintf('spm_file basename returned "%s", expected "foo"', b));

fprintf('Testing spm_platform...\n');
ext = spm_platform('mexext');
assert(ischar(ext) && startsWith(ext, 'mex'), ...
    sprintf('spm_platform(''mexext'') returned "%s"', ext));

%% --- MEX: spm_bsplinc (MEX-only, no MATLAB fallback) -------------------

fprintf('Testing spm_bsplinc...\n');
V = rand(7, 7, 7);
c = spm_bsplinc(V, [3 3 3 0 0 0]);
assert(isequal(size(c), size(V)), ...
    sprintf('spm_bsplinc returned size [%s], expected [%s]', ...
            num2str(size(c)), num2str(size(V))));
assert(isa(c, 'single') || isa(c, 'double'), ...
    'spm_bsplinc returned unexpected class');

%% --- MEX: spm_cat ------------------------------------------------------

fprintf('Testing spm_cat...\n');
M = spm_cat({eye(2), zeros(2); zeros(2), [1 1; 1 1]});
expected = [1 0 0 0; 0 1 0 0; 0 0 1 1; 0 0 1 1];
assert(isequal(full(M), expected), 'spm_cat did not produce the expected block matrix');

%% --- MEX: spm_jsonread -------------------------------------------------

fprintf('Testing spm_jsonread...\n');
j = spm_jsonread('{"a": 1, "b": [2, 3]}');
assert(isstruct(j) && isfield(j, 'a') && isfield(j, 'b'), ...
    'spm_jsonread did not return a struct with fields a and b');
assert(j.a == 1, sprintf('spm_jsonread: j.a = %g, expected 1', j.a));
assert(isequal(j.b(:)', [2 3]), 'spm_jsonread: j.b was not [2 3]');

%% --- Channel gate: every shipped MEX must load (issue #16) -------------
% SPM ships ~70 MEX spanning the core plus the bundled externals under
% external/fieldtrip, external/bemcp and toolbox/FieldMap. Many live in
% private/ or @class/private/ folders (so they are not callable by bare
% name) and most require domain-specific inputs, so genuinely exercising
% each is impractical. The channel gate (assert_all_mex_exercised in
% scripts/test_one.m) only requires that every shipped MEX was loaded --
% i.e. appears in `inmem` -- which catches the real failure mode: a MEX
% that will not load on the target machine (missing symbol, bad linkage,
% wrong arch). We force each binary to load by invoking it once from its
% own directory (so private / class-private MEX resolve), inside a
% try/catch because a no-argument call is expected to error *after* the
% binary has been loaded. The three MEX above are additionally checked for
% correct behaviour; here we only require a clean load. Enumerating the
% MEX dynamically keeps this in step with the master-tracked upstream.
% NB: do not register an onCleanup to restore the cwd. `mip test` runs this
% script via `run()` in its own workspace, so an onCleanup variable created
% here outlives the script and fires when `mip test` returns -- after it has
% already restored the cwd -- re-entering the package directory. `mip test`
% restores the cwd itself, so we only cd back synchronously below.
fprintf('Force-loading every shipped MEX...\n');
spmRoot = fileparts(which('spm'));
mexFiles = dir(fullfile(spmRoot, '**', ['*.' mexext]));
origDir = pwd;
for k = 1:numel(mexFiles)
    [~, name] = fileparts(mexFiles(k).name);
    fprintf('  [%d/%d] %s\n', k, numel(mexFiles), name);
    cd(mexFiles(k).folder);
    try
        feval(name);
    catch
        % expected: most MEX reject a no-argument call once loaded
    end
end
cd(origDir);
fprintf('Force-loaded %d MEX binaries.\n', numel(mexFiles));

fprintf('SUCCESS\n');
