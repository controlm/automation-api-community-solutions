#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.decrypt.file.sh
# purpose : Decrypt a file using a private key held by the mftgpg
#           service account.
#
# origin  : Hardened, production-like-demo version of a training script
#           that took a passphrase as a CLI argument and printed it in
#           cleartext via display_project_details() -- deliberately, so a
#           student could see exactly what value was driving the decrypt.
#           That was reasonable for its original purpose; it is not
#           reasonable for a script invoked unattended from a Control-M
#           Run Command, where the "terminal" a passphrase would print to
#           is a job log that persists indefinitely. This version resolves
#           the passphrase only from a locked-down file (mode 600, owned
#           by mftgpg) via --passphrase-file, and never accepts it as a
#           flag or writes it anywhere.
#
# default : If -k isn't given, falls back to the fingerprint recorded in
#           default-key.json (written by werkstatt.gpg.generate.key.sh /
#           werkstatt.gpg.export.key.sh) -- same "default key" concept the
#           original dsse.gpg.info.json served, just without a passphrase
#           field in it.

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
  -f  file        path to the encrypted file to decrypt

Optional:
  -o  output      output path, default: derived from -f (extension
                   stripped) under \$MFTE_GPG_OUTPUT_DIR, with a numeric
                   suffix added if that name already exists
  -k  key         fingerprint of the private key to decrypt with,
                   default: fingerprint in default-key.json
  -q  quiet
  -h  help

The passphrase is never a flag on this script. It is read directly from a
600-permission file owned by \$MFTE_GPG_USER (see
\$MFTE_GPG_PASSPHRASE_DIR/<fingerprint>.passphrase) via gpg's own
--passphrase-file, and is never echoed to stdout or written to a log line
by this script.

Recommended Run Command:
  $SCRIPT_NAME -f "\$\$FILE_ABS_PATH\$\$" -q
USAGE
}

FILE=""
OUTPUT=""
KEY_FP=""
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':f:o:k:qh' opt; do
  case "$opt" in
    f) FILE="$(mfte_unquote "$OPTARG")" ;;
    o) OUTPUT="$(mfte_unquote "$OPTARG")" ;;
    k) KEY_FP="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
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

if [[ -z "$KEY_FP" ]]; then
  KEY_FP="$(mfte_gpg_default_fingerprint)"
fi
if [[ -z "$KEY_FP" ]]; then
  log_system ERROR "no -k key given and no default-key.json found"
  echo "ERROR: no -k key given, and no default key is recorded in ${MFTE_GPG_META_DIR}/default-key.json." >&2
  echo "Generate a key first (werkstatt.gpg.generate.key.sh) or pass -k explicitly." >&2
  exit 1
fi

PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$KEY_FP")"
if ! mfte_gpg_require_locked_down "$PASSPHRASE_FILE" 600; then
  log_system ERROR "passphrase file failed lockdown check for key=${KEY_FP}"
  echo "ERROR: passphrase file for key ${KEY_FP} is missing or not properly locked down." >&2
  exit 1
fi

log_system INFO "start file=${FILE} key=${KEY_FP}"

if [[ -z "$OUTPUT" ]]; then
  mkdir -p "${MFTE_GPG_OUTPUT_DIR}"
  BASE_NAME="$(basename "$FILE")"
  case "$BASE_NAME" in
    *.asc|*.gpg|*.pgp) BASE_NAME="${BASE_NAME%.*}" ;;
    *) BASE_NAME="${BASE_NAME}.decrypted" ;;
  esac
  OUTPUT="$(mfte_increment_filename "${MFTE_GPG_OUTPUT_DIR}/${BASE_NAME}")"
else
  mkdir -p "$(dirname "$OUTPUT")"
fi

if ! DEC_OUTPUT="$(mfte_gpg_run --batch --yes --pinentry-mode loopback --passphrase-file "$PASSPHRASE_FILE" --output "$OUTPUT" --decrypt "$FILE" 2>&1)"; then
  log_system ERROR "decryption failed file=${FILE} key=${KEY_FP}"
  echo "ERROR: decryption failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${DEC_OUTPUT}"
  exit 1
fi

CHECKSUM=""
if [[ -f "$OUTPUT" ]]; then
  CHECKSUM="$(sha256sum "$OUTPUT" 2>/dev/null | awk '{print $1}')"
  [[ -z "$CHECKSUM" ]] && CHECKSUM="$(shasum -a 256 "$OUTPUT" 2>/dev/null | awk '{print $1}')"
fi

log_system INFO "complete file=${FILE} key=${KEY_FP} output=${OUTPUT} sha256=${CHECKSUM}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG decryption complete
  input             : $FILE
  key fingerprint   : $KEY_FP
  output            : $OUTPUT
  output sha256     : $CHECKSUM
REPORT
fi

exit 0
