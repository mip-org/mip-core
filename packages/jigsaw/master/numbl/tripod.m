function [varargout] = tripod(opts)
%TRIPOD an interface to JIGSAW's "restricted" Delaunay tessellator (numbl_wasm).
%
%   MESH = TRIPOD(OPTS);
%
%   numbl override of the upstream TRIPOD interface. Reads the initial-point
%   distribution (OPTS.INIT_FILE, required) and optional geometry
%   (OPTS.GEOM_FILE) with loadmsh, runs the rDT tessellator in WASM, writes the
%   result to OPTS.MESH_FILE with savemsh, and returns the mesh struct. See the
%   native tripod.m for the full OPTS reference.
%
%   See also LOADMSH, SAVEMSH

    if (isempty(opts))
        error('TRIPOD: insufficient inputs!!') ;
    end
    if (~isstruct(opts))
        error('TRIPOD: invalid input types!!') ;
    end

    geom = read_msh_opt(opts, 'geom_file') ;
    init = read_msh_opt(opts, 'init_file') ;

    mesh = jigsaw_kernel('tripod', opts, geom, init, []) ;

    if (isfield(opts, 'mesh_file') && ~isempty(opts.mesh_file))
        savemsh(opts.mesh_file, mesh) ;
    end

    if (nargout == +1)
        varargout{1} = mesh ;
    end

end

function [data] = read_msh_opt(opts, name)
%READ-MSH-OPT load a *.MSH input named by OPTS.(NAME), or [] if not present.

    data = [] ;
    if (isfield(opts, name) && ~isempty(opts.(name)))
        data = loadmsh(opts.(name)) ;
    end

end
