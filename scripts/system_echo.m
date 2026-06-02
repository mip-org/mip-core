function [status, cmdout] = system_echo(cmd)
%SYSTEM_ECHO   Echo a shell command, then run it via system().

fprintf('  %s\n', cmd);
[status, cmdout] = system(cmd);
if ~isempty(cmdout)
    lines = splitlines(cmdout);
    fprintf('    %s\n', lines{1:end-1});
end

end
