function initjig
%INITJIG set-up JIGSAW's global constants (numbl_wasm port).
%
%   numbl override of the upstream initjig. The upstream version extends the
%   MATLAB path via addpath(genpath('tools')) / addpath(genpath('parse')), but
%   numbl has no genpath and, more importantly, the mip package already places
%   tools/ and parse/ on the path (recursively) at load time. So this override
%   only loads JIGSAW's global constants.
%
%   See also GLOBALS

    globals ;

end
