% compile_packages.m
% Compile prepared MATLAB packages that require compilation.
%
% This script:
% 1. Discovers all .dir directories in build/prepared/
% 2. For each .dir with a compile.m file:
%    - Executes the compile.m script
%    - Updates mip.json with compilation duration
% 3. Runs after prepare_packages.py and before bundle_and_upload_packages.py

function compile_packages()
    % Get the script directory and project root
    scriptDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(scriptDir);
    preparedDir = fullfile(projectRoot, 'build', 'prepared');
    
    fprintf('Starting package compilation process...\n');
    fprintf('Prepared packages directory: %s\n', preparedDir);
    
    % Check if prepared directory exists
    if ~exist(preparedDir, 'dir')
        error('Prepared packages directory not found: %s', preparedDir);
    end
    
    % Get all .dir directories
    dirEntries = dir(fullfile(preparedDir, '*.dir'));
    dirPaths = {};
    for i = 1:length(dirEntries)
        if dirEntries(i).isdir
            dirPaths{end+1} = fullfile(preparedDir, dirEntries(i).name);
        end
    end
    
    if isempty(dirPaths)
        fprintf('No .dir directories found in %s\n', preparedDir);
        % Explicitly exit MATLAB to avoid hanging
        exit(0);
    end
    
    fprintf('Found %d .dir package(s)\n', length(dirPaths));
    
    % Process each package
    packagesWithCompile = 0;
    for i = 1:length(dirPaths)
        dirPath = dirPaths{i};
        [~, dirName, ~] = fileparts(dirPath);
        
        % Check for compile.m file
        compileMPath = fullfile(dirPath, 'compile.m');
        if ~exist(compileMPath, 'file')
            fprintf('\n%s: No compile.m found - skipping\n', dirName);
            continue;
        end
        
        packagesWithCompile = packagesWithCompile + 1;
        fprintf('\n%s: Found compile.m - compiling...\n', dirName);
        
        % Compile the package
        success = compilePackage(dirPath, dirName);
        if ~success
            error('Compilation failed for %s', dirName);
        end
    end
    
    fprintf('\nPackages requiring compilation: %d\n', packagesWithCompile);
    fprintf('\n✓ All packages compiled successfully\n');

    % explicitly exit MATLAB to avoid hanging
    exit(0);
end

function success = compilePackage(dirPath, dirName)
    % Compile a single package
    success = false;
    
    try
        % Save current directory
        originalDir = pwd;
        
        % Change to package directory
        cd(dirPath);
        
        fprintf('  Running compile.m...\n');
        compileStart = tic;
        
        % Run the compile.m script
        compile;
        
        compileDuration = toc(compileStart);
        fprintf('  Compilation completed in %.2f seconds\n', compileDuration);
        
        % Restore original directory
        cd(originalDir);
        
        % Update mip.json with compilation time
        updateMipJsonCompilationTime(dirPath, compileDuration);
        
        success = true;
        
    catch ME
        % Restore original directory on error
        cd(originalDir);
        
        fprintf('  Error during compilation: %s\n', ME.message);
        fprintf('  Stack trace:\n');
        for j = 1:length(ME.stack)
            fprintf('    In %s at line %d\n', ME.stack(j).name, ME.stack(j).line);
        end
        success = false;
    end
end

function updateMipJsonCompilationTime(dirPath, compileDuration)
    % Update mip.json with compilation duration
    mipJsonPath = fullfile(dirPath, 'mip.json');
    
    if ~exist(mipJsonPath, 'file')
        fprintf('  Warning: mip.json not found at %s\n', mipJsonPath);
        return;
    end
    
    try
        % Read existing mip.json
        fid = fopen(mipJsonPath, 'r');
        if fid == -1
            error('Could not open mip.json for reading');
        end
        jsonText = fread(fid, '*char')';
        fclose(fid);
        
        % Parse JSON
        mipData = jsondecode(jsonText);
        
        % Update compile_duration
        mipData.compile_duration = round(compileDuration, 2);
        
        % Write updated JSON
        fid = fopen(mipJsonPath, 'w');
        if fid == -1
            error('Could not open mip.json for writing');
        end
        jsonText = jsonencode(mipData);
        % Pretty print JSON
        jsonText = prettifyJson(jsonText);
        fwrite(fid, jsonText);
        fclose(fid);
        
        fprintf('  Updated mip.json with compile_duration: %.2fs\n', compileDuration);
        
    catch ME
        fprintf('  Error updating mip.json: %s\n', ME.message);
    end
end

function prettyJson = prettifyJson(jsonText)
    % Simple JSON prettifier
    % Add newlines and indentation for basic readability
    prettyJson = strrep(jsonText, ',', sprintf(',\n  '));
    prettyJson = strrep(prettyJson, '{', sprintf('{\n  '));
    prettyJson = strrep(prettyJson, '}', sprintf('\n}'));
    prettyJson = strrep(prettyJson, '[', sprintf('[\n    '));
    prettyJson = strrep(prettyJson, ']', sprintf('\n  ]'));
end
