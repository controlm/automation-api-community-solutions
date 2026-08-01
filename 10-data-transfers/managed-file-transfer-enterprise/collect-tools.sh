#!/usr/bin/env bash
set -o pipefail
umask 022

# file name: collect-tools.sh
# purpose : Merge the interactively-run python/bash tools from every
#           subproject's src/ tree into a single flat tools/ folder,
#           matching how these get copied onto a hub in practice -- an
#           operator cd's into one "tools" directory and runs whatever
#           script it needs, rather than juggling separate per-project
#           deploy zips.
#
# discovery: Projects are found automatically, not hardcoded -- any
#           immediate subdirectory of this script's own location that
#           contains a src/ folder is treated as a project (e.g.
#           site-connection-test/src, privacy-guard/src). tools/ itself
#           is skipped (it has no src/). A new project only needs to
#           follow the same src/{bin,lib/bash,config,vendor,data} +
#           top-level entry script convention -- nothing in this script
#           needs to change to pick it up.
#
# layout  : Flat merge -- tools/bin/, tools/lib/bash/, tools/config/,
#           tools/vendor/, tools/data/ each hold files from every
#           discovered project side by side. bin/ and lib/bash/
#           filenames don't collide today (werkstatt.gpg.*.sh / mfte*.sh
#           vs ldaps-import-cert.sh / cert_trust_common.sh), but
#           config/ does -- both current projects ship a
#           config/sample.env with entirely unrelated keys. Collisions
#           are detected generically (by content, not a hardcoded
#           filename list) and resolved by prefixing BOTH colliding
#           files with their project name, so nothing is ever silently
#           overwritten -- this applies to any future project too, not
#           just the two that exist today.
#
# scope   : Only pulls each project's actual tool-suite (top-level entry
#           script + bin/ + lib/bash/ + vendor/ + config/ + data/).
#           Deliberately excludes:
#             - build_package.py / build_package.py's own outputs --
#               dev-time packaging tooling, not something an operator
#               runs from tools/
#             - anything outside a project's src/ tree (e.g.
#               privacy-guard/vault/**, a separate systemd-deployed
#               subsystem for the Vault/DB host) -- excluded naturally
#               by discovery, not a special case
#             - any literal ".env" file -- only "sample.env"-style
#               templates are ever collected, never a real local file
#               that might hold actual (even if non-secret-by-policy)
#               connection details
#
# safety  : tools/ is fully regenerated output. A manifest written to
#           tools/.collector-manifest.txt on each run lets a later run
#           remove exactly the files THIS script previously wrote and
#           no longer produces -- it never touches anything else that
#           might be sitting in tools/.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
MANIFEST_FILE="${TOOLS_DIR}/.collector-manifest.txt"
PACKAGE_DIR="${SCRIPT_DIR}/package"
TAR_NAME="mfte-tools-${SCRIPT_VERSION}.tar.gz"
TAR_PATH="${PACKAGE_DIR}/${TAR_NAME}"
# A real copy, not a symlink: GitHub's raw-content endpoint serves a
# symlink as the literal text of its target path, not the target file's
# actual bytes, so a symlink here would break "latest" for wget/curl.
LATEST_PATH="${PACKAGE_DIR}/mfte-tools-latest.tar.gz"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  fi
}

# Files that must never end up in a shipped tarball, by basename,
# regardless of which project's src/ tree they live in or which
# collection loop below would otherwise pick them up:
#   - build_package.py: dev-only packaging tooling, not something an
#     operator runs from tools/
#   - mfte.ftevent.sh: production-only today (not yet in this repo), but
#     excluded proactively so it's never shipped even if it lands in
#     privacy-guard/src/lib/bash/ later without this list being revisited
EXCLUDE_BASENAMES=(
  "build_package.py"
  "mfte.ftevent.sh"
)

is_excluded_basename() {
  local base="$1" x
  for x in "${EXCLUDE_BASENAMES[@]}"; do
    [[ "$base" == "$x" ]] && return 0
  done
  return 1
}

# Discovery is scoped to managed-file-transfer-enterprise/ specifically,
# not "wherever this script happens to be run from" -- if it were ever
# copied or symlinked elsewhere (e.g. into tools/, or up to the repo
# root), SCRIPT_DIR would resolve to that new location and the discovery
# loop below would start scanning unrelated sibling directories (at the
# repo root, every other example project in the whole repo). Refuse to
# run rather than risk that.
if [[ "$(basename "$SCRIPT_DIR")" != "managed-file-transfer-enterprise" ]]; then
  echo "ERROR: this script must live directly in managed-file-transfer-enterprise/ (found: ${SCRIPT_DIR})" >&2
  exit 1
