#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.import.public.key.sh
# purpose : Import a partner/recipient's PUBLIC key into the mftgpg
#           keyring, so files can later be encrypted to them.
#
# origin  : Hardened, production-like-demo version of a training script.
#           No passphrase is involved in a public key import -- there was
#           never anything to protect here beyond normal file permissions
#           on the keyring itself (mftgpg-owned, checked by
#           mfte_gpg_preflight below).
#
# trust   : Importing a key does NOT mean this framework trusts it for
#           encryption yet -- werkstatt.gpg.encrypt.file.sh's --trust-model
#           always only matters because the only keys ever imported here
#           are ones whose fingerprint was verified out of band first (see
#           werkstatt.gpg.fingerprint.file.sh). Verify before you import.

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
  $SCRIPT_NAME [-f "<file>"] [options]

Optional:
  -f  file        path to the public key file to import (armored or binary).
                   Default: the one file matching *.public.* in
                   \$MFTE_GPG_EXCHANGE_DIR, if exactly one exists -- error if
                   zero or more than one, since guessing which key to import
                   is not a safe default.
  -q  quiet
  -h  help

Verify the fingerprint of the key you're about to import (out of band,
against what the partner actually published) before running this --
werkstatt.gpg.fingerprint.file.sh can compute the fingerprint of a local file.

\$MFTE_GPG_EXCHANGE_DIR is the conventional place to stage inbound key
files before importing them (it's also where werkstatt.gpg.export.key.sh
writes its output) -- -f accepts any path if you'd rather point elsewhere.

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
  FILE="$(mfte_gpg_find_single_file "${MFTE_GPG_EXCHANGE_DIR}" '*.public.*')" || {
    log_system ERROR "no -f given and no single unambiguous *.public.* match in ${MFTE_GPG_EXCHANGE_DIR}"
    echo "ERROR: -f not given, and \$MFTE_GPG_EXCHANGE_DIR (${MFTE_GPG_EXCHANGE_DIR}) does not contain exactly one *.public.* file to default to." >&2
    usage
    exit 2
  }
  log_system INFO "defaulted -f to ${FILE} (single *.public.* match in MFTE_GPG_EXCHANGE_DIR)"
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

if ! IMPORT_OUTPUT="$(mfte_gpg_import_key "$FILE" public 2>&1)"; then
  log_system ERROR "public key import failed file=${FILE}"
  echo "ERROR: import failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

FINGERPRINT="$(mfte_gpg_import_fingerprint "$IMPORT_OUTPUT")"
if [[ -z "$FINGERPRINT" ]]; then
  log_system ERROR "import produced no IMPORT_OK status file=${FILE}"
  echo "ERROR: gpg did not report an imported key (already present with no change, or not a valid public key?)." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

UID_STR="$(mfte_gpg_uid_for_fingerprint "$FINGERPRINT" public)"

log_system INFO "complete file=${FILE} fingerprint=${FINGERPRINT} uid=\"${UID_STR}\""

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG public key import complete
  input             : $FILE
  fingerprint       : $FINGERPRINT
  uid               : $UID_STR
REPORT
fi

exit 0
