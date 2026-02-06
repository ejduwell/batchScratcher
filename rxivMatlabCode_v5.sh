#!/bin/bash
# rxivMatlabCode_v5.sh
#
# Archive files by extension while preserving full directory structure (including empty dirs),
# with support for:
#   1) Ignored subdirectories (dir structure preserved, but no matching files copied from them)
#   2) Individually specified files to include (--indFiles), even if they don't match extensions
#   3) Optional compression (--compress 1|0). Default is 0 (no compression).
#   4) Optional accelerated gzip compression via pigz (--pigz [N])
#        - If --pigz is provided and --compress 1, tar.gz compression uses pigz.
#        - Optional N controls number of CPUs (pigz -p N). If omitted, pigz chooses default.
#
# Usage:
#   ./rxivMatlabCode_v5.sh <source_directory> <output_directory> \
#     --ext <ext1> [ext2 ...] \
#     [--ignore <subdir1> [subdir2 ...]] \
#     [--indFiles <relFile1> [relFile2 ...]] \
#     [--compress 1|0] \
#     [--pigz [N]]
#
# Examples:
#   ./rxivMatlabCode_v5.sh /data/proj /tmp/out --ext .m .sh .mat
#   ./rxivMatlabCode_v5.sh /data/proj /tmp/out --ext .m .sh --ignore .git build --compress 1
#   ./rxivMatlabCode_v5.sh /data/proj /tmp/out --ext .m --indFiles README.md sub/config.json --compress 0
#   ./rxivMatlabCode_v5.sh /data/proj /tmp/out --ext .m .sh --compress 1 --pigz
#   ./rxivMatlabCode_v5.sh /data/proj /tmp/out --ext .m .sh --compress 1 --pigz 8
#
# Notes:
# - --ignore and --indFiles are optional (can be omitted or provided with 0 items).
# - ignore entries are PATHS RELATIVE to <source_directory> (no leading slash).
#   Examples: ".git", "build", "sub/dirA"
# - indFiles entries are FILE PATHS RELATIVE to <source_directory>.
#   Examples: "README.md", "sub/config.json", "scripts/run_this.py"
# - If an indFile is under an ignored directory, it will NOT be copied (consistent with ignore behavior).
# - Full directory tree is always recreated in the archive.
# - If --compress 1, produces matlabCodeRxiv_<timestamp>.tar.gz and removes the working folder.
#   If --compress 0 (default), leaves the working folder in place (matlabCodeRxiv/).
# - If --pigz is used without --compress 1, it is ignored (with a warning).

