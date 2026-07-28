% Test script for kwave (k-Wave) — mip-org/staging.
%
% Exercises core utilities and a tiny end-to-end 2D simulation using only base
% MATLAB (no add-on toolboxes), so it runs on the channel's base-only CI.
rng('default');

% --- utility functions ---------------------------------------------------
fprintf('Testing makeDisc / getWin / db2neper...\n');
D = makeDisc(64, 64, 32, 32, 6);
assert(isequal(unique(D(:)), [0; 1]), 'makeDisc should be a binary map');
assert(full(sum(D(:))) == 113, 'makeDisc(64,64,32,32,6) area mismatch');

w = getWin(64, 'Hanning');
w = w(:);
assert(numel(w) == 64, 'getWin returned wrong length');
assert(norm(w - flipud(w)) < 1e-12, 'Hanning window should be symmetric');

a = 3.5;
assert(abs(neper2db(db2neper(a)) - a) < 1e-9, 'db2neper/neper2db roundtrip');

% --- tiny end-to-end 2D simulation ---------------------------------------
% A small initial-value problem: a disc of initial pressure recorded on a
% Cartesian circle of sensors. Runs headless (no plotting) for 30 steps.
fprintf('Testing kspaceFirstOrder2D (tiny headless run)...\n');
Nx = 64; Ny = 64; dx = 0.1e-3; dy = 0.1e-3;
kgrid = kWaveGrid(Nx, dx, Ny, dy);
assert(kgrid.Nx == Nx && kgrid.dx == dx, 'kWaveGrid property mismatch');

medium.sound_speed = 1500;                 % [m/s]
kgrid.setTime(30, 2e-8);                    % 30 steps, dt = 20 ns (stable)
source.p0 = 5 * makeDisc(Nx, Ny, 32, 32, 4);
sensor.mask = makeCartCircle(2e-3, 20);     % 20 sensor points

sensor_data = kspaceFirstOrder2D(kgrid, medium, source, sensor, ...
    'PlotSim', false, 'PMLInside', false);

assert(isequal(size(sensor_data), [20, 30]), 'sensor_data has unexpected size');
assert(all(isfinite(sensor_data(:))), 'sensor_data contains non-finite values');
assert(max(abs(sensor_data(:))) > 0, 'wave did not propagate to the sensors');

fprintf('SUCCESS\n');
