#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.import.all.private.sh
# purpose : Import every PRIVATE key file staged in $MFTE_GPG_EXCHANGE_DIR
#           (or -d) into the mftgpg keyring in one pass -- the batch
#           counterpart to werkstatt.gpg.import.private.key.sh, for
#           provisioning many customer decrypt-only keys (or migrating
#           mftgpg's own identities between hosts) at once rather than one
#           werkstatt.gpg.import.private.key.sh -f <file> call per key.
#
# scope   : Each file is inspected (never imported blind) before anything
#           happens to it -- same checks as
#           werkstatt.gpg.import.all.public.sh, mirrored for the private
#           case:
#             - files named *.passphrase are skipped outright -- never
#               even handed to gpg.
#             - anything gpg can't read any key material from is skipped
#               (not failed) as "not a key file".
#             - a file whose PRIMARY record is "pub" (public key only, no
#               secret material) is skipped (not imported, not failed) and
#               pointed at werkstatt.gpg.import.all.public.sh instead --
#               this script only ever imports keys that carry a secret
#               half.
#             - a fingerprint whose SECRET key is already present (checked
#               via gpg --list-secret-keys against the file's own
#               fingerprint, BEFORE calling --import) is skipped as
#               "already present", not re-imported.
#           Only an actual `gpg --import` call failing on a file that
#           passed all of the above checks counts as a real failure.
#
# NOT done here, deliberately:
#   - Passphrase filing. Each imported key still needs its passphrase
#     filed separately via werkstatt.gpg.import.passphrase.sh -k
#     <fingerprint> -f <passphrase-file> before werkstatt.gpg.decrypt.file.sh
#     or werkstatt.gpg.receive.file.sh can use it -- there is no way for
#     this script to know which passphrase file (if any) goes with which
#     of N keys just from scanning a directory of key files, and guessing
#     would be worse than requiring the explicit follow-up step. Every
#     newly-imported fingerprint is listed in this script's summary
#     specifically so that follow-up step is easy to script against.
#   - Setting a default key (werkstatt.gpg.import.private.key.sh's -D).
#     Importing N keys in one batch has no single obvious "default"
#     candidate -- set one explicitly afterward if needed.
#
# exit codes:
#   0  ran to completion with zero real import failures (individual files
#      may still have been skipped for any of the reasons above -- see the
#      per-file report and the summary counts)
#   1  at least one file that should have imported cleanly did not; other
#      files in the same run were still attempted (see the report for
#      which one(s) failed)
#   2  usage error (bad/missing flags, directory doesn't exist)

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"

# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.sh" >&2
  echo "If MFTE_OPS_HOME/MFTE_LIB_DIR were already exported in this shell (e.g. from an earlier" >&2
  echo "'source .env' in the same session), they override this script's own location-based" >&2
  echo "derivation -- a stale value from a different host/mount can point here at nothing." >&2
  echo "Try: unset MFTE_OPS_HOME MFTE_LIB_DIR" >&2
  exit 1
fi
# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.gpg.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.gpg.sh" >&2
  exit 1
fi

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Optional:
  -d  directory   default: \$MFTE_GPG_EXCHANGE_DIR
  -q  quiet       suppress the per-file + summary report (errors for real
                   failures still print). Skips are never printed to
                   stderr regardless of -q -- they aren't errors.
  -h  help

Only imports keys that carry SECRET key material. A file containing only a
public key is skipped and reported, not imported -- use
werkstatt.gpg.import.all.public.sh for those. Safe to re-run: a
fingerprint whose secret key is already in the keyring is skipped, not
re-imported.

This script does NOT file passphrases and does NOT set a default key --
see the header comment's "NOT done here" section. Every newly-imported
fingerprint is listed in the summary so
werkstatt.gpg.import.passphrase.sh can be run against each one as a
separate, explicit follow-up step.

Recommended Run Command:
  $SCRIPT_NAME -q
USAGE
}

DIR="${MFTE_GPG_EXCHANGE_DIR}"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':d:qh' opt; do
  case "$opt" in
    d) DIR="$(mfte_unquote "$OPTARG")" ;;
    q) QUIET="true" ;;
    h) usage; exit 0 ;;
    :) log_system ERROR "missing value for -$OPTARG"; echo "Missing value for -$OPTARG" >&2; usage; exit 2 ;;
    \?) log_system ERROR "unknown option -$OPTARG"; echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done

shift $((OPTIND - 1))
if ! mfte_check_no_leftover_args "$@"; then
  log_system ERROR "unexpected positional arguments after parsing (OPTIND=${OPTIND}, count=$#): $(mfte_dump_argv "$@")"
  echo "Full raw argv as received: ARGV[${ARGV_COUNT:-?}]: ${ARGV_DUMP}" >&2
  exit 2
fi

if [[ ! -d "$DIR" ]]; then
  log_system ERROR "directory not found: ${DIR}"
  echo "ERROR: directory not found: ${DIR}" >&2
  exit 2
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start dir=${DIR}"

