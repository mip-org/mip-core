% Channel post-install test for pivlab -- pure-MATLAB layer only.
%
% Used by the [any] build (no MEX). The CI runners have base MATLAB without
% the Image Processing Toolbox, so this does not run the PIV engine itself
% (piv.piv_FFTmulti needs padarray/fspecial/regionprops at runtime); it
% checks the package layout and exercises the toolbox-free numerical helpers.
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

fprintf('SUCCESS\n');
