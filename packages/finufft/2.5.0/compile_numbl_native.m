% Compile FINUFFT for numbl native target
% Wraps the shell build script via system()
% compile.m runs with cwd set to the package source root (full finufft repo)

fprintf('=== Compiling FINUFFT for numbl native ===\n');

scriptPath = fullfile(pwd, 'matlab', 'numbl', 'build_native.sh');
if ~exist(scriptPath, 'file')
    error('build_native.sh not found at %s', scriptPath);
end

% FINUFFT_SRC points to the repo root (where CMakeLists.txt lives)
setenv('FINUFFT_SRC', pwd);

[status, output] = system(sprintf('bash "%s"', scriptPath));
fprintf('%s', output);
if status ~= 0
    error('build_native.sh failed (exit code %d)', status);
end

fprintf('=== FINUFFT numbl native build complete ===\n');
