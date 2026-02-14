function cmdOut = runHeadlessMatlabJob_wrapper(runScriptPth, matlabFile, projectDirPthz, varargin)
% runHeadlessMatlabJob_wrapper
%
% Launch runHeadlessMatlabJob.sh in a NEW terminal window (non-blocking),
% keeping the MATLAB GUI/command window responsive.
%
% Key features:
%   - Spawns an external terminal window (gnome-terminal / x-terminal-emulator / xterm)
%   - Runs: runHeadlessMatlabJob.sh <matlabFile> <projectDir1> [projectDir2 ...]
%   - Adds dirs to MATLAB path inside the spawned MATLAB session (handled by the bash script)
%   - Optionally keeps terminal open after completion
%   - Works around MATLAB's LD_LIBRARY_PATH injection that can break system GUI apps
%     (e.g., gnome-terminal requiring newer GLIBCXX than MATLAB's bundled libstdc++).
%
% USAGE:
%   cmdOut = runHeadlessMatlabJob_wrapper(runScriptPth, matlabFile, projectDirPthz)
%
% INPUTS:
%   runScriptPth   : full path to runHeadlessMatlabJob.sh
%   matlabFile     : MATLAB function/script name to run (NO .m extension)
%   projectDirPthz : one or more project directories to add to path in the spawned session.
%                    Accepts:
%                      - char/string (single path), OR
%                      - cell array of char, OR
%                      - string array
%
% NAME-VALUE OPTIONS:
%   'Title'        : Terminal window title (default: 'MATLAB headless job')
%   'HoldOpen'     : Keep terminal open after completion (default: true)
%   'PrintCommand' : Print the constructed launch command + log path (default: true)
%
% OUTPUT:
%   cmdOut         : The full shell command used to launch the terminal.
%
% NOTES:
%   - This wrapper is intended for Linux desktop environments (Ubuntu/GNOME etc.).
%   - If the underlying MATLAB run prompts for input (e.g., y/n), it will appear
%     in the spawned terminal window.

% -----------------------
% Parse inputs/options
% -----------------------
p = inputParser;
p.addRequired('runScriptPth', @(x) (ischar(x) || isstring(x)) && strlength(string(x))>0);
p.addRequired('matlabFile',   @(x) (ischar(x) || isstring(x)) && strlength(string(x))>0);
p.addRequired('projectDirPthz');
p.addParameter('Title', 'MATLAB headless job', @(x) ischar(x) || isstring(x));
p.addParameter('HoldOpen', true, @(x) islogical(x) && isscalar(x));
p.addParameter('PrintCommand', true, @(x) islogical(x) && isscalar(x));
p.parse(runScriptPth, matlabFile, projectDirPthz, varargin{:});

runScriptPth = char(string(p.Results.runScriptPth));
matlabFile   = char(string(p.Results.matlabFile));
titleStr     = char(string(p.Results.Title));
holdOpen     = p.Results.HoldOpen;
printCmd     = p.Results.PrintCommand;

% -----------------------
% Normalize projectDirPthz to cellstr
% -----------------------
if ischar(projectDirPthz) || isstring(projectDirPthz)
    projectDirPthz = cellstr(projectDirPthz);
elseif iscell(projectDirPthz)
    % assume cell array of char/strings
    projectDirPthz = cellfun(@(x) char(string(x)), projectDirPthz, 'UniformOutput', false);
else
    error('projectDirPthz must be a char/string path, a string array, or a cell array of paths.');
end

% -----------------------
% Basic validation
% -----------------------
if ~isfile(runScriptPth)
    error('runHeadlessMatlabJob.sh not found: %s', runScriptPth);
end

% Validate matlabFile is a MATLAB identifier
if isempty(regexp(matlabFile, '^[A-Za-z_][A-Za-z0-9_]*$', 'once'))
    error('matlabFile must be a MATLAB function/script name (no path, no .m). Got: %s', matlabFile);
end

for i = 1:numel(projectDirPthz)
    if ~isfolder(projectDirPthz{i})
        error('Project directory not found: %s', projectDirPthz{i});
    end
end

% -----------------------
% Build the command line:
%   <runScriptPth> <matlabFile> <projectDir1> <projectDir2> ...
% with safe shell quoting.
% -----------------------
args = [{runScriptPth}, {matlabFile}, projectDirPthz(:)'];
argsQuoted = cellfun(@shellQuote, args, 'UniformOutput', false);
baseCmd = strjoin(argsQuoted, ' ');

% Use bash -lc so PATH/env behave like a login shell
bashCmd = sprintf('bash -lc %s', shellQuote(baseCmd));

% Keep terminal open if requested
if holdOpen
    bashCmd = sprintf('%s; echo; echo "=== Done. Press ENTER to close. ==="; read -r', bashCmd);
end

% -----------------------
% Pick a terminal emulator
% -----------------------
term = pickTerminal();
if isempty(term)
    error(['No supported terminal emulator found (tried gnome-terminal, x-terminal-emulator, xterm). ' ...
           'Install one or adjust the wrapper.']);
end

% Some environments need a DBus session to launch gnome-terminal.
needDbus = isempty(getenv('DBUS_SESSION_BUS_ADDRESS'));
hasDbusLaunch = (system('bash -lc "command -v dbus-launch >/dev/null 2>&1"') == 0);

prefix = "";
if needDbus && hasDbusLaunch
    prefix = "dbus-launch ";
end

% Detach with setsid if available (prevents child from being tied to MATLAB)
hasSetsid = (system('bash -lc "command -v setsid >/dev/null 2>&1"') == 0);
detach = "";
if hasSetsid
    detach = "setsid -f ";
end

% -----------------------
% Construct terminal launch command
% -----------------------
switch term
    case 'gnome-terminal'
        termCmd = sprintf('gnome-terminal --title=%s -- bash -lc %s', ...
            shellQuote(titleStr), shellQuote(bashCmd));
    case 'x-terminal-emulator'
        termCmd = sprintf('x-terminal-emulator -T %s -e bash -lc %s', ...
            shellQuote(titleStr), shellQuote(bashCmd));
    case 'xterm'
        termCmd = sprintf('xterm -T %s -e bash -lc %s', ...
            shellQuote(titleStr), shellQuote(bashCmd));
    otherwise
        error('Unsupported terminal emulator: %s', term);
end

% CRITICAL FIX:
% MATLAB injects LD_LIBRARY_PATH etc., which can break system GUI apps (gnome-terminal)
% by forcing them to load MATLAB's bundled libstdc++. Unset those for the terminal launch.
termCmd = wrapCleanEnv(termCmd);

% Log for debugging terminal launch failures
logPth = fullfile(tempdir, sprintf('runHeadlessMatlabJob_wrapper_%s.log', datestr(now,'yyyymmdd_HHMMSS_FFF')));

% Full launcher line (run in a shell)
launchLine = sprintf('%s%s%s 2>>%s &', prefix, detach, termCmd, shellQuote(logPth));
fullCmd = sprintf('bash -lc %s', shellQuote(launchLine));

if printCmd
    fprintf('Launching terminal via:\n%s\n\n', fullCmd);
    fprintf('If nothing appears, check log:\n%s\n\n', logPth);
end

[status, out] = system(fullCmd);
if status ~= 0
    error('Failed to launch terminal.\nCommand:\n%s\n\nOutput:\n%s', fullCmd, out);
end

cmdOut = fullCmd;

end % main function


% =====================================================================
% Helper functions
% =====================================================================

function term = pickTerminal()
% pickTerminal: choose a terminal emulator likely to exist on Ubuntu.
if system('bash -lc "command -v gnome-terminal >/dev/null 2>&1"') == 0
    term = 'gnome-terminal';
elseif system('bash -lc "command -v x-terminal-emulator >/dev/null 2>&1"') == 0
    term = 'x-terminal-emulator';
elseif system('bash -lc "command -v xterm >/dev/null 2>&1"') == 0
    term = 'xterm';
else
    term = '';
end
end

function cmd = wrapCleanEnv(cmd)
% wrapCleanEnv: remove MATLAB-injected library environment variables that can
% break launching system GUI apps (e.g., gnome-terminal / libvte / GLIBCXX errors).
varsToUnset = { ...
    'LD_LIBRARY_PATH', ...
    'LD_PRELOAD', ...
    'LD_RUN_PATH', ...
    'DYLD_LIBRARY_PATH', ...
    'DYLD_INSERT_LIBRARIES' ...
    };

unsetParts = strings(1,0);
for i = 1:numel(varsToUnset)
    unsetParts(end+1) = "-u " + varsToUnset{i};
end

cmd = "env " + strjoin(unsetParts, " ") + " " + string(cmd);
cmd = char(cmd);
end

function q = shellQuote(s)
% shellQuote: safe POSIX shell quoting using single quotes.
% Replaces embedded single quotes with the sequence: '"'"'
s = char(string(s));
repl = ['''' '"' '''' '"' ''''];  % this literal is: '"'"'
s = strrep(s, '''', repl);
q = ['''' s ''''];
end
