% Test script for finufft package
% Exercises all 9 simple-interface transforms (1D/2D/3D, types 1/2/3).
% Each is checked for output size, absence of NaN, and accuracy against a
% direct (brute-force) evaluation of one output element.
% Direct-computation math mirrors the upstream matlab/test/check_finufft.m.

rng(1);             % deterministic inputs for a reproducible CI test
isign = +1;         % sign of imaginary unit in the exponential
eps = 1e-9;         % requested accuracy
tol = 1e-6;         % allowed relative error of the direct-computation check

%% ---------- 1D ----------
nj = 100;
x = pi * (2 * rand(nj, 1) - 1);  % random NU source points in [-pi, pi]

%% 1D type 1 (nonuniform to uniform)
fprintf('Testing finufft1d1...\n');
ms = 64;
c = randn(nj, 1) + 1i * randn(nj, 1);
f = finufft1d1(x, c, isign, eps, ms);
assert(numel(f) == ms, 'finufft1d1: output length should equal ms');
assert(~any(isnan(f)), 'finufft1d1: output should not contain NaN');
nt = 19;                                    % a mode index in [-ms/2, (ms-1)/2]
fe = sum(c .* exp(1i * isign * nt * x));     % direct evaluation of that mode
idx = nt + floor(ms/2) + 1;                  % its index in CMCL mode ordering
assert(abs(fe - f(idx)) < tol * max(abs(f)), 'finufft1d1: does not match direct computation');

%% 1D type 2 (uniform to nonuniform)
fprintf('Testing finufft1d2...\n');
ms = 64;
f = randn(ms, 1) + 1i * randn(ms, 1);
c = finufft1d2(x, isign, eps, f);
assert(numel(c) == nj, 'finufft1d2: output length should equal nj');
assert(~any(isnan(c)), 'finufft1d2: output should not contain NaN');
j = 37;                                      % a NU point index to check
mm = (ceil(-ms/2):floor((ms-1)/2))';         % mode index list
ce = sum(f .* exp(1i * isign * mm * x(j)));  % direct evaluation at that point
assert(abs(ce - c(j)) < tol * max(abs(c)), 'finufft1d2: does not match direct computation');

%% 1D type 3 (nonuniform to nonuniform)
fprintf('Testing finufft1d3...\n');
nk = 80;
c = randn(nj, 1) + 1i * randn(nj, 1);
s = (ms/2) * (2 * rand(nk, 1) - 1);          % target frequencies of size O(ms)
f = finufft1d3(x, c, isign, eps, s);
assert(numel(f) == nk, 'finufft1d3: output length should equal nk');
assert(~any(isnan(f)), 'finufft1d3: output should not contain NaN');
k = 41;                                      % a target index to check
fe = sum(c .* exp(1i * isign * s(k) * x));   % direct evaluation at that target
assert(abs(fe - f(k)) < tol * max(abs(f)), 'finufft1d3: does not match direct computation');

%% ---------- 2D ----------
nj = 100;
x = pi * (2 * rand(nj, 1) - 1);
y = pi * (2 * rand(nj, 1) - 1);
ms = 32; mt = 32;

%% 2D type 1
fprintf('Testing finufft2d1...\n');
c = randn(nj, 1) + 1i * randn(nj, 1);
f = finufft2d1(x, y, c, isign, eps, ms, mt);
assert(isequal(size(f), [ms, mt]), 'finufft2d1: output size should be [ms, mt]');
assert(~any(isnan(f(:))), 'finufft2d1: output should not contain NaN');
nt1 = 3; nt2 = -5;                           % mode indices in range
fe = sum(c .* exp(1i * isign * (nt1 * x + nt2 * y)));
idx1 = nt1 + floor(ms/2) + 1; idx2 = nt2 + floor(mt/2) + 1;
assert(abs(fe - f(idx1, idx2)) < tol * max(abs(f(:))), 'finufft2d1: does not match direct computation');

