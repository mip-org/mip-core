% Channel post-install test for Spot (MEX-enabled architectures).
% Exercises the core operator algebra plus the wavelet operators (RWT MEX).

fprintf('=== Testing Spot ===\n');

assert(~isempty(which('opMatrix')), 'Spot (opMatrix) is not on the path');
assert(~isempty(which('opWavelet')), 'Spot (opWavelet) is not on the path');

% --- Core operator algebra (pure MATLAB) ---
rng(0);
A = randn(8);
M = opMatrix(A);
x = randn(8, 1);
assert(norm(M * x - A * x) < 1e-12, 'opMatrix forward mismatch');
assert(norm(M' * x - A' * x) < 1e-12, 'opMatrix adjoint mismatch');

F = opDFT(16);
z = randn(16, 1);
assert(norm(F' * (F * z) - z) < 1e-10, 'opDFT is not unitary (round-trip failed)');
fprintf('  core operators OK\n');

% --- Wavelet operators (RWT MEX) ---
n = 64;
xb = randn(n, 1);

% Orthogonal wavelet: W is orthonormal, so W'*W = I (exercises mdwt + midwt).
W = opWavelet(n, 'Daubechies');
assert(norm(W' * (W * xb) - xb) < 1e-9, 'orthogonal wavelet reconstruction failed');

% Redundant (undecimated) wavelet: exercises mrdwt + mirdwt.
Wr = opWavelet(n, 'Daubechies', 8, 3, true);
zr = Wr' * (Wr * xb);
assert(numel(zr) == n && all(isfinite(zr)), 'redundant wavelet transform failed');
fprintf('  wavelet operators OK\n');

% Channel all-MEX-exercised gate: all four RWT MEX must have been loaded.
[~, loadedMex] = inmem;
for nm = {'mdwt', 'midwt', 'mrdwt', 'mirdwt'}
    assert(any(strcmp(loadedMex, nm{1})), 'MEX %s was not exercised', nm{1});
end

fprintf('=== Spot test passed ===\n');