# Top-level files only, sorted for a stable/repeatable run order. Hidden
# files (dotfiles) excluded -- .DS_Store and similar are common clutter in
# a shared staging directory, not something worth even attempting.
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "$DIR" -maxdepth 1 -type f -not -name '.*' -print0 | sort -z)

SCANNED=0
IMPORTED=0
ALREADY_PRESENT=0
SKIPPED_OTHER=0
FAILED=0
REPORT_LINES=()
IMPORTED_FPS=()

for FILE in "${FILES[@]}"; do
  SCANNED=$((SCANNED + 1))
  BASE="$(basename "$FILE")"

  case "$BASE" in
    *.passphrase)
      log_system INFO "skip file=${FILE} reason=passphrase_file"
      REPORT_LINES+=("SKIP      ${BASE}  reason=passphrase_file")
      SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
      continue
      ;;
  esac

  if ! SHOW_OUTPUT="$(mfte_gpg_file_show_only "$FILE" 2>&1)"; then
    log_system INFO "skip file=${FILE} reason=not_a_key_file"
    log_system DEBUG "gpg show-only output: ${SHOW_OUTPUT}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=not_a_key_file")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  FP="$(mfte_gpg_file_fingerprint "$SHOW_OUTPUT")"
  if [[ -z "$FP" ]]; then
    log_system INFO "skip file=${FILE} reason=not_a_key_file"
    REPORT_LINES+=("SKIP      ${BASE}  reason=not_a_key_file")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  HAS_SECRET="$(mfte_gpg_file_has_secret "$SHOW_OUTPUT")"
  if [[ "$HAS_SECRET" != "true" ]]; then
    log_system INFO "skip file=${FILE} reason=public_key_file fingerprint=${FP}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=public_key_file  fp=${FP}  (use werkstatt.gpg.import.all.public.sh)")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  if mfte_gpg_lookup_fingerprint "$FP" secret >/dev/null 2>&1; then
    log_system INFO "skip file=${FILE} reason=already_present fingerprint=${FP}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=already_present  fp=${FP}")
    ALREADY_PRESENT=$((ALREADY_PRESENT + 1))
    continue
  fi

  if ! IMPORT_OUTPUT="$(mfte_gpg_import_key "$FILE" private 2>&1)"; then
    log_system ERROR "import failed file=${FILE} fingerprint=${FP}"
    log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
    echo "ERROR: import failed for ${FILE} (fingerprint ${FP}). See ${SYSTEM_LOG_FILE} for details." >&2
    REPORT_LINES+=("FAILED    ${BASE}  fp=${FP}  (see log)")
    FAILED=$((FAILED + 1))
    continue
  fi

  IMPORTED_FP="$(mfte_gpg_import_fingerprint "$IMPORT_OUTPUT")"
  if [[ -z "$IMPORTED_FP" ]]; then
    # gpg ran without error but reported no IMPORT_OK -- the pre-check
    # above already ruled out "already present", so this means gpg
    # considered the import a no-op for some other reason. Not treated as
    # a failure (the gpg call itself succeeded), but worth its own bucket
    # rather than silently counting as "imported".
    log_system INFO "skip file=${FILE} reason=no_change fingerprint=${FP}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=no_change  fp=${FP}")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  UID_STR="$(mfte_gpg_uid_for_fingerprint "$IMPORTED_FP" secret)"
  log_system INFO "imported file=${FILE} fingerprint=${IMPORTED_FP} uid=\"${UID_STR}\" passphrase_filed=false"
  REPORT_LINES+=("IMPORTED  ${BASE}  fp=${IMPORTED_FP}  uid=\"${UID_STR}\"  passphrase: NOT filed -- run werkstatt.gpg.import.passphrase.sh")
  IMPORTED_FPS+=("$IMPORTED_FP")
  IMPORTED=$((IMPORTED + 1))
done

log_system INFO "complete dir=${DIR} scanned=${SCANNED} imported=${IMPORTED} already_present=${ALREADY_PRESENT} skipped_other=${SKIPPED_OTHER} failed=${FAILED}"

if [[ "$QUIET" != "true" ]]; then
  if [[ "${#REPORT_LINES[@]}" -gt 0 ]]; then
    printf '%s\n' "${REPORT_LINES[@]}"
  fi
  cat <<REPORT

GPG batch private key import complete
  directory         : $DIR
  files scanned     : $SCANNED
  imported          : $IMPORTED
  already present   : $ALREADY_PRESENT
  skipped (other)   : $SKIPPED_OTHER
  failed            : $FAILED
REPORT
  if [[ "${#IMPORTED_FPS[@]}" -gt 0 ]]; then
    echo
    echo "Passphrases NOT filed for the following newly-imported fingerprints --"
    echo "run werkstatt.gpg.import.passphrase.sh -k <fingerprint> -f <passphrase-file> for each:"
    printf '  %s\n' "${IMPORTED_FPS[@]}"
  fi
fi

[[ "$FAILED" -gt 0 ]] && exit 1
exit 0
