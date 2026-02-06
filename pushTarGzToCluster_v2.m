function out = pushTarGzToCluster_v2(localTarGzPath, remoteDestDir, varargin)
% pushTarGzToCluster_v2
% Copy a local .tar.gz to a remote Linux cluster, extract it there into an
% enclosing directory named after the tarball (minus .tar.gz/.tgz), then delete the .tar.gz.
%
% This version supports interactive password authentication by letting ssh/rsync prompt
% you in the terminal (system(...,'-echo')).
%
% REQUIRED INPUTS
%   localTarGzPath : string/char, path to local .tar.gz/.tgz
%   remoteDestDir  : string/char, remote destination directory
%
% NAME-VALUE OPTIONS
%   'RemoteHost'      : e.g. 'login.cluster.edu' (REQUIRED)
%   'RemoteUser'      : string; if empty and PromptForCredentials=true, you will be asked
%   'PromptForCredentials' : true/false (default: false)
%   'UseRsync'        : true (default) | false (scp)
%   'SSHPort'         : default 22
%   'SSHKey'          : path to private key (optional)
%   'SSHOptions'      : extra ssh options (default depends on PromptForCredentials)
%   'RsyncOptions'    : default '-avz --partial'
%   'ScpOptions'      : default '-p'
%   'Verbose'         : true/false
%   'DryRun'          : true/false
%
% OUTPUT
%   out struct with executed commands and stdout/status, plus:
%     - out.remoteWrapperDir : remote directory used as enclosing extraction target
%
% NOTE
%   If PromptForCredentials=true, this function will run external commands with
%   system(cmd,'-echo') so you can type your password at the prompt.

% --------------------------
% Parse inputs
% --------------------------
p = inputParser;
p.FunctionName = mfilename;

addRequired(p,'localTarGzPath',@(x)ischar(x)||isstring(x));
addRequired(p,'remoteDestDir', @(x)ischar(x)||isstring(x));

addParameter(p,'RemoteHost','',@(x)ischar(x)||isstring(x));
addParameter(p,'RemoteUser',getenv('USER'),@(x)ischar(x)||isstring(x));
addParameter(p,'PromptForCredentials',false,@(x)islogical(x)&&isscalar(x));

addParameter(p,'UseRsync',true,@(x)islogical(x)&&isscalar(x));
addParameter(p,'SSHPort',22,@(x)isnumeric(x)&&isscalar(x) && x>0);
addParameter(p,'SSHKey','',@(x)ischar(x)||isstring(x));

% If PromptForCredentials=false, we default to BatchMode=yes (non-interactive).
% If true, default to BatchMode=no (allow password prompt).
addParameter(p,'SSHOptions','',@(x)ischar(x)||isstring(x));

addParameter(p,'RsyncOptions','-avz --partial',@(x)ischar(x)||isstring(x));
addParameter(p,'ScpOptions','-p',@(x)ischar(x)||isstring(x));
addParameter(p,'Verbose',true,@(x)islogical(x)&&isscalar(x));
addParameter(p,'DryRun',false,@(x)islogical(x)&&isscalar(x));

parse(p,localTarGzPath,remoteDestDir,varargin{:});
S = p.Results;

if isempty(S.RemoteHost)
    error('RemoteHost must be specified.');
end

% Prompt for username if requested
if S.PromptForCredentials
    if isempty(S.RemoteUser)
        S.RemoteUser = input('Remote username: ','s');
    else
        uIn = input(sprintf('Remote username [%s]: ',char(S.RemoteUser)),'s');
        if ~isempty(uIn)
            S.RemoteUser = uIn;
        end
    end
end

% Set default SSHOptions if not provided
if isempty(char(S.SSHOptions))
    if S.PromptForCredentials
        % Allow interactive password prompt
        S.SSHOptions = '-o BatchMode=no -o PreferredAuthentications=password,keyboard-interactive,publickey';
    else
        % Non-interactive (keys/GSSAPI only)
        S.SSHOptions = '-o BatchMode=yes';
    end
end

localTarGzPath = absolutePath_(char(localTarGzPath));
remoteDestDir  = char(remoteDestDir);

if ~isfile(localTarGzPath)
    error('Local file not found: %s',localTarGzPath);
end

% Remote filename = local basename
[~,baseName,ext] = fileparts(localTarGzPath);
remoteFileName  = [baseName ext];

% remote tar path in destination directory
remoteTarPath   = [ensureTrailingSlash_(remoteDestDir) remoteFileName];

% NEW: wrapper directory name = tar filename minus .tar.gz or .tgz
wrapperName = stripTarExtension_(remoteFileName);
remoteWrapperDir = [ensureTrailingSlash_(remoteDestDir) wrapperName];

remoteTarget = sprintf('%s@%s:%s',char(S.RemoteUser),char(S.RemoteHost),remoteDestDir);

% --------------------------
% SSH base
% --------------------------
sshKeyPart = '';
if ~isempty(char(S.SSHKey))
    sshKeyPart = sprintf('-i %s',shellQuote_(char(S.SSHKey)));
end

