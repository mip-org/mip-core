% Test script for gptoolbox (all builds).
%
% Always runs the pure-MATLAB checks. On a compiled build it then exercises
% EVERY MEX shipped in the .mhl; on a pure-MATLAB (`any`) build, where no MEX
% are present, it stops after the MATLAB checks.
%
% Why exercise every MEX: a MEX can compile/link cleanly yet still fail at
% load/run (missing runtime lib, ABI/symbol mismatch, wrong triplet), and the
% only gate that catches it is the test actually *invoking* it. Loading alone is
% not enough -- e.g. the El Topo 32-vs-64-bit BLAS bug loaded fine and only
% crashed once a BLAS routine ran with real data. So every MEX is called with
% inputs valid enough to reach its real work, with light sanity checks; a few
% get correctness asserts. Completeness -- that *every* shipped MEX was invoked
% -- is enforced by the channel test runner (scripts/test_one.m), which diffs
% the built MEX against what `inmem` shows was loaded; it is not re-checked here.
%
% Each test is its own %% section so it can be run on its own in the editor
% (after the relevant Setup section, which defines the shared fixtures).

%% Setup (pure-MATLAB)
rng('default');
V2 = [0 0; 1 0; 1 1; 0 1];                  % 2D square
F2 = [1 2 3; 1 3 4];

%% MATLAB: normalizerow
fprintf('Testing normalizerow...\n');
B = normalizerow([3 4; 0 5; 1 0]);
assert(all(abs(sqrt(sum(B.^2, 2)) - 1) < 1e-12), 'normalizerow did not produce unit rows');

%% MATLAB: doublearea
fprintf('Testing doublearea...\n');
assert(abs(sum(abs(doublearea(V2, F2))) - 2) < 1e-12, 'doublearea wrong');

