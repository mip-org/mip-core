% Compile gptoolbox MEX files (linux_x86_64, macos_arm64, windows_x86_64).
% compile.m runs with cwd set to the package source root.
%
% Approach (see BUILD_NOTES.md): CMake builds ONLY the C/C++ dependency
% libraries as static libs (predicates, tetgen, triangle, libccd, tinyxml2,
% embree) and discovers the header-only deps (libigl, Eigen, cyCodeBase, CGAL,
% Boost) + static gmp/mpfr, emitting a manifest. CMake never touches MATLAB, so
% there is no find_package(Matlab). Each MEX is then compiled and linked with
% mex(), driven by the `groups` table below (mirrors upstream's compile_each),
% so it uses the channel's mexopts (static libstdc++/libgcc, MATLAB libs by
% basename — no patchelf). The full feature set is built (CGAL, Embree, XML;
% El Topo and the macOS-only impaste are handled separately / TODO).

fprintf('=== Compiling gptoolbox MEX files ===\n');

% MATLAB injects its own libcurl/libstdc++ onto LD_LIBRARY_PATH, which breaks
% the system git/curl that CMake FetchContent shells out to. Clear it for the
% duration of this script; onCleanup restores it.
if isunix && ~ismac
    origLdPath = getenv('LD_LIBRARY_PATH');
    setenv('LD_LIBRARY_PATH', '');
    restoreLdPath = onCleanup(@() setenv('LD_LIBRARY_PATH', origLdPath)); %#ok<NASGU>
end

srcRoot = pwd;
mexDir = fullfile(srcRoot, 'mex');
if ~exist(mexDir, 'dir')
    error('mex/ directory not found at %s', mexDir);
end
if ~exist(fullfile(srcRoot, 'CMakeLists.txt'), 'file')
    error('CMakeLists.txt (dependency builder) not found at %s', srcRoot);
end

% ---- 1. Build the dependency static libraries with CMake ----------------
depsBuild = tempname;
mkdir(depsBuild);
cleanupDeps = onCleanup(@() rmdir_silent(depsBuild)); %#ok<NASGU>

% Per-arch dependency discovery. CGAL + Boost are prebuilt header-only on every
% arch (Boost is never compiled): macOS gets them from Homebrew, Linux from dnf,
% Windows by downloading the release headers. gmp/mpfr is the one real library:
% brew on macOS, built from source on Linux, vcpkg (MSVC-compatible .lib) on
% Windows.
prefixArg = '';
extraInc = {};   % extra -I flags prepended to the MEX include path (Linux gmp/mpfr)
genArg   = '';   % CMake generator selection (Windows uses the VS generator)
if ismac
    % Apple Clang is selected by the framework on macOS (per mip.yaml's
    % `compiler` field) — the native toolchain for CGAL/libigl/embree, uniform
    % libc++, and able to compile the Objective-C++ impaste. The framework also
    % exports CC/CXX so the CMake deps build below uses the same clang.
    [s, brewPrefix] = system('brew --prefix');
    if s == 0
        brewPrefix = strtrim(brewPrefix);
    else
        brewPrefix = '/opt/homebrew';
    end
    % Build the static deps for macOS 11.0 (oldest Apple-Silicon macOS) so they
    % don't out-version the MEX. The MEX's own minimum-load version is set by
    % the selected mexopts (-mmacosx-version-min=11.0 in clang.xml/clang++.xml);
    % this just keeps the CMake-built .a's consistent (no "built for newer
    % macOS" link warnings).
    prefixArg = sprintf(' -DCMAKE_PREFIX_PATH="%s" -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0', brewPrefix);
