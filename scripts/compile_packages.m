% compile_packages.m
% Compile prepared MATLAB packages that require compilation.
%
% This script:
% 1. Discovers all .dir directories in build/prepared/
% 2. For each .dir, reads prepare.yaml to check if compilation is needed
% 3. Checks if ARCHITECTURE environment variable matches
% 4. Executes the compile script if specified
% 5. Updates mip.json with compilation duration

function compile_packages()
    % Get the script directory and project root
    scriptDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(scriptDir);
    preparedDir = fullfile(projectRoot, 'build', 'prepared');
    packagesDir = fullfile(projectRoot, 'packages');
    
    % Add yamlmatlab to path
    yamlmatlabPath = fullfile(projectRoot, 'external', 'yamlmatlab');
    if ~exist(yamlmatlabPath, 'dir')
        error('yamlmatlab library not found at: %s', yamlmatlabPath);
    end
    addpath(yamlmatlabPath);
    
    fprintf('Starting package compilation process...\n');
    fprintf('Prepared packages directory: %s\n', preparedDir);

    % Get ARCHITECTURE from environment
    architecture = getenv('ARCHITECTURE');
    if isempty(architecture)
        architecture = 'any';
    end
    fprintf('ARCHITECTURE: %s\n', architecture);
    
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
        return;
    end
    
    fprintf('Found %d .dir package(s)\n', length(dirPaths));
    
    % Process each package
    packagesWithCompile = 0;
    for i = 1:length(dirPaths)
        dirPath = dirPaths{i};
        [~, dirName, ~] = fileparts(dirPath);
        
        % Extract package name from directory name (format: name-version-...)
        parts = strsplit(dirName, '-');
        packageName = parts{1};
        
        % Find prepare.yaml for this package
        yamlPath = fullfile(packagesDir, packageName, 'prepare.yaml');
        if ~exist(yamlPath, 'file')
            fprintf('\n%s: No prepare.yaml found - skipping\n', dirName);
            continue;
        end
        
        % Read YAML file using yamlmatlab
        try
            yamlData = yaml.ReadYaml(yamlPath);
        catch ME
            fprintf('\n%s: Could not read prepare.yaml - %s - skipping\n', dirName, ME.message);
            continue;
        end

        % Check if any build matches current ARCHITECTURE and has compile_script
        compileScript = '';
        if isfield(yamlData, 'builds') && iscell(yamlData.builds)
            for j = 1:length(yamlData.builds)
                build = yamlData.builds{j};
                % check if architecture matches or is 'any'
                if isfield(build, 'architecture') && (strcmp(build.architecture, architecture) || strcmp(build.architecture, 'any'))
                    if isfield(build, 'compile_script')
                        compileScript = build.compile_script;
                        break;
                    end
                end
            end
        end
        
        if isempty(compileScript)
            fprintf('\n%s: No compilation needed for ARCHITECTURE=%s\n', dirName, architecture);
            continue;
        end
        
        % Check if compile script exists
        compileScriptPath = fullfile(dirPath, compileScript);
        if ~exist(compileScriptPath, 'file')
            fprintf('\n%s: Compile script not found: %s - skipping\n', dirName, compileScriptPath);
            % raise error
            error('Compile script not found: %s', compileScriptPath);
        end
        
        packagesWithCompile = packagesWithCompile + 1;
        fprintf('\n%s: Found %s - compiling...\n', dirName, compileScript);
        
        % Compile the package
        success = compilePackage(dirPath, dirName, compileScript);
        if ~success
            error('Compilation failed for %s', dirName);
        end
    end
    
    fprintf('\nPackages requiring compilation: %d\n', packagesWithCompile);
    fprintf('\n✓ All packages compiled successfully\n');
end

function success = compilePackage(dirPath, dirName, compileScript)
    % Compile a single package
    success = false;
    
    try
        % Save current directory
        originalDir = pwd;
        
        % Change to package directory
        cd(dirPath);
        
        fprintf('  Running %s...\n', compileScript);
        compileStart = tic;
        
        % Run the compile script (without .m extension)
        [~, scriptName, ~] = fileparts(compileScript);
        eval(scriptName);
        
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
    prettyJson = strrep(jsonText, ',', sprintf(',\n  '));
    prettyJson = strrep(prettyJson, '{', sprintf('{\n  '));
    prettyJson = strrep(prettyJson, '}', sprintf('\n}'));
    prettyJson = strrep(prettyJson, '[', sprintf('[\n    '));
    prettyJson = strrep(prettyJson, ']', sprintf('\n  ]'));
end