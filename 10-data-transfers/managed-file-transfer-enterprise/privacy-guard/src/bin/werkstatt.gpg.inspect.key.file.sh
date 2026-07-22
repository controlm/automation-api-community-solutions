#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.inspect.key.file.sh
# purpose : Show the fingerprint(s) and uid(s) of a key FILE without
#           importing it -- the out-of-band verification step meant to
#           happen before werkstatt.gpg.import.public.key.sh / .private.key.sh,
#           and before trusting werkstatt.gpg.encrypt.file.sh's --trust-model
#           always for a given recipient.
#
# origin  : This used to be werkstatt.gpg.fingerprint.file.sh. Renamed
#           because real usage showed "fingerprint file" naturally reads
#           as "which key(s) do I need to decrypt this file" (an
#           encrypted MESSAGE) to whoever's actually running these
#           scripts, not "inspect this KEY file before importing it" --
#           two genuinely different operations that happened to share a
#           name. werkstatt.gpg.fingerprint.file.sh now does the
#           decrypt-key-listing job; this script keeps the original
#           key-file-inspection behavior under a name that doesn't
#           collide with it.
#
# note    : No passphrase involved -- this only ever reads a key file's
#           public packet headers (--import-options show-only never
#           touches the keyring or requires unlocking anything, whether
#           the file is a public or private key).

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
  $SCRIPT_NAME -f "<file>" [options]

Required:
  -f  file        path to the key file to inspect (armored or binary,
                   public or private -- never imported, never unlocked)

Optional:
  -q  quiet       suppress the human-readable report (errors still print)
  -h  help

This inspects a KEY file (something you'd hand to
werkstatt.gpg.import.public.key.sh / .private.key.sh). If you have an
ENCRYPTED MESSAGE instead and want to know which key(s) can decrypt it,
use werkstatt.gpg.fingerprint.file.sh -- different operation, different
kind of input file.

Recommended Run Command:
  $SCRIPT_NAME -f "\$\$FILE_ABS_PATH\$\$" -q
USAGE
}

FILE=""
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':f:qh' opt; do
  case "$opt" in
    f) FILE="$(mfte_unquote "$OPTARG")" ;;
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

if [[ -z "$FILE" ]]; then
  log_system ERROR "missing required -f"
  echo "ERROR: -f file is required." >&2
  usage
  exit 2
fi

if [[ ! -f "$FILE" || ! -r "$FILE" ]]; then
  log_system ERROR "file not found or unreadable: ${FILE}"
  echo "ERROR: file not found or unreadable: ${FILE}" >&2
  exit 1
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start file=${FILE}"

if ! SHOW_OUTPUT="$(mfte_gpg_run --batch --with-colons --import-options show-only --import "$FILE" 2>&1)"; then
  log_system ERROR "show-only inspection failed file=${FILE}"
  echo "ERROR: could not read key material from ${FILE}. See ${SYSTEM_LOG_FILE} for details." >&2
  echo "Note: this script inspects KEY files. If ${FILE} is an ENCRYPTED MESSAGE, use" >&2
  echo "werkstatt.gpg.fingerprint.file.sh instead -- different operation, different input." >&2
  log_system DEBUG "gpg output: ${SHOW_OUTPUT}"
  exit 1
fi

PRIMARY_FP="$(printf '%s\n' "$SHOW_OUTPUT" | awk -F: '
  $1=="pub"||$1=="sec"{grab=1; next}
  $1=="sub"||$1=="ssb"{grab=0; next}
  $1=="fpr" && grab{print $10; grab=0}
' | head -1)"

if [[ -z "$PRIMARY_FP" ]]; then
  log_system ERROR "no key found in file=${FILE}"
  echo "ERROR: ${FILE} does not appear to contain OpenPGP key material." >&2
  exit 1
fi

UID_LIST="$(printf '%s\n' "$SHOW_OUTPUT" | awk -F: '$1=="uid"{print $10}')"
SUBKEY_COUNT="$(printf '%s\n' "$SHOW_OUTPUT" | awk -F: '$1=="sub"||$1=="ssb"{c++} END{print c+0}')"

log_system INFO "complete file=${FILE} fingerprint=${PRIMARY_FP} subkeys=${SUBKEY_COUNT}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG key file inspection
  file              : $FILE
  fingerprint       : $PRIMARY_FP
  uid(s)            :
$(printf '%s\n' "$UID_LIST" | sed 's/^/                      /')
  subkeys           : $SUBKEY_COUNT
REPORT
fi

exit 0