%% 2D type 2
fprintf('Testing finufft2d2...\n');
f = randn(ms, mt) + 1i * randn(ms, mt);
c = finufft2d2(x, y, isign, eps, f);
assert(numel(c) == nj, 'finufft2d2: output length should equal nj');
assert(~any(isnan(c)), 'finufft2d2: output should not contain NaN');
j = 37;
[mm1, mm2] = ndgrid(ceil(-ms/2):floor((ms-1)/2), ceil(-mt/2):floor((mt-1)/2));
ce = sum(f(:) .* exp(1i * isign * (mm1(:) * x(j) + mm2(:) * y(j))));
assert(abs(ce - c(j)) < tol * max(abs(c)), 'finufft2d2: does not match direct computation');

%% 2D type 3
fprintf('Testing finufft2d3...\n');
nk = 80;
c = randn(nj, 1) + 1i * randn(nj, 1);
s = (ms/2) * (2 * rand(nk, 1) - 1);          % target freqs of size O(ms)
t = (mt/2) * (2 * rand(nk, 1) - 1);          % target freqs of size O(mt)
f = finufft2d3(x, y, c, isign, eps, s, t);
assert(numel(f) == nk, 'finufft2d3: output length should equal nk');
assert(~any(isnan(f)), 'finufft2d3: output should not contain NaN');
k = 41;
fe = sum(c .* exp(1i * isign * (s(k) * x + t(k) * y)));
assert(abs(fe - f(k)) < tol * max(abs(f)), 'finufft2d3: does not match direct computation');

%% ---------- 3D ----------
nj = 200;
x = pi * (2 * rand(nj, 1) - 1);
y = pi * (2 * rand(nj, 1) - 1);
z = pi * (2 * rand(nj, 1) - 1);
ms = 16; mt = 16; mu = 16;

%% 3D type 1
fprintf('Testing finufft3d1...\n');
c = randn(nj, 1) + 1i * randn(nj, 1);
f = finufft3d1(x, y, z, c, isign, eps, ms, mt, mu);
assert(isequal(size(f), [ms, mt, mu]), 'finufft3d1: output size should be [ms, mt, mu]');
assert(~any(isnan(f(:))), 'finufft3d1: output should not contain NaN');
nt1 = 3; nt2 = -5; nt3 = 2;                  % mode indices in range
fe = sum(c .* exp(1i * isign * (nt1 * x + nt2 * y + nt3 * z)));
idx1 = nt1 + floor(ms/2) + 1; idx2 = nt2 + floor(mt/2) + 1; idx3 = nt3 + floor(mu/2) + 1;
assert(abs(fe - f(idx1, idx2, idx3)) < tol * max(abs(f(:))), 'finufft3d1: does not match direct computation');

%% 3D type 2
fprintf('Testing finufft3d2...\n');
f = randn(ms, mt, mu) + 1i * randn(ms, mt, mu);
c = finufft3d2(x, y, z, isign, eps, f);
assert(numel(c) == nj, 'finufft3d2: output length should equal nj');
assert(~any(isnan(c)), 'finufft3d2: output should not contain NaN');
j = 37;
[mm1, mm2, mm3] = ndgrid(ceil(-ms/2):floor((ms-1)/2), ceil(-mt/2):floor((mt-1)/2), ceil(-mu/2):floor((mu-1)/2));
ce = sum(f(:) .* exp(1i * isign * (mm1(:) * x(j) + mm2(:) * y(j) + mm3(:) * z(j))));
assert(abs(ce - c(j)) < tol * max(abs(c)), 'finufft3d2: does not match direct computation');

%% 3D type 3
fprintf('Testing finufft3d3...\n');
nk = 80;
c = randn(nj, 1) + 1i * randn(nj, 1);
s = (ms/2) * (2 * rand(nk, 1) - 1);          % target freqs of size O(ms)
t = (mt/2) * (2 * rand(nk, 1) - 1);          % target freqs of size O(mt)
u = (mu/2) * (2 * rand(nk, 1) - 1);          % target freqs of size O(mu)
f = finufft3d3(x, y, z, c, isign, eps, s, t, u);
assert(numel(f) == nk, 'finufft3d3: output length should equal nk');
assert(~any(isnan(f)), 'finufft3d3: output should not contain NaN');
k = 41;
fe = sum(c .* exp(1i * isign * (s(k) * x + t(k) * y + u(k) * z)));
assert(abs(fe - f(k)) < tol * max(abs(f)), 'finufft3d3: does not match direct computation');

fprintf('SUCCESS\n');
