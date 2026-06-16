function compile_windows()
% compile_windows.m — compile SPM MEX files on Windows (MinGW-w64).
% Runs with cwd set to the package source root.
%
% SPM's upstream build is a recursive GNU-make tree (src/Makefile +
% subdir/external Makefiles) that assumes a Unix shell (sh, rm, mv, cp,
% uname, which) and drives `mex` from that shell. Rather than recreate that
% environment on the Windows runner, this script reproduces the same
% compilations as direct mex() calls — the convention used by the other
% native packages in this channel (see fmmlib2d/compile_windows.m,
% sedumi/compile.m). The MinGW-w64 toolchain and the static-linking
% mingw64.xml are selected by setup_mex_compilers, so the resulting .mexw64
% files carry no MinGW runtime DLL dependency.
%
% Every rule below is taken verbatim from the upstream Makefiles for the
% MINGW64 platform (MEXEXT=mexw64, MEXOPTS += -DSPM_WIN32, AR = ar rcs):
%   src/Makefile, src/Makefile.var,
%   @file_array/private/Makefile, @gifti/private/Makefile,
%   @xmltree/private/Makefile, toolbox/FieldMap/Makefile,
%   external/bemcp/Makefile, external/Makefile.fieldtrip.
% OpenMP is off upstream (USE_OPENMP defaults to 0), so it is off here too.

fprintf('=== Compiling SPM MEX files (Windows/MinGW-w64) ===\n');

root = pwd;
restore = onCleanup(@() cd(root));

mx   = mexext;                                  % 'mexw64'
opts = {'-O', '-largeArrayDims', '-DSPM_WIN32'};
arch = ['spm_vol_utils.' mx '.a'];              % static archive name

srcDir = fullfile(root, 'src');
if ~isfolder(srcDir)
    error('spm: src/ directory not found at %s', srcDir);
end

%% ---- 1. spm_vol_utils archive --------------------------------------------
% spm_vol_utils.c is compiled once per datatype (-D...), each object renamed
% to utils_<type>.<mexext>.o, then archived with MinGW ar alongside four
% support objects. The volume MEX below link against this archive.
cd(srcDir);

utilsVariants = {
    'utils_uchar',     {'-DSPM_UNSIGNED_CHAR'}
    'utils_short',     {'-DSPM_SIGNED_SHORT'}
    'utils_int',       {'-DSPM_SIGNED_INT'}
    'utils_schar',     {'-DSPM_SIGNED_CHAR'}
    'utils_ushort',    {'-DSPM_UNSIGNED_SHORT'}
    'utils_uint',      {'-DSPM_UNSIGNED_INT'}
    'utils_float',     {'-DSPM_FLOAT'}
    'utils_double',    {'-DSPM_DOUBLE'}
    'utils_uint64',    {'-DSPM_UNSIGNED_LONG_LONG'}
    'utils_int64',     {'-DSPM_SIGNED_LONG_LONG'}
    'utils_short_s',   {'-DSPM_SIGNED_SHORT',       '-DSPM_BYTESWAP'}
    'utils_int_s',     {'-DSPM_SIGNED_INT',         '-DSPM_BYTESWAP'}
    'utils_ushort_s',  {'-DSPM_UNSIGNED_SHORT',     '-DSPM_BYTESWAP'}
    'utils_uint_s',    {'-DSPM_UNSIGNED_INT',       '-DSPM_BYTESWAP'}
    'utils_float_s',   {'-DSPM_FLOAT',              '-DSPM_BYTESWAP'}
    'utils_double_s',  {'-DSPM_DOUBLE',             '-DSPM_BYTESWAP'}
    'utils_uint64_s',  {'-DSPM_UNSIGNED_LONG_LONG', '-DSPM_BYTESWAP'}
    'utils_int64_s',   {'-DSPM_SIGNED_LONG_LONG',   '-DSPM_BYTESWAP'}
    };

objs = {};
for k = 1:size(utilsVariants, 1)
    name = utilsVariants{k, 1};
    defs = utilsVariants{k, 2};
    obj  = [name '.' mx '.o'];
    fprintf('  [archive] %s\n', name);
    mex('-c', opts{:}, defs{:}, 'spm_vol_utils.c');
    movefile(['spm_vol_utils.' objext()], obj, 'f');
    objs{end+1} = obj; %#ok<AGROW>
end

for src = {'spm_make_lookup', 'spm_getdata', 'spm_vol_access', 'spm_mapping'}
    name = src{1};
    obj  = [name '.' mx '.o'];
    fprintf('  [archive] %s\n', name);
    mex('-c', opts{:}, [name '.c']);
    movefile([name '.' objext()], obj, 'f');
    objs{end+1} = obj; %#ok<AGROW>