elseif isunix
    % Linux: CGAL/Boost headers come from dnf (mip.yaml setup), but RHEL/EPEL
    % ship no static gmp/mpfr (.a). Build them from source into an isolated,
    % ephemeral prefix this script owns (no /usr/local pollution, auto-cleaned)
    % and pass the .a paths so CMakeLists skips its find_library. CGAL links
    % these. Built with the same gcc as mex (CC exported by setup_mex_compilers
    % in bundle_one). LD_LIBRARY_PATH was cleared above so system curl works.
    gmpmpfr = tempname;
    mkdir(gmpmpfr);
    cleanupGmpMpfr = onCleanup(@() rmdir_silent(gmpmpfr)); %#ok<NASGU>
    % --enable-fat: gmp otherwise bakes the build runner's CPU assembly into the
    % .a (an -march=native-style hazard → SIGILL on older end-user CPUs). Fat
    % builds all x86 variants and dispatches at runtime.
    build_autotools_static('https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz', ...
        'gmp-6.3.0', {'--enable-static', '--disable-shared', '--with-pic', ...
        '--enable-fat'}, gmpmpfr);
    build_autotools_static('https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz', ...
        'mpfr-4.2.1', {'--enable-static', '--disable-shared', '--with-pic', ...
        sprintf('--with-gmp=%s', gmpmpfr)}, gmpmpfr);
    prefixArg = sprintf(' -DGMP_STATIC="%s/lib/libgmp.a" -DMPFR_STATIC="%s/lib/libmpfr.a"', ...
        gmpmpfr, gmpmpfr);
    % Put our gmp.h/mpfr.h first: they must match the .a we just built (CGAL's
    % dnf deps may also drop older headers in /usr/include).
    extraInc = {['-I' fullfile(gmpmpfr, 'include')]};
