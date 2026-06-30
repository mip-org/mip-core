function [mesh] = loadmsh(name)
%LOADMSH load a *.MSH file for JIGSAW (numbl_wasm port).
%
%   MESH = LOADMSH(NAME);
%
%   numbl override of the upstream loadmsh. The upstream reader uses fscanf and
%   regexp(...,'split'), neither of which numbl supports, so this reimplements
%   the same *.MSH parser with fgetl + sscanf + strsplit. The MESH struct it
%   returns is identical (same fields, same 1-based element indices), so the
%   rest of the JIGSAW interface and user code are unaffected.
%
%   See also JIGSAW, SAVEMSH

    mesh = [] ;

    ffid = fopen(name, 'r') ;
    if (ffid < +0)
        error(['File not found: ', name]) ;
    end

    kind = 'EUCLIDEAN-MESH' ;
    nver = +0 ;
    ndim = +0 ;

    while (true)

        lstr = fgetl(ffid) ;

        if (~ischar(lstr))
            break ;                                 % end-of-file
        end
        if (isempty(lstr) || lstr(1) == '#')
            continue ;
        end

        tstr = strsplit(lstr, '=') ;
        if (numel(tstr) ~= +2)
            continue ;
        end

        tag = lower(strtrim(tstr{1})) ;
        val = strtrim(tstr{2}) ;

        switch (tag)
        case 'mshid'
            stag = strsplit(val, ';') ;
            nver = str2double(stag{1}) ;
            if (numel(stag) >= +2)
                kind = upper(strtrim(stag{2})) ;
            end

        case 'ndims'
            ndim = str2double(val) ;

        case 'radii'
            stag = strsplit(val, ';') ;
            if (numel(stag) == +3)
                mesh.radii = [str2double(stag{1}), ...
                              str2double(stag{2}), ...
                              str2double(stag{3})] ;
            end

        case 'point'
            nnum = str2double(val) ;
            data = read_rows(ffid, nnum, ndim + 1) ;
            mesh.point.coord = data ;

        case 'seeds'
            nnum = str2double(val) ;
            data = read_rows(ffid, nnum, ndim + 1) ;
            mesh.seeds.coord = data ;

        case 'coord'
            stag = strsplit(val, ';') ;
            idim = str2double(stag{1}) ;
            cnum = str2double(stag{2}) ;
            ndim = max(ndim, idim) ;
            data = read_rows(ffid, cnum, 1) ;
            mesh.point.coord{idim} = data ;

        case 'edge2'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 3) ;
            index(:, 1:2) = index(:, 1:2) + 1 ;     % 1-based indexing
            mesh.edge2.index = index ;

        case 'tria3'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 4) ;
            index(:, 1:3) = index(:, 1:3) + 1 ;
            mesh.tria3.index = index ;

        case 'quad4'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 5) ;
            index(:, 1:4) = index(:, 1:4) + 1 ;
            mesh.quad4.index = index ;

        case 'tria4'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 5) ;
            index(:, 1:4) = index(:, 1:4) + 1 ;
            mesh.tria4.index = index ;

        case 'hexa8'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 9) ;
            index(:, 1:8) = index(:, 1:8) + 1 ;
            mesh.hexa8.index = index ;

        case 'wedg6'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 7) ;
            index(:, 1:6) = index(:, 1:6) + 1 ;
            mesh.wedg6.index = index ;

        case 'pyra5'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 6) ;
            index(:, 1:5) = index(:, 1:5) + 1 ;
            mesh.pyra5.index = index ;

        case 'bound'
            nnum = str2double(val) ;
            index = read_rows(ffid, nnum, 3) ;
            index(:, 2:2) = index(:, 2:2) + 1 ;
            mesh.bound.index = index ;

        case 'value'
            stag = strsplit(val, ';') ;
            nnum = str2double(stag{1}) ;
            vnum = str2double(stag{2}) ;
            mesh.value = read_rows(ffid, nnum, vnum) ;

        case 'power'
            stag = strsplit(val, ';') ;
            nnum = str2double(stag{1}) ;
            pnum = str2double(stag{2}) ;
            mesh.point.power = read_rows(ffid, nnum, pnum) ;

        case 'slope'
            stag = strsplit(val, ';') ;
            nnum = str2double(stag{1}) ;
            vnum = str2double(stag{2}) ;
            mesh.slope = read_rows(ffid, nnum, vnum) ;

        end

    end

    fclose(ffid) ;

    mesh.mshID = kind ;
    mesh.fileV = nver ;

    % Grid forms store VALUE/SLOPE flat; reshape to the grid dimensions, just
    % as the upstream reader does (column-major over [ny, nx(, nz)]).
    if (ndim > +0)
        switch (lower(mesh.mshID))
        case {'euclidean-grid', 'ellipsoid-grid'}
            if (isfield(mesh, 'value') && isfield(mesh, 'point') && ...
                    isfield(mesh.point, 'coord') && iscell(mesh.point.coord))
                mesh.value = reshape_grid(mesh.value, mesh.point.coord, ndim) ;
            end
            if (isfield(mesh, 'slope') && isfield(mesh, 'point') && ...
                    isfield(mesh.point, 'coord') && iscell(mesh.point.coord))
                mesh.slope = reshape_grid(mesh.slope, mesh.point.coord, ndim) ;
            end
        end
    end

end

function [M] = read_rows(ffid, nrows, ncols)
%READ-ROWS read NROWS lines of NCOLS ';'-separated numbers via sscanf.

    M = zeros(nrows, ncols) ;
    fmt = repmat('%f;', 1, ncols) ;
    fmt = fmt(1:end-1) ;                            % drop trailing ';'
    for r = +1 : nrows
        line = fgetl(ffid) ;
        if (~ischar(line))
            break ;
        end
        v = sscanf(line, fmt) ;
        n = min(numel(v), ncols) ;
        M(r, 1:n) = v(1:n).' ;
    end

end

function [A] = reshape_grid(A, coord, ndim)
%RESHAPE-GRID reshape a flat grid array into its [ny, nx(, nz)] dimensions.

    if (ndim == +2)
        A = reshape(A, numel(coord{2}), numel(coord{1}), []) ;
    elseif (ndim == +3)
        A = reshape(A, numel(coord{2}), numel(coord{1}), ...
                       numel(coord{3}), []) ;
    end

end
