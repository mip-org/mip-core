% Test script for fmmlib2d.
% Exercises the Laplace (real), Laplace (complex Cauchy), and Helmholtz
% particle FMMs and checks them against the package's own direct evaluators
% at a modest tolerance.

rng('default');

iprec = 4;                    % ~1e-6 target accuracy
nsource = 200;
ntarget = 150;
source = rand(2, nsource);
target = rand(2, ntarget) + 2;

ifcharge = 1;
ifdipole = 0;
dipstr = zeros(1, nsource);
dipvec = zeros(2, nsource);

ifpot = 1;
ifgrad = 0;
ifhess = 0;
ifpottarg = 1;
ifgradtarg = 0;
ifhesstarg = 0;

%% rfmm2dpart — Laplace FMM, real charges
fprintf('Testing rfmm2dpart (Laplace, real)...\n');
charge_r = rand(1, nsource);
U = rfmm2dpart(iprec, nsource, source, ifcharge, charge_r, ifdipole, dipstr, dipvec, ...
    ifpot, ifgrad, ifhess, ntarget, target, ifpottarg, ifgradtarg, ifhesstarg);
F = r2dpartdirect(nsource, source, ifcharge, charge_r, ifdipole, dipstr, dipvec, ...
    ifpot, ifgrad, ifhess, ntarget, target, ifpottarg, ifgradtarg, ifhesstarg);
err_pot = norm(U.pot - F.pot) / norm(F.pot);
err_tpt = norm(U.pottarg - F.pottarg) / norm(F.pottarg);
fprintf('  rel err: pot=%.2e pottarg=%.2e\n', err_pot, err_tpt);
assert(err_pot < 1e-3, 'rfmm2dpart pot error too large');
assert(err_tpt < 1e-3, 'rfmm2dpart pottarg error too large');

%% lfmm2dpart — Laplace FMM, complex charges
fprintf('Testing lfmm2dpart (Laplace, complex)...\n');
charge_c = rand(1, nsource) + 1i * rand(1, nsource);
U = lfmm2dpart(iprec, nsource, source, ifcharge, charge_c, ifdipole, dipstr, dipvec, ...
    ifpot, ifgrad, ifhess, ntarget, target, ifpottarg, ifgradtarg, ifhesstarg);
F = l2dpartdirect(nsource, source, ifcharge, charge_c, ifdipole, dipstr, dipvec, ...
    ifpot, ifgrad, ifhess, ntarget, target, ifpottarg, ifgradtarg, ifhesstarg);
err_pot = norm(U.pot - F.pot) / norm(F.pot);
err_tpt = norm(U.pottarg - F.pottarg) / norm(F.pottarg);
fprintf('  rel err: pot=%.2e pottarg=%.2e\n', err_pot, err_tpt);
assert(err_pot < 1e-3, 'lfmm2dpart pot error too large');
assert(err_tpt < 1e-3, 'lfmm2dpart pottarg error too large');

%% hfmm2dpart — Helmholtz FMM
fprintf('Testing hfmm2dpart (Helmholtz)...\n');
zk = complex(1.1, 0.0);
U = hfmm2dpart(iprec, zk, nsource, source, ifcharge, charge_c, ifdipole, dipstr, dipvec, ...
    ifpot, ifgrad, ifhess, ntarget, target, ifpottarg, ifgradtarg, ifhesstarg);
F = h2dpartdirect(zk, nsource, source, ifcharge, charge_c, ifdipole, dipstr, dipvec, ...
    ifpot, ifgrad, ifhess, ntarget, target, ifpottarg, ifgradtarg, ifhesstarg);
err_pot = norm(U.pot - F.pot) / norm(F.pot);
err_tpt = norm(U.pottarg - F.pottarg) / norm(F.pottarg);
fprintf('  rel err: pot=%.2e pottarg=%.2e\n', err_pot, err_tpt);
assert(err_pot < 1e-3, 'hfmm2dpart pot error too large');
assert(err_tpt < 1e-3, 'hfmm2dpart pottarg error too large');

fprintf('SUCCESS\n');
