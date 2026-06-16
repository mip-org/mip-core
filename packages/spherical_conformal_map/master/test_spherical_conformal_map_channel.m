% Channel post-install test for spherical-conformal-map (pure MATLAB).
% Builds a genus-0 closed triangle mesh (an ellipsoid), conformally maps it
% to the unit sphere, and checks the result. Display-free (no plotting).

fprintf('=== Testing spherical-conformal-map ===\n');

assert(~isempty(which('spherical_conformal_map')), 'spherical_conformal_map is not on the path');
assert(~isempty(which('cotangent_laplacian')), 'cotangent_laplacian is not on the path');
assert(~isempty(which('mobius_area_correction_spherical')), 'extension is not on the path');

% --- Build a genus-0 closed triangle mesh: convex hull of points on a sphere,
%     then stretched into an ellipsoid so the conformal map does real work. ---
rng(0);
n = 300;
p = randn(n, 3);
p = p ./ sqrt(sum(p.^2, 2));        % points on the unit sphere
f = convhull(p(:,1), p(:,2), p(:,3));
v = p .* [2.0, 1.0, 0.6];           % stretch into an ellipsoid

% Euler characteristic of a genus-0 closed mesh: V - E + F = 2.
nv = size(v,1); nf = size(f,1);
assert(nv - 3*nf/2 + nf == 2, 'constructed mesh is not genus-0 closed');

% --- Conformal map to the unit sphere ---
map = spherical_conformal_map(v, f);

assert(isequal(size(map), size(v)), 'map has wrong size');
assert(all(isfinite(map(:))), 'map contains non-finite values');

% Every mapped vertex must lie on the unit sphere.
r = sqrt(sum(map.^2, 2));
assert(max(abs(r - 1)) < 1e-3, ...
    sprintf('mapped vertices are not on the unit sphere (max |r-1| = %g)', max(abs(r-1))));
fprintf('  spherical map lands on unit sphere (max |r-1| = %.2e)\n', max(abs(r-1)));

% The angle distortion should be small for a conformal map. Recompute it here
% rather than calling angle_distortion(), which forces a histogram figure.
fa = @(a,b) acos(sum(a.*b,2) ./ (sqrt(sum(a.^2,2)).*sqrt(sum(b.^2,2))));
ang = @(V) [fa(V(f(:,2),:)-V(f(:,1),:), V(f(:,3),:)-V(f(:,1),:)); ...
            fa(V(f(:,1),:)-V(f(:,2),:), V(f(:,3),:)-V(f(:,2),:)); ...
            fa(V(f(:,1),:)-V(f(:,3),:), V(f(:,2),:)-V(f(:,3),:))];
distortion = abs(ang(map) - ang(v)) * 180/pi;
assert(median(distortion) < 12, ...
    sprintf('angle distortion too large for a conformal map (median %g deg)', median(distortion)));
fprintf('  angle distortion small (median %.2f deg)\n', median(distortion));

% The Mobius area-correction extension is on the path. It is not executed here
% because it requires the MATLAB Optimization Toolbox (fmincon).

fprintf('=== spherical-conformal-map test passed ===\n');
