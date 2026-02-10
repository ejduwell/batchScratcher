#!/usr/bin/env bash
# pull_remote_dir_tar_slurm.sh
#
# Defines:
#   pull_remote_dir_tar_slurm
#
# Usage:
#   pull_remote_dir_tar_slurm <user@host> <remoteDirPth> <localDirPth> <slurm_account> <time_limit_DD-HH:MM:SS> <rmRemoteDir_true|false> [pigz_threads]
#
# Example:
#   source /path/to/pull_remote_dir_tar_slurm.sh
#   pull_remote_dir_tar_slurm \
#     eduwell@login-hpc.rcc.mcw.edu \
#     /scratch/g/agreenberg/eduwell/projects/matlabBatchScratch/myDir \
#     /home/eduwell/Downloads \
#     agreenberg \
#     00-02:00:00 \
#     false \
#     16
#
# Optional cleanup env vars:
#   CLEAN_REMOTE_TAR=1      # remove remote tarball after success
#   CLEAN_REMOTE_JOBDIR=1   # remove remote jobdir after success
#   CLEAN_LOCAL_TAR=1       # remove local tarball after success
#
# Notes:
# - Uses sbatch on the cluster to do tar+pigz on a compute node.
# - Loads pigz via: module load pigz
# - Creates tarball in the parent of remoteDirPth so it is not inside the archived tree.
# - After job completes, downloads tarball (rsync if available, else scp), extracts locally,
#   then optionally deletes the REMOTE DIRECTORY if rmRemoteDir=true.
#

