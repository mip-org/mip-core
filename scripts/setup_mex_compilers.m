function setup_mex_compilers(architecture)
%SETUP_MEX_COMPILERS   Setup the default MEX compilers.
%
% Configures MEX C/C++ compilers to use the gcc_static.xml/g++_static.xml files
% under ../mexopts/<architecture>/, if present. The setup persists for the
% current MATLAB session, so all subsequent MEX calls in per-package compile.m
% scripts pick it up automatically. Also exports CC and CXX environment
% variables to match the resolved compilers, so CMake/autotools invocations
% from compile.m scripts use the same toolchain as MEX.
%
% Architectures without a matching mexopts subdirectory (e.g. 'any', 'numbl_*',
% 'windows_x86_64') are skipped silently.

scriptDir      = fileparts(mfilename('fullpath'));
mexoptsDir     = fullfile(scriptDir, '..', 'mexopts');
archMexoptsDir = fullfile(mexoptsDir, architecture);
if ~isfolder(archMexoptsDir)
    fprintf('No project mexopts for architecture "%s"\n', architecture);
    return;
end

gccXML = fullfile(archMexoptsDir, 'gcc_static.xml');
gxxXML = fullfile(archMexoptsDir, 'g++_static.xml');

if isfile(gccXML)
    fprintf('Setting up MEX C compiler: %s\n', gccXML);
    mex(['-setup:' gccXML], 'C');
    cfg = mex.getCompilerConfigurations('C');
    setenv('CC', cfg.Details.CompilerExecutable);
    fprintf('  CC=%s\n', cfg.Details.CompilerExecutable);
end

if isfile(gxxXML)
    fprintf('Setting up MEX C++ compiler: %s\n', gxxXML);
    mex(['-setup:' gxxXML], 'C++');
    cfg = mex.getCompilerConfigurations('C++');
    setenv('CXX', cfg.Details.CompilerExecutable);
    fprintf('  CXX=%s\n', cfg.Details.CompilerExecutable);
end

end
