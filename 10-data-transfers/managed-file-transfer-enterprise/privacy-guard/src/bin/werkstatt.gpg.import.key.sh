#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.import.key.sh
# purpose : Generic key import -- dispatches to the same import logic as
#           werkstatt.gpg.import.public.key.sh / werkstatt.gpg.import.private.key.sh
#           based on an explicit -m mode flag, for callers that want one
#           script regardless of key type rather than choosing between the
#           two single-purpose scripts.
#
# origin  : Hardened, production-like-demo version of a training script
#           that combined public/private import behind flag translation.
#           Same passphrase-file discipline as
#           werkstatt.gpg.import.private.key.sh applies here when -m private is
#           used: the passphrase must already be staged in a locked-down
#           file, never passed as a flag value or printed.

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
  $SCRIPT_NAME [-f "<file>"] -m public|private [options]

Required:
  -m  mode        "public" or "private"

Optional:
  -f  file        path to the key file to import (armored or binary).
                   Default: the one file matching *.<mode>.* in
                   \$MFTE_GPG_EXCHANGE_DIR, if exactly one exists -- error if
                   zero or more than one.

Optional (private mode only):
  -P  passphrase file for the imported key -- must already exist, mode
      600, owned by \$MFTE_GPG_USER. Copied into this framework's standard
      fingerprint-keyed location after import. If omitted, also tries
      \$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase once the fingerprint
      is known, same demo-convenience default as
      werkstatt.gpg.import.private.key.sh -- see that script for the full
      explanation.
  -D  set the imported key as the default. Off by default.

Optional:
  -q  quiet
  -h  help

\$MFTE_GPG_EXCHANGE_DIR is the conventional place to stage the inbound key
file -- -f accepts any path if you'd rather point elsewhere.

If you always know which type you're importing, prefer
werkstatt.gpg.import.public.key.sh / werkstatt.gpg.import.private.key.sh directly --
this script exists for callers that want one entry point either way.

Recommended Run Command:
  $SCRIPT_NAME -f "\$\$FILE_ABS_PATH\$\$" -m public -q
USAGE
}

FILE=""
MODE=""
PASSPHRASE_FILE=""
SET_DEFAULT="false"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':f:m:P:Dqh' opt; do
  case "$opt" in
    f) FILE="$(mfte_unquote "$OPTARG")" ;;
    m) MODE="$(mfte_unquote "$OPTARG")" ;;
    P) PASSPHRASE_FILE="$(mfte_unquote "$OPTARG")" ;;
    D) SET_DEFAULT="true" ;;
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

if [[ -z "$MODE" ]]; then
  log_system ERROR "missing required -m"
  echo "ERROR: -m mode (public|private) is required." >&2
  usage
  exit 2
fi

case "$MODE" in
  public|private) ;;
  *)
    log_system ERROR "invalid -m mode: ${MODE}"
    echo "ERROR: -m must be 'public' or 'private', got: ${MODE}" >&2
    exit 2
    ;;
esac

if [[ -z "$FILE" ]]; then
  FILE="$(mfte_gpg_find_single_file "${MFTE_GPG_EXCHANGE_DIR}" "*.${MODE}.*")" || {
    log_system ERROR "no -f given and no single unambiguous *.${MODE}.* match in ${MFTE_GPG_EXCHANGE_DIR}"
    echo "ERROR: -f not given, and \$MFTE_GPG_EXCHANGE_DIR (${MFTE_GPG_EXCHANGE_DIR}) does not contain exactly one *.${MODE}.* file to default to." >&2
    usage
    exit 2
  }
  log_system INFO "defaulted -f to ${FILE} (single *.${MODE}.* match in MFTE_GPG_EXCHANGE_DIR)"
fi

if [[ ! -f "$FILE" || ! -r "$FILE" ]]; then
  log_system ERROR "file not found or unreadable: ${FILE}"
  echo "ERROR: file not found or unreadable: ${FILE}" >&2
  exit 1
fi

if [[ "$MODE" == "private" && -n "$PASSPHRASE_FILE" ]] && ! mfte_gpg_require_locked_down "$PASSPHRASE_FILE" 600; then
  log_system ERROR "supplied -P passphrase file failed lockdown check: ${PASSPHRASE_FILE}"
  echo "ERROR: -P passphrase file must exist, mode 600, owned by ${MFTE_GPG_USER}." >&2
  exit 1
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start file=${FILE} mode=${MODE}"

if ! IMPORT_OUTPUT="$(mfte_gpg_import_key "$FILE" "$MODE" 2>&1)"; then
  log_system ERROR "${MODE} key import failed file=${FILE}"
  echo "ERROR: import failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

FINGERPRINT="$(mfte_gpg_import_fingerprint "$IMPORT_OUTPUT")"
if [[ -z "$FINGERPRINT" ]]; then
  log_system ERROR "import produced no IMPORT_OK status file=${FILE}"
  echo "ERROR: gpg did not report an imported key (already present with no change, or not valid key material?)." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

UID_LOOKUP_MODE="public"
[[ "$MODE" == "private" ]] && UID_LOOKUP_MODE="secret"
UID_STR="$(mfte_gpg_uid_for_fingerprint "$FINGERPRINT" "$UID_LOOKUP_MODE")"
FILED_PASSPHRASE="false"

if [[ "$MODE" == "private" && -z "$PASSPHRASE_FILE" ]]; then
  CANDIDATE_PASSPHRASE="${MFTE_GPG_EXCHANGE_DIR}/${FINGERPRINT}.passphrase"
  if [[ -f "$CANDIDATE_PASSPHRASE" ]]; then
    if mfte_gpg_require_locked_down "$CANDIDATE_PASSPHRASE" 600; then
      PASSPHRASE_FILE="$CANDIDATE_PASSPHRASE"
      log_system INFO "defaulted -P to ${PASSPHRASE_FILE} (fingerprint-matched file in MFTE_GPG_EXCHANGE_DIR)"
    else
      log_system WARN "found ${CANDIDATE_PASSPHRASE} but it failed the mode-600 lockdown check -- not auto-filing, pass -P explicitly if you intend to use it"
    fi
  fi
fi

if [[ "$MODE" == "private" && -n "$PASSPHRASE_FILE" ]]; then
  TARGET="$(mfte_gpg_passphrase_file "$FINGERPRINT")"
  runuser -u "${MFTE_GPG_USER}" -- mkdir -p "${MFTE_GPG_PASSPHRASE_DIR}"
  runuser -u "${MFTE_GPG_USER}" -- chmod 700 "${MFTE_GPG_PASSPHRASE_DIR}"
  runuser -u "${MFTE_GPG_USER}" -- cp "$PASSPHRASE_FILE" "$TARGET"
  runuser -u "${MFTE_GPG_USER}" -- chmod 600 "$TARGET"
  FILED_PASSPHRASE="true"
fi

if [[ "$SET_DEFAULT" == "true" ]]; then
  mfte_gpg_write_default_key_json "$FINGERPRINT" "$UID_STR" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fi

log_system INFO "complete file=${FILE} mode=${MODE} fingerprint=${FINGERPRINT} uid=\"${UID_STR}\" passphrase_filed=${FILED_PASSPHRASE} default_updated=${SET_DEFAULT}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG key import complete
  mode              : $MODE
  input             : $FILE
  fingerprint       : $FINGERPRINT
  uid               : $UID_STR
  passphrase filed  : $FILED_PASSPHRASE
  default updated   : $SET_DEFAULT
REPORT
fi

exit 0
