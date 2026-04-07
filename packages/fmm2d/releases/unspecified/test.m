% Test script for fmm2d package

eps = 1e-6;

%% Test rfmm2d (real Laplace) sources only, charges, potential
fprintf('Testing rfmm2d (sources, charges, pot)...\n');
ns = 200;
srcinfo = struct();
srcinfo.sources = rand(2, ns);
srcinfo.charges = rand(1, ns);
pg = 1;
U1 = rfmm2d(eps, srcinfo, pg);
assert(numel(U1.pot) == ns, 'rfmm2d pot should have ns entries');
assert(~any(isnan(U1.pot(:))), 'rfmm2d pot should not contain NaN');

% Compare against direct evaluation on a few points
ntest = 5;
stmp = srcinfo.sources(:, 1:ntest);
U2 = r2ddir(srcinfo, stmp, pg);
err = norm(U1.pot(1:ntest) - U2.pottarg) / norm(U2.pottarg);
assert(err < 1e-4, sprintf('rfmm2d vs direct error too large: %g', err));

%% Test rfmm2d sources to targets, charges, potential and gradient
fprintf('Testing rfmm2d (targets, charges, pot+grad)...\n');
nt = 150;
targ = rand(2, nt);
pg = 0;
pgt = 2;
U1 = rfmm2d(eps, srcinfo, pg, targ, pgt);
assert(all(size(U1.pottarg) == [1, nt]), 'rfmm2d pottarg size mismatch');
assert(all(size(U1.gradtarg) == [2, nt]), 'rfmm2d gradtarg size mismatch');

ttmp = targ(:, 1:ntest);
U2 = r2ddir(srcinfo, ttmp, pgt);
err = norm(U1.pottarg(1:ntest) - U2.pottarg) / norm(U2.pottarg);
assert(err < 1e-4, sprintf('rfmm2d targ pot error too large: %g', err));

%% Test lfmm2d (complex Laplace) sources only, charges, potential
fprintf('Testing lfmm2d (sources, charges, pot)...\n');
srcinfo = struct();
srcinfo.sources = rand(2, ns);
srcinfo.charges = rand(1, ns) + 1i * rand(1, ns);
pg = 1;
U1 = lfmm2d(eps, srcinfo, pg);
assert(numel(U1.pot) == ns, 'lfmm2d pot should have ns entries');
assert(~any(isnan(U1.pot(:))), 'lfmm2d pot should not contain NaN');

stmp = srcinfo.sources(:, 1:ntest);
U2 = l2ddir(srcinfo, stmp, pg);
err = norm(U1.pot(1:ntest) - U2.pottarg) / norm(U2.pottarg);
assert(err < 1e-4, sprintf('lfmm2d vs direct error too large: %g', err));

%% Test hfmm2d (Helmholtz) sources to targets, charges, potential
fprintf('Testing hfmm2d (targets, charges, pot)...\n');
zk = complex(1.1, 0.0);
srcinfo = struct();
srcinfo.sources = rand(2, ns);
srcinfo.charges = rand(1, ns) + 1i * rand(1, ns);
pg = 0;
pgt = 1;
U1 = hfmm2d(eps, zk, srcinfo, pg, targ, pgt);
assert(numel(U1.pottarg) == nt, 'hfmm2d pottarg should have nt entries');
assert(~any(isnan(U1.pottarg(:))), 'hfmm2d pottarg should not contain NaN');

ttmp = targ(:, 1:ntest);
U2 = h2ddir(zk, srcinfo, ttmp, pgt);
err = norm(U1.pottarg(1:ntest) - U2.pottarg) / norm(U2.pottarg);
assert(err < 1e-4, sprintf('hfmm2d vs direct error too large: %g', err));

fprintf('SUCCESS\n');
