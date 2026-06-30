function [varargout] = marche(opts)
%MARCHE an interface to JIGSAW's "gradient-limiting" solver (numbl_wasm).
%
%   HFUN = MARCHE(OPTS);
%
%   numbl override of the upstream MARCHE interface. Reads the mesh-size
%   function OPTS.HFUN_FILE with loadmsh, solves the gradient-limiting Eikonal
%   problem in WASM, writes the limited h(x) back to OPTS.HFUN_FILE *in place*
%   with savemsh (matching the native behaviour), and returns the HFUN struct.
%   See the native marche.m for the full OPTS reference.
%
%   See also LOADMSH, SAVEMSH

    if (isempty(opts))
        error('MARCHE: insufficient inputs!!') ;
    end
    if (~isstruct(opts))
        error('MARCHE: invalid input types!!') ;
    end

    ffun = read_msh_opt(opts, 'hfun_file') ;

    hfun = jigsaw_kernel('marche', opts, [], [], ffun) ;

    if (isfield(opts, 'hfun_file') && ~isempty(opts.hfun_file))
        savemsh(opts.hfun_file, hfun) ;        % data is overwritten in-place
    end

    if (nargout == +1)
        varargout{1} = hfun ;
    end

end

function [data] = read_msh_opt(opts, name)
%READ-MSH-OPT load a *.MSH input named by OPTS.(NAME), or [] if not present.

    data = [] ;
    if (isfield(opts, name) && ~isempty(opts.(name)))
        data = loadmsh(opts.(name)) ;
    end

end
