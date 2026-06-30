% Test script for fmm3dbie. Exercises the single shipped MEX gateway
% (fmm3dbie_routs) across the Laplace and Helmholtz boundary-integral solvers
% so the channel's MEX-coverage gate passes and a broken build is caught.
%
% Both blocks use the unit sphere, whose layer potentials have closed-form
% eigenvalues, so we assert the FMM/quadrature result against the exact answer
% (a broken MEX yields O(1) error or NaN). Tolerances are loose relative to the
% measured discretization error -- this is a smoke/correctness gate, not an
% accuracy benchmark. mip puts matlab/ and matlab/src on the path, so no
% startup.m is needed.

rng('default');

eps = 1e-7;

%% Laplace single layer on the sphere (exact eigenvalue 1/(2n+1))
disp('Running Laplace Dirichlet test...');
S = geometries.sphere(1, 2, [0;0;0], 4, 1);
[~, ~, ~, ~, ~, wts] = extract_arrays(S);

dpars = [1.0, 0.0];
ndeg = 1;
rr  = sqrt(S.r(1,:).^2 + S.r(2,:).^2 + S.r(3,:).^2);
rhs = (S.r(3,:)./rr).';

p    = lap3d.dirichlet.eval(S, rhs, S, eps, dpars);
p_ex = rhs / (2*ndeg + 1);
errL = norm((p - p_ex).*sqrt(wts)) / norm(rhs.*sqrt(wts));
fprintf('  Laplace single-layer rel. error = %.3e\n', errL);
assert(errL < 1e-2, 'fmm3dbie:lapEval', ...
    'Laplace single-layer error too large: %.3e', errL);

% Iterative solver + kernel evaluation (interior source, exterior target).
xyz_in  = [0.3; 0.5; 0.1];
xyz_out = [1.3; -5.2; 0.1];
src_info = struct('r', xyz_in);
rhs_s    = lap3d.kern(src_info, S, 's');
dpars2   = [1, 1];
sig      = lap3d.dirichlet.solver(S, rhs_s, eps, dpars2);
targ_info = struct('r', xyz_out);
dat    = lap3d.kern(S, targ_info, 'c', dpars2(1), dpars2(2));
pot    = dat*(sig.*wts);
pot_ex = lap3d.kern(src_info, targ_info, 's');
errLs  = abs(pot - pot_ex) / abs(pot_ex);
fprintf('  Laplace solver rel. error = %.3e\n', errLs);
assert(errLs < 1e-3, 'fmm3dbie:lapSolver', ...
    'Laplace solver error too large: %.3e', errLs);

%% Helmholtz single layer on the sphere (exact eigenvalue i*zk*j_n*h_n)
disp('Running Helmholtz Dirichlet test...');
Sh = geometries.sphere(1, 2, [0;0;0]);
[~, ~, ~, ~, ~, wtsh] = extract_arrays(Sh);

zk = 1.1;
rep_pars = [1.0, 0.0];
ndeg = 1;
jn = sqrt(pi/2/zk)*besselj(ndeg+0.5, zk);
hn = sqrt(pi/2/zk)*besselh(ndeg+0.5, 1, zk);
rrh  = sqrt(Sh.r(1,:).^2 + Sh.r(2,:).^2 + Sh.r(3,:).^2);
rhsh = (Sh.r(3,:)./rrh).';

ph    = helm3d.dirichlet.eval(Sh, rhsh, Sh, eps, zk, rep_pars);
ph_ex = rhsh*jn*hn*1j*zk;
errH  = norm((ph - ph_ex).*sqrt(wtsh)) / norm(rhsh.*sqrt(wtsh));
fprintf('  Helmholtz single-layer rel. error = %.3e\n', errH);
assert(errH < 1e-2, 'fmm3dbie:helmEval', ...
    'Helmholtz single-layer error too large: %.3e', errH);

% Iterative solver + kernel evaluation.
src_h   = struct('r', xyz_in);
rhs_h   = helm3d.kern(zk, src_h, Sh, 's');
rep2    = [-1j*zk, 1];
sigh    = helm3d.dirichlet.solver(Sh, rhs_h, eps, zk, rep2);
targ_h  = struct('r', xyz_out);
dath    = helm3d.kern(zk, Sh, targ_h, 'c', rep2);
poth    = dath*(sigh.*wtsh);
poth_ex = helm3d.kern(zk, src_h, targ_h, 's');
errHs   = abs(poth - poth_ex) / abs(poth_ex);
fprintf('  Helmholtz solver rel. error = %.3e\n', errHs);
assert(errHs < 1e-3, 'fmm3dbie:helmSolver', ...
    'Helmholtz solver error too large: %.3e', errHs);

fprintf('SUCCESS\n');
