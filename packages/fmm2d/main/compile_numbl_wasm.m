% Compile fmm2d for the numbl WASM target.
%
% Wraps matlab/numbl/build_wasm.sh, which (1) transpiles the upstream Fortran
% to C with fort2c and (2) compiles the C to a standalone fmm2d.wasm with emcc.
% Runs with cwd set to the package source root (the fetched fmm2d repo).
%
% Requires `fort2c` and `emcc` on PATH (the build workflow installs both for
% the numbl_wasm architecture).

fprintf('=== Compiling fmm2d for numbl WASM ===\n');

scriptPath = fullfile(pwd, 'matlab', 'numbl', 'build_wasm.sh');
if ~exist(scriptPath, 'file')
    error('build_wasm.sh not found at %s', scriptPath);
end

% FMM2D_SRC points to the repo root (where src/ and matlab/ live).
setenv('FMM2D_SRC', pwd);

[status, output] = system(sprintf('bash "%s"', scriptPath));
fprintf('%s', output);
if status ~= 0
    error('build_wasm.sh failed (exit code %d)', status);
end

fprintf('=== fmm2d numbl WASM build complete ===\n');
