#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.delete.key.sh
# purpose : Remove a key (public, secret, or both) from the mftgpg
#           keyring.
#
# origin  : Hardened, production-like-demo version of a training script.
#           No passphrase involved -- gpg's --delete-secret-keys and
#           --delete-keys don't require one in batch mode (verified
#           against this gpg version).
#
# safety  : This is the one operation in this script family that is not
#           safely re-runnable -- deleting a key you don't have a backup
#           of is permanent. -k is required with no default-key fallback
#           (never guess what to delete), and the script defaults to a
#           DRY RUN that reports what it would do without touching
#           anything; pass -y to actually perform the deletion. This
#           matters specifically because these scripts are meant to be
#           invoked from Control-M Run Commands, where an argument-
#           parsing mistake upstream (see mfte.sh's argv-quoting
#           discussion) could otherwise turn "check a fingerprint" into
#           "delete a key" with no human in the loop.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"

# shellcheck source=/dev/null
source "${MFTE_LIB_DIR}/bash/mfte.sh"
# shellcheck source=/dev/null
source "${MFTE_LIB_DIR}/bash/mfte.gpg.sh"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME -k "<fingerprint>" [options]

Required:
  -k  key         full fingerprint to delete (no default-key fallback --
                   this operation is never allowed to guess)

Optional:
  -m  mode        public | secret | both, default: public
                   public : delete only the public key (fails if a secret
                            key for it is still present -- delete that
                            first with -m secret or -m both)
                   secret : delete only the secret key (keeps the public
                            key, e.g. to still verify old signatures)
                   both   : delete secret key then public key
  -y  confirm     actually perform the deletion. Without -y, this script
                   only reports what it WOULD delete (exit code 3) and
                   changes nothing.
  -q  quiet
  -h  help

Deleting a secret key also removes its passphrase file under
\$MFTE_GPG_PASSPHRASE_DIR, and clears default-key.json if it pointed at
the deleted key.

Recommended Run Command (dry run first, then confirm):
  $SCRIPT_NAME -k "<fingerprint>" -m both -q
  $SCRIPT_NAME -k "<fingerprint>" -m both -y -q
USAGE
}

KEY_FP=""
MODE="public"
CONFIRM="false"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:m:yqh' opt; do
  case "$opt" in
    k) KEY_FP="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
    m) MODE="$(mfte_unquote "$OPTARG")" ;;
    y) CONFIRM="true" ;;
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

if [[ -z "$KEY_FP" ]]; then
  log_system ERROR "missing required -k"
  echo "ERROR: -k fingerprint is required -- this operation never guesses a default key." >&2
  usage
  exit 2
fi

case "$MODE" in
  public|secret|both) ;;
  *)
    log_system ERROR "invalid -m mode: ${MODE}"
    echo "ERROR: -m must be public, secret, or both, got: ${MODE}" >&2
    exit 2
    ;;
esac

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

HAS_SECRET="false"
mfte_gpg_run --batch --with-colons --list-secret-keys "$KEY_FP" >/dev/null 2>&1 && HAS_SECRET="true"
HAS_PUBLIC="false"
mfte_gpg_run --batch --with-colons --list-keys "$KEY_FP" >/dev/null 2>&1 && HAS_PUBLIC="true"

if [[ "$HAS_PUBLIC" != "true" && "$HAS_SECRET" != "true" ]]; then
  log_system ERROR "key not found: ${KEY_FP}"
  echo "ERROR: no key matching ${KEY_FP} found in ${MFTE_GPG_HOME}." >&2
  exit 1
fi

DEFAULT_FP="$(mfte_gpg_default_fingerprint)"
WOULD_CLEAR_DEFAULT="false"
[[ -n "$DEFAULT_FP" && "$DEFAULT_FP" == "$KEY_FP" ]] && WOULD_CLEAR_DEFAULT="true"

log_system INFO "start key=${KEY_FP} mode=${MODE} confirm=${CONFIRM} has_public=${HAS_PUBLIC} has_secret=${HAS_SECRET}"

if [[ "$CONFIRM" != "true" ]]; then
  log_system INFO "dry run only -- no -y given, nothing deleted"
  if [[ "$QUIET" != "true" ]]; then
    cat <<REPORT
GPG key deletion -- DRY RUN (pass -y to actually delete)
  fingerprint       : $KEY_FP
  mode              : $MODE
  public present    : $HAS_PUBLIC
  secret present     : $HAS_SECRET
  would clear default: $WOULD_CLEAR_DEFAULT
REPORT
  fi
  exit 3
fi

if [[ "$MODE" == "secret" || "$MODE" == "both" ]]; then
  if [[ "$HAS_SECRET" != "true" ]]; then
    log_system ERROR "mode=${MODE} requested but no secret key present for ${KEY_FP}"
    echo "ERROR: -m ${MODE} requested but no secret key is present for ${KEY_FP}." >&2
    exit 1
  fi
  if ! DEL_OUTPUT="$(mfte_gpg_run --batch --yes --delete-secret-keys "$KEY_FP" 2>&1)"; then
    log_system ERROR "secret key deletion failed key=${KEY_FP}"
    echo "ERROR: secret key deletion failed. See ${SYSTEM_LOG_FILE} for details." >&2
    log_system DEBUG "gpg output: ${DEL_OUTPUT}"
    exit 1
  fi
  runuser -u "${MFTE_GPG_USER}" -- rm -f "$(mfte_gpg_passphrase_file "$KEY_FP")"
fi

if [[ "$MODE" == "public" || "$MODE" == "both" ]]; then
  if ! DEL_OUTPUT="$(mfte_gpg_run --batch --yes --delete-keys "$KEY_FP" 2>&1)"; then
    log_system ERROR "public key deletion failed key=${KEY_FP}"
    echo "ERROR: public key deletion failed. See ${SYSTEM_LOG_FILE} for details." >&2
    log_system DEBUG "gpg output: ${DEL_OUTPUT}"
    exit 1
  fi
fi

if [[ "$WOULD_CLEAR_DEFAULT" == "true" ]]; then
  rm -f "${MFTE_GPG_DEFAULT_KEY_FILE}"
  log_system WARN "cleared default-key.json -- it pointed at the just-deleted key ${KEY_FP}"
fi

log_system INFO "complete key=${KEY_FP} mode=${MODE} default_cleared=${WOULD_CLEAR_DEFAULT}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG key deletion complete
  fingerprint       : $KEY_FP
  mode              : $MODE
  default cleared   : $WOULD_CLEAR_DEFAULT
REPORT
fi

exit 0
