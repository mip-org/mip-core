mip install --channel mip-org/staging pivlab
mip load pivlab

% PIVlab is GUI-centric; start it with:
%   PIVlab_GUI
%
% The functions can also be scripted. This example runs the FFT-based PIV
% engine on a synthetic image pair with a known uniform shift.
% Note: piv.piv_FFTmulti requires the Image Processing Toolbox.

rng('default');

% Synthetic particle image pair: smoothed noise, second frame shifted by
% a known amount (u = -7 px, v = +3 px).
N = 160;
A = conv2(rand(N), ones(5)/25, 'same');
B = circshift(A, [3, -7]);

% PIV analysis: 2 passes, 64->32 px interrogation windows (same settings as
% upstream's Example_scripts/PIVlab_commandline.m).
[x, y, u, v, typevector, correlation_map] = piv.piv_FFTmulti( ...
    A, B, ...         % image pair
    64, 32, ...       % first-pass interrogation area and step
    1, ...            % subpixel finder (1 = 3-point Gauss)
    [], [], ...       % no mask, no ROI
    2, 32, 16, 16, ...% nr. of passes; window sizes for passes 2-4
    '*linear', ...    % window deformation interpolation
    0, 0, ...         % repeated correlation off, autocorrelation enabled
    0, 0, ...         % circular correlation; no correlation matrices output
    0, 0.025);        % repeat-last-pass off; last-pass quality slope

fprintf('median u = %.2f px (expected -7), median v = %.2f px (expected +3)\n', ...
    median(u(:), 'omitnan'), median(v(:), 'omitnan'));

% Postprocessing: validate and smooth the vector field.
u_filt = misc.smoothn(u);
v_filt = misc.smoothn(v);

quiver(x, y, u_filt, v_filt, 'k');
axis ij equal tight;
title('PIVlab: recovered displacement field');

% For complete command-line workflows (batch processing, ensemble
% correlation, session files), load the example scripts:
%   mip load pivlab --with examples
% and open PIVlab_commandline.m.
