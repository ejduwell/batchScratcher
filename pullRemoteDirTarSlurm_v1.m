function [status, cmdOut, localExtractDir, localTarPath] = pullRemoteDirTarSlurm_v1( ...
    remoteHost, remoteDirPth, localDirPth, slurmAccount, timeLimit, pigzThreads, varargin)
% pullRemoteDirTarSlurm_v1
%
% MATLAB wrapper around the bash function:
%   pull_remote_dir_tar_slurm <user@host> <remoteDirPth> <localDirPth> <slurm_account> <time_limit_DD-HH:MM:SS> [pigz_threads]
%
% It:
%   1) sources a bash file that defines pull_remote_dir_tar_slurm
%   2) calls it with your args
%   3) returns command output, and tries to parse the "Extracted content is under:" path.
%
% Inputs:
%   remoteHost   : 'user@host' (e.g., 'eduwell@login-hpc.rcc.mcw.edu')
%   remoteDirPth : remote directory path to archive
%   localDirPth  : local directory to download into
%   slurmAccount : required Slurm account string
%   timeLimit    : 'DD-HH:MM:SS' (e.g., '01-06:00:00')
%   pigzThreads  : integer (optional; pass [] to use default)
%
% Name-value options (varargin):
%   'BashSourceFile' : path to the bash file defining pull_remote_dir_tar_slurm
%                      default: '~/bin/cluster_pull_tools.sh'
%   'CleanRemoteTar' : true/false (sets CLEAN_REMOTE_TAR=1)
%   'CleanRemoteJob' : true/false (sets CLEAN_REMOTE_JOBDIR=1)
%   'CleanLocalTar'  : true/false (sets CLEAN_LOCAL_TAR=1)
%   'Verbose'        : true/false (prints the full command)
%
% Outputs:
%   status         : system() status code (0 means success)
%   cmdOut         : captured stdout/stderr from the bash execution
%   localExtractDir: parsed extracted directory path ('' if not found)
%   localTarPath   : parsed local tarball path ('' if not found)
%
% Example:
%   [st,out,exdir,tar] = pullRemoteDirTarSlurm_v1( ...
%       'eduwell@login-hpc.rcc.mcw.edu', '/home/eduwell/bigData', ...
%       '/home/eduwell/Downloads', 'myAccount', '01-06:00:00', 16, ...
%       'CleanRemoteTar', true, 'CleanRemoteJob', true, 'CleanLocalTar', true);

  % -----------------------
  % Defaults + input checks
  % -----------------------
  if nargin < 5
    error('Need at least remoteHost, remoteDirPth, localDirPth, slurmAccount, timeLimit.');
  end
  if nargin < 6 || isempty(pigzThreads)
    pigzThreads = []; % let bash function default
  end

  p = inputParser;
  p.addParameter('BashSourceFile', '~/bin/cluster_pull_tools.sh', @(s)ischar(s)||isstring(s));
  p.addParameter('CleanRemoteTar', false, @(x)islogical(x)&&isscalar(x));
  p.addParameter('CleanRemoteJob', false, @(x)islogical(x)&&isscalar(x));
  p.addParameter('CleanLocalTar',  false, @(x)islogical(x)&&isscalar(x));
  p.addParameter('Verbose', true,  @(x)islogical(x)&&isscalar(x));
  p.parse(varargin{:});
  opt = p.Results;

  bashSourceFile = char(opt.BashSourceFile);

  % Expand ~ in the bash source file path
  bashSourceFile = expandTildeLocal_(bashSourceFile);

  if ~exist(bashSourceFile, 'file')
    error('BashSourceFile not found: %s', bashSourceFile);
  end

  % -----------------------
  % Build env vars for cleanup
  % -----------------------
  envParts = {};
  if opt.CleanRemoteTar, envParts{end+1} = 'CLEAN_REMOTE_TAR=1'; end %#ok<AGROW>
  if opt.CleanRemoteJob, envParts{end+1} = 'CLEAN_REMOTE_JOBDIR=1'; end %#ok<AGROW>
  if opt.CleanLocalTar,  envParts{end+1} = 'CLEAN_LOCAL_TAR=1'; end %#ok<AGROW>

  envPrefix = strjoin(envParts, ' ');
  if ~isempty(envPrefix)
    envPrefix = [envPrefix ' ']; %#ok<AGROW>
  end

  % -----------------------
  % Quote arguments for bash safely
  % -----------------------
  % We call:
  %   bash -lc 'source "file"; ENVVARS pull_remote_dir_tar_slurm "arg1" "arg2" ...'
  %
  q = @(s) bashSingleQuote_(char(s));  % returns a single-quoted bash-safe literal

  remoteHost   = char(remoteHost);
  remoteDirPth = char(remoteDirPth);
  localDirPth  = char(localDirPth);
  slurmAccount = char(slurmAccount);
  timeLimit    = char(timeLimit);

  if isempty(pigzThreads)
    callStr = sprintf('%spull_remote_dir_tar_slurm %s %s %s %s %s', ...
      envPrefix, q(remoteHost), q(remoteDirPth), q(localDirPth), q(slurmAccount), q(timeLimit));
  else
    if ~(isscalar(pigzThreads) && isnumeric(pigzThreads) && pigzThreads >= 1 && mod(pigzThreads,1)==0)
      error('pigzThreads must be a positive integer (or [] to use default).');
    end
    callStr = sprintf('%spull_remote_dir_tar_slurm %s %s %s %s %s %d', ...
      envPrefix, q(remoteHost), q(remoteDirPth), q(localDirPth), q(slurmAccount), q(timeLimit), pigzThreads);
  end

  % Source file path inside bash:
  sourceStr = sprintf('source %s', q(bashSourceFile));

  % Full bash -lc payload:
  payload = sprintf('%s; %s', sourceStr, callStr);

  % Full system command from MATLAB:
  cmd = sprintf('bash -lc %s', q(payload));

  if opt.Verbose
    fprintf('Running command:\n%s\n\n', cmd);
  end

  % -----------------------
  % Run it
  % -----------------------
  [status, cmdOut] = system(cmd);

  % Echo output in MATLAB (system already returns cmdOut, but this helps visibility)
  fprintf('%s\n', cmdOut);

  if status ~= 0
    error('pullRemoteDirTarSlurm_v1:CommandFailed', ...
      'Bash call failed (status=%d). See output above.', status);
  end

  % -----------------------
  % Parse useful paths from output
  % -----------------------
  localExtractDir = '';
  localTarPath    = '';

  % From bash function:
  %   Extracted content is under: <path>
  m = regexp(cmdOut, 'Extracted content is under:\s*(.+)\s*', 'tokens', 'once');
  if ~isempty(m)
    localExtractDir = strtrim(m{1});
  end

  % From bash function:
  %   Local tarball    : <path>
  m2 = regexp(cmdOut, 'Local tarball\s*:\s*(.+)\s*', 'tokens', 'once');
  if ~isempty(m2)
    localTarPath = strtrim(m2{1});
  end
end

% -----------------------
% Helpers
% -----------------------
function out = bashSingleQuote_(s)
% Wrap s in single quotes for bash, escaping any internal single quotes safely.
% Bash-safe rule: close quote, insert '\'' , reopen quote.
  s = strrep(s, '''', '''\''''');
  out = ['''' s ''''];
end

function pth = expandTildeLocal_(pth)
% Expand leading ~ to home directory on local machine.
  pth = char(pth);
  if startsWith(pth, ['~' filesep]) || strcmp(pth, '~')
    homeDir = char(java.lang.System.getProperty('user.home'));
    if strcmp(pth, '~')
      pth = homeDir;
    else
      pth = fullfile(homeDir, pth(3:end));
    end
  end
end
