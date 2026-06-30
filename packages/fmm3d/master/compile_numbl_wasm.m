function compile_numbl_wasm()

% Compile fmm3d for the numbl WASM target.
%
% Wraps matlab/numbl/build_wasm.sh, which (1) transpiles the upstream Fortran
% to C with fort2c and (2) compiles the C to two standalone WASM modules with
% emcc: fmm3d.wasm (modern API) and fmm3d_legacy.wasm (legacy API), one per
% mwrap gateway. Runs with cwd set to the package source root (the fetched
% fmm3d repo).
%
% Requires `fort2c` and `emcc` on PATH (the build workflow installs both for
% the numbl_wasm architecture).

fprintf('=== Compiling fmm3d for numbl WASM ===\n');

scriptPath = fullfile(pwd, 'matlab', 'numbl', 'build_wasm.sh');
if ~exist(scriptPath, 'file')
    error('build_wasm.sh not found at %s', scriptPath);
end

% FMM3D_SRC points to the repo root (where src/ and matlab/ live).
setenv('FMM3D_SRC', pwd);

[status, output] = system(sprintf('bash "%s"', scriptPath));
fprintf('%s', output);
if status ~= 0
    error('build_wasm.sh failed (exit code %d)', status);
end

fprintf('=== fmm3d numbl WASM build complete ===\n');
