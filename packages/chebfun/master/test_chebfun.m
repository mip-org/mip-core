% Test script for chebfun package.

rng('default');
tol = 1e-10;

%% Construct a chebfun and integrate it
fprintf('Testing chebfun construction and integration...\n');
f = chebfun(@(x) sin(x), [0 pi]);
I = sum(f);                       % integral of sin over [0, pi] = 2
assert(abs(I - 2) < tol, sprintf('sum(sin) error: %g', abs(I - 2)));

%% Differentiation: d/dx sin = cos
fprintf('Testing differentiation...\n');
g = diff(f);
xx = linspace(0, pi, 17);
assert(norm(g(xx) - cos(xx), inf) < 1e-9, 'diff(sin) does not match cos');

%% Root finding
fprintf('Testing roots...\n');
h = chebfun(@(x) cos(x), [0 2*pi]);
r = sort(roots(h));
expected = [pi/2; 3*pi/2];
assert(numel(r) == 2, sprintf('expected 2 roots, got %d', numel(r)));
assert(norm(r - expected, inf) < 1e-9, 'cos root locations error');

%% Global maximum of x^3 - x on [-1, 1] (at x = -1/sqrt(3))
fprintf('Testing max...\n');
p = chebfun(@(x) x.^3 - x, [-1 1]);
[mx, xmx] = max(p);
xstar = -1/sqrt(3);
assert(abs(xmx - xstar) < 1e-7, sprintf('argmax error: %g', abs(xmx - xstar)));
assert(abs(mx - (xstar^3 - xstar)) < 1e-9, 'max value error');

%% Antiderivative via cumsum + fundamental theorem of calculus
fprintf('Testing cumsum...\n');
F = cumsum(f);                    % F(pi) - F(0) should equal sum(f) = 2
assert(abs(F(pi) - 2) < tol, sprintf('cumsum endpoint error: %g', abs(F(pi) - 2)));

%% Pointwise algebra: integral of sin^2 over [0, pi] = pi/2
fprintf('Testing pointwise algebra...\n');
I2 = sum(f.^2);
assert(abs(I2 - pi/2) < 1e-9, sprintf('sum(sin^2) error: %g', abs(I2 - pi/2)));

fprintf('SUCCESS\n');
