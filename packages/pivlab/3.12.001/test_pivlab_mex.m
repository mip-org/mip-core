% Channel post-install test for pivlab -- MEX builds.
%
% Exercises the pure-MATLAB layer plus every shipped MEX (the coverage gate
% requires each one to be invoked): +plot/fastLICFunction and the four
% minFunc helpers mcholC, lbfgsC, lbfgsAddC, lbfgsProdC. The CI runners have
% base MATLAB without the Image Processing Toolbox, so the PIV engine itself
% (piv.piv_FFTmulti) is not run here.
rng('default');

fprintf('Checking package layout...\n');
assert(~isempty(which('PIVlab_GUI')), 'PIVlab_GUI.m not found on path');
assert(~isempty(which('PIVlab_settings_default.mat')), ...
    'PIVlab_settings_default.mat not found on path');
assert(~isempty(which('piv.piv_FFTmulti')), 'piv.piv_FFTmulti not found');
assert(~isempty(which('piv.piv_analysis')), 'piv.piv_analysis not found');
assert(~isempty(which('preproc.PIVlab_preproc')), 'preproc.PIVlab_preproc not found');
assert(~isempty(which('minFunc')), 'minFunc (wOFV optimizer) not found on path');

fprintf('Testing misc.inpaint_nans...\n');
[X, Y] = meshgrid(linspace(0, 1, 32));
Z = sin(2*pi*X) .* cos(2*pi*Y);
Zh = Z;
Zh(5, 7) = NaN; Zh(17, 23) = NaN; Zh(24, 12) = NaN;
Zf = misc.inpaint_nans(Zh);
assert(~any(isnan(Zf(:))), 'inpaint_nans left NaNs behind');
assert(max(abs(Zf(:) - Z(:))) < 0.1, ...
    sprintf('inpaint_nans error too large: %g', max(abs(Zf(:) - Z(:)))));

fprintf('Testing misc.smoothn...\n');
noisy = Z + 0.2 * randn(size(Z));
Zs = misc.smoothn(noisy);
assert(all(isfinite(Zs(:))), 'smoothn returned non-finite values');
err_noisy = norm(noisy - Z, 'fro');
err_smooth = norm(Zs - Z, 'fro');
assert(err_smooth < 0.5 * err_noisy, ...
    sprintf('smoothn did not denoise (noisy %g, smoothed %g)', err_noisy, err_smooth));

fprintf('Testing plot.fastLICFunction (LIC MEX)...\n');
% Mirrors how +plot/LIC.m calls it: a vector field, a white-noise image, and
% a box kernel whose column count sets the LIC streamline length.
n = 64;
[Xg, Yg] = meshgrid(linspace(-1, 1, n));
vx = -Yg;   % solid-body rotation
vy = Xg;
noiseImage = rand(n);
kernel = ones(1, 6);
[LICImage, intensity, normvx, normvy] = plot.fastLICFunction( ...
    double(vx), double(vy), noiseImage, kernel);
assert(isequal(size(LICImage), [n n]), 'fastLICFunction: wrong output size');
assert(all(isfinite(LICImage(:))), 'fastLICFunction: non-finite LIC image');
assert(isequal(size(normvx), [n n]) && isequal(size(normvy), [n n]), ...
    'fastLICFunction: wrong normalized-field size');
assert(all(isfinite(intensity(:))), 'fastLICFunction: non-finite intensity');

fprintf('Testing mcholC (modified Cholesky MEX)...\n');
A = randn(12);
H = A * A' + 12 * eye(12);   % symmetric positive definite
[L, D, perm] = mcholC(H);
if isvector(D)
    Dm = diag(D);
else
    Dm = D;
end
recon_err = norm(L * Dm * L' - H(perm, perm), 'fro') / norm(H, 'fro');
assert(recon_err < 1e-10, ...
    sprintf('mcholC factorization mismatch: relative error %g', recon_err));

% Small L-BFGS history with positive curvature (y_i''*s_i > 0), as minFunc
% maintains it.
nv = 10; k = 4;
g = randn(nv, 1);
S = randn(nv, k);
Yv = S * diag(0.5 + rand(k, 1)) + 0.05 * randn(nv, k);
for i = 1:k
    assert(Yv(:, i)' * S(:, i) > 0, 'test setup: curvature not positive');
end
Hdiag = 1.0;

fprintf('Testing lbfgsC against the pure-MATLAB lbfgs...\n');
d_mex = lbfgsC(-g, S, Yv, Hdiag);
d_m = lbfgs(-g, S, Yv, Hdiag);
assert(norm(d_mex - d_m) < 1e-10 * max(1, norm(d_m)), ...
    sprintf('lbfgsC disagrees with lbfgs.m: diff %g', norm(d_mex - d_m)));

fprintf('Testing lbfgsProdC against the pure-MATLAB lbfgsProd...\n');
YS = sum(Yv .* S, 1)';
d_pmex = lbfgsProdC(g, S, Yv, YS, int32(1), int32(k), Hdiag);
d_pm = lbfgsProd(g, S, Yv, YS, 1, k, Hdiag);
assert(norm(d_pmex - d_pm) < 1e-10 * max(1, norm(d_pm)), ...
    sprintf('lbfgsProdC disagrees with lbfgsProd.m: diff %g', norm(d_pmex - d_pm)));

fprintf('Testing lbfgsAddC (in-place correction update)...\n');
S2 = zeros(nv, k);
Y2 = zeros(nv, k);
ynew = randn(nv, 1);
snew = randn(nv, 1);
ys = ynew' * snew;
if ys < 0
    snew = -snew;
    ys = -ys;
end
lbfgsAddC(ynew, snew, Y2, S2, ys, int32(1));
assert(norm(Y2(:, 1) - ynew) < 1e-12 && norm(S2(:, 1) - snew) < 1e-12, ...
    'lbfgsAddC did not write the correction pair into column 1');

fprintf('Testing minFunc end-to-end on the Rosenbrock function...\n');
% PIVlab's minFunc copy reads option fields case-sensitively (uppercase).
opts = struct('DISPLAY', 'none', 'MAXITER', 500, 'MAXFUNEVALS', 2000);
x = minFunc(@rosenbrock, [-1.2; 1], opts);
assert(norm(x - [1; 1]) < 1e-4, ...
    sprintf('minFunc did not converge to [1;1]: got [%g; %g]', x(1), x(2)));

fprintf('SUCCESS\n');
