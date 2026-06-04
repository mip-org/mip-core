% Test script for chunkie package.

rng('default');

%% Test chunkerfunc on a circle (area)
fprintf('Testing chunkerfunc (circle area)...\n');
r = 1.3;
ctr = [0.4; -0.2];
circfun = @(t) ctr + r * [cos(t(:).'); sin(t(:).')];
cparams = []; cparams.eps = 1e-10;
chnkr = chunkerfunc(circfun, cparams);
a = area(chnkr);
assert(abs(a - pi*r^2) < 1e-10, ...
    sprintf('chunkerfunc circle area error too large: %g', abs(a - pi*r^2)));

%% Test chunkerintegral
fprintf('Testing chunkerintegral...\n');
% Integrate the constant function 1 over the circle -> arclength = 2*pi*r
fvals = ones(chnkr.k, chnkr.nch);
len = chunkerintegral(chnkr, fvals(:));
assert(abs(len - 2*pi*r) < 1e-10, ...
    sprintf('chunkerintegral arclength error too large: %g', abs(len - 2*pi*r)));

% Integrate (x - ctr_x) over the circle -> 0 by symmetry
fhandle = @(xx) xx(1,:) - ctr(1);
val = chunkerintegral(chnkr, fhandle);
assert(abs(val) < 1e-10, ...
    sprintf('chunkerintegral symmetry error too large: %g', abs(val)));

%% Test chunkerinterior
fprintf('Testing chunkerinterior...\n');
nt = 500;
% Random points scaled along radial directions from the center
theta = 2*pi*rand(1, nt);
scal = 2*rand(1, nt);  % some inside (<1), some outside (>1)
targs = ctr + scal .* [cos(theta); sin(theta)] * r;
in = chunkerinterior(chnkr, targs);
assert(all(in(:) == (scal(:) < 1)), ...
    'chunkerinterior misclassified points relative to scaling');

%% Test chunkermat: solve interior Laplace Dirichlet BVP on the circle
fprintf('Testing chunkermat (Laplace Dirichlet solve)...\n');

% Refine the circle a bit for the BVP
cparams = []; cparams.eps = 1e-10; cparams.nover = 1;
pref = []; pref.k = 16;
chnkr = chunkerfunc(circfun, cparams, pref);

% A few sources placed outside the circle generate a harmonic field inside
ns = 5;
src_theta = 2*pi*rand(ns, 1);
sources = ctr + 2.5*r * [cos(src_theta(:).'); sin(src_theta(:).')];
strengths = randn(ns, 1);

% Targets strictly inside the circle
ntarg = 4;
targ_theta = 2*pi*rand(ntarg, 1);
targ_rad = 0.5*r * rand(1, ntarg);
targets = ctr + targ_rad .* [cos(targ_theta(:).'); sin(targ_theta(:).')];

% Single-layer Laplace kernel: known potential from sources
kerns = @(s, t) chnk.lap2d.kern(s, t, 's');

srcinfo = struct('r', sources);
bdryinfo = struct('r', reshape(chnkr.r, 2, chnkr.k*chnkr.nch));
ubdry = kerns(srcinfo, bdryinfo) * strengths;

targinfo = struct('r', targets);
utarg = kerns(srcinfo, targinfo) * strengths;

% Build the Laplace double-layer matrix and solve the
% (-1/2 I + D) sigma = u_bdry interior Dirichlet system
fkern = @(s, t) chnk.lap2d.kern(s, t, 'D');
D = chunkermat(chnkr, fkern);
sys = -0.5*eye(chnkr.k*chnkr.nch) + D;
sol = sys \ ubdry(:);

% Evaluate the layer potential at the interior targets
opts = []; opts.usesmooth = false; opts.verb = false;
Dsol = chunkerkerneval(chnkr, fkern, sol, targets, opts);

relerr = norm(utarg - Dsol) / norm(utarg);
fprintf('  Laplace Dirichlet relative error: %5.2e\n', relerr);
assert(relerr < 1e-9, ...
    sprintf('chunkermat Laplace Dirichlet solve error too large: %g', relerr));

fprintf('SUCCESS\n');
