% Compile fmm2d for numbl native target.
% Wraps the shell build script via system().
% compile.m runs with cwd set to the package source root (full fmm2d repo).

fprintf('=== Compiling fmm2d for numbl native ===\n');

% Add Homebrew paths so that gfortran can be found on macOS.
% /opt/homebrew/bin is the ARM brew location, /usr/local/bin is the
% Intel brew (and the default GitHub Actions Intel-runner brew prefix).
setenv('PATH', ['/opt/homebrew/bin:/usr/local/bin:' getenv('PATH')]);

scriptPath = fullfile(pwd, 'matlab', 'numbl', 'build_native.sh');
if ~exist(scriptPath, 'file')
    error('build_native.sh not found at %s', scriptPath);
end

% FMM2D_SRC points to the repo root
setenv('FMM2D_SRC', pwd);

[status, output] = system(sprintf('bash "%s"', scriptPath));
fprintf('%s', output);
if status ~= 0
    error('build_native.sh failed (exit code %d)', status);
end

fprintf('=== fmm2d numbl native build complete ===\n');
