#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.vault.status.sh
# purpose : Diagnostic-only check of the Vault integration: reachability,
#           seal status, auth, and whether a passphrase actually exists at
#           the expected path for a given key -- WITHOUT ever printing the
#           passphrase value itself, and without performing any gpg
#           operation.
#
# use     : Run this before werkstatt.gpg.vault.decrypt.file.sh in a new
#           environment, or whenever a decrypt fails and it's unclear
#           whether the problem is Vault-side or gpg-side.

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
  -k  key         fingerprint to check for a Vault-stored passphrase,
                   default: fingerprint in default-key.json. If no
                   fingerprint resolves at all, this script still reports
                   reachability/seal/auth status and skips the
                   secret-presence check.
  -h  help

Env:
  VAULT_ADDR                        required
  VAULT_TOKEN                       or:
  VAULT_ROLE_ID / VAULT_SECRET_ID   optional -- if neither is set, this
                                      script reports reachability/seal
                                      status only and skips the auth and
                                      secret-presence checks (clearly
                                      marked as skipped, not silently
                                      omitted).

Never prints a passphrase value -- only whether one is present at the
expected path.

Recommended Run Command:
  $SCRIPT_NAME
  $SCRIPT_NAME -k "<fingerprint>"
USAGE
}

KEY_FP=""

while getopts ':k:h' opt; do
  case "$opt" in
    k) KEY_FP="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
    h) usage; exit 0 ;;
    :) echo "Missing value for -$OPTARG" >&2; usage; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done

shift $((OPTIND - 1))
if ! mfte_check_no_leftover_args "$@"; then
  echo "ERROR: unexpected extra arguments." >&2
  exit 2
fi

echo "=== Vault reachability / seal status ==="
if mfte_gpg_vault_preflight; then
  echo "  OK -- reachable at ${VAULT_ADDR}, unsealed"
  REACHABLE="true"
else
  echo "  FAILED -- see error above"
  REACHABLE="false"
fi

echo
echo "=== Vault auth ==="
if [[ "$REACHABLE" != "true" ]]; then
  echo "  SKIPPED -- Vault not reachable"
elif [[ -z "${VAULT_TOKEN:-}" && ( -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ) ]]; then
  echo "  SKIPPED -- no VAULT_TOKEN, and VAULT_ROLE_ID/VAULT_SECRET_ID not both set"
  AUTHED="false"
elif mfte_gpg_vault_login_if_needed; then
  echo "  OK -- authenticated (token policies not shown here; use 'vault token lookup' if needed)"
  AUTHED="true"
else
  echo "  FAILED -- see error above"
  AUTHED="false"
fi

echo
echo "=== Passphrase presence ==="
if [[ -z "$KEY_FP" ]]; then
  KEY_FP="$(mfte_gpg_default_fingerprint)"
fi
if [[ -z "$KEY_FP" ]]; then
  echo "  SKIPPED -- no -k given and no default-key.json found"
elif [[ "${AUTHED:-false}" != "true" ]]; then
  echo "  SKIPPED -- not authenticated to Vault"
else
  VAULT_PATH="$(mfte_gpg_vault_passphrase_path "$KEY_FP")"
  if mfte_gpg_vault_get_passphrase "$KEY_FP" >/dev/null 2>&1 && [[ -n "$(mfte_gpg_vault_get_passphrase "$KEY_FP")" ]]; then
    echo "  OK -- a passphrase is present at ${VAULT_PATH} for fingerprint ${KEY_FP} (value not shown)"
  else
    echo "  NOT FOUND -- no passphrase at ${VAULT_PATH} for fingerprint ${KEY_FP} (or token lacks read permission there)"
  fi
fi

exit 0
