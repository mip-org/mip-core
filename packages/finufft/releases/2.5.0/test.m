% Test script for finufft package

%% Test 1D type 1 (nonuniform to uniform)
fprintf('Testing finufft1d1...\n');
nj = 100;
x = pi * (2 * rand(nj, 1) - 1);  % random points in [-pi, pi]
c = randn(nj, 1) + 1i * randn(nj, 1);
isign = -1;
eps = 1e-9;
ms = 64;
f = finufft1d1(x, c, isign, eps, ms);
assert(numel(f) == ms, 'Output length should equal ms');
assert(~any(isnan(f)), 'Output should not contain NaN');

% Verify against direct computation for a single mode
k = 0;  % check the zero-frequency mode
f_direct = sum(c .* exp(1i * isign * k * x));
idx = floor(ms/2) + 1;  % index of k=0 in CMCL ordering
assert(abs(f(idx) - f_direct) < 1e-6, 'Type 1 result does not match direct computation');

%% Test 1D type 2 (uniform to nonuniform)
fprintf('Testing finufft1d2...\n');
nj = 100;
x = pi * (2 * rand(nj, 1) - 1);
ms = 64;
f = randn(ms, 1) + 1i * randn(ms, 1);
isign = 1;
eps = 1e-9;
c = finufft1d2(x, isign, eps, f);
assert(numel(c) == nj, 'Output length should equal nj');
assert(~any(isnan(c)), 'Output should not contain NaN');

%% Test 2D type 1
fprintf('Testing finufft2d1...\n');
nj = 100;
x = pi * (2 * rand(nj, 1) - 1);
y = pi * (2 * rand(nj, 1) - 1);
c = randn(nj, 1) + 1i * randn(nj, 1);
isign = -1;
eps = 1e-9;
ms = 32; mt = 32;
f = finufft2d1(x, y, c, isign, eps, ms, mt);
assert(all(size(f) == [ms, mt]), 'Output size should be [ms, mt]');
assert(~any(isnan(f(:))), 'Output should not contain NaN');

fprintf('SUCCESS\n');
