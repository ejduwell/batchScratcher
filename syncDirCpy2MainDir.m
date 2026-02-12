function [status, cmd, stdout, stderr] = syncDirCpy2MainDir(dirCopy, dirMain, varargin)
% syncDirCpy2MainDir.m
%
% MATLAB wrapper for syncDirCpy2MainDir.sh (directional rsync dirCopy -> dirMain).
%
% Usage:
%   [status, cmd, stdout, stderr] = syncDirCpy2MainDir(dirCopy, dirMain)
%   ... = syncDirCpy2MainDir(dirCopy, dirMain, '--dryRun')
%   ... = syncDirCpy2MainDir(dirCopy, dirMain, '--rmDirCopy')
%   ... = syncDirCpy2MainDir(dirCopy, dirMain, '--dryRun', '--rmDirCopy')
%
% Notes:
%   - This wrapper calls the shell script via system().
%   - By default it expects syncDirCpy2MainDir.sh to be:
%       1) on your PATH, OR
%       2) in the same directory as this .m file.
%   - Works in MATLAB and should be Octave-friendly.
%
% Outputs:
%   status : system() return code (0 is success)
%   cmd    : the executed command string
%   stdout : combined standard output
%   stderr : best-effort stderr capture (see below)
%
% Stderr capture:
%   MATLAB's system() returns combined output in many setups. To reliably
%   split stdout/stderr, this wrapper redirects stderr to a temp file.

  if nargin < 2
    error('syncDirCpy2MainDir:BadInput', ...
      'Need at least 2 inputs: dirCopy, dirMain.');
  end

  validateattributes(dirCopy, {'char','string'}, {'nonempty'}, mfilename, 'dirCopy', 1);
  validateattributes(dirMain, {'char','string'}, {'nonempty'}, mfilename, 'dirMain', 2);

  dirCopy = char(dirCopy);
  dirMain = char(dirMain);

  % Options are passed through as literal flags (e.g., '--dryRun', '--rmDirCopy')
  passFlags = cell(1, numel(varargin));
  for i = 1:numel(varargin)
    if ~(ischar(varargin{i}) || isstring(varargin{i}))
      error('syncDirCpy2MainDir:BadOption', ...
        'All options must be strings, e.g., ''--dryRun''.');
    end
    passFlags{i} = char(varargin{i});
  end

  % --- Locate script ---
  scriptName = 'syncDirCpy2MainDir.sh';
  scriptPath = '';

  % 1) If on PATH, use as-is
  if isOnPath(scriptName)
    scriptPath = scriptName;
  else
    % 2) Try same folder as this .m file
    thisFile = mfilename('fullpath');
    thisDir  = fileparts(thisFile);
    candidate = fullfile(thisDir, scriptName);
    if exist(candidate, 'file') == 2
      scriptPath = candidate;
    else
      error('syncDirCpy2MainDir:ScriptNotFound', ...
        ['Could not find %s on PATH or next to this .m file.\n' ...
         'Either add it to PATH or place it beside %s.m.\n' ...
         'Tried: %s'], scriptName, mfilename, candidate);
    end
  end

  % Ensure it's executable if it's a local file path
  if ~(strcmp(scriptPath, scriptName)) % implies we found a path, not PATH lookup
    makeExecutableBestEffort(scriptPath);
  end

  % --- Build command ---
  % Use bash -lc so PATH/login env are applied, and quote safely.
  qScript  = shQuote(scriptPath);
  qDirCopy = shQuote(dirCopy);
  qDirMain = shQuote(dirMain);

  % Quote flags too (they are simple but still safe)
  qFlags = cellfun(@shQuote, passFlags, 'UniformOutput', false);

  % Capture stderr to temp file for better separation
  errFile = [tempname() '.stderr.txt'];
  qErrFile = shQuote(errFile);

  % bash -lc "<script> <args...>" 2>errfile
  inner = strjoin([{qScript, qDirCopy, qDirMain}, qFlags], ' ');
  cmd = sprintf('bash -lc %s 2> %s', shQuote(inner), qErrFile);

  % --- Run ---
  [status, stdout] = system(cmd);

  % Read stderr (best effort)
  stderr = '';
  if exist(errFile, 'file') == 2
    try
      stderr = fileread(errFile);
    catch
      stderr = '';
    end
    try
      delete(errFile);
    catch
      % ignore
    end
  end

  % If stderr is empty but stdout contains typical error prefixes, leave it as-is.
end

% ---------------- helpers ----------------

function tf = isOnPath(exeName)
  % Works on Linux/macOS; for Windows+WSL you'd still use bash.
  [s, ~] = system(sprintf('bash -lc %s', shQuote(['command -v ' exeName ' >/dev/null 2>&1'])));
  tf = (s == 0);
end

function makeExecutableBestEffort(p)
  % Try to chmod +x. If it fails, the subsequent call may still work if invoked via bash.
  try
    system(sprintf('bash -lc %s', shQuote(['chmod +x ' shQuote(p)])));
  catch
    % ignore
  end
end

function q = shQuote(s)
  % Robust single-quote shell quoting: ' -> '\'' pattern
  s = char(s);
  q = ['''' strrep(s, '''', '''\''''') ''''];
end
