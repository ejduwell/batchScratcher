function [status, cmdOut, localExtractDir, localTarPath] = pullRemoteDirTarSlurm_v1( ...
    remoteHost, remoteDirPth, localDirPth, slurmAccount, timeLimit, rmRemoteDir, pigzThreads, varargin)
% pullRemoteDirTarSlurm_v1
%
% MATLAB wrapper around the bash function (defined in pull_remote_dir_tar_slurm.sh):
%   pull_remote_dir_tar_slurm <user@host> <remoteDirPth> <localDirPth> <slurm_account> <time_limit_DD-HH:MM:SS> <rmRemoteDir_true|false> [pigz_threads]
%
% Inputs:
%   remoteHost   : 'user@host' (e.g., 'eduwell@login-hpc.rcc.mcw.edu')
%   remoteDirPth : remote directory path to archive
%   localDirPth  : local directory to download into
%   slurmAccount : required Slurm account string
%   timeLimit    : 'DD-HH:MM:SS' (e.g., '01-06:00:00')
%   rmRemoteDir  : logical true/false (or 'true'/'false' as char/string)
%   pigzThreads  : integer (optional; pass [] to use bash default)
%
% Name-value options (varargin):
%   'BashSourceFile' : path to the bash file defining pull_remote_dir_tar_slurm
%                      default: '~/bin/pull_remote_dir_tar_slurm.sh'
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
%       'eduwell@login-hpc.rcc.mcw.edu', ...
%       '/scratch/g/agreenberg/eduwell/projects/matlabBatchScratch/myDir', ...
%       '/home/eduwell/SynologyDrive/projects/batchScratcher/mirror2cluster', ...
%       'agreenberg', '00-02:00:00', true, 16, ...
%       'BashSourceFile','/home/eduwell/SynologyDrive/projects/batchScratcher/pull_remote_dir_tar_slurm.sh', ...
%       'CleanRemoteTar',true, 'CleanRemoteJob',true, 'CleanLocalTar',true);

  % -----------------------
  % Defaults + basic checks
  % -----------------------
  if nargin < 6
    error('Need at least remoteHost, remoteDirPth, localDirPth, slurmAccount, timeLimit, rmRemoteDir.');
  end
  if nargin < 7
    pigzThreads = [];
  end

  p = inputParser;
  p.addParameter('BashSourceFile', '~/bin/pull_remote_dir_tar_slurm.sh', @(s)ischar(s)||isstring(s));
  p.addParameter('CleanRemoteTar', false, @(x)islogical(x)&&isscalar(x));
  p.addParameter('CleanRemoteJob', false, @(x)islogical(x)&&isscalar(x));
  p.addParameter('CleanLocalTar',  false, @(x)islogical(x)&&isscalar(x));
  p.addParameter('Verbose', true,  @(x)islogical(x)&&isscalar(x));
  p.parse(varargin{:});
  opt = p.Results;

  bashSourceFile = expandTildeLocal_(char(opt.BashSourceFile));
  if ~exist(bashSourceFile, 'file')
    error('BashSourceFile not found: %s', bashSourceFile);
  end

  if ~exist(localDirPth, 'dir')
    error('localDirPth not found (or not a directory): %s', localDirPth);
  end

  % Validate time format DD-HH:MM:SS
  if isempty(regexp(timeLimit, '^[0-9]+-[0-9]{2}:[0-9]{2}:[0-9]{2}$', 'once'))
    error('timeLimit must match DD-HH:MM:SS (got: %s)', timeLimit);
  end

  % Normalize rmRemoteDir to 'true'/'false' strings for bash
  rmRemoteDirStr = normalizeBoolStr_(rmRemoteDir);

  % pigzThreads validation
  if ~isempty(pigzThreads)
    if ~(isscalar(pigzThreads) && isnumeric(pigzThreads) && pigzThreads >= 1 && mod(pigzThreads,1)==0)
      error('pigzThreads must be a positive integer (or [] to use bash default).');
    end
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
  q = @(s) bashSingleQuote_(char(s));  % returns a single-quoted bash-safe literal

  remoteHost   = char(remoteHost);
  remoteDirPth = char(remoteDirPth);
  localDirPth  = char(localDirPth);
  slurmAccount = char(slurmAccount);
  timeLimit    = char(timeLimit);

  % Build the function call string
  if isempty(pigzThreads)
    callStr = sprintf('%spull_remote_dir_tar_slurm %s %s %s %s %s %s', ...
      envPrefix, q(remoteHost), q(remoteDirPth), q(localDirPth), q(slurmAccount), q(timeLimit), q(rmRemoteDirStr));
  else
    callStr = sprintf('%spull_remote_dir_tar_slurm %s %s %s %s %s %s %d', ...
      envPrefix, q(remoteHost), q(remoteDirPth), q(localDirPth), q(slurmAccount), q(timeLimit), q(rmRemoteDirStr), pigzThreads);
  end

  % Source bash file
  sourceStr = sprintf('source %s', q(bashSourceFile));

  % Full bash payload + system command
  payload = sprintf('%s; %s', sourceStr, callStr);
  cmd = sprintf('bash -lc %s', q(payload));

  if opt.Verbose
    fprintf('Running command:\n%s\n\n', cmd);
  end

  % -----------------------
  % Run it
  % -----------------------
  [status, cmdOut] = system(cmd);

  % Print output for visibility
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

  m = regexp(cmdOut, 'Extracted content is under:\s*(.+)\s*', 'tokens', 'once');
  if ~isempty(m)
    localExtractDir = strtrim(m{1});
  end

  m2 = regexp(cmdOut, 'Local tarball\s*:\s*(.+)\s*', 'tokens', 'once');
  if ~isempty(m2)
    localTarPath = strtrim(m2{1});
  end
end

% -----------------------
% Helpers
% -----------------------
function out = bashSingleQuote_(s)
% Wrap s in single quotes for bash, escaping any internal single quotes safely:
% close quote, insert '\'' , reopen quote
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

function s = normalizeBoolStr_(x)
% Convert logical / numeric / string forms into 'true' or 'false' for bash.
  if islogical(x) && isscalar(x)
    s = ternary_(x, 'true', 'false');
    return;
  end
  if isnumeric(x) && isscalar(x)
    s = ternary_(x ~= 0, 'true', 'false');
    return;
  end
  if isstring(x) || ischar(x)
    t = lower(strtrim(char(x)));
    switch t
      case {'true','t','1','yes','y','on'}
        s = 'true';
      case {'false','f','0','no','n','off'}
        s = 'false';
      otherwise
        error('rmRemoteDir must be logical/0/1 or a string like true/false (got: %s)', char(x));
    end
    return;
  end
  error('rmRemoteDir must be logical/0/1 or a string like true/false.');
end

function out = ternary_(cond, a, b)
  if cond, out = a; else, out = b; end
end
