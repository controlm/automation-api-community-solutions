#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.generate.key.sh
# purpose : Generate a new GPG key pair, held by the mftgpg service
#           account, for MFTE encrypt/decrypt/sign operations.
#
# origin  : This is a hardened, production-like-demo version of a
#           training script that intentionally printed every intermediate
#           value -- including the generated passphrase -- in cleartext,
#           so a student could see the whole mechanism. That was the right
#           design for its original purpose. This version keeps the same
#           operation and stays informative about what it's doing, but a
#           generated passphrase now goes straight into a locked-down file
#           (mode 600, owned by mftgpg) instead of stdout or a log line --
#           this script runs unattended against real key material now, not
#           in front of a student watching the terminal.
#
# structure: Builds a certify-only primary key with separate sign and
#           encrypt subkeys, rather than one single-purpose key. This is
#           the generally recommended OpenPGP structure (the primary/
#           identity key is used as little as possible; day-to-day sign
#           and encrypt operations use subkeys that can be rotated or
#           revoked independently) -- and it's also a functional
#           requirement here, not just a nicety: a --quick-generate-key
#           with usage "default" on this gpg version produces a sign+cert
#           key with NO encryption capability, which made
#           werkstatt.gpg.encrypt.file.sh fail outright ("Unusable public key")
#           until this was fixed to add an explicit encr subkey.

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
  $SCRIPT_NAME -u "<uid>" [options]

Required:
  -u  UID           Key identity, e.g. "MFTE Ops <mfte-ops@example.com>"

Optional:
  -t  key type      default: rsa4096
  -x  expire        default: 0 (never expires) -- gpg expiry syntax, e.g. 2y
  -P  passphrase file to reuse instead of generating a new one (must
      already exist, mode 600, owned by \$MFTE_GPG_USER)
  -N  do not update default-key.json with this key
  -q  quiet
  -h  help

On success, prints the new key's fingerprint and the path of the
passphrase file it was written to -- never the passphrase itself. The
passphrase is generated with openssl rand and written directly to a
600-permission file owned by \$MFTE_GPG_USER; it is not echoed to stdout,
not written to any log line, and not passed as a gpg CLI argument.

Recommended Run Command:
  $SCRIPT_NAME -u "MFTE Ops <mfte-ops@example.com>" -q
USAGE
}

UID_STR=""
KEY_TYPE="rsa4096"
EXPIRE="0"
REUSE_PASSPHRASE_FILE=""
SET_DEFAULT="true"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':u:t:x:P:Nqh' opt; do
  case "$opt" in
    u) UID_STR="$(mfte_unquote "$OPTARG")" ;;
    t) KEY_TYPE="$(mfte_unquote "$OPTARG")" ;;
    x) EXPIRE="$(mfte_unquote "$OPTARG")" ;;
    P) REUSE_PASSPHRASE_FILE="$(mfte_unquote "$OPTARG")" ;;
    N) SET_DEFAULT="false" ;;
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

if [[ -z "$UID_STR" ]]; then
  log_system ERROR "missing required -u UID"
  echo "ERROR: -u UID is required, e.g. -u \"MFTE Ops <mfte-ops@example.com>\"" >&2
  usage
  exit 2
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start uid=\"${UID_STR}\" type=${KEY_TYPE} expire=${EXPIRE}"

CLEANUP_TMP_PASSPHRASE=""
cleanup() {
  if [[ -n "$CLEANUP_TMP_PASSPHRASE" ]]; then
    runuser -u "${MFTE_GPG_USER}" -- rm -f "$CLEANUP_TMP_PASSPHRASE" 2>/dev/null
  fi
}
trap cleanup EXIT

if [[ -n "$REUSE_PASSPHRASE_FILE" ]]; then
  if ! mfte_gpg_require_locked_down "$REUSE_PASSPHRASE_FILE" 600; then
    log_system ERROR "supplied -P passphrase file failed lockdown check: ${REUSE_PASSPHRASE_FILE}"
    exit 1
  fi
  GEN_PASSPHRASE_FILE="$REUSE_PASSPHRASE_FILE"
else
  TMP_IDENT="pending-$$-$(date -u +%Y%m%dT%H%M%SZ)"
  GEN_PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$TMP_IDENT")"
  mfte_gpg_write_passphrase_file "$TMP_IDENT" "$(mfte_gpg_generate_passphrase)"
  CLEANUP_TMP_PASSPHRASE="$GEN_PASSPHRASE_FILE"
fi

# Primary key: certify-only. Day-to-day sign/encrypt capability lives on
# the two subkeys added below, not on this key.
GEN_OUTPUT="$(mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$GEN_PASSPHRASE_FILE" --status-fd 1 --quick-generate-key "$UID_STR" "$KEY_TYPE" cert "$EXPIRE" 2>&1)"
GEN_STATUS=$?

FINGERPRINT="$(printf '%s\n' "$GEN_OUTPUT" | awk '/\[GNUPG:\] KEY_CREATED/{print $NF}')"

if [[ $GEN_STATUS -ne 0 || -z "$FINGERPRINT" ]]; then
  log_system ERROR "primary key generation failed uid=\"${UID_STR}\" status=${GEN_STATUS}"
  echo "ERROR: key generation failed (gpg exit ${GEN_STATUS}). See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${GEN_OUTPUT}"
  exit 1
fi

# Sign subkey, then encrypt subkey. Both protected by the same passphrase
# file as the primary -- it's one secret identity, not separate secrets
# per subkey.
if ! SUB_OUTPUT="$(mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$GEN_PASSPHRASE_FILE" --quick-add-key "$FINGERPRINT" "$KEY_TYPE" sign "$EXPIRE" 2>&1)"; then
  log_system ERROR "sign subkey generation failed fingerprint=${FINGERPRINT}"
  echo "ERROR: sign subkey generation failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${SUB_OUTPUT}"
  exit 1
fi
if ! SUB_OUTPUT="$(mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$GEN_PASSPHRASE_FILE" --quick-add-key "$FINGERPRINT" "$KEY_TYPE" encr "$EXPIRE" 2>&1)"; then
  log_system ERROR "encrypt subkey generation failed fingerprint=${FINGERPRINT}"
  echo "ERROR: encrypt subkey generation failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${SUB_OUTPUT}"
  exit 1
fi

# Move the passphrase file to its permanent, fingerprint-keyed name (skip
# if the caller supplied an existing -P file, which stays where it is).
if [[ -z "$REUSE_PASSPHRASE_FILE" ]]; then
  FINAL_PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$FINGERPRINT")"
  runuser -u "${MFTE_GPG_USER}" -- mv "$GEN_PASSPHRASE_FILE" "$FINAL_PASSPHRASE_FILE"
  CLEANUP_TMP_PASSPHRASE=""
else
  FINAL_PASSPHRASE_FILE="$REUSE_PASSPHRASE_FILE"
fi

CREATED_ISO="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ "$SET_DEFAULT" == "true" ]]; then
  mfte_gpg_write_default_key_json "$FINGERPRINT" "$UID_STR" "$CREATED_ISO"
fi

log_system INFO "complete fingerprint=${FINGERPRINT} uid=\"${UID_STR}\" passphrase_file=${FINAL_PASSPHRASE_FILE} default_updated=${SET_DEFAULT}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG key generation complete
  uid              : $UID_STR
  fingerprint      : $FINGERPRINT
  key type         : $KEY_TYPE
  expire           : $EXPIRE
  passphrase file  : $FINAL_PASSPHRASE_FILE (mode 600, owned by ${MFTE_GPG_USER} -- not displayed here)
  default updated  : $SET_DEFAULT
REPORT
fi

exit 0
