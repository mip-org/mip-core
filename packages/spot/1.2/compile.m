% Compile Spot's bundled Rice Wavelet Toolbox (RWT) MEX files.
% compile.m runs with cwd set to the package source root.
%
% These four C MEX (mdwt/midwt = orthogonal DWT and inverse, mrdwt/mirdwt =
% redundant DWT and inverse) back Spot's wavelet operators (opWavelet,
% opWavelet2, opHaar). They are the only compiled component; the rest of Spot
% is pure MATLAB.

fprintf('=== Compiling Spot RWT wavelet MEX ===\n');

rwtDir = fullfile(pwd, '+spot', '+rwt');

% The RWT sources predate C99: they call worker functions without prototypes
% and use intptr_t without including <stdint.h>. Allow the implicit
% declarations and force-include <stdint.h> so they build under modern GCC.
flags = {['CFLAGS=$CFLAGS -std=gnu17 -Wno-implicit-function-declaration ' ...
          '-Wno-implicit-int -include stdint.h']};
srcs = {'mdwt.c', 'midwt.c', 'mrdwt.c', 'mirdwt.c'};

for i = 1:numel(srcs)
    fprintf('  [%d/%d] %s\n', i, numel(srcs), srcs{i});
    mex(flags{:}, '-outdir', rwtDir, fullfile(rwtDir, srcs{i}));
end

fprintf('=== Spot RWT MEX compilation complete ===\n');
