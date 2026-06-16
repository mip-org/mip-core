% Channel post-install test for MOLE (MATLAB/Octave version, pure MATLAB).
% Checks the mimetic Laplacian operator and a 1-D elliptic solve.

fprintf('=== Testing MOLE ===\n');

assert(~isempty(which('lap')), 'MOLE (lap) is not on the path');
assert(~isempty(which('robinBC')), 'MOLE (robinBC) is not on the path');

west = 0; east = 1;
k = 6;            % order of accuracy
m = 2*k + 1;      % cells
dx = (east - west) / m;
grid = [west, west+dx/2 : dx : east-dx/2, east]';

% (1) The k-th order mimetic Laplacian is exact for low-degree polynomials:
% applied to u = x^2 it must return u'' = 2 at the interior nodes.
L = lap(k, m, dx);
Lu = L * (grid.^2);
assert(max(abs(Lu(2:end-1) - 2)) < 1e-9, ...
    'mimetic Laplacian is not exact on a quadratic (max dev %.2e)', ...
    max(abs(Lu(2:end-1) - 2)));
fprintf('  mimetic Laplacian OK (Lap(x^2) = 2 to %.1e)\n', max(abs(Lu(2:end-1) - 2)));

% (2) Solve the getting-started 1-D elliptic problem (Robin BCs); the solution
% is exp(x).
La = lap(k, m, dx) + robinBC(k, m, dx, 1, 1);
U = exp(grid);
U(1) = 0;
U(end) = 2*exp(1);
U = La \ U;
err = norm(U - exp(grid)) / norm(exp(grid));
assert(err < 1e-6, '1-D elliptic solve error too large: %g', err);
fprintf('  1-D elliptic solve OK (rel err %.2e)\n', err);

fprintf('=== MOLE test passed ===\n');
