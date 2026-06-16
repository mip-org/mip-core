function setup_mex_compilers(architecture, compiler)
%SETUP_MEX_COMPILERS   Set up the MEX compilers.
%
%   setup_mex_compilers(architecture)            % Uses architecture's default
%   setup_mex_compilers(architecture, compiler)  % Uses specified compiler
%
% Supported compilers for each architecture [default]:
%
%   Architecture       Compilers
%   ----------------   -----------------
%   'linux_x86_64'     ['gcc']
%   'macos_arm64'      ['gcc'], 'clang'
%   'macos_x86_64'     ['gcc'], 'clang'
%   'windows_x86_64'   ['mingw'], 'msvc'
%
% Persists the selection for the session so subsequent mex() calls in
% per-package compile.m scripts pick it up. Also exports environment variables
% CC, CXX, CMAKE_C_COMPILER, CMAKE_CXX_COMPILER if needed. An architecture that
% does not use MEX compilation (e.g. 'any', 'numbl_*') skips the setup.

if nargin < 2
    compiler = [];
end

scriptDir        = fileparts(mfilename('fullpath'));
mipMexoptsDir    = fullfile(scriptDir, '..', 'mexopts', architecture);
matlabMexoptsDir = fullfile(matlabroot, 'bin', computer('arch'), 'mexopts');

ccXML   = [];
cxxXML  = [];
ccPath  = [];
cxxPath = [];
switch architecture
    case 'linux_x86_64'
        if isempty(compiler), compiler = 'gcc'; end
        switch compiler
            case 'gcc'
                ccXML   = fullfile(mipMexoptsDir, 'gcc.xml');
                cxxXML  = fullfile(mipMexoptsDir, 'g++.xml');
                ccPath  = @() get_mex_compiler('C');
                cxxPath = @() get_mex_compiler('C++');
            otherwise
                unsupported(compiler, architecture);
        end

    case {'macos_arm64', 'macos_x86_64'}
        if isempty(compiler), compiler = 'gcc'; end
        switch compiler
            case 'gcc'
                ccXML   = fullfile(mipMexoptsDir, 'gcc.xml');
                cxxXML  = fullfile(mipMexoptsDir, 'g++.xml');
                ccPath  = @() get_mex_compiler('C');
                cxxPath = @() get_mex_compiler('C++');
            case 'clang'
                ccXML  = fullfile(mipMexoptsDir, 'clang.xml');
                cxxXML = fullfile(mipMexoptsDir, 'clang++.xml');
                [~, ccPath]  = system('xcrun -find clang');   ccPath  = strtrim(ccPath);
                [~, cxxPath] = system('xcrun -find clang++'); cxxPath = strtrim(cxxPath);
            otherwise
                unsupported(compiler, architecture);
        end

    case 'windows_x86_64'
        if isempty(compiler), compiler = 'mingw'; end
        switch compiler
            case 'mingw'
                mingw = getenv('MW_MINGW64_LOC');
                if isempty(mingw), mingw = 'C:\mingw64'; end
                setenv('MW_MINGW64_LOC', mingw);
                setenv('PATH', [fullfile(mingw, 'bin') ';' getenv('PATH')]);
                ccXML   = fullfile(matlabMexoptsDir, 'mingw64.xml');
                cxxXML  = fullfile(matlabMexoptsDir, 'mingw64_g++.xml');
                ccPath  = fullfile(mingw, 'bin', 'gcc.exe');
                cxxPath = fullfile(mingw, 'bin', 'g++.exe');
            case 'msvc'
                ccXML  = latest_msvc_mexopt('C');
                cxxXML = latest_msvc_mexopt('C++');
            otherwise
                unsupported(compiler, architecture);
        end

    otherwise
        if ~(strcmp(architecture, 'any') || startsWith(architecture, 'numbl_'))
            error('setup_mex_compilers:badArch', 'Unknown architecture "%s".', architecture);
        end
end

if isempty(ccXML) || isempty(cxxXML)
    fprintf('Architecture "%s" does not compile MEX. Skipping compiler setup.\n', ...
            architecture);
    return
end

if ~isfile(ccXML) || ~isfile(cxxXML)
    error('setup_mex_compilers:noMexopts', ...
          'MEX options file not found: %s / %s', ccXML, cxxXML);
end
fprintf('Setting up MEX C compiler: %s\n', ccXML);
mex(['-setup:' ccXML], 'C');
fprintf('Setting up MEX C++ compiler: %s\n', cxxXML);
mex(['-setup:' cxxXML], 'C++');

if ~isempty(ccPath) && ~isempty(cxxPath)
    if isa(ccPath,  'function_handle'), ccPath  = ccPath();  end
    if isa(cxxPath, 'function_handle'), cxxPath = cxxPath(); end
    setenv('CC', ccPath);
    setenv('CXX', cxxPath);
    setenv('CMAKE_C_COMPILER', ccPath);
    setenv('CMAKE_CXX_COMPILER', cxxPath);
    fprintf('  CC=%s\n  CXX=%s\n', ccPath, cxxPath);
    fprintf('  CMAKE_C_COMPILER=%s\n  CMAKE_CXX_COMPILER=%s\n', ccPath, cxxPath);
end

end


function unsupported(compiler, architecture)
%UNSUPPORTED  Error: this compiler is not valid for this architecture.

error('setup_mex_compilers:badCompiler', ...
      'Compiler "%s" is not supported for architecture "%s".', ...
      compiler, architecture);

end


function compiler = get_mex_compiler(lang)
%GET_MEX_COMPILER  Read the currently-selected MEX compiler executable.

config   = mex.getCompilerConfigurations(lang, 'Selected');
compiler = config.Details.CompilerExecutable;

end


function mexopt = latest_msvc_mexopt(lang)
%LATEST_MSVC_MEXOPT  Path to the latest installed MSVC mexopts for a language.

cfgs = mex.getCompilerConfigurations(lang, 'Installed');
msvc = cfgs(arrayfun(@(c) contains(c.Name, 'Microsoft Visual C++'), cfgs));
if isempty(msvc)
    error('setup_mex_compilers:noMSVC', ...
          'No Microsoft Visual C++ compiler found for %s.', lang);
end
% Pick the latest Visual Studio (highest year in the config name).
years = zeros(1, numel(msvc));
for i = 1:numel(msvc)
    tok = regexp(msvc(i).Name, '(\d{4})', 'tokens', 'once');
    if ~isempty(tok); years(i) = str2double(tok{1}); end
end
[~, latest] = max(years);
mexopt = msvc(latest).MexOpt;

end
