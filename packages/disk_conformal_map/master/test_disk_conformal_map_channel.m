% Channel post-install test for disk-conformal-map (pure MATLAB).
% Builds a simply-connected open (disk-topology) triangle mesh with curvature,
% conformally maps it to the unit disk, and checks the result. Display-free.

fprintf('=== Testing disk-conformal-map ===\n');

assert(~isempty(which('disk_conformal_map')), 'disk_conformal_map is not on the path');
assert(~isempty(which('cotangent_laplacian')), 'cotangent_laplacian is not on the path');
assert(~isempty(which('mobius_area_correction_disk')), 'extension is not on the path');

% --- Build a disk-topology mesh: a polar grid triangulated in 2D, lifted into
%     3D with a height function so the conformal map has real work to do. ---
nr = 12; nt = 30;
x = 0; y = 0;                         % center vertex
for i = 1:nr
    r = i/nr;
    th = (0:nt-1) * (2*pi/nt) + 0.1*i;   % slight twist per ring
    x = [x, r*cos(th)]; %#ok<AGROW>
    y = [y, r*sin(th)]; %#ok<AGROW>
end
x = x(:); y = y(:);
f = delaunay(x, y);
z = 0.25 * sin(pi*x) .* cos(pi*y);    % curvature
v = [x, y, z];
nv = size(v, 1);

% --- Conformal map to the unit disk ---
map = disk_conformal_map(v, f);

assert(isequal(size(map), [nv, 2]), 'map has wrong size (expected nv x 2)');
assert(all(isfinite(map(:))), 'map contains non-finite values');

% Nothing may land outside the closed unit disk.
rad = sqrt(sum(map.^2, 2));
assert(max(rad) <= 1 + 1e-6, sprintf('map left the unit disk (max radius %g)', max(rad)));

% The mesh boundary must map onto the unit circle.
B = freeBoundary(triangulation(f, v));
bdy = unique(B(:));
assert(min(rad(bdy)) > 0.99, ...
    sprintf('boundary did not map to the unit circle (min boundary radius %g)', min(rad(bdy))));
fprintf('  map fills the unit disk; boundary on unit circle (min %.4f)\n', min(rad(bdy)));

% Angle distortion should be small for a conformal map (computed inline to
% avoid angle_distortion(), which forces a histogram figure).
m3 = [map, zeros(nv,1)];
fa = @(a,b) acos(sum(a.*b,2) ./ (sqrt(sum(a.^2,2)).*sqrt(sum(b.^2,2))));
ang = @(V) [fa(V(f(:,2),:)-V(f(:,1),:), V(f(:,3),:)-V(f(:,1),:)); ...
            fa(V(f(:,1),:)-V(f(:,2),:), V(f(:,3),:)-V(f(:,2),:)); ...
            fa(V(f(:,1),:)-V(f(:,3),:), V(f(:,2),:)-V(f(:,3),:))];
distortion = abs(ang(m3) - ang(v)) * 180/pi;
assert(median(distortion) < 12, ...
    sprintf('angle distortion too large for a conformal map (median %g deg)', median(distortion)));
fprintf('  angle distortion small (median %.2f deg)\n', median(distortion));

% The Mobius area-correction and remeshing extensions are on the path. The
% Mobius extension is not executed here as it requires the Optimization Toolbox.

fprintf('=== disk-conformal-map test passed ===\n');
