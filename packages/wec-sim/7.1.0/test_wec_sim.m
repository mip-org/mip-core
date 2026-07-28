% Test script for wec-sim package.
% Running a simulation requires Simulink/Simscape/Simscape Multibody, so this
% smoke test only exercises the pure-MATLAB surface.

%% Core entry points are on the path
fprintf('Checking path setup...\n');
assert(exist('wecSim', 'file') == 2, 'wecSim not found on path');
assert(exist('initializeWecSim', 'file') == 2, 'initializeWecSim not found on path');
assert(exist('stopWecSim', 'file') == 2, 'stopWecSim not found on path');

%% Simulink library directories are on the path (no .m files in them)
assert(~isempty(which('WECSim_Lib.slx')), 'WECSim_Lib.slx not found on path');

%% Instantiate core classes (pure MATLAB, no Simulink required)
fprintf('Instantiating simulationClass...\n');
simu = simulationClass();
assert(strcmp(simu.caseDir, pwd), 'unexpected simulationClass case directory');

fprintf('Instantiating waveClass...\n');
waves = waveClass('regular');
assert(strcmp(waves.type, 'regular'), 'waveClass type not set');

fprintf('SUCCESS\n');
