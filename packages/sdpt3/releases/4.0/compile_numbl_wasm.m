% Compile SDPT3 for numbl WASM target
% Wraps the shell build script via system()
% compile.m runs with cwd set to the package source root

fprintf('=== Compiling SDPT3 for numbl WASM ===\n');

scriptPath = fullfile(pwd, 'numbl', 'build_wasm.sh');
if ~exist(scriptPath, 'file')
    error('build_wasm.sh not found at %s', scriptPath);
end

[status, output] = system(sprintf('bash "%s"', scriptPath));
fprintf('%s', output);
if status ~= 0
    error('build_wasm.sh failed (exit code %d)', status);
end

fprintf('=== SDPT3 numbl WASM build complete ===\n');
