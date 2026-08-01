#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.vault.import.passphrase.sh
# purpose : Pull a key's passphrase from Vault, prove it actually unlocks
#           that key, and file it locally at this framework's standard
#           fingerprint-keyed location -- the Vault-sourced counterpart to
#           werkstatt.gpg.import.passphrase.sh (which pulls from a staged
#           file instead).
#
# origin  : Same "own script name, not another flag" reasoning as every
#           other passphrase-move script in this family. Use this when you
#           want a Vault-stored passphrase materialized locally (e.g. for
#           a host that will keep using the plain werkstatt.gpg.decrypt.
#           file.sh rather than the Vault-aware variant, or as a one-time
#           migration step). If you'd rather never materialize the
#           passphrase locally at all, use
#           werkstatt.gpg.vault.decrypt.file.sh instead, which fetches
#           just-in-time per decrypt and never files anything.
#
# safety  : Refuses to file a passphrase for a fingerprint whose SECRET key
#           isn't already present in this keyring -- same guard
#           werkstatt.gpg.import.passphrase.sh uses. Before filing anything
#           permanently, this also proves the passphrase actually unlocks
#           that key via the same non-destructive encrypt/decrypt round
#           trip werkstatt.gpg.import.passphrase.sh uses: a candidate
#           passphrase is written to a TEMPORARY location first, validated,
#           and only moved into its permanent fingerprint-keyed name if
#           validation succeeds. Nothing permanent is written on a failed
#           validation.

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
  $SCRIPT_NAME -k "<fingerprint>" [options]

Required:
  -k  key         fingerprint (or uid/email substring resolving to exactly
                   one SECRET key already in this keyring) whose passphrase
                   to pull from Vault -- no default-key.json fallback,
                   deliberately, same reasoning as
                   werkstatt.gpg.import.passphrase.sh's -k.

Optional:
  -q  quiet
  -h  help

Env (required):
  VAULT_ADDR
  VAULT_TOKEN                 or:
  VAULT_ROLE_ID / VAULT_SECRET_ID

Refuses to proceed if the secret key for -k isn't already in this keyring,
if Vault is unreachable/sealed, or if no passphrase is found at the
expected Vault path. Refuses to file the passphrase if it doesn't actually
unlock that key -- proven with the same non-destructive encrypt/decrypt
round trip werkstatt.gpg.import.passphrase.sh uses, against a TEMPORARY
file first. Nothing permanent is written to \$MFTE_GPG_PASSPHRASE_DIR
unless that round trip succeeds.

Recommended Run Command:
  $SCRIPT_NAME -k "<fingerprint>" -q
USAGE
}

KEY=""
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:qh' opt; do
  case "$opt" in
    k) KEY="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
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

if [[ -z "$KEY" ]]; then
  log_system ERROR "missing required -k"
  echo "ERROR: -k key is required." >&2
  usage
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

log_system INFO "start key=${KEY}"

FP="$(mfte_gpg_lookup_fingerprint "$KEY" secret)"
if [[ -z "$FP" ]]; then
  log_system ERROR "no secret key resolved for -k: ${KEY}"
  echo "ERROR: \"${KEY}\" did not resolve to exactly one SECRET key in ${MFTE_GPG_HOME}." >&2
  echo "Import the private key first (werkstatt.gpg.import.private.key.sh) before pulling a passphrase for it." >&2
  exit 1
fi

VAULT_PATH="$(mfte_gpg_vault_passphrase_path "$FP")"
UID_STR="$(mfte_gpg_uid_for_fingerprint "$FP" secret)"
TARGET="$(mfte_gpg_passphrase_file "$FP")"

# Fetch into a TEMPORARY fingerprint-keyed location first -- nothing
# permanent is written until the round-trip validation below succeeds.
# The passphrase value goes straight from mfte_gpg_vault_get_passphrase's
# stdout into mfte_gpg_write_passphrase_file's function argument -- never
# assigned to a variable this script itself echoes or logs.
TMP_IDENT="pending-vault-$$-$(date -u +%Y%m%dT%H%M%SZ)"
PENDING_FILE="$(mfte_gpg_passphrase_file "$TMP_IDENT")"

CLEANUP_PENDING="$PENDING_FILE"
cleanup() {
  if [[ -n "${CLEANUP_PENDING:-}" ]]; then
    runuser -u "${MFTE_GPG_USER}" -- rm -f "$CLEANUP_PENDING" 2>/dev/null
  fi
}
trap cleanup EXIT

CANDIDATE="$(mfte_gpg_vault_get_passphrase "$FP")"
if [[ -z "$CANDIDATE" ]]; then
  log_system ERROR "no passphrase found in vault for fp=${FP} path=${VAULT_PATH}"
  echo "ERROR: no passphrase found at Vault path ${VAULT_PATH} (or token lacks read permission there)." >&2
  exit 1
fi
mfte_gpg_write_passphrase_file "$TMP_IDENT" "$CANDIDATE"
unset CANDIDATE

# Non-destructive proof the passphrase actually unlocks this key -- same
# encrypt/decrypt round trip werkstatt.gpg.import.passphrase.sh uses.
TEST_PLAINTEXT="mfte-vault-passphrase-validation-$(date -u '+%Y%m%dT%H%M%SZ')-$$"

ENC_OUT="$(printf '%s' "$TEST_PLAINTEXT" | mfte_gpg_run --batch --yes --trust-model always --recipient "$FP" --armor --encrypt 2>/dev/null)"
if [[ -z "$ENC_OUT" ]]; then
  log_system ERROR "validation encrypt step failed fp=${FP} -- key may not be encrypt-capable"
  echo "ERROR: could not encrypt a test message to ${FP} -- cannot validate the Vault passphrase this way." >&2
  echo "Check the key has an encrypt-capable subkey (gpg --list-keys --with-colons ${FP} -- look for a 'sub' line ending in 'e')." >&2
  exit 1
fi

DEC_ERR="$(printf '%s' "$ENC_OUT" | mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$PENDING_FILE" --decrypt 2>&1 >/dev/null)"
DEC_STATUS=$?

if [[ "$DEC_STATUS" -ne 0 ]]; then
  log_system ERROR "validation round trip failed fp=${FP} status=${DEC_STATUS} vault_path=${VAULT_PATH}"
  echo "ERROR: passphrase fetched from Vault (${VAULT_PATH}) does not unlock the secret key for ${FP} -- NOT filed." >&2
  echo "Check that MFTE_VAULT_MOUNT/MFTE_VAULT_GPG_PREFIX resolve to the right path, and that the stored value is current." >&2
  log_system DEBUG "gpg output: ${DEC_ERR}"
  exit 1
fi

OVERWRITTEN="false"
[[ -e "$TARGET" ]] && OVERWRITTEN="true"

if ! runuser -u "${MFTE_GPG_USER}" -- mv "$PENDING_FILE" "$TARGET"; then
  log_system ERROR "filing failed fp=${FP} target=${TARGET}"
  echo "ERROR: passphrase validated correctly but moving it into place at ${TARGET} failed." >&2
  exit 1
fi
CLEANUP_PENDING=""

log_system INFO "complete fp=${FP} vault_path=${VAULT_PATH} target=${TARGET} overwritten=${OVERWRITTEN}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG passphrase import from Vault complete
  fingerprint       : $FP
  uid               : $UID_STR
  vault path        : $VAULT_PATH
  validated         : true (encrypt/decrypt round trip against ${FP})
  filed             : $TARGET
  overwritten       : $OVERWRITTEN
REPORT
fi

exit 0