end

fprintf('  [archive] ar rcs %s\n', arch);
arCmd = sprintf('ar rcs "%s" %s', arch, strjoin(objs, ' '));
[st, out] = system(arCmd);
fprintf('%s', out);
if st ~= 0
    error('spm: ar failed building %s (exit %d)', arch, st);
end

%% ---- 2. main SPM MEX (src/) ----------------------------------------------
% Each entry is the list of mex() arguments after `opts`. Output is named
% after the first source. Volume routines link the archive built above.
mainTargets = {
    {'spm_sample_vol.c', arch}
    {'spm_slice_vol.c',  arch}
    {'spm_brainwarp.c',  arch, 'spm_matfuns.c'}
    {'spm_conv_vol.c',   arch}
    {'spm_render_vol.c', arch}
    {'spm_global.c',     arch}
    {'spm_resels_vol.c', arch}
    {'spm_bsplinc.c', 'bsplines.c', arch}
    {'spm_bsplins.c', 'bsplines.c'}
    {'spm_unlink.c'}
    {'spm_existfile.c'}
    {'spm_gamrnd.c'}
    {'spm_hist.c'}
    {'spm_krutil.c'}
    {'spm_project.c'}
    {'spm_hist2.c', 'hist2.c'}
    {'spm_dilate_erode.c'}
    {'spm_bwlabel.c'}
    {'spm_get_lm.c'}
    {'spm_voronoi.c'}
    {'spm_mesh_dist.cpp'}
    {'spm_mesh_utils.c'}
    {'spm_mrf.c'}
    {'spm_diffeo.c', 'shoot_diffeo3d.c', 'shoot_optim3d.c', ...
        'shoot_multiscale.c', 'shoot_regularisers.c', 'shoot_expm3.c', ...
        'shoot_invdef.c', 'shoot_dartel.c', 'shoot_boundary.c', ...
        'spm_openmp.c', 'shoot_bsplines.c', 'bsplines.c', '-DIMAGE_SINGLE'}
    {'spm_field.c', 'shoot_optimN.c', 'shoot_multiscale.c', ...
        'shoot_boundary.c', 'spm_openmp.c'}
    {'spm_cat.c'}
    {'spm_jsonread.c', fullfile('external', 'jsmn', 'jsmn.c'), '-DJSMN_PARENT_LINKS'}
    {'spm_mesh_reduce.c', fullfile('external', 'nii2mesh', 'quadric.c')}
    {'spm_mesh_geodesic.cpp'}
    {'spm_mesh_ray_triangle.c'}
    {'spm_gmmlib.c', 'gmmlib.c'}
    };

spmmex = cell(1, numel(mainTargets));
for k = 1:numel(mainTargets)
    t = mainTargets{k};
    [~, base] = fileparts(t{1});
    spmmex{k} = base;
    fprintf('  [main] %s\n', base);
    mex(opts{:}, t{:});
end

% main-install: copy the SPM MEX up to the package root (where their .m
% stubs live), then move spm_brainwarp into toolbox/OldNorm (upstream layout).
for k = 1:numel(spmmex)
    copyfile([spmmex{k} '.' mx], fullfile(root, [spmmex{k} '.' mx]), 'f');
end
movefile(fullfile(root, ['spm_brainwarp.' mx]), ...
         fullfile(root, 'toolbox', 'OldNorm', ['spm_brainwarp.' mx]), 'f');

%% ---- 3. subdirectory MEX -------------------------------------------------
% Built in place; their Makefiles have empty install targets.
compileDir(fullfile(root, '@file_array', 'private'), opts, {
    {'file2mat.c'}
    {'mat2file.c'}
    {'init.c'}
    });

% @gifti pins -std=c99 (the upstream Makefile sets it on every platform).
giftiOpts = [opts, {'CFLAGS=$CFLAGS -std=c99'}];
compileDir(fullfile(root, '@gifti', 'private'), giftiOpts, {
    {'zstream.c'}
    {'base64.c'}
    {'xml_parser.c', 'yxml.c'}
    });

compileDir(fullfile(root, '@xmltree', 'private'), opts, {
    {'xml_findstr.c'}
    });

compileDir(fullfile(root, 'toolbox', 'FieldMap'), opts, {
    {'pm_invert_phasemap_dtj.c'}
    {'pm_merge_regions.c'}
    {'pm_create_connectogram_dtj.c'}
    {'pm_pad.c'}
    {'pm_estimate_ramp.c'}
    {'pm_restore_ramp.c'}
    {'pm_ff_unwrap.c'}
    });