%% MATLAB: cotmatrix
fprintf('Testing cotmatrix...\n');
L = cotmatrix([0 0 0; 1 0 0; 0 1 0; 1 1 0], F2);
assert(isequal(size(L), [4 4]) && max(max(abs(L - L.'))) < 1e-12, 'cotmatrix wrong');

%% Stop here on the pure-MATLAB `any` build (ships no compiled MEX)
% has_mex() keys off the package's *effective* architecture -- the arch
% `mip test` installed -- not the machine's, so it is correct even when an
% `any` build is produced on a compiled-arch runner. On `any` there are no
% MEX, so finish after the pure-MATLAB checks above.
if ~mip.build.has_mex(mip.test.get_fqn())
    fprintf('SUCCESS\n');
    return
end

%% Setup (MEX fixtures)
[V, F]  = subdivided_sphere(2);            % closed sphere: 162 V, 320 F
nV = size(V, 1);
VN = normalizerow(V);                       % per-vertex normals (= positions on unit sphere)
P  = [0 0 0; 0.3 -0.1 0.2; 2 0 0];         % query points
S_iso = V(:,3);                             % per-vertex scalar field (z)

E2 = [1 2; 2 3; 3 4; 4 1];
Su = [1 0; 0 1; 0 1; 1 0];                  % #V2 x 2 scalar fields (upper_envelope)

Va = [0 0 0; 1 0 0; 0 1 0; 0 0 1];          % tetrahedron, outward-oriented
Fa = [1 3 2; 1 2 4; 1 4 3; 2 3 4];
Vb = Va + [0.3 0.1 0.1]; Fb = Fa;           % overlapping tet
Vin = Va * 0.3 + 0.2; Fin = Fa;             % small tet inside Va
TVt = Va; TT = [1 2 3 4];                    % single-tet volume mesh

Pc = [0 0; 0 1; 1 1; 1 0];                   % 4 cubic-Bezier control points (one curve)
Qc = [0.5 0.5; 0.25 0.25];
Psp = [0 0; 0.5 1; 1.5 1; 2 0]; Csp = [1 2 3 4];     % spline: control pts + index
Ploop = [0 0; 0.5 1; 1.5 1; 2 0; 1.5 -1; 0.5 -1]; Cloop = [1 2 3 4; 4 5 6 1];

Poly = [1 0 -1; 1 0 -4];                     % polynomials x^2-1, x^2-4
dcurve = [(0:0.1:1)', ((0:0.1:1)').^2];      % open curve to fit
Hpsd = [reshape(eye(3),1,9); reshape([2 1 0; 1 2 0; 0 0 1],1,9)];
Scov = eye(3) + 0.1 * [0 1 0; -1 0 0; 0 0 0];
aV = [1 0 0; 0 1 0]; aW = [0 1 0; 1 0 0]; aA = [0 0 1; 0 0 1];
Ag = sparse([1 2 3 4 1], [2 3 4 1 3], 1, 4, 4); Ag = Ag + Ag.';
Vd = [0 0 0; 1 0 0; 1 1 0; 0 1 0]; Fd = [1 2 3; 1 3 4];   % disk for slim
bd = [1; 2; 3; 4]; bcd = [0 0; 1 0; 1 1; 0 1];
WV = [0 0 0; 1 0 0; 0.5 1 0]; WE = [1 2; 2 3; 3 1];      % wire
Vsr = [0.1 0.2; 1.9 0.1; 1.0 1.8]; Esr = [1 2; 2 3; 3 1];
src = [0 0 5]; rdir = [0 0 -1];

% Temp files for the file-reading MEX (write with gptoolbox writers, then read).
td = tempname; mkdir(td);
objf = fullfile(td, 'm.obj'); writeOBJ(objf, V, F);
mshf = fullfile(td, 'm.msh'); writeMSH(mshf, TVt, TT, []);
xmlf = fullfile(td, 'm.xml'); write_serialize_xml(xmlf, Va, Fa - 1);   % libigl stores 0-based F

%% MEX: fast_sparse
fprintf('Testing fast_sparse...\n');
I = [1; 2; 3; 1]; J = [1; 2; 3; 2]; Vv = [10; 20; 30; 5];
assert(isequal(full(fast_sparse(I, J, Vv, 3, 3)), full(sparse(I, J, Vv, 3, 3))), ...
    'fast_sparse disagrees with sparse');

%% MEX: orient2d
fprintf('Testing orient2d...\n');
assert(orient2d([0 0],[1 0],[0 1]) > 0 && orient2d([0 0],[1 0],[0 -1]) < 0, 'orient2d sign wrong');

%% MEX: orient3d
fprintf('Testing orient3d...\n');
assert(orient3d(Va(1,:), Va(2,:), Va(3,:), Va(4,:)) ~= 0, 'orient3d degenerate');

%% MEX: winding_number
fprintf('Testing winding_number...\n');
Vc = [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1] * 0.5;
Fcu = [1 3 2; 1 4 3; 5 6 7; 5 7 8; 1 2 6; 1 6 5; 4 7 3; 4 8 7; 1 5 8; 1 8 4; 2 3 7; 2 7 6];
assert(abs(abs(winding_number(Vc, Fcu, [0 0 0])) - 1) < 1e-6, 'winding_number inside wrong');
assert(abs(winding_number(Vc, Fcu, [10 0 0])) < 1e-6, 'winding_number outside wrong');

%% MEX: eltopo
fprintf('Testing eltopo...\n');
[Vs, Fs] = subdivided_sphere(1);
[Ue, ~, te] = eltopo(Vs, Fs, Vs + [0.25 0 0]);
assert(all(isfinite(Ue(:))) && abs(te - 1) < 1e-6, 'eltopo no-collision wrong');
ns = size(Vs, 1);
[Uc, ~, tc] = eltopo([Vs + [-1.5 0 0]; Vs + [1.5 0 0]], [Fs; Fs + ns], [Vs; Vs]);
gap = sqrt(sum((permute(Uc(1:ns,:),[1 3 2]) - permute(Uc(ns+1:end,:),[3 1 2])).^2, 3));
assert(all(isfinite(Uc(:))) && tc >= 0 && tc <= 1 && min(gap(:)) > 0, 'eltopo collision wrong');

%% MEX: aabb
fprintf('Testing aabb...\n');
[bb_min, bb_max, el] = aabb(V, F);
assert(~isempty(bb_min) && size(bb_min, 2) == 3 && ~isempty(el));

%% MEX: ambient_occlusion
fprintf('Testing ambient_occlusion...\n');
AO = ambient_occlusion(V, F, V, VN, 16);
assert(numel(AO) == nV && all(AO >= -1e-9 & AO <= 1 + 1e-9));

%% MEX: angle_derivatives
fprintf('Testing angle_derivatives...\n');
th = angle_derivatives(aV, aW, aA);
assert(numel(th) == size(aV, 1) && all(isfinite(th)));

%% MEX: blue_noise
fprintf('Testing blue_noise...\n');
Pbn = blue_noise(V, F, 0.2);
assert(size(Pbn, 2) == 3);

%% MEX: bone_visible
fprintf('Testing bone_visible...\n');
vis = bone_visible(V, F, [0 0 2], [0 0 3]);
assert(numel(vis) == nV);

%% MEX: bone_visible_embree
fprintf('Testing bone_visible_embree...\n');
vis = bone_visible_embree(V, F, [0 0 2], [0 0 3]);
assert(numel(vis) == nV);

%% MEX: box_intersect
fprintf('Testing box_intersect...\n');
Ib = box_intersect([0 0 0], [1 1 1], [0.5 0 0], [1.5 1 1]);
assert(size(Ib, 2) == 2 && ~isempty(Ib));

%% MEX: collapse_small_triangles
fprintf('Testing collapse_small_triangles...\n');
FFc = collapse_small_triangles(V, F, 1e-7);
assert(size(FFc, 2) == 3);

%% MEX: decimate_libigl
fprintf('Testing decimate_libigl...\n');
[Wd, Gd] = decimate_libigl(V, F, 0.5);
assert(size(Gd, 2) == 3 && size(Gd, 1) <= size(F, 1) && ~isempty(Wd));

%% MEX: dual_laplacian
fprintf('Testing dual_laplacian...\n');
[Ld, Md] = dual_laplacian(TVt, TT);
assert(isequal(size(Ld), [4 4]) && isequal(size(Md), [4 4]));

%% MEX: exact_geodesic
fprintf('Testing exact_geodesic...\n');
D = exact_geodesic(V, F, 1, zeros(0,1), (2:nV)', zeros(0,1));
assert(numel(D) == nV - 1 && all(D >= -1e-9));

%% MEX: fast_roots
fprintf('Testing fast_roots...\n');
X = fast_roots(Poly, -10, 10);
assert(size(X, 1) == 2);

%% MEX: fit_cubic_bezier
fprintf('Testing fit_cubic_bezier...\n');
cub = fit_cubic_bezier(dcurve, 0.01);   % cell of 4-by-dim control-point blocks
assert(iscell(cub) && ~isempty(cub) && size(cub{1}, 1) == 4);

%% MEX: fit_rotations_mex
fprintf('Testing fit_rotations_mex...\n');
R = fit_rotations_mex(Scov);
assert(isequal(size(R), [3 3]) && abs(det(R) - 1) < 1e-6);

%% MEX: form_factor
fprintf('Testing form_factor...\n');
FFr = form_factor(V2, E2);
assert(size(FFr, 1) == size(E2, 1));

%% MEX: gjk_intersect
fprintf('Testing gjk_intersect...\n');
assert(gjk_intersect(Va, Fa, Vb, Fb) == true);   % overlapping tets

%% MEX: gjk_penetration
fprintf('Testing gjk_penetration...\n');
depth = gjk_penetration(Va, Fa, Vb, Fb);
assert(~isempty(depth) && depth >= 0);

%% MEX: icp
fprintf('Testing icp...\n');
[Ricp, ticp] = icp(Va, Fa, Vb, Fb, 'NumSamples', 50, 'MaxIter', 5);
assert(isequal(size(Ricp), [3 3]) && numel(ticp) == 3);

%% MEX: in_element_aabb
fprintf('Testing in_element_aabb...\n');
idx = in_element_aabb(V2, F2, [0.2 0.2; 0.8 0.8]);
assert(numel(idx) == 2);

%% MEX: intersect_other
fprintf('Testing intersect_other...\n');
IFo = intersect_other(Va, Fa, Vb, Fb);
assert(size(IFo, 2) == 2);

%% MEX: isolines
fprintf('Testing isolines...\n');
[iV, iE] = isolines(V, F, S_iso, [-0.5; 0; 0.5]);
assert(size(iV, 2) == 3 && size(iE, 2) == 2);

%% MEX: mesh_boolean
fprintf('Testing mesh_boolean...\n');
[VCb, FCb] = mesh_boolean(Va, Fa, Vb, Fb, 'union');
assert(~isempty(VCb) && size(FCb, 2) == 3);

%% MEX: mpr_intersect
fprintf('Testing mpr_intersect...\n');
assert(mpr_intersect(Va, Fa, Vb, Fb) == true);

%% MEX: mpr_penetration
fprintf('Testing mpr_penetration...\n');
depth = mpr_penetration(Va, Fa, Vb, Fb);
assert(~isempty(depth) && depth >= 0);

%% MEX: outer_hull
fprintf('Testing outer_hull...\n');
[HV, HG] = outer_hull(V, F);
assert(~isempty(HV) && size(HG, 2) == 3);

%% MEX: point_cubic_squared_distance
fprintf('Testing point_cubic_squared_distance...\n');
sqD = point_cubic_squared_distance(Qc, Pc);
assert(numel(sqD) == size(Qc, 1) && all(sqD >= -1e-12));

%% MEX: point_mesh_squared_distance
fprintf('Testing point_mesh_squared_distance...\n');
sqD = point_mesh_squared_distance(P, V, F);
assert(numel(sqD) == size(P, 1) && all(sqD >= -1e-12));

%% MEX: point_spline_signed_distance
fprintf('Testing point_spline_signed_distance...\n');
sd = point_spline_signed_distance(Qc, Psp, Csp);
assert(numel(sd) == size(Qc, 1) && all(isfinite(sd)));

%% MEX: point_spline_squared_distance
fprintf('Testing point_spline_squared_distance...\n');
sqD = point_spline_squared_distance(Qc, Psp, Csp);
assert(numel(sqD) == size(Qc, 1) && all(sqD >= -1e-12));

%% MEX: principal_curvature
fprintf('Testing principal_curvature...\n');
[PD1, ~, PV1] = principal_curvature(V, F);
assert(size(PD1, 1) == nV && numel(PV1) == nV);

%% MEX: psd_project_rows
fprintf('Testing psd_project_rows...\n');
Hp = psd_project_rows(Hpsd);
assert(isequal(size(Hp), size(Hpsd)) && all(isfinite(Hp(:))));

%% MEX: ray_mesh_intersect
fprintf('Testing ray_mesh_intersect...\n');
[rid, rt] = ray_mesh_intersect(src, rdir, V, F);
assert(numel(rid) == 1 && numel(rt) == 1);

%% MEX: ray_mesh_intersect_all
fprintf('Testing ray_mesh_intersect_all...\n');
Ir = ray_mesh_intersect_all(src, rdir, V, F);
assert(~isempty(Ir));     % a ray through the sphere hits it

%% MEX: readMSH
fprintf('Testing readMSH...\n');
[Vm, ~, Tm] = readMSH(mshf);
assert(size(Vm, 2) == 3 && size(Tm, 2) == 4);

%% MEX: read_mesh_from_xml (skipped on Windows -- upstream bug, gated out of build)
% read_mesh_from_xml.cpp assigns `filename` only inside a POSIX `#if __unix__`
% (wordexp) block with no Windows branch, so the MEX reads an empty path and fails
% on Windows. It's an upstream gptoolbox bug we don't patch; compile.m drops it from
% the Windows build, so skip it here in lockstep (the test_one.m coverage gate diffs
% built vs loaded MEX -- the build exclusion and this guard must move together).
if ~ispc
    fprintf('Testing read_mesh_from_xml...\n');
    [Vx, Fx] = read_mesh_from_xml(xmlf);
    assert(size(Vx, 1) == size(Va, 1) && size(Fx, 1) == size(Fa, 1));
end

%% MEX: read_triangle_mesh (skipped on Windows -- upstream bug, gated out of build)
% Same upstream POSIX-only path handling: read_triangle_mesh.cpp wraps the path in
% literal quotes that only wordexp strips, so on Windows the quotes survive and the
% file is not found. Excluded from the Windows build in compile.m; skip in lockstep.
if ~ispc
    fprintf('Testing read_triangle_mesh...\n');
    [Vo, Fo] = read_triangle_mesh(objf);
    assert(size(Vo, 1) == nV && size(Fo, 1) == size(F, 1));
end

%% MEX: refine_triangulation
fprintf('Testing refine_triangulation...\n');
[Vr, Fr] = refine_triangulation(V2, E2, F2, 'Flags', 'ra0.1');
assert(size(Fr, 2) == 3 && size(Fr, 1) >= size(F2, 1));

%% MEX: reorient_facets
fprintf('Testing reorient_facets...\n');
FFo = reorient_facets(V, F);
assert(isequal(size(FFo), size(F)));

%% MEX: segment_graph
fprintf('Testing segment_graph...\n');
C = segment_graph(Ag);
assert(numel(C) == size(Ag, 1));

%% MEX: selfintersect
fprintf('Testing selfintersect...\n');
[VV, FFs] = selfintersect(V, F);
assert(~isempty(VV) && size(FFs, 2) == 3);

%% MEX: signed_distance
fprintf('Testing signed_distance...\n');
Sd = signed_distance(P, V, F);
assert(numel(Sd) == size(P, 1));

%% MEX: signed_distance_isosurface
fprintf('Testing signed_distance_isosurface...\n');
[SV, SF] = signed_distance_isosurface(V, F, 'GridSize', 8);
assert(~isempty(SV) && size(SF, 2) == 3);

%% MEX: simplify_polyhedron
fprintf('Testing simplify_polyhedron...\n');
[Wsp, Gsp] = simplify_polyhedron(Va, Fa);
assert(~isempty(Wsp) && size(Gsp, 2) == 3);

%% MEX: slim
fprintf('Testing slim...\n');
U = slim(Vd, Fd, bd, bcd, 'Iters', 5);
assert(size(U, 1) == size(Vd, 1) && all(isfinite(U(:))));

%% MEX: snap_rounding
fprintf('Testing snap_rounding...\n');
[VI, EI] = snap_rounding(Vsr, Esr);
assert(size(VI, 2) == 2 && size(EI, 2) == 2);

%% MEX: solid_angle
fprintf('Testing solid_angle...\n');
SA = solid_angle(V, F, [0 0 0]);
assert(numel(SA) == size(F, 1));

%% MEX: spline_winding_number
fprintf('Testing spline_winding_number...\n');
Wsw = spline_winding_number(Ploop, Cloop, [1 0]);
assert(numel(Wsw) == 1 && isfinite(Wsw));

%% MEX: split_nonmanifold
fprintf('Testing split_nonmanifold...\n');
SFn = split_nonmanifold(F);
assert(size(SFn, 2) == 3);

%% MEX: tetrahedralize
fprintf('Testing tetrahedralize...\n');
[TVo, TTo] = tetrahedralize(Va, Fa, 'Flags', '-q2');
assert(~isempty(TTo) && size(TTo, 2) == 4);

%% MEX: triangulate
fprintf('Testing triangulate...\n');
[TVt2, TFt2] = triangulate(V2, E2);
assert(size(TFt2, 2) == 3 && ~isempty(TVt2));

%% MEX: trim_with_solid
fprintf('Testing trim_with_solid...\n');
[Vt, Ft] = trim_with_solid(Vin, Fin, Va, Fa);
assert(~isempty(Vt) && size(Ft, 2) == 3);

%% MEX: upper_envelope
fprintf('Testing upper_envelope...\n');
[VVu, FFu] = upper_envelope(V2, F2, Su);
assert(~isempty(VVu) && size(FFu, 2) == 3);

%% MEX: wire_mesh
fprintf('Testing wire_mesh...\n');
[Vw, Fw] = wire_mesh(WV, WE, 'Thickness', 0.05);
assert(~isempty(Vw) && size(Fw, 2) == 3);

%% MEX: impaste (macOS only; clipboard paste -- cannot fully run headless)
% Invoking it still loads the MEX (catches load/ABI failures); guard the
% expected "no image" runtime error so the test does not fail on it.
if ismac
    fprintf('Testing impaste...\n');
    try; impaste(); catch; end %#ok<NOSEMI>
end

%% Done
fprintf('SUCCESS\n');


function write_serialize_xml(filename, V, F)
% Write V (#V x dim) and F (#F x dim) in libigl's igl::xml::serialize_xml format
% (root <serialization>, one element per matrix with rows/cols and a `matrix`
% attribute whose value is "\n v,v,v,\n ..."), as read by read_mesh_from_xml.
    fid = fopen(filename, 'w');
    fprintf(fid, '<?xml version="1.0"?>\n<serialization>\n');
    write_mat(fid, 'vertices', V, '%.17g');
    write_mat(fid, 'faces',    F, '%d');
    fprintf(fid, '</serialization>\n');
    fclose(fid);
end

function write_mat(fid, name, M, fmt)
    [r, c] = size(M);
    rowfmt = [repmat([fmt ','], 1, c) '\n'];
    fprintf(fid, '<%s rows="%d" cols="%d" matrix="\n', name, r, c);
    fprintf(fid, rowfmt, M.');
    fprintf(fid, '"/>\n');
end
