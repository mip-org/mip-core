% Compile fmm2d for numbl WASM target.
% Wraps the shell build script via system().
% compile.m runs with cwd set to the package source root (full fmm2d repo).

fprintf('=== Compiling fmm2d for numbl WASM ===\n');

scriptPath = fullfile(pwd, 'matlab', 'numbl', 'build_wasm.sh');
if ~exist(scriptPath, 'file')
    error('build_wasm.sh not found at %s', scriptPath);
end

% FMM2D_SRC points to the repo root
setenv('FMM2D_SRC', pwd);

[status, output] = system(sprintf('bash "%s"', scriptPath));
fprintf('%s', output);
if status ~= 0
    error('build_wasm.sh failed (exit code %d)', status);
end

fprintf('=== fmm2d numbl WASM build complete ===\n');
