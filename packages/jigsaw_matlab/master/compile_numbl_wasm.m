% Compile JIGSAW for the numbl WASM target.
%
% Wraps numbl/build_wasm.sh, which compiles JIGSAW's in-memory C library
% (lib_jigsaw, from external/jigsaw/src/jigsaw.cpp built with -D__lib_jigsaw)
% plus the flat shim (numbl/jigsaw_shim.cpp) into a standalone jigsaw.wasm with
% emcc. The jigsaw_kernel.numbl.js builtin dispatches through that module.
%
% Runs with cwd set to the package source root (the fetched jigsaw-matlab repo,
% which carries the JIGSAW C++ source under external/jigsaw). Requires `emcc` /
% `em++` on PATH (provided by the numbl_wasm build workflow).

fprintf('=== Compiling JIGSAW for numbl WASM ===\n');

scriptPath = fullfile(pwd, 'numbl', 'build_wasm.sh');
if ~exist(scriptPath, 'file')
    error('build_wasm.sh not found at %s', scriptPath);
end

% JIGSAW_SRC points to the repo root (where external/jigsaw lives).
setenv('JIGSAW_SRC', pwd);

[status, output] = system(sprintf('bash "%s"', scriptPath));
fprintf('%s', output);
if status ~= 0
    error('build_wasm.sh failed (exit code %d)', status);
end

wasmPath = fullfile(pwd, 'numbl', 'jigsaw.wasm');
if ~exist(wasmPath, 'file')
    error('jigsaw.wasm not produced at %s', wasmPath);
end

fprintf('=== JIGSAW numbl WASM build complete ===\n');
