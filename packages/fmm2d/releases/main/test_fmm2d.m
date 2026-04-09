% Test script for fmm2d package.
%
% Works for both the MEX build and the numbl builds. References for
% rfmm2d / lfmm2d / cfmm2d / stfmm2d are computed inline as O(N^2)
% direct sums (so the test does not depend on the *2ddir helper
% routines, which go through the MEX file and therefore are not
% available in the numbl builds).
%
% hfmm2d is only exercised on the MEX build because it has not yet
% been ported to numbl.

eps = 1e-6;
ns = 200;
nt = 150;
ntest = 5;

rng('default');
sources = rand(2, ns);
targ = rand(2, nt);

% Detect whether the MEX function `fmm2d` is available. The numbl
% builds expose rfmm2d/lfmm2d/cfmm2d/stfmm2d via numbl's JS shims and
% do not provide a MEX file at all.
has_mex = (exist('fmm2d', 'file') == 3);

%% Test rfmm2d (real Laplace) sources only, charges, potential
fprintf('Testing rfmm2d (sources, charges, pot)...\n');
charges_r = rand(1, ns);
srcinfo = struct('sources', sources, 'charges', charges_r);
pg = 1;
U1 = rfmm2d(eps, srcinfo, pg);
assert(numel(U1.pot) == ns, 'rfmm2d pot should have ns entries');
assert(~any(isnan(U1.pot(:))), 'rfmm2d pot should not contain NaN');

% Inline reference at a few source points (excluding self).
ref = zeros(1, ntest);
for j = 1:ntest
  s = 0;
  for i = 1:ns
    if i == j, continue; end
    dx = sources(1, j) - sources(1, i);
    dy = sources(2, j) - sources(2, i);
    s = s + charges_r(i) * 0.5 * log(dx*dx + dy*dy);
  end
  ref(j) = s;
end
err = norm(U1.pot(1:ntest) - ref) / norm(ref);
assert(err < 1e-4, sprintf('rfmm2d sources vs direct error too large: %g', err));

%% Test rfmm2d sources to targets, charges, potential and gradient
fprintf('Testing rfmm2d (targets, charges, pot+grad)...\n');
pg = 0;
pgt = 2;
U1 = rfmm2d(eps, srcinfo, pg, targ, pgt);
assert(all(size(U1.pottarg) == [1, nt]), 'rfmm2d pottarg size mismatch');
assert(all(size(U1.gradtarg) == [2, nt]), 'rfmm2d gradtarg size mismatch');
assert(~any(isnan(U1.pottarg(:))), 'rfmm2d pottarg should not contain NaN');

ref_pot = zeros(1, ntest);
ref_grad = zeros(2, ntest);
for j = 1:ntest
  pp = 0; gx = 0; gy = 0;
  for i = 1:ns
    dx = targ(1, j) - sources(1, i);
    dy = targ(2, j) - sources(2, i);
    r2 = dx*dx + dy*dy;
    pp = pp + charges_r(i) * 0.5 * log(r2);
    % grad of log|x-y| = (x - y)/|x - y|^2
    gx = gx + charges_r(i) * dx / r2;
    gy = gy + charges_r(i) * dy / r2;
  end
  ref_pot(j) = pp;
  ref_grad(:, j) = [gx; gy];
end
err = norm(U1.pottarg(1:ntest) - ref_pot) / norm(ref_pot);
assert(err < 1e-4, sprintf('rfmm2d targ pot error too large: %g', err));
err = norm(U1.gradtarg(:, 1:ntest) - ref_grad, 'fro') / norm(ref_grad, 'fro');
assert(err < 1e-4, sprintf('rfmm2d targ grad error too large: %g', err));

%% Test lfmm2d (log-kernel Laplace, complex charges) sources only
fprintf('Testing lfmm2d (sources, charges, pot)...\n');
charges_c = rand(1, ns) + 1i * rand(1, ns);
srcinfo = struct('sources', sources, 'charges', charges_c);
pg = 1;
U1 = lfmm2d(eps, srcinfo, pg);
assert(numel(U1.pot) == ns, 'lfmm2d pot should have ns entries');
assert(~any(isnan(U1.pot(:))), 'lfmm2d pot should not contain NaN');