pull_remote_dir_tar_slurm() {
  local remoteHost="$1"
  local remoteDirPth="$2"
  local localDirPth="$3"
  local slurmAccount="$4"
  local timeLimit="$5"
  local rmRemoteDir="$6"
  local pigzThreads="${7:-8}"

  if [[ -z "$remoteHost" || -z "$remoteDirPth" || -z "$localDirPth" || -z "$slurmAccount" || -z "$timeLimit" || -z "$rmRemoteDir" ]]; then
    echo "ERROR: Missing args."
    echo "Usage: pull_remote_dir_tar_slurm <user@host> <remoteDirPth> <localDirPth> <slurm_account> <time_limit_DD-HH:MM:SS> <rmRemoteDir_true|false> [pigz_threads]"
    return 2
  fi

  if [[ ! -d "$localDirPth" ]]; then
    echo "ERROR: localDirPth does not exist or is not a directory: $localDirPth"
    return 2
  fi

  if ! [[ "$pigzThreads" =~ ^[0-9]+$ ]] || [[ "$pigzThreads" -lt 1 ]]; then
    echo "ERROR: pigz_threads must be a positive integer (got: $pigzThreads)"
    return 2
  fi

  # Validate time format DD-HH:MM:SS
  if ! [[ "$timeLimit" =~ ^[0-9]+-[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    echo "ERROR: time_limit must match DD-HH:MM:SS (got: $timeLimit)"
    return 2
  fi

  # Validate rmRemoteDir boolean-ish
  case "$rmRemoteDir" in
    true|false) ;;
    *)
      echo "ERROR: rmRemoteDir must be 'true' or 'false' (got: $rmRemoteDir)"
      return 2
      ;;
  esac

  local localAbs
  localAbs="$(cd "$localDirPth" && pwd -P)" || return 2

  # Compute remoteParent + remoteBase on the remote side (avoid heredocs/newline quoting issues)
  # Use printf %q to safely inject the path into the remote bash -lc snippet.
  local remoteParent remoteBase
  remoteParent="$(ssh -o BatchMode=yes "$remoteHost" "bash -lc 'p=$(printf %q "$remoteDirPth"); p=\${p%/}; dirname -- \"\$p\"'")" || return 3
  remoteBase="$(ssh -o BatchMode=yes "$remoteHost" "bash -lc 'p=$(printf %q "$remoteDirPth"); p=\${p%/}; basename -- \"\$p\"'")" || return 3

  if [[ -z "$remoteParent" || -z "$remoteBase" || "$remoteBase" == "/" ]]; then
    echo "ERROR: Could not parse remoteDirPth safely."
    return 3
  fi

  local stamp tarName remoteTar remoteJobDir remoteJobScript remoteJobOut
  stamp="$(date +%Y%m%d_%H%M%S)"
  tarName="${remoteBase}_${stamp}.tar.gz"
  remoteTar="${remoteParent%/}/${tarName}"

  remoteJobDir="~/pullTar_${remoteBase}_${stamp}"
  remoteJobScript="${remoteJobDir}/make_tar.sbatch"
  remoteJobOut="${remoteJobDir}/slurm-%j.out"

  echo "Remote host      : $remoteHost"
  echo "Remote directory : $remoteDirPth"
  echo "Remote tarball   : $remoteTar"
  echo "Local dir        : $localAbs"
  echo "Slurm account    : $slurmAccount"
  echo "Time limit       : $timeLimit"
  echo "rmRemoteDir      : $rmRemoteDir"
  echo "pigz threads     : $pigzThreads"
  echo

  echo "==> Writing sbatch script on remote..."
  ssh -o BatchMode=yes "$remoteHost" "bash -lc $(printf %q \
    "set -euo pipefail
     mkdir -p \"$remoteJobDir\"

     cat > \"$remoteJobScript\" <<'SBATCH'
#!/bin/bash
#SBATCH --job-name=pullTar_${remoteBase}
#SBATCH --output=${remoteJobOut}
#SBATCH --account=${slurmAccount}
#SBATCH --time=${timeLimit}
#SBATCH --cpus-per-task=${pigzThreads}
#SBATCH --mem=4G

set -euo pipefail

REMOTE_DIR=${remoteDirPth@Q}
REMOTE_PARENT=${remoteParent@Q}
REMOTE_BASE=${remoteBase@Q}
REMOTE_TAR=${remoteTar@Q}
PIGZ_THREADS=${pigzThreads@Q}

module load pigz

if [[ ! -d \"\$REMOTE_DIR\" ]]; then
  echo \"ERROR: Remote directory does not exist: \$REMOTE_DIR\" >&2
  exit 10
fi

cd \"\$REMOTE_PARENT\"

# Create tar.gz using pigz
tar --numeric-owner -cpf - \"\$REMOTE_BASE\" | pigz -p \"\$PIGZ_THREADS\" > \"\$REMOTE_TAR\"

echo \"Created: \$REMOTE_TAR\"
ls -lh \"\$REMOTE_TAR\"
SBATCH

     chmod +x \"$remoteJobScript\"")" || return 4

  echo "==> Submitting sbatch job..."
  local jobid
  jobid="$(ssh -o BatchMode=yes "$remoteHost" "bash -lc $(printf %q "sbatch \"$remoteJobScript\" | awk '{print \$4}'")")" || return 5
  if [[ -z "$jobid" ]]; then
    echo "ERROR: Failed to obtain jobid from sbatch."
    return 5
  fi
  echo "Submitted jobid: $jobid"
  echo

  echo "==> Waiting for Slurm job to finish..."
  while true; do
    local state
    state="$(ssh -o BatchMode=yes "$remoteHost" "bash -lc $(printf %q \
      "sacct -j ${jobid} --format=State --noheader 2>/dev/null | head -n 1 | awk '{print \$1}'")")" || true
    if [[ -z "$state" || "$state" == "UNKNOWN" ]]; then
      state="$(ssh -o BatchMode=yes "$remoteHost" "bash -lc $(printf %q \
        "squeue -j ${jobid} -h -o %T 2>/dev/null | head -n 1")")" || true
    fi
    if [[ -z "$state" ]]; then
      sleep 5
      continue
    fi

    echo "  job $jobid state: $state"

    case "$state" in
      COMPLETED) break ;;
      FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|PREEMPTED)
        echo "ERROR: Slurm job ended in state: $state"
        echo "Remote slurm output (if available):"
        ssh -o BatchMode=yes "$remoteHost" "bash -lc $(printf %q \
          "ls -1 \"$remoteJobDir\" 2>/dev/null || true; echo; tail -n 200 \"$remoteJobDir\"/slurm-*.out 2>/dev/null || true")"
        return 6
        ;;
      *) sleep 10 ;;
    esac
  done

  echo "==> Verifying remote tarball exists..."
  ssh -o BatchMode=yes "$remoteHost" "test -f $(printf %q "$remoteTar")" || {
    echo "ERROR: Remote tarball not found: $remoteTar"
    ssh -o BatchMode=yes "$remoteHost" "bash -lc $(printf %q "tail -n 200 \"$remoteJobDir\"/slurm-*.out 2>/dev/null || true")"
    return 7
  }

  echo "==> Downloading tarball..."
  local localTar localExtractDir
  localTar="${localAbs%/}/${tarName}"
  localExtractDir="${localAbs%/}/${remoteBase}_${stamp}"

  if command -v rsync >/dev/null 2>&1; then
    rsync -av --progress "${remoteHost}:$(printf %q "$remoteTar")" "$localAbs/" || return 8
  else
    scp -p "${remoteHost}:$remoteTar" "$localAbs/" || return 8
  fi

  echo "==> Extracting locally..."
  mkdir -p "$localExtractDir" || return 9
  tar -xzf "$localTar" -C "$localExtractDir" || return 9

  echo "==> Done."
  echo "Extracted content is under: $localExtractDir"

  # Optional: delete remote directory AFTER successful download + extraction
  if [[ "$rmRemoteDir" == "true" ]]; then
    echo "==> rmRemoteDir=true: preparing to delete remote directory..."

    # Safety: refuse to delete obviously dangerous targets
    # (You can extend this list for your environment.)
    local remoteToDelete="${remoteDirPth%/}"
    if [[ -z "$remoteToDelete" || "$remoteToDelete" == "/" ]]; then
      echo "ERROR: Refusing to delete remote directory: '$remoteToDelete'"
      return 10
    fi

    # Remote-side safety checks: must exist and be a directory, and not be the parent itself.
    ssh -o BatchMode=yes "$remoteHost" "bash -lc $(printf %q \
      "set -euo pipefail
       tgt=\"$remoteToDelete\"
       if [[ ! -d \"\$tgt\" ]]; then
         echo \"ERROR: Remote delete target is not a directory (or no longer exists): \$tgt\" >&2
         exit 11
       fi
       if [[ \"\$tgt\" == \"/\" ]]; then
         echo \"ERROR: Refusing to delete '/'\" >&2
         exit 12
       fi
       rm -rf -- \"\$tgt\"
       echo \"Deleted remote directory: \$tgt\"")" || return 10
  fi

  # Optional cleanup toggles (tar/jobdir/local tar)
  if [[ "${CLEAN_REMOTE_TAR:-0}" == "1" ]]; then
    echo "==> Cleaning remote tarball..."
    ssh -o BatchMode=yes "$remoteHost" "rm -f $(printf %q "$remoteTar")" || true
  fi
  if [[ "${CLEAN_REMOTE_JOBDIR:-0}" == "1" ]]; then
    echo "==> Cleaning remote job dir..."
    ssh -o BatchMode=yes "$remoteHost" "rm -rf $(printf %q "$remoteJobDir")" || true
  fi
  if [[ "${CLEAN_LOCAL_TAR:-0}" == "1" ]]; then
    echo "==> Cleaning local tarball..."
    rm -f "$localTar" || true
  fi
}