%% ---- 4. externals: bemcp + fieldtrip -------------------------------------
compileDir(fullfile(root, 'external', 'bemcp'), opts, {
    {'bem_Cii_cog.c'}
    {'bem_Cii_cst.c'}
    {'bem_Cii_lin.c'}
    {'bem_Cij_cog.c'}
    {'bem_Cij_cst.c'}
    {'bem_Cij_lin.c'}
    {'bem_Gi_cog.c'}
    {'bem_Gi_vert.c'}
    });

ftSrc = fullfile(root, 'external', 'fieldtrip', 'src');
% Most fieldtrip MEX are single-source; the six geometry routines link
% geometry.c (explicit rules in Makefile.fieldtrip). geometry.c is the only
% extra source needed.
ftSingle = {'read_24bit', 'read_16bit', 'ft_getopt', 'nanmean', 'nanstd', ...
            'nansum', 'nanvar', 'meg_leadfield1', 'plgndr', 'splint_gh'};
ftGeometry = {'ptriproj', 'lmoutr', 'solid_angle', 'routlm', 'ltrisect', ...
              'plinproj'};
geomSrc = fullfile(ftSrc, 'geometry.c');
for k = 1:numel(ftSingle)
    fprintf('  [fieldtrip] %s\n', ftSingle{k});
    mex(opts{:}, '-outdir', ftSrc, fullfile(ftSrc, [ftSingle{k} '.c']));
end
for k = 1:numel(ftGeometry)
    fprintf('  [fieldtrip] %s (+geometry)\n', ftGeometry{k});
    mex(opts{:}, '-outdir', ftSrc, fullfile(ftSrc, [ftGeometry{k} '.c']), geomSrc);
end

% external-install: distribute the fieldtrip MEX into the private/ folders
% where fieldtrip looks for them at runtime (verbatim from Makefile.fieldtrip).
ftRoot = fullfile(root, 'external', 'fieldtrip');
ftInstall = {
    'read_24bit',     'fileio/private'
    'read_16bit',     'fileio/private'
    'ft_getopt',      'fileio/private'
    'solid_angle',    'fileio/private'
    'meg_leadfield1', 'forward/private'
    'ptriproj',       'forward/private'
    'lmoutr',         'forward/private'
    'plgndr',         'forward/private'
    'solid_angle',    'forward/private'
    'routlm',         'forward/private'
    'ft_getopt',      'forward/private'
    'solid_angle',    'inverse/private'
    'ft_getopt',      'inverse/private'
    'solid_angle',    'plotting/private'
    'ltrisect',       'plotting/private'
    'ptriproj',       'private'
    'lmoutr',         'private'
    'plgndr',         'private'
    'routlm',         'private'
    'solid_angle',    'private'
    'ft_getopt',      'utilities'
    'ptriproj',       'utilities/private'
    'lmoutr',         'utilities/private'
    'ft_getopt',      'connectivity/private'
    'nanmean',        'external/stats'
    'nansum',         'external/stats'
    'nanstd',         'external/stats'
    'nanvar',         'external/stats'
    };
for k = 1:size(ftInstall, 1)
    binName = [ftInstall{k, 1} '.' mx];
    destDir = fullfile(ftRoot, ftInstall{k, 2});
    if ~isfolder(destDir)
        error('spm: fieldtrip install dir missing: %s', destDir);
    end
    copyfile(fullfile(ftSrc, binName), fullfile(destDir, binName), 'f');
end

cd(root);
fprintf('=== SPM MEX compilation complete (Windows) ===\n');

end


function ext = objext()
% Object-file extension produced by `mex -c` on this platform.
if ispc
    ext = 'obj';
else
    ext = 'o';
end
end


function compileDir(dirPath, opts, targets)
% Build a list of single-/multi-source MEX in their own directory.
if ~isfolder(dirPath)
    error('spm: source directory missing: %s', dirPath);
end
back = cd(dirPath);
restore = onCleanup(@() cd(back));
for k = 1:numel(targets)
    t = targets{k};
    [~, base] = fileparts(t{1});
    fprintf('  [%s] %s\n', dirName(dirPath), base);
    mex(opts{:}, t{:});
end
end


function d = dirName(p)
parts = strsplit(strip_trailing_sep(p), filesep);
if numel(parts) >= 2
    d = strjoin(parts(end-1:end), '/');
else
    d = parts{end};
end
end


function p = strip_trailing_sep(p)
if ~isempty(p) && (p(end) == filesep)
    p(end) = [];
end
end