elseif ispc
    % Windows: MSVC 2022, selected by the framework (per mip.yaml's `compiler`
    % field). embree has no MinGW support on Windows, and MSVC is MATLAB's
    % native Windows MEX compiler, so the .mexw64 is ABI-correct against
    % MATLAB's libmx. CGAL + Boost are fetched as header-only releases (never
    % compiled); gmp/mpfr come from vcpkg as MSVC static .lib (installed in
    % mip.yaml setup) via its CMake toolchain. El Topo is skipped on Windows
    % (see the eltopo block below).
    genArg = ' -G "Visual Studio 17 2022" -A x64';

    % Fetch the .zip, not the .tar.xz: the Windows System32 bsdtar (used to
    % extract via system()) has no built-in xz on the windows-2022 image, so on
    % .tar.xz it shells out to an external xz over a pipe that deadlocks (a 6h
    % hang). zip and gzip decode in-process. The zip expands to the same
    % CGAL-6.0.1/ tree. See fetch_archive below.
    cgalRoot  = fetch_archive(['https://github.com/CGAL/cgal/releases/' ...
        'download/v6.0.1/CGAL-6.0.1.zip'], 'CGAL-6.0.1');
    boostRoot = fetch_archive(['https://archives.boost.io/release/1.86.0/' ...
        'source/boost_1_86_0.tar.gz'], 'boost_1_86_0');

    vcpkg = strrep(getenv('VCPKG_INSTALLATION_ROOT'), '\', '/');
    if isempty(vcpkg); vcpkg = 'C:/vcpkg'; end
    % vcpkg toolchain provides the static gmp/mpfr; CGAL_DIR points find_package
    % at the fetched CGAL; Boost is header-only via its include dir (force the
    % FindBoost module since the fetched tree has no BoostConfig).
    prefixArg = sprintf([ ...
        ' -DCMAKE_TOOLCHAIN_FILE="%s/scripts/buildsystems/vcpkg.cmake"' ...
        ' -DVCPKG_TARGET_TRIPLET=x64-windows-static-md' ...
        ' -DCGAL_DIR="%s"' ...
        ' -DBoost_INCLUDE_DIR="%s" -DBoost_NO_BOOST_CMAKE=ON'], ...
        vcpkg, strrep(cgalRoot, '\', '/'), strrep(boostRoot, '\', '/'));
end

% feature('numcores'), not maxNumCompThreads: the latter is MATLAB's
% computational-thread cap, which the matlab-actions CI session pins to 1, so
% the cmake build ran -j1. feature('numcores') re-probes the hardware.
nproc = feature('numcores');
cfgCmd = sprintf('cmake -S "%s" -B "%s"%s%s -DCMAKE_BUILD_TYPE=Release', ...
    srcRoot, depsBuild, genArg, prefixArg);
fprintf('Configuring dependency libraries:\n  %s\n', cfgCmd);
[status, out] = system(cfgCmd);
fprintf('%s', out);
if status ~= 0
    error('CMake configuration of dependency libraries failed (exit %d)', status);
end

% embree's internal archives (sys/math/...) build as deps of the `embree`
% target; predicates/tetgen/triangle/ccd/tinyxml2 are explicit. El Topo is not
% built on Windows (skipped — see the eltopo block below).
targets = 'embree predicates tetgen triangle ccd tinyxml2';
if ispc
    targets = [targets ' eltopo_msvc'];     % our own MSVC target (see CMakeLists.txt)
else
    targets = [targets ' eltopo_release'];  % eltopo3d's gcc/clang target
end
buildCmd = sprintf('cmake --build "%s" --config Release --target %s -j%d', ...
    depsBuild, targets, nproc);
fprintf('Building dependency libraries:\n  %s\n', buildCmd);
[status, out] = system(buildCmd);
fprintf('%s', out);
if status ~= 0
    error('CMake build of dependency libraries failed (exit %d)', status);
end

% ---- 2. Parse the manifest: include dirs + categorized lib paths --------
% Emitted per-config (manifest-<CONFIG>.txt) so the multi-config VS generator on
% Windows resolves $<TARGET_FILE> per config; we always configure/build Release.
manifest = fileread(fullfile(depsBuild, 'manifest-Release.txt'));
incFlags = {};
libsByCat = containers.Map();
for ln = splitlines(string(manifest))'
    s = strtrim(char(ln));
    if startsWith(s, 'I ')
        d = strtrim(s(3:end));
        if ~isempty(d) && isfolder(d) && ~any(strcmp(incFlags, ['-I' d]))
            incFlags{end+1} = ['-I' d]; %#ok<SAGROW>
        end
    elseif startsWith(s, 'L ')
        rest = strtrim(s(3:end));
        sp = find(rest == ' ', 1);
        cat = rest(1:sp-1);
        p = strtrim(rest(sp+1:end));
        if ~isKey(libsByCat, cat); libsByCat(cat) = {}; end
        v = libsByCat(cat); v{end+1} = p; libsByCat(cat) = v;
    end
end
incFlags{end+1} = ['-I' mexDir];   % gptoolbox's own mex/ headers
incFlags = [extraInc, incFlags];   % Linux gmp/mpfr headers first (no-op elsewhere)

% ---- 3. Compile each MEX with mex() -------------------------------------
% -largeArrayDims (classic API), -std=c++17 (libigl/CGAL), -DMEX (upstream's
% global define), -DCY_NO_INTRIN_H (no x86 <immintrin.h> in cyCodeBase / no AVX
% baking). Per-group -DWITH_CGAL/-DWITH_EMBREE/-DWITH_PREDICATES go with the
% matching library link.
% C++17 for libigl/CGAL. Flag syntax differs by compiler: gcc/clang take
% -std=c++17 via CXXFLAGS; MSVC takes /std:c++17 via COMPFLAGS, plus /bigobj
% (CGAL's heavy templates overflow MSVC's default object section limit) and the
% NOMINMAX / _USE_MATH_DEFINES defines CGAL/Eigen need against <windows.h>.
if ispc
    % WIN32: MSVC defines _WIN32 but not bare WIN32 (MinGW defines both). libigl's
    % Timer.h (pulled in by the embree MEX via EmbreeIntersector) guards its
    % <windows.h> include on `#ifdef WIN32` and otherwise includes POSIX
    % <sys/time.h>, which MSVC lacks (C1083 on bone_visible_embree). Define WIN32
    % so it takes the Windows path; it's the conventional Windows macro (MSVC
    % project defaults define it) so it's safe for the other deps too.
    %
    % CCD_STATIC_DEFINE / EMBREE_STATIC_LIB: libccd and embree decorate their
    % public API with __declspec(dllimport) by default. We link both as static
    % libs, but the MEX are compiled by mex() (not CMake), so they don't inherit
    % the static targets' compile definitions; without these, MSVC emits import
    % stubs and the link fails with unresolved __imp_* externals (e.g.
    % gjk_intersect -> __imp_ccdGJKIntersect, the embree MEX -> __imp_rtc*).
    % Windows/MSVC only: GCC/Clang have no import-stub mechanism, so the macros
    % are a no-op off-Windows, and they're harmless to MEX that include neither
    % header. See BUILD_NOTES.md.
    %
    % _DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR: the MEX is built /MD with the
    % runner's latest VS2022 toolset (14.4x), but at load time its MSVCP140.dll
    % resolves to MATLAB R2023a's OLDER bundled copy (<matlabroot>\bin\win64),
    % which the host process searches ahead of System32. VS2022 17.10 (toolset
    % 14.40) made std::mutex's default constructor constexpr/zero-init; a
    % 14.40+-built mutex run against a pre-14.40 MSVCP140.dll dereferences a
    % field the old lock code expects to be initialized -> null-deref Access
    % Violation in MSVCP140 (symbolized MSVCP140!_Thrd_yield). This is the
    % mesh_boolean crash: its CGAL exact-construction path is the first MEX to
    % touch std::mutex at runtime. Microsoft's opt-out macro restores the
    % pre-14.40 (non-constexpr) constructor so the MEX stays compatible with the
    % runtime MATLAB ships. Harmless to MEX that never construct a std::mutex.
    % See microsoft/STL#4730.
    stdFlags = {'COMPFLAGS=$COMPFLAGS /std:c++17 /bigobj', ...
                '-DNOMINMAX', '-D_USE_MATH_DEFINES', '-DWIN32', ...
                '-DCCD_STATIC_DEFINE', '-DEMBREE_STATIC_LIB', ...
                '-D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR'};
else
    stdFlags = {'CXXFLAGS=$CXXFLAGS -std=c++17'};
end
common = [{'-largeArrayDims'}, stdFlags, {'-DMEX', '-DCY_NO_INTRIN_H'}, ...
          incFlags, {'-outdir', mexDir}];

% Groups mirror upstream mex/CMakeLists.txt compile_each() with all features
% on. Each row: { extra-defines, {lib categories}, {source basenames} }.
groups = {
    {}, {}, { ...
        'aabb','angle_derivatives','bone_visible','blue_noise', ...
        'collapse_small_triangles','decimate_libigl','dual_laplacian', ...
        'exact_geodesic','fast_sparse','fit_rotations_mex','fit_cubic_bezier', ...
        'icp','isolines','in_element_aabb','psd_project_rows', ...
        'principal_curvature','readMSH','read_triangle_mesh','segment_graph', ...
        'signed_distance','simplify_polyhedron','slim','split_nonmanifold', ...
        'solid_angle'};
    {},                        {'ccd'},        {'gjk_intersect','gjk_penetration','mpr_intersect','mpr_penetration'};
    {},                        {},             {'fast_roots','point_spline_squared_distance','point_cubic_squared_distance'};
    {},                        {'tetgen'},     {'tetrahedralize'};
    {},                        {'triangle'},   {'refine_triangulation'};
    {'-DWITH_CGAL'},           {'triangle','cgal'}, {'triangulate'};
    {'-DWITH_PREDICATES'},     {'predicates'}, {'orient2d','orient3d','point_spline_signed_distance','spline_winding_number'};
    {'-DWITH_EMBREE'},         {'embree'},     {'ambient_occlusion','bone_visible_embree','ray_mesh_intersect','ray_mesh_intersect_all','reorient_facets'};
    {'-DWITH_EMBREE','-DWITH_CGAL'}, {'embree','cgal'}, {'winding_number'};
    {'-DWITH_CGAL'},           {'cgal'},       { ...
        'box_intersect','form_factor','intersect_other','mesh_boolean', ...
        'outer_hull','point_mesh_squared_distance','selfintersect', ...
        'signed_distance_isosurface','snap_rounding','trim_with_solid', ...
        'upper_envelope','wire_mesh'};
    {'-DWITH_CGAL'},           {'cgal','xml'}, {'read_mesh_from_xml'};
    };

% Per-arch MEX exclusions. read_mesh_from_xml and read_triangle_mesh are broken
% on Windows by an UPSTREAM gptoolbox bug, not by our build: both extract the
% input path only inside a POSIX `#if defined(__unix__)` (wordexp) block, so on
% Windows read_mesh_from_xml gets an empty filename and read_triangle_mesh gets a
% still-quoted path -- both fail with "file not found" at runtime. (readMSH does
% the same job correctly -- unconditional mxArrayToString, no quotes -- and works
% on Windows.) We don't carry patches for upstream source bugs, so drop these two
% from the Windows build. This MUST stay in sync with the matching `if ~ispc`
% guards in test_gptoolbox.m so the issue-#16 coverage gate (built == loaded)
% stays balanced. (Same per-arch pattern as the macOS-only impaste below.)
if ispc
    excludeMex = {'read_mesh_from_xml', 'read_triangle_mesh'};
    for g = 1:size(groups, 1)
        groups{g, 3} = setdiff(groups{g, 3}, excludeMex, 'stable');
    end
end

nBuilt = 0;
for g = 1:size(groups, 1)
    extra = groups{g, 1};
    cats  = groups{g, 2};
    names = groups{g, 3};
    libs = {};
    for c = 1:numel(cats)
        if ~isKey(libsByCat, cats{c})
            error('Manifest is missing lib category "%s".', cats{c});
        end
        libs = [libs, libsByCat(cats{c})]; %#ok<AGROW>
    end
    for k = 1:numel(names)
        name = names{k};
        src = fullfile(mexDir, [name '.cpp']);
        if ~exist(src, 'file')
            error('Expected MEX source missing: %s', src);
        end
        fprintf('  mex %s\n', name);
        mex(common{:}, extra{:}, '-output', name, src, libs{:});
        nBuilt = nBuilt + 1;
    end
end
% El Topo is handled on its own: it needs BLAS/LAPACK, which don't fit the
% category->lib model. Its BLAS interface is platform-gated: macOS uses CBLAS
% (cblas_*), elsewhere it uses -DUSE_FORTRAN_BLAS (daxpy_, ...). So on macOS link
% Accelerate (provides CBLAS, OS-framework -> self-contained); off-macOS link
% MATLAB's Fortran BLAS/LAPACK (-lmwlapack/-lmwblas, also self-contained as
% MATLAB provides them -- MATLAB's Windows Fortran ABI is MWF77_UNDERSCORE1,
% matching daxpy_, same as Linux). The .a/.lib precedes the BLAS so the linker
% resolves eltopo's references; <eltopo.h> is already in incFlags via the
% libeltopo target in the manifest. On Windows libeltopo is our own MSVC target
% (eltopo_msvc; see CMakeLists.txt) since eltopo3d's CMakeLists is gcc/clang-only.
eltopoLib = libsByCat('eltopo');
eltopoSrcs = {fullfile(mexDir, 'eltopo.cpp')};
if ismac
    blasArgs = {'LDFLAGS=$LDFLAGS -framework Accelerate'};
else
    % Off-macOS, eltopo links MATLAB's libmwblas/libmwlapack, whose Fortran
    % integer is 64-bit (ptrdiff_t); El Topo's wrappers declare 32-bit int.
    % eltopo_blas_shim.cpp bridges that width gap: El Topo's BLAS/LAPACK calls
    % are renamed to eltopo_* (CMakeLists.txt ELTOPO_BLAS_RENAME) and bind to the
    % shim, which widens the integer args and forwards to MATLAB's BLAS. macOS
    % links Accelerate (32-bit-int CBLAS, matches El Topo) and needs no shim.
    % The shim is overlaid at srcRoot (a channel-provided file, like compile.m).
    blasArgs = {'-lmwlapack', '-lmwblas'};
    eltopoSrcs{end+1} = fullfile(srcRoot, 'eltopo_blas_shim.cpp');
end
fprintf('  mex eltopo\n');
mex(common{:}, '-output', 'eltopo', eltopoSrcs{:}, ...
    eltopoLib{:}, blasArgs{:});
nBuilt = nBuilt + 1;

% impaste (macOS only): Objective-C++ clipboard paste, two sources
% (impaste.cpp + paste.mm) linking the Cocoa/Foundation system frameworks
% (OS-provided -> self-contained). clang compiles the .mm directly; the
% Homebrew-gcc toolchain can't, which is part of why macOS uses clang.
if ismac
    fprintf('  mex impaste\n');
    % paste.mm is manual-reference-counting Objective-C++; pass -fno-objc-arc so
    % it builds regardless of the toolchain's ARC default (the memory model is a
    % per-.mm property, declared here at the call site rather than in the mexopts).
    mex(common{:}, '-output', 'impaste', ...
        fullfile(mexDir, 'impaste.cpp'), fullfile(mexDir, 'paste.mm'), ...
        'CXXFLAGS=$CXXFLAGS -fno-objc-arc', ...
        'LDFLAGS=$LDFLAGS -framework Cocoa -framework Foundation');
    nBuilt = nBuilt + 1;
