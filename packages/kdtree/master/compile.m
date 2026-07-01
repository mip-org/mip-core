% Compile MEX files for kdtree
fprintf('Compiling kdtree MEX files...\n');

% compile.m runs with cwd set to the package source root
toolbox_path = fullfile(pwd, 'toolbox');

original_dir = pwd;
cd(toolbox_path);

try
    cpp_files = dir('*.cpp');

    for i = 1:length(cpp_files)
        cpp_file = cpp_files(i).name;
        fprintf('  Compiling %s...\n', cpp_file);
        if ispc
            mex('COMPFLAGS=$COMPFLAGS /std:c++14', ...
                cpp_file);
        else
            mex('CXXFLAGS=$CXXFLAGS -std=c++14', ...
                'LDFLAGS=$LDFLAGS', ...
                cpp_file);
        end
    end

    fprintf('MEX compilation completed successfully.\n');
catch ME
    cd(original_dir);
    rethrow(ME);
end

cd(original_dir);
