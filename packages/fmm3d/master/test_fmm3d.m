% Test script for fmm3d. Exercises BOTH shipped MEX gateways so the channel's
% MEX-coverage gate passes:
%
%   fmm3d         <- lfmm3dTest, hfmm3dTest, stfmm3dTest, emfmm3dTest
%                    (the modern lfmm3d/hfmm3d/stfmm3d/emfmm3d wrappers and
%                     their l3ddir/h3ddir/st3ddir/em3ddir direct-sum references)
%   fmm3d_legacy  <- lfmm3dLegacyTest, hfmm3dLegacyTest
%                    (the legacy lfmm3dpart/hfmm3dpart wrappers and their
%                     l3dpartdirect/h3dpartdirect references)
%
% The four modern Test scripts assert FMM-vs-direct relative error internally;
% the two legacy Test scripts report relative errors. Seed once up front for
% determinism across the whole run.
rng('default');

disp('Running lfmm3dTest...');
lfmm3dTest;
disp('Running hfmm3dTest...');
hfmm3dTest;
disp('Running stfmm3dTest...');
stfmm3dTest;
disp('Running emfmm3dTest...');
emfmm3dTest;

disp('Running lfmm3dLegacyTest...');
lfmm3dLegacyTest;
disp('Running hfmm3dLegacyTest...');
hfmm3dLegacyTest;

fprintf('SUCCESS\n');