end

fprintf('Built %d MEX files.\n', nBuilt);

fprintf('=== gptoolbox MEX compilation complete ===\n');


function rmdir_silent(d)
if exist(d, 'dir')
    try; rmdir(d, 's'); catch; end
end
end


function build_autotools_static(url, dirName, cfgArgs, prefix)
% Download an autotools source tarball and install a static lib into `prefix`.
% Used on Linux for gmp/mpfr (no static .a in RHEL/EPEL). Builds in a scratch
% dir that's removed on return; only the installed prefix persists.
work = tempname;
mkdir(work);
cleanupWork = onCleanup(@() rmdir_silent(work)); %#ok<NASGU>
tarball = fullfile(work, 'src.tar.xz');
run_or_error(sprintf('curl -fL --retry 5 -o "%s" "%s"', tarball, url), ...
    ['download ' dirName]);
run_or_error(sprintf('tar xf "%s" -C "%s"', tarball, work), ['extract ' dirName]);
src = fullfile(work, dirName);
run_or_error(sprintf('cd "%s" && ./configure --prefix="%s" %s', ...
    src, prefix, strjoin(cfgArgs, ' ')), ['configure ' dirName]);
run_or_error(sprintf('cd "%s" && make -j%d && make install', ...
    src, feature('numcores')), ['build ' dirName]);
