#!/bin/bash
# ------------------------------------------------------------------
# runHeadlessMatlabJob.sh
#
# Run a MATLAB function/script headlessly (no GUI) using:
#   matlab -nodisplay -nosplash -nodesktop -r "<command>"
#
# Adds one or more project directories recursively to the MATLAB path
# before running the specified MATLAB function/script.
#
# Usage:
#   ./runHeadlessMatlabJob.sh <matlabFile> <projectDir1> [projectDir2] [...]
#
# Example:
#   ./runHeadlessMatlabJob.sh submitBatchClstrJobMain \
#       "/home/eduwell/SynologyDrive/projects/revCorrStimFMRI" \
#       "/home/eduwell/SynologyDrive/projects/batchScratcher"
# ------------------------------------------------------------------

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <matlabFile> <projectDir1> [projectDir2] [...]"
  exit 1
fi

matlabFile="$1"
shift

# Validate matlabFile format (simple MATLAB identifier)
if ! [[ "$matlabFile" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "Error: matlabFile must be a MATLAB function/script name (no path, no .m). Got: $matlabFile"
  exit 1
fi

# Validate directories
for dir in "$@"; do
  if [ ! -d "$dir" ]; then
    echo "Error: Not a valid directory: $dir"
    exit 1
  fi
done

echo "Running MATLAB headlessly (using -r):"
echo "  matlabFile: $matlabFile"
echo "  Adding project directories:"
for dir in "$@"; do
  echo "    $dir"
done
echo ""

# Build MATLAB command as ONE line (important for quoting robustness)
# Escape single quotes for MATLAB strings: ' -> ''
matlabCmd=""

for dir in "$@"; do
  escapedDir="${dir//\'/\'\'}"
  matlabCmd+="addpath(genpath('${escapedDir}'));"
done

# Wrap execution so errors yield nonzero exit status.
# Use exit(0/1) explicitly to ensure MATLAB terminates.
matlabCmd+="try, ${matlabFile}; catch ME, disp(getReport(ME,'extended')); exit(1); end; exit(0);"

# Optional debug:
# echo "DEBUG MATLAB -r command:"
# echo "$matlabCmd"
# echo ""

# Run MATLAB headless (no desktop, no splash, no display)
matlab -nodisplay -nosplash -nodesktop -r "$matlabCmd"

# If MATLAB exits cleanly, the shell will get that exit code.
exit $?