sshBase = strtrim(sprintf( ...
    'ssh -p %d %s %s %s@%s', ...
    S.SSHPort, char(S.SSHOptions), sshKeyPart, char(S.RemoteUser), char(S.RemoteHost)));

% --------------------------
% Remote mkdir (dest + wrapper)
% --------------------------
mkdirCmd = sprintf('%s %s', sshBase, ...
    shellQuote_(sprintf('mkdir -p %s %s', remoteDestDir, remoteWrapperDir)));

% --------------------------
% Transfer command
% --------------------------
if S.UseRsync
    rsyncSSH = sprintf('ssh -p %d %s %s', ...
        S.SSHPort, char(S.SSHOptions), sshKeyPart);
    transferCmd = sprintf('rsync %s -e %s %s %s/', ...
        char(S.RsyncOptions), ...
        shellQuote_(rsyncSSH), ...
        shellQuote_(localTarGzPath), ...
        shellQuote_(remoteTarget));
else
    transferCmd = sprintf('scp -P %d %s %s %s %s/', ...
        S.SSHPort, char(S.ScpOptions), sshKeyPart, ...
        shellQuote_(localTarGzPath), ...
        shellQuote_(remoteTarget));
end

% --------------------------
% Remote extract (into wrapper dir) + cleanup tarball
% --------------------------
remoteScript = sprintf([ ...
    'set -euo pipefail; ' ...
    'mkdir -p %s; ' ...
    'tar -xzf %s -C %s; ' ...
    'rm -f %s'], ...
    remoteWrapperDir, ...
    remoteTarPath, ...
    remoteWrapperDir, ...
    remoteTarPath);

remoteCmd = sprintf('%s %s', sshBase, shellQuote_(remoteScript));

% --------------------------
% Output struct
% --------------------------
out = struct();
out.mkdirCmd          = mkdirCmd;
out.transferCmd       = transferCmd;
out.remoteCmd         = remoteCmd;
out.remoteTarPath     = remoteTarPath;
out.remoteWrapperDir  = remoteWrapperDir;

if S.Verbose
    fprintf('\n[pushTarGzToCluster_v2]\n');
    fprintf('Local : %s\n', localTarGzPath);
    fprintf('Remote: %s\n', remoteTarget);
    fprintf('Tar   : %s\n', remoteTarPath);
    fprintf('Wrap  : %s\n\n', remoteWrapperDir);

    if S.PromptForCredentials
        fprintf('NOTE: Interactive mode enabled. You may be prompted for your password.\n\n');
    end
end

if S.DryRun
    out.mkdirStatus    = NaN; out.mkdirStdout    = '[DryRun]';
    out.transferStatus = NaN; out.transferStdout = '[DryRun]';
    out.remoteStatus   = NaN; out.remoteStdout   = '[DryRun]';
    return
end

% Choose execution mode
useEcho = S.PromptForCredentials;

% --------------------------
% Execute
% --------------------------
[st,so] = runSystem_(mkdirCmd, useEcho);
out.mkdirStatus = st;
out.mkdirStdout = so;
if st ~= 0
    error('Remote mkdir failed:\n%s', so);
end

[st,so] = runSystem_(transferCmd, useEcho);
out.transferStatus = st;
out.transferStdout = so;
if st ~= 0
    error('Transfer failed:\n%s', so);
end

[st,so] = runSystem_(remoteCmd, useEcho);
out.remoteStatus = st;
out.remoteStdout = so;
if st ~= 0
    error('Remote extract/delete failed:\n%s', so);
end

end

% ==========================================================
% Helper functions
% ==========================================================
function [status, outStr] = runSystem_(cmd, useEcho)
% runSystem_ - run system command; if useEcho, allow interactive prompts
    if useEcho
        status = system(cmd, '-echo');
        outStr = ''; % MATLAB doesn't reliably capture stdout in '-echo' mode
    else
        [status, outStr] = system(cmd);
    end
end

function pthAbs = absolutePath_(pth)
pth = char(pth);
if startsWith(pth, filesep)
    pthAbs = pth;
else
    pthAbs = fullfile(pwd, pth);
end
try
    pthAbs = char(java.io.File(pthAbs).getCanonicalPath());
end
end

function s = ensureTrailingSlash_(s)
s = char(s);
if isempty(s) || s(end) ~= '/'
    s = [s '/'];
end
end

function q = shellQuote_(str)
% Safely single-quote a string for POSIX shells (MATLAB-safe)
str = char(str);
sq = '''\''''';          % yields: '\''
strEsc = strrep(str, '''', sq);
q = ['''' strEsc ''''];
end

function nm = stripTarExtension_(fname)
% stripTarExtension_ - remove .tar.gz or .tgz (case-insensitive) from filename if present
fname = char(fname);
fLower = lower(fname);

if endsWith(fLower, '.tar.gz')
    nm = fname(1:end-7);   % length('.tar.gz') == 7
elseif endsWith(fLower, '.tgz')
    nm = fname(1:end-4);   % length('.tgz') == 4
else
    % Fallback: strip last extension only
    [nm,~] = fileparts(fname);
end

% Safety: if somehow empty, use a default name
if isempty(nm)
    nm = 'extracted';
end
end
