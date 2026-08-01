#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.vault.decrypt.file.sh
# purpose : Decrypt a file using a private key held by the mftgpg service
#           account, with the passphrase fetched from Vault fresh on every
#           run -- the Vault-aware sibling of werkstatt.gpg.decrypt.
#           file.sh, kept as its own script rather than a flag on that one
#           so the plain file-based path never has a Vault dependency
#           forced onto it.
#
# mechanism: The passphrase goes from Vault to gpg via --passphrase-fd and
#           process substitution -- it is never written to disk at any
#           point, never a CLI argument to gpg or to this script, and never
#           echoed or logged. Unlike werkstatt.gpg.vault.import.passphrase.
#           sh, nothing is filed locally; this script re-fetches from Vault
#           every single run. Trade-off, stated plainly: this decrypt now
#           depends on Vault being reachable and unsealed at the moment of
#           the run -- a local passphrase file has no such dependency. If
#           that trade-off is wrong for a given host, use
#           werkstatt.gpg.vault.import.passphrase.sh once to file the
#           passphrase locally, then use the plain
#           werkstatt.gpg.decrypt.file.sh from then on.
#
# fd note : Depends on a file descriptor opened by process substitution
#           surviving mfte_gpg_run's internal `runuser -u ${MFTE_GPG_USER}`
#           identity switch. See mfte.gpg.vault.sh's header for how this
#           was verified (2026-07-27, ctm-mfte-hub-03) -- re-verify on any
#           host where MFTE_GPG_USER's account type or the runuser/PAM
#           build differs.

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

Env (required):
  VAULT_ADDR
  VAULT_TOKEN                 or:
  VAULT_ROLE_ID / VAULT_SECRET_ID

The passphrase is fetched from Vault fresh on every run and handed to gpg
via --passphrase-fd + process substitution -- never written to disk,
never a flag on this script or on gpg, never echoed or logged. This
script has no local passphrase file dependency at all; it also has no
functioning fallback if Vault is unreachable or sealed at run time --
that's the trade-off for never materializing the passphrase locally. See
the header comment in this file for the alternative if that's wrong for a
given host.

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
log_system INFO "version=${SCRIPT_VERSION} argv[$#]: ${ARGV_DUMP}"

while getopts ':f:o:k:qVh' opt; do
  case "$opt" in
    f) FILE="$(mfte_unquote "$OPTARG")" ;;
    o) OUTPUT="$(mfte_unquote "$OPTARG")" ;;
    k) KEY_FP="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
    q) QUIET="true" ;;
    V) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
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
  echo "Generate a key first (werkstatt.gpg.generate.key.sh) or pass -k explicitly." >&2
  exit 1
fi

VAULT_PATH="$(mfte_gpg_vault_passphrase_path "$KEY_FP")"
log_system INFO "start file=${FILE} key=${KEY_FP} vault_path=${VAULT_PATH}"

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

# Process substitution: the passphrase is read by gpg directly off fd 3,
# never written to disk, never this script's (or gpg's) own CLI argument.
if ! DEC_OUTPUT="$(mfte_gpg_run --batch --yes --pinentry-mode loopback --passphrase-fd 3 --output "$OUTPUT" --decrypt "$FILE" 3< <(mfte_gpg_vault_get_passphrase "$KEY_FP") 2>&1)"; then
  log_system ERROR "decryption failed file=${FILE} key=${KEY_FP} vault_path=${VAULT_PATH}"
  echo "ERROR: decryption failed. See ${SYSTEM_LOG_FILE} for details." >&2
  echo "If no passphrase exists yet at ${VAULT_PATH}, run werkstatt.gpg.vault.export.passphrase.sh first." >&2
  log_system DEBUG "gpg output: ${DEC_OUTPUT}"
  exit 1
fi

CHECKSUM=""
if [[ -f "$OUTPUT" ]]; then
  CHECKSUM="$(sha256sum "$OUTPUT" 2>/dev/null | awk '{print $1}')"
  [[ -z "$CHECKSUM" ]] && CHECKSUM="$(shasum -a 256 "$OUTPUT" 2>/dev/null | awk '{print $1}')"
fi

log_system INFO "complete file=${FILE} key=${KEY_FP} vault_path=${VAULT_PATH} output=${OUTPUT} sha256=${CHECKSUM}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG decryption complete (passphrase source: Vault)
  input             : $FILE
  key fingerprint   : $KEY_FP
  vault path        : $VAULT_PATH
  output            : $OUTPUT
  output sha256     : $CHECKSUM
REPORT
fi

exit 0
