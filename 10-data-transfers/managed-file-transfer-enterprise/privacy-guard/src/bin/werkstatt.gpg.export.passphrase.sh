#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.export.passphrase.sh
# purpose : Copy a key's passphrase file out to a chosen location -- e.g.
#           staging it for werkstatt.gpg.import.private.key.sh -P on
#           another host.
#
# origin  : Not one of the original nine -- split out as its own script
#           rather than folded into werkstatt.gpg.export.key.sh, on
#           purpose. werkstatt.gpg.export.key.sh -s -W CAN bundle a
#           passphrase alongside a key export, but that's an explicit
#           opt-in specifically because bundling them undoes the point of
#           keeping the passphrase on a separate channel. Giving the
#           passphrase its own script name (rather than another flag
#           combination) keeps "move just the passphrase, deliberately,
#           by itself" as the easy, ordinary path, and "bundle it with
#           the key" as the harder, explicit exception -- not the other
#           way around.
#
# note    : No gpg call happens here at all -- this only validates the
#           source passphrase file is properly locked down (mode 600,
#           owned by mftgpg) and copies it. The passphrase value itself
#           is never read into a shell variable, echoed, or logged; only
#           file paths appear in any log line this script writes.

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
  -k  key         fingerprint whose passphrase to export, default:
                   fingerprint in default-key.json
  -o  output      output path, default: \$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase
  -q  quiet
  -h  help

Refuses to run if the source passphrase file isn't exactly mode 600,
owned by \$MFTE_GPG_USER -- same lockdown check every other script in
this family uses before touching a passphrase file. The output copy is
written at mode 600 too, but that's this script's own doing, not
inherited automatically -- if you move it again afterward, set
permissions explicitly at the destination.

This is deliberately a separate command from werkstatt.gpg.export.key.sh
-- see the header comment in this file for why.

Recommended Run Command:
  $SCRIPT_NAME -q
  $SCRIPT_NAME -k "<fingerprint>" -o "/secure/staging/key.passphrase" -q
USAGE
}

KEY_FP=""
OUTPUT=""
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:o:qh' opt; do
  case "$opt" in
    k) KEY_FP="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
    o) OUTPUT="$(mfte_unquote "$OPTARG")" ;;
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
  exit 1
fi

SOURCE_FILE="$(mfte_gpg_passphrase_file "$KEY_FP")"
if ! mfte_gpg_require_locked_down "$SOURCE_FILE" 600; then
  log_system ERROR "passphrase file failed lockdown check for key=${KEY_FP}"
  echo "ERROR: passphrase file for key ${KEY_FP} is missing or not properly locked down -- refusing to export it." >&2
  exit 1
fi

log_system INFO "start key=${KEY_FP}"

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="${MFTE_GPG_EXCHANGE_DIR}/${KEY_FP}.passphrase"
fi

# Copied as MFTE_GPG_USER (mfte_gpg_copy_passphrase_as_user), not as
# whatever identity is running this script (root, in production) -- a
# plain `cp` here would leave the output owned by root, inconsistent
# with every other passphrase file mftgpg owns in this framework.
if ! mfte_gpg_copy_passphrase_as_user "$SOURCE_FILE" "$OUTPUT"; then
  log_system ERROR "copy failed key=${KEY_FP} source=${SOURCE_FILE} output=${OUTPUT}"
  echo "ERROR: failed to copy passphrase file to ${OUTPUT}." >&2
  exit 1
fi

log_system INFO "complete key=${KEY_FP} output=${OUTPUT}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG passphrase export complete
  fingerprint       : $KEY_FP
  output            : $OUTPUT (mode 600 -- handle as sensitive material)
REPORT
fi

exit 0
