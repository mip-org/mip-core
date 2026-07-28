% Minimal end-to-end example for k-Wave: an initial-value problem in 2D.
%
%   mip install --channel mip-org/staging kwave
%   mip load kwave

% Computational grid.
Nx = 128; Ny = 128; dx = 0.1e-3; dy = 0.1e-3;   % [m]
kgrid = kWaveGrid(Nx, dx, Ny, dy);

% Homogeneous medium.
medium.sound_speed = 1500;   % [m/s]

% Initial pressure distribution: two discs.
source.p0 = 5 * makeDisc(Nx, Ny, 50, 50, 8) + 3 * makeDisc(Nx, Ny, 80, 60, 5);

% Record on a Cartesian circle of sensor points.
sensor.mask = makeCartCircle(4e-3, 50);

% Run the simulation (set PlotSim=false to run headless).
sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor);

fprintf('Recorded %d sensor traces of %d time steps.\n', ...
    size(sensor_data, 1), size(sensor_data, 2));