fi

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Optional:
  -n  dry-run     show what would be collected/removed, write nothing
                   (implies no tarball either)
  -T  no-tar      collect into tools/ but skip building the tarball
  -q  quiet       suppress per-file output, keep the summary
  -V  version
  -h  help

Collects from:
  any immediate subdirectory of this script's own location that has a
  src/ folder (currently: site-connection-test/src, privacy-guard/src) --
  see "discovery" in the header comment for what a new project needs.

into:
  tools/                                       (this script's sibling directory)
  package/mfte-tools-<SCRIPT_VERSION>.tar.gz    (tarball of the above, unless -n or -T)
  package/mfte-tools-latest.tar.gz              (a copy of the above, same condition --
                                                  stable filename for wget/curl)
USAGE
}

DRY_RUN="false"
QUIET="false"
NO_TAR="false"

while getopts ':nTqVh' opt; do
  case "$opt" in
    n) DRY_RUN="true" ;;
    T) NO_TAR="true" ;;
    q) QUIET="true" ;;
    V) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
    h) usage; exit 0 ;;
    :) echo "Missing value for -$OPTARG" >&2; usage; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
if [[ $# -gt 0 ]]; then
  echo "ERROR: unexpected extra arguments: $*" >&2
  usage
  exit 2
fi

log() {
  [[ "$QUIET" == "true" ]] && return 0
  printf '%s\n' "$*"
}

shopt -s nullglob

# Parallel arrays (bash 3.2 compatible -- no associative arrays) describing
# every file staged for collection so far: STAGE_DEST[i] is the path
# relative to tools/, STAGE_SRC[i] is the absolute source file, and
# STAGE_PROJECT[i] is which project it came from.
STAGE_DEST=()
STAGE_SRC=()
STAGE_PROJECT=()

# stage_file PROJECT SRC_ABS_PATH DEST_REL_PATH
# Records one file for collection. If DEST_REL_PATH is already staged by a
# DIFFERENT project with different content, both the existing entry and
# this new one are renamed to "<dir>/<project>.<basename>" so neither is
# silently overwritten. Identical content at the same dest path (e.g. two
# projects happening to ship a byte-identical file) is treated as a
# no-op, not a collision.
stage_file() {
  local project="$1" src="$2" dest_rel="$3"
  local i
  for i in "${!STAGE_DEST[@]}"; do
    if [[ "${STAGE_DEST[$i]}" == "$dest_rel" ]]; then
      if cmp -s "$src" "${STAGE_SRC[$i]}"; then
        return 0
      fi
      local prev_project="${STAGE_PROJECT[$i]}" dir base
      dir="$(dirname "$dest_rel")"
      base="$(basename "$dest_rel")"
      STAGE_DEST[$i]="${dir}/${prev_project}.${base}"
      dest_rel="${dir}/${project}.${base}"
      log "COLLISION: ${dir}/${base} differs between ${prev_project} and ${project} -- renamed both"
      break
    fi
  done
  STAGE_DEST+=("$dest_rel")
  STAGE_SRC+=("$src")
  STAGE_PROJECT+=("$project")
}

# collect_project PROJECT SRC_ROOT
collect_project() {
  local project="$1" src_root="$2"
  [[ -d "$src_root" ]] || { log "SKIP: ${project} (no ${src_root})"; return 0; }

  # Top-level entry scripts (e.g. ldap_smtp_test.py) -> tools/ root.
  local f base
  for f in "$src_root"/*.py "$src_root"/*.sh; do
    base="$(basename "$f")"
    is_excluded_basename "$base" && continue
    stage_file "$project" "$f" "$base"
  done

  # bin/*.sh -> tools/bin/
  for f in "$src_root"/bin/*.sh; do
    base="$(basename "$f")"
    is_excluded_basename "$base" && continue
    stage_file "$project" "$f" "bin/${base}"
  done

  # lib/bash/*.sh -> tools/lib/bash/
  for f in "$src_root"/lib/bash/*.sh; do
    base="$(basename "$f")"
    is_excluded_basename "$base" && continue
    stage_file "$project" "$f" "lib/bash/${base}"
  done

  # config/* -> tools/config/, except a literal ".env" (never collect a
  # real local config, only "sample.env"-style templates).
  for f in "$src_root"/config/*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == ".env" ]] && continue
    is_excluded_basename "$base" && continue
    stage_file "$project" "$f" "config/${base}"
  done

  # vendor/** -> tools/vendor/, preserving the package's internal layout
  # (e.g. vendor/ldap3/..., vendor/pyasn1/...). __pycache__/*.pyc are
  # gitignored, locally-generated bytecode caches (tied to whatever
  # python3 happened to run here) -- never source, never collected.
  if [[ -d "$src_root/vendor" ]]; then
    while IFS= read -r f; do
      base="$(basename "$f")"
      is_excluded_basename "$base" && continue
      stage_file "$project" "$f" "vendor/${f#"$src_root"/vendor/}"
    done < <(find "$src_root/vendor" -type f -name '*.pyc' -prune -o -type d -name '__pycache__' -prune -o -type f -print)
  fi

  # data/* -> tools/data/
  for f in "$src_root"/data/*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    is_excluded_basename "$base" && continue
    stage_file "$project" "$f" "data/${base}"
  done
}

# Discover projects: any immediate subdirectory of this script's own
# location that has a src/ folder. tools/ itself has no src/, so it's
# excluded without needing a special case; same for anything else (e.g.
# rules/) that isn't organized as a project yet.
for project_dir in "$SCRIPT_DIR"/*/; do
  project="$(basename "$project_dir")"
  src_root="${project_dir}src"
  [[ -d "$src_root" ]] || continue
  collect_project "$project" "$src_root"
done

if [[ ${#STAGE_DEST[@]} -eq 0 ]]; then
  echo "ERROR: nothing found to collect -- check that the subproject src/ trees exist." >&2
  exit 1
fi

# Stale cleanup: remove exactly what a PRIOR run of this script wrote and
# this run no longer produces. Never touches anything not in the old
# manifest, so hand-placed files in tools/ are left alone.
STALE=()
if [[ -f "$MANIFEST_FILE" ]]; then
  while IFS= read -r old_path; do
    [[ -z "$old_path" ]] && continue
    local_found="false"
    for d in "${STAGE_DEST[@]}"; do
      [[ "$d" == "$old_path" ]] && { local_found="true"; break; }
    done
    [[ "$local_found" == "false" ]] && STALE+=("$old_path")
  done < "$MANIFEST_FILE"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run -- no files written."
  for i in "${!STAGE_DEST[@]}"; do
    log "  WRITE  ${STAGE_DEST[$i]}  (from ${STAGE_PROJECT[$i]})"
  done
  for s in "${STALE[@]}"; do
    log "  REMOVE ${s}  (stale)"
  done
  echo "Would collect ${#STAGE_DEST[@]} file(s), remove ${#STALE[@]} stale file(s)."
  exit 0
fi

mkdir -p "$TOOLS_DIR"
for i in "${!STAGE_DEST[@]}"; do
  dest="${TOOLS_DIR}/${STAGE_DEST[$i]}"
  mkdir -p "$(dirname "$dest")"
  cp -p "${STAGE_SRC[$i]}" "$dest"
  log "  wrote ${STAGE_DEST[$i]}  (${STAGE_PROJECT[$i]})"
done

for s in "${STALE[@]}"; do
  rm -f "${TOOLS_DIR:?}/${s}"
  log "  removed ${s}  (stale)"
done
# Prune any directories left empty by stale removal (deepest first).
find "$TOOLS_DIR" -type d -empty -depth -exec rmdir {} \; 2>/dev/null || true

printf '%s\n' "${STAGE_DEST[@]}" | sort > "$MANIFEST_FILE"

echo "Collected ${#STAGE_DEST[@]} file(s) into ${TOOLS_DIR}"
[[ ${#STALE[@]} -gt 0 ]] && echo "Removed ${#STALE[@]} stale file(s) from a prior run"

if [[ "$NO_TAR" != "true" ]]; then
  require_command tar
  mkdir -p "$PACKAGE_DIR"
  # macOS's bsdtar embeds Apple-specific metadata two different ways that
  # both cause trouble when the archive is later extracted with GNU tar
  # on RHEL:
  #   - AppleDouble "._filename" sidecar entries (COPYFILE_DISABLE=1
  #     stops these) -- GNU tar doesn't recognize the format and
  #     extracts them as literal junk files alongside the real ones.
  #   - extended attributes (e.g. com.apple.provenance) written as a PAX
  #     header on the real file's own entry (--no-xattrs stops this) --
  #     GNU tar warns "Ignoring unknown extended header keyword" for
  #     each one, even though it still extracts the file fine.
  # Both flags are no-ops on Linux, where GNU tar never writes this
  # metadata in the first place.
  # --exclude the manifest -- it's local bookkeeping for this script's own
  # stale-cleanup, not something a host unpacking the tarball needs.
  COPYFILE_DISABLE=1 tar --no-xattrs -czf "$TAR_PATH" --exclude=".collector-manifest.txt" -C "$SCRIPT_DIR" tools
  size_kb=$(( $(wc -c < "$TAR_PATH") / 1024 ))
  echo "Built: ${TAR_PATH} (${size_kb} KB)"

  cp -p "$TAR_PATH" "$LATEST_PATH"
  echo "Updated: ${LATEST_PATH} -> ${TAR_NAME}"
fi

exit 0
