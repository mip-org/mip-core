% Test script for chebfun.

rng('default');

%% Test chebfun is on the path
fprintf('Testing chebfun is on the path...\n');
assert(exist('chebfun', 'file') > 0, 'chebfun is not on the MATLAB path');

%% Test construction and evaluation
fprintf('Testing construction and evaluation of sin on [0, pi]...\n');
f = chebfun(@sin, [0 pi]);
xs = linspace(0, pi, 17);
err = max(abs(f(xs) - sin(xs)));
assert(err < 1e-12, ...
    sprintf('chebfun(sin) evaluation error %g exceeds tolerance', err));

%% Test integration: int_0^pi sin(x) dx = 2
fprintf('Testing sum (integration)...\n');
I = sum(f);
assert(abs(I - 2) < 1e-12, ...
    sprintf('sum(sin on [0,pi]) returned %g, expected 2', I));

%% Test differentiation: d/dx sin = cos
fprintf('Testing diff (differentiation)...\n');
g = diff(f);
err = max(abs(g(xs) - cos(xs)));
assert(err < 1e-10, ...
    sprintf('diff(sin) vs cos error %g exceeds tolerance', err));

%% Test roots: sin has zeros at 0, pi, 2*pi on [0, 2*pi]
fprintf('Testing roots...\n');
h = chebfun(@sin, [0 2*pi]);
r = sort(roots(h));
expected = [0; pi; 2*pi];
assert(numel(r) == 3, ...
    sprintf('roots(sin on [0,2pi]) returned %d roots, expected 3', numel(r)));
assert(max(abs(r - expected)) < 1e-10, ...
    'roots(sin on [0,2pi]) values do not match [0, pi, 2*pi]');

%% Test min/max via minandmax
fprintf('Testing minandmax...\n');
p = chebfun(@(x) x.^3 - x, [-1 1]);
[vals, ~] = minandmax(p);
expectedMin = -2/(3*sqrt(3));
expectedMax =  2/(3*sqrt(3));
assert(abs(vals(1) - expectedMin) < 1e-10, ...
    sprintf('min of x^3-x on [-1,1] returned %g, expected %g', vals(1), expectedMin));
assert(abs(vals(2) - expectedMax) < 1e-10, ...
    sprintf('max of x^3-x on [-1,1] returned %g, expected %g', vals(2), expectedMax));

%% Test arithmetic: (sin)^2 + (cos)^2 == 1
fprintf('Testing arithmetic (sin^2 + cos^2 == 1)...\n');
s = chebfun(@sin, [-pi pi]);
c = chebfun(@cos, [-pi pi]);
one = s.^2 + c.^2;
err = max(abs(one(xs) - 1));
assert(err < 1e-10, ...
    sprintf('sin^2+cos^2 deviates from 1 by %g', err));

fprintf('SUCCESS\n');