copy_files_by_ext() {

  if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <source_directory> <output_directory> --ext <ext1> [ext2 ...] [--ignore <subdir...>] [--indFiles <relFile...>] [--compress 1|0] [--pigz [N]]"
    echo "Example: $0 /path/src /path/out --ext .m .sh .mat --ignore .git build --indFiles README.md --compress 1 --pigz 8"
    exit 1
  fi

  local src_dir="$1"
  local out_dir_base="$2"
  shift 2

  # -----------------------------
  # Parse flags: --ext, --ignore, --indFiles, --compress, --pigz
  # -----------------------------
  local fileExtTypes=()
  local ignoreSubDirs=()
  local indFiles=()
  local compress=0   # default: no compression

  local use_pigz=0   # default: no pigz
  local pigz_cpus="" # optional numeric CPU count

  local mode=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --ext)
        mode="ext"
        ;;
      --ignore)
        mode="ignore"
        ;;
      --indFiles)
        mode="indFiles"
        ;;
      --compress)
        mode="compress"
        ;;
      --pigz)
        use_pigz=1
        # Optional next arg: CPU count
        if [ "$#" -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
          pigz_cpus="$2"
          shift
        fi
        mode=""
        ;;
      --help|-h)
        echo "Usage: $0 <source_directory> <output_directory> --ext <ext1> [ext2 ...] [--ignore <subdir...>] [--indFiles <relFile...>] [--compress 1|0] [--pigz [N]]"
        exit 0
        ;;
      *)
        if [ "$mode" = "ext" ]; then
          fileExtTypes+=("$1")
        elif [ "$mode" = "ignore" ]; then
          ignoreSubDirs+=("$1")
        elif [ "$mode" = "indFiles" ]; then
          indFiles+=("$1")
        elif [ "$mode" = "compress" ]; then
          compress="$1"
          mode=""  # consume exactly one value
        else
          echo "ERROR: Unexpected argument '$1'. You must specify a section: --ext (required), --ignore, --indFiles, --compress, --pigz."
          echo "Usage: $0 <source_directory> <output_directory> --ext <ext1> [ext2 ...] [--ignore <subdir...>] [--indFiles <relFile...>] [--compress 1|0] [--pigz [N]]"
          exit 1
        fi
        ;;
    esac
    shift
  done

  if [ "${#fileExtTypes[@]}" -lt 1 ]; then
    echo "ERROR: You must provide at least one extension after --ext"
    exit 1
  fi

  if [ "$compress" != "0" ] && [ "$compress" != "1" ]; then
    echo "ERROR: --compress must be 0 or 1 (got: '$compress')"
    exit 1
  fi

  if [ "$use_pigz" -eq 1 ] && [ -n "$pigz_cpus" ] && ! [[ "$pigz_cpus" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --pigz CPU count must be an integer (got: '$pigz_cpus')"
    exit 1
  fi

  echo " "
  echo "############################################################################################################"
  echo "ARCHIVE FILES (EXTENSIONS + OPTIONAL INDIVIDUAL FILES), FULL DIR STRUCTURE, OPTIONAL IGNORED SUBDIRS, COMPRESS"
  echo "############################################################################################################"
  echo " "
  echo "src_dir      : $src_dir"
  echo "out_dir_base : $out_dir_base"
  echo -n "fileExtTypes : "
  printf "%s " "${fileExtTypes[@]}"
  echo
  echo -n "ignoreSubDirs: "
  if [ "${#ignoreSubDirs[@]}" -eq 0 ]; then
    echo "(none)"
  else
    printf "%s " "${ignoreSubDirs[@]}"
    echo
  fi
  echo -n "indFiles     : "
  if [ "${#indFiles[@]}" -eq 0 ]; then
    echo "(none)"
  else
    printf "%s " "${indFiles[@]}"
    echo
  fi
  echo "compress     : $compress"
  if [ "$use_pigz" -eq 1 ]; then
    if [ -n "$pigz_cpus" ]; then
      echo "pigz         : 1 (CPUs: $pigz_cpus)"
    else
      echo "pigz         : 1 (CPUs: default)"
    fi
  else
    echo "pigz         : 0"
  fi
  echo " "

  # Ensure source directory exists
  if [ ! -d "$src_dir" ]; then
    echo "Source directory does not exist: $src_dir"
    exit 1
  fi

  # Make src_dir absolute for consistent path stripping
  src_dir="$(cd "$src_dir" && pwd)"

  # Create the output directory if it doesn't exist
  mkdir -p "$out_dir_base/matlabCodeRxiv"

  local strtDir
  strtDir="$(pwd)"

  cd "$out_dir_base/matlabCodeRxiv" || exit 1
  local rxiv_root
  rxiv_root="$(pwd)"

  local now
  now="$(date)"

  # Archive should have first subdir named like the input dir
  local src_name
  src_name="$(basename "$src_dir")"

  local archive_root="$rxiv_root/$src_name"
  mkdir -p "$archive_root"

  # Normalize ignoreSubDirs: remove leading ./ and any leading/trailing slashes
  local norm_ignore=()
  local ig
  for ig in "${ignoreSubDirs[@]}"; do
    ig="${ig#./}"
    ig="${ig#/}"
    ig="${ig%/}"
    [ -n "$ig" ] && norm_ignore+=("$ig")
  done

  # Normalize indFiles: remove leading ./ and leading slash
  local norm_indFiles=()
  local f
  for f in "${indFiles[@]}"; do
    f="${f#./}"
    f="${f#/}"
    [ -n "$f" ] && norm_indFiles+=("$f")
  done

  # Write README
  {
    echo "This directory was created by the bash script 'rxivMatlabCode_v5.sh' (written by E.J. Duwell, PhD)."
    echo "It contains an archived copy of content from:"
    echo "  $src_dir"
    echo
    echo "Included file extensions:"
    printf "  %s\n" "${fileExtTypes[@]}"
    echo
    if [ "${#norm_indFiles[@]}" -gt 0 ]; then
      echo "Additionally included individual files (relative to src_dir):"
      printf "  %s\n" "${norm_indFiles[@]}"
      echo
    fi
    if [ "${#norm_ignore[@]}" -gt 0 ]; then
      echo "Ignored subdirectories (relative to src_dir; directory structure preserved but files NOT copied):"
      printf "  %s\n" "${norm_ignore[@]}"
      echo
    else
      echo "Ignored subdirectories: (none)"
      echo
    fi
    echo "Compression (--compress): $compress"
    echo "Use pigz (--pigz): $use_pigz"
    if [ "$use_pigz" -eq 1 ]; then
      if [ -n "$pigz_cpus" ]; then
        echo "pigz CPUs (-p): $pigz_cpus"
      else
        echo "pigz CPUs (-p): (default)"
      fi
    fi
    echo
    echo "Created on:"
    echo "  $now"
  } > "$rxiv_root/README.txt"

  cd "$strtDir" || exit 1

  # ------------------------------------------------------------
  # Helper: test whether a relative path is within an ignored dir
  # ------------------------------------------------------------
  is_ignored_relpath() {
    local rel="$1"
    local d
    for d in "${norm_ignore[@]}"; do
      if [[ "$rel" == "$d" ]] || [[ "$rel" == "$d/"* ]]; then
        return 0
      fi
    done
    return 1
  }

  # ------------------------------------------------------------
  # 1) Recreate FULL directory structure (including empty dirs)
  # ------------------------------------------------------------
  find "$src_dir" -type d -print0 | while IFS= read -r -d '' d; do
    local rel="${d#$src_dir/}"
    if [ "$d" = "$src_dir" ]; then
      rel=""
    fi
    mkdir -p "$archive_root/$rel"
  done

  # ------------------------------------------------------------
  # 2) Copy matching files by extension (skipping ignored dirs)
  # ------------------------------------------------------------
  local find_expr=()
  local ext
  for ext in "${fileExtTypes[@]}"; do
    ext="${ext#.}"            # allow ".m" or "m"
    find_expr+=( -iname "*.${ext}" -o )
  done
  unset 'find_expr[${#find_expr[@]}-1]'  # remove trailing -o

  find "$src_dir" -type f \( "${find_expr[@]}" \) -print0 | while IFS= read -r -d '' file; do
    local rel="${file#$src_dir/}"

    if is_ignored_relpath "$rel"; then
      continue
    fi

    local rel_dir
    rel_dir="$(dirname "$rel")"
    mkdir -p "$archive_root/$rel_dir"
    cp "$file" "$archive_root/$rel_dir/"
  done

  # ------------------------------------------------------------
  # 3) Copy individually-specified files (--indFiles)
  # ------------------------------------------------------------
  if [ "${#norm_indFiles[@]}" -gt 0 ]; then
    local relf
    for relf in "${norm_indFiles[@]}"; do

      # Safety: refuse path traversal outside src_dir
      if [[ "$relf" == *".."* ]]; then
        echo "WARNING: Skipping indFile with '..' (path traversal not allowed): $relf"
        continue
      fi

      if is_ignored_relpath "$relf"; then
        echo "WARNING: Skipping indFile under ignored subdir: $relf"
        continue
      fi

      local absf="$src_dir/$relf"
      if [ ! -f "$absf" ]; then
        echo "WARNING: indFile not found (skipping): $relf"
        continue
      fi

      local rel_dir
      rel_dir="$(dirname "$relf")"
      if [ "$rel_dir" = "." ]; then
        rel_dir=""
      fi

      mkdir -p "$archive_root/$rel_dir"
      cp "$absf" "$archive_root/$rel_dir/"
    done
  fi

  echo "Copy operation completed."

  # ------------------------------------------------------------
  # 4) Optional compression
  # ------------------------------------------------------------
  if [ "$compress" -eq 1 ]; then
    echo "Compressing to .tar.gz"

    if [ "$use_pigz" -eq 1 ]; then
      if ! command -v pigz >/dev/null 2>&1; then
        echo "ERROR: --pigz was requested but pigz is not installed or not in PATH."
        echo "       Install it (e.g., 'sudo apt-get install pigz') or omit --pigz."
        exit 1
      fi
    fi

    cd "$rxiv_root" || exit 1
    cd .. || exit 1

    local dateStr
    dateStr="$(date +'%m-%d-%Y-%H%M%S')"

    if [ "$use_pigz" -eq 1 ]; then
      local pigz_prog="pigz"
      if [ -n "$pigz_cpus" ]; then
        pigz_prog="pigz -p $pigz_cpus"
      fi

      # Use GNU tar's -I when available; fall back to --use-compress-program otherwise.
      if tar --help 2>/dev/null | grep -qE '(^|[[:space:]])-I[[:space:]]'; then
        tar -I "$pigz_prog" -cvf "matlabCodeRxiv_${dateStr}.tar.gz" "matlabCodeRxiv"
      else
        tar --use-compress-program="$pigz_prog" -cvf "matlabCodeRxiv_${dateStr}.tar.gz" "matlabCodeRxiv"
      fi
    else
      tar -czvf "matlabCodeRxiv_${dateStr}.tar.gz" "matlabCodeRxiv"
    fi

    rm -rf "matlabCodeRxiv"

    echo "Done: matlabCodeRxiv_${dateStr}.tar.gz"
  else
    if [ "$use_pigz" -eq 1 ]; then
      echo "WARNING: --pigz was provided but --compress is 0. Skipping compression; --pigz has no effect."
    fi
    echo "Skipping compression (--compress 0)."
    echo "Output folder retained at: $out_dir_base/matlabCodeRxiv"
  fi
}

# Calling the function with command line arguments
copy_files_by_ext "$@"