ref = complex(zeros(1, ntest));
for j = 1:ntest
  s = 0;
  for i = 1:ns
    if i == j, continue; end
    dx = sources(1, j) - sources(1, i);
    dy = sources(2, j) - sources(2, i);
    s = s + charges_c(i) * 0.5 * log(dx*dx + dy*dy);
  end
  ref(j) = s;
end
err = norm(U1.pot(1:ntest) - ref) / norm(ref);
assert(err < 1e-4, sprintf('lfmm2d sources vs direct error too large: %g', err));

%% Test cfmm2d (Cauchy / complex Laplace) sources to targets,
%% charges, real(pot) and gradient
fprintf('Testing cfmm2d (targets, charges, pot+grad)...\n');
srcinfo = struct('sources', sources, 'charges', charges_c);
pg = 0;
pgt = 2;
U1 = cfmm2d(eps, srcinfo, pg, targ, pgt);
assert(all(size(U1.pottarg) == [1, nt]), 'cfmm2d pottarg size mismatch');
assert(all(size(U1.gradtarg) == [1, nt]), 'cfmm2d gradtarg size mismatch');
assert(~any(isnan(U1.pottarg(:))), 'cfmm2d pottarg should not contain NaN');

% cfmm2d's pot has a gauge-dependent imaginary part — only the real
% part is unambiguous for charge sources. The gradient is the complex
% Cauchy kernel d/dz = sum_i charge_i / (z - z_i) and is fully
% unambiguous.
ref_re = zeros(1, ntest);
ref_grad = complex(zeros(1, ntest));
for j = 1:ntest
  pre = 0; gz = 0;
  for i = 1:ns
    dx = targ(1, j) - sources(1, i);
    dy = targ(2, j) - sources(2, i);
    r2 = dx*dx + dy*dy;
    pre = pre + real(charges_c(i)) * 0.5 * log(r2);
    % grad: charge / (z - z_i), z = x + i*y
    gz = gz + charges_c(i) / (dx + 1i*dy);
  end
  ref_re(j) = pre;
  ref_grad(j) = gz;
end
err = norm(real(U1.pottarg(1:ntest)) - ref_re) / norm(ref_re);
assert(err < 1e-4, sprintf('cfmm2d Re(pot) error too large: %g', err));
err = norm(U1.gradtarg(1:ntest) - ref_grad) / norm(ref_grad);
assert(err < 1e-4, sprintf('cfmm2d grad error too large: %g', err));

%% Test stfmm2d (Stokes) with Stokeslet sources to targets,
%% velocity and pressure
fprintf('Testing stfmm2d (targets, stoklet, vel+pre)...\n');
stoklet = rand(2, ns) - 0.5;
srcinfo = struct('sources', sources, 'stoklet', stoklet);
ifppreg = 0;
ifppregtarg = 2;
U1 = stfmm2d(eps, srcinfo, ifppreg, targ, ifppregtarg);
assert(all(size(U1.pottarg) == [2, nt]), 'stfmm2d pottarg size mismatch');
assert(all(size(U1.pretarg) == [1, nt]), 'stfmm2d pretarg size mismatch');
assert(~any(isnan(U1.pottarg(:))), 'stfmm2d pottarg should not contain NaN');

% Stokeslet kernel (fmm2d convention; G is 2*pi larger than standard):
%   G_{ij}(x,y) = (-delta_{ij} log(r) + r_i r_j / r^2) / 2
%   P_j(x,y)    = r_j / r^2
% so u_i(x) = sum_m G_ij sigma^m_j and p(x) = sum_m P_j sigma^m_j.
ref_vel = zeros(2, ntest);
ref_pre = zeros(1, ntest);
for j = 1:ntest
  u1 = 0; u2 = 0; pp = 0;
  for i = 1:ns
    dx = targ(1, j) - sources(1, i);
    dy = targ(2, j) - sources(2, i);
    r2 = dx*dx + dy*dy;
    lr = 0.5 * log(r2);
    sx = stoklet(1, i);
    sy = stoklet(2, i);
    dot = dx*sx + dy*sy;
    u1 = u1 + 0.5 * (-lr * sx + dx * dot / r2);
    u2 = u2 + 0.5 * (-lr * sy + dy * dot / r2);
    pp = pp + dot / r2;
  end
  ref_vel(:, j) = [u1; u2];
  ref_pre(j) = pp;
