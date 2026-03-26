% Compile MEX files for kdtree
fprintf('Compiling kdtree MEX files...\n');

% Get the kdtree directory
kdtree_toolbox_path = fullfile(fileparts(mfilename('fullpath')), 'kdtree/toolbox');

% Change to kdtree directory
original_dir = pwd;
cd(kdtree_toolbox_path);

try
    % Find all .cpp files
    cpp_files = dir('*.cpp');
    
    % Compile each .cpp file
    for i = 1:length(cpp_files)
        cpp_file = cpp_files(i).name;
        fprintf('  Compiling %s...\n', cpp_file);
        mex('CXXFLAGS=$CXXFLAGS -std=c++14', ...
            'LDFLAGS=$LDFLAGS', ...
            cpp_file);
    end
    
    fprintf('MEX compilation completed successfully.\n');
catch ME
    cd(original_dir);
    rethrow(ME);
end

% Return to original directory
cd(original_dir);
