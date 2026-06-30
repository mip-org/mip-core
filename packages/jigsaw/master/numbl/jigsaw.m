function [varargout] = jigsaw(opts)
%JIGSAW an interface to the JIGSAW mesh generator (numbl_wasm port).
%
%   MESH = JIGSAW(OPTS);
%
%   numbl override of the upstream JIGSAW interface. numbl cannot launch
%   JIGSAW's native executable (no system(), and a WASM builtin has no file
%   access), so instead of writing a *.JIG config and shelling out, this reads
%   the geometry / mesh-size / initial-condition files named in OPTS with
%   loadmsh, runs the meshing kernel in WASM (jigsaw_kernel), writes the result
%   to OPTS.MESH_FILE with savemsh, and returns the mesh struct. The file-based
%   OPTS contract is unchanged, so scripts run identically on numbl and the
%   native architectures. See the native jigsaw.m for the full OPTS reference.
%
%   See also LOADMSH, SAVEMSH

    if (isempty(opts))
        error('JIGSAW: insufficient inputs!!') ;
    end
    if (~isstruct(opts))
        error('JIGSAW: invalid input types!!') ;
    end

    geom = read_msh_opt(opts, 'geom_file') ;
    init = read_msh_opt(opts, 'init_file') ;
    hfun = read_msh_opt(opts, 'hfun_file') ;

    mesh = jigsaw_kernel('jigsaw', opts, geom, init, hfun) ;

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