end
err = norm(U1.pottarg(:, 1:ntest) - ref_vel, 'fro') / norm(ref_vel, 'fro');
assert(err < 1e-4, sprintf('stfmm2d Stokeslet vel error too large: %g', err));
err = norm(U1.pretarg(1:ntest) - ref_pre) / norm(ref_pre);
assert(err < 1e-4, sprintf('stfmm2d Stokeslet pre error too large: %g', err));

%% Test stfmm2d with stresslet sources, velocity at targets
fprintf('Testing stfmm2d (targets, strslet, vel)...\n');
strslet = rand(2, ns) - 0.5;
strsvec = rand(2, ns) - 0.5;
srcinfo = struct('sources', sources, ...
                 'strslet', strslet, 'strsvec', strsvec);
ifppreg = 0;
ifppregtarg = 1;
U1 = stfmm2d(eps, srcinfo, ifppreg, targ, ifppregtarg);
assert(all(size(U1.pottarg) == [2, nt]), 'stfmm2d strslet pottarg size mismatch');
assert(~any(isnan(U1.pottarg(:))), 'stfmm2d strslet pottarg should not contain NaN');

% Stresslet kernel (fmm2d convention; type-I stresslet):
%   T_{ijk}(x,y) = -2 r_i r_j r_k / r^4
% so u_i(x) = sum_m T_{ijk} mu^m_j nu^m_k
%           = -2 r_i (r . mu) (r . nu) / r^4
ref_vel = zeros(2, ntest);
for j = 1:ntest
  u1 = 0; u2 = 0;
  for i = 1:ns
    dx = targ(1, j) - sources(1, i);
    dy = targ(2, j) - sources(2, i);
    r2 = dx*dx + dy*dy;
    rmu = dx * strslet(1, i) + dy * strslet(2, i);
    rnu = dx * strsvec(1, i) + dy * strsvec(2, i);
    coef = -2 * rmu * rnu / (r2 * r2);
    u1 = u1 + dx * coef;
    u2 = u2 + dy * coef;
  end
  ref_vel(:, j) = [u1; u2];
end
err = norm(U1.pottarg(:, 1:ntest) - ref_vel, 'fro') / norm(ref_vel, 'fro');
assert(err < 1e-4, sprintf('stfmm2d strslet vel error too large: %g', err));

%% hfmm2d (Helmholtz) is only available on the MEX build (not yet
%% ported to numbl). Use h2ddir as the reference there.
if has_mex
  fprintf('Testing hfmm2d (targets, charges, pot)...\n');
  zk = complex(1.1, 0.0);
  srcinfo = struct('sources', sources, ...
                   'charges', rand(1, ns) + 1i * rand(1, ns));
  pg = 0;
  pgt = 1;
  U1 = hfmm2d(eps, zk, srcinfo, pg, targ, pgt);
  assert(numel(U1.pottarg) == nt, 'hfmm2d pottarg should have nt entries');
  assert(~any(isnan(U1.pottarg(:))), 'hfmm2d pottarg should not contain NaN');

  ttmp = targ(:, 1:ntest);
  U2 = h2ddir(zk, srcinfo, ttmp, pgt);
  err = norm(U1.pottarg(1:ntest) - U2.pottarg) / norm(U2.pottarg);
  assert(err < 1e-4, sprintf('hfmm2d vs direct error too large: %g', err));
else
  fprintf('Skipping hfmm2d (no MEX, hfmm2d not yet ported to numbl).\n');
end

fprintf('SUCCESS\n');
