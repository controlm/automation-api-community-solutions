#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.vault.export.passphrase.sh
# purpose : Push a key's already-filed local passphrase file into Vault,
#           at the path werkstatt.gpg.vault.decrypt.file.sh /
#           werkstatt.gpg.vault.import.passphrase.sh expect.
#
# origin  : Vault-backed sibling of werkstatt.gpg.export.passphrase.sh --
#           same "own script name for the passphrase move, not another flag
#           on an existing script" reasoning as that file's header. The
#           local passphrase file is the source of truth here (created by
#           werkstatt.gpg.generate.key.sh); this script copies it TO Vault,
#           it does not remove or alter the local file.
#
# note    : No gpg call happens here. The passphrase value itself is never
#           read into a shell variable -- vault's own `key=@file` syntax
#           reads the local file directly, so it never appears in this
#           script's argv, stdout, or any log line it writes.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"

# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.sh" >&2
  exit 1
fi
# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.gpg.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.gpg.sh" >&2
  exit 1
fi
# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.gpg.vault.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.gpg.vault.sh" >&2
  exit 1
fi

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Optional:
  -k  key         fingerprint whose passphrase to push, default:
                   fingerprint in default-key.json
  -q  quiet
  -h  help

Env (required):
  VAULT_ADDR
  VAULT_TOKEN                 or:
  VAULT_ROLE_ID / VAULT_SECRET_ID

Refuses to run if the local passphrase file isn't exactly mode 600, owned
by \$MFTE_GPG_USER -- same lockdown check every other script in this
family uses. Refuses to run if Vault is unreachable or sealed.

This is deliberately a separate command from
werkstatt.gpg.export.passphrase.sh -- see that file's header, and this
one's, for why.

Recommended Run Command:
  $SCRIPT_NAME -q
  $SCRIPT_NAME -k "<fingerprint>" -q
USAGE
}

KEY_FP=""
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:qh' opt; do
  case "$opt" in
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

if ! mfte_gpg_preflight; then
  log_system ERROR "gpg preflight failed"
  exit 1
fi
if ! mfte_gpg_vault_preflight; then
  log_system ERROR "vault preflight failed"
  exit 1
fi
if ! mfte_gpg_vault_login_if_needed; then
  log_system ERROR "vault auth failed"
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
  echo "ERROR: local passphrase file for key ${KEY_FP} is missing or not properly locked down -- refusing to push it to Vault." >&2
  exit 1
fi

VAULT_PATH="$(mfte_gpg_vault_passphrase_path "$KEY_FP")"
log_system INFO "start key=${KEY_FP} vault_path=${VAULT_PATH}"

if ! mfte_gpg_vault_put_passphrase_from_file "$KEY_FP" "$SOURCE_FILE"; then
  log_system ERROR "vault write failed key=${KEY_FP} vault_path=${VAULT_PATH}"
  echo "ERROR: failed to write passphrase to Vault at ${VAULT_PATH}. See ${SYSTEM_LOG_FILE} for details." >&2
  exit 1
fi

log_system INFO "complete key=${KEY_FP} vault_path=${VAULT_PATH}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG passphrase export to Vault complete
  fingerprint       : $KEY_FP
  vault path        : $VAULT_PATH (key: passphrase)
  local source file  : $SOURCE_FILE (unchanged)
REPORT
fi

exit 0