end


function run_or_error(cmd, what)
fprintf('  [%s]\n', what);
[st, out] = system(cmd);
fprintf('%s', out);
if st ~= 0
    error('gptoolbox:linuxDeps', '%s failed (exit %d)', what, st);
end
end


function root = fetch_archive(url, dirName)
% Download a source/header archive and extract it; return the path to its
% top-level <dirName> directory. Used on Windows to fetch the header-only CGAL
% and Boost releases (never compiled). Windows ships curl.exe and a bsdtar
% (tar.exe); use .zip (CGAL) or .tar.gz (Boost) here, never .tar.xz — that
% bsdtar build has no built-in xz, so on .tar.xz it shells out to an external
% xz over a Windows pipe that deadlocks (the 6h CGAL hang). zip and gzip
% decode in-process and are fine.
%
% Call System32 bsdtar by absolute path, not a bare "tar": some runners put
% MSYS2's GNU tar first on PATH, and GNU tar cannot read .zip at all. bsdtar
% handles both .zip and .tar.gz natively.
work = tempname;
mkdir(work);
[~, ~, ext] = fileparts(url);
arc = fullfile(work, ['src' ext]);
tarExe = fullfile(getenv('SystemRoot'), 'System32', 'tar.exe');
run_or_error(sprintf('curl -fL --retry 5 -o "%s" "%s"', arc, url), ...
    ['download ' dirName]);
run_or_error(sprintf('"%s" -xf "%s" -C "%s"', tarExe, arc, work), ['extract ' dirName]);
root = fullfile(work, dirName);
if ~isfolder(root)
    error('gptoolbox:fetchArchive', 'Expected %s after extracting %s', root, url);
end
end
