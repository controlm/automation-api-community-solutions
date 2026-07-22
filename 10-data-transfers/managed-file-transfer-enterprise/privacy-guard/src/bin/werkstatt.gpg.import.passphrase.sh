#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.import.passphrase.sh
# purpose : File a staged passphrase file into this framework's standard
#           fingerprint-keyed location ($MFTE_GPG_PASSPHRASE_DIR/<fingerprint>.passphrase),
#           independent of importing a private key.
#
# origin  : werkstatt.gpg.import.private.key.sh's -P flag already files a
#           passphrase as part of importing the key itself -- for the
#           ordinary "migrate mftgpg's identity to a new hub" case, that's
#           the only script you need. This one exists for the cases that
#           fall outside that: re-staging a passphrase file that was lost
#           or corrupted after the key was already imported, rotating a
#           passphrase for a key already present, or filing one for a key
#           that was imported earlier without -P at the time. Companion to
#           werkstatt.gpg.export.passphrase.sh, which has the same "not
#           folded into the key-export/import scripts, on purpose" reasoning
#           in its own header -- see that file.
#
# safety  : Refuses to file a passphrase for a fingerprint whose SECRET key
#           isn't already present in this keyring -- filing one for a key
#           you don't hold is almost always the wrong fingerprint or the
#           wrong hub, not a legitimate use case. Before filing anything,
#           this also proves the passphrase actually unlocks that key: it
#           encrypts a throwaway string to the key's own public half, then
#           decrypts it back using the staged passphrase file. A mistyped
#           or stale passphrase file fails loudly here instead of being
#           discovered later when werkstatt.gpg.decrypt.file.sh fails
#           against real data. Nothing is written to
#           $MFTE_GPG_PASSPHRASE_DIR unless that round trip succeeds.

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
  $SCRIPT_NAME -k "<fingerprint>" [-f "<file>"] [options]

Required:
  -k  key         fingerprint (or uid/email substring resolving to exactly
                   one SECRET key already in this keyring) this passphrase
                   belongs to -- no default-key.json fallback, deliberately:
                   filing a passphrase is a write against sensitive
                   material, worth naming the key explicitly every time.

Optional:
  -f  file        path to the staged passphrase file -- must exist, mode
                   600, owned by \$MFTE_GPG_USER (same lockdown check
                   werkstatt.gpg.import.private.key.sh's -P uses). Default:
                   \$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase (-k's
                   resolved fingerprint), the name
                   werkstatt.gpg.export.passphrase.sh's own default writes
                   -- demo convenience, matched to this framework's
                   export/import naming agreement.
  -q  quiet
  -h  help

Refuses to proceed if the secret key for -k isn't already in this keyring
(import it first: werkstatt.gpg.import.private.key.sh), and refuses to
file the passphrase if it doesn't actually unlock that key -- proven with
a non-destructive encrypt/decrypt round trip against a throwaway string
before anything is written to \$MFTE_GPG_PASSPHRASE_DIR.

Recommended Run Command:
  $SCRIPT_NAME -k "<fingerprint>" -f "/secure/staging/key.passphrase" -q
USAGE
}

KEY=""
FILE=""
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:f:qh' opt; do
  case "$opt" in
    k) KEY="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
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

if [[ -z "$KEY" ]]; then
  log_system ERROR "missing required -k"
  echo "ERROR: -k key is required." >&2
  usage
  exit 2
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start key=${KEY} file=${FILE:-<defaulting after fingerprint resolution>}"

FP="$(mfte_gpg_lookup_fingerprint "$KEY" secret)"
if [[ -z "$FP" ]]; then
  log_system ERROR "no secret key resolved for -k: ${KEY}"
  echo "ERROR: \"${KEY}\" did not resolve to exactly one SECRET key in ${MFTE_GPG_HOME}." >&2
  echo "Import the private key first (werkstatt.gpg.import.private.key.sh) before filing a passphrase for it." >&2
  exit 1
fi

if [[ -z "$FILE" ]]; then
  FILE="${MFTE_GPG_EXCHANGE_DIR}/${FP}.passphrase"
  log_system INFO "defaulted -f to ${FILE} (fingerprint-matched name in MFTE_GPG_EXCHANGE_DIR)"
fi

if ! mfte_gpg_require_locked_down "$FILE" 600; then
  log_system ERROR "passphrase file failed lockdown check: ${FILE}"
  echo "ERROR: passphrase file ${FILE} must exist, mode 600, owned by ${MFTE_GPG_USER}." >&2
  exit 1
fi

UID_STR="$(mfte_gpg_uid_for_fingerprint "$FP" secret)"
TARGET="$(mfte_gpg_passphrase_file "$FP")"

if [[ "$FILE" -ef "$TARGET" ]]; then
  log_system INFO "source and target are the same file, nothing to validate or copy fp=${FP}"
  if [[ "$QUIET" != "true" ]]; then
    cat <<REPORT
GPG passphrase import complete
  fingerprint       : $FP
  uid               : $UID_STR
  validated         : true (already in place)
  filed             : $TARGET
  overwritten       : false
REPORT
  fi
  exit 0
fi

# Non-destructive proof the passphrase actually unlocks this key, before
# anything is written to $MFTE_GPG_PASSPHRASE_DIR: encrypt a throwaway
# string to the key's own public half, then decrypt it back using the
# staged file via --passphrase-file, exactly the way
# werkstatt.gpg.decrypt.file.sh will use it for real later. Pure
# stdin/stdout through runuser -- no temp file on disk at any point.
TEST_PLAINTEXT="mfte-passphrase-validation-$(date -u '+%Y%m%dT%H%M%SZ')-$$"

ENC_OUT="$(printf '%s' "$TEST_PLAINTEXT" | mfte_gpg_run --batch --yes --trust-model always --recipient "$FP" --armor --encrypt 2>/dev/null)"
if [[ -z "$ENC_OUT" ]]; then
  log_system ERROR "validation encrypt step failed fp=${FP} -- key may not be encrypt-capable"
  echo "ERROR: could not encrypt a test message to ${FP} -- cannot validate the passphrase this way." >&2
  echo "Check the key has an encrypt-capable subkey (gpg --list-keys --with-colons ${FP} -- look for a 'sub' line ending in 'e')." >&2
  exit 1
fi

DEC_ERR="$(printf '%s' "$ENC_OUT" | mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$FILE" --decrypt 2>&1 >/dev/null)"
DEC_STATUS=$?

if [[ "$DEC_STATUS" -ne 0 ]]; then
  log_system ERROR "validation round trip failed fp=${FP} status=${DEC_STATUS}"
  echo "ERROR: passphrase in ${FILE} does not unlock the secret key for ${FP} -- NOT filed." >&2
  log_system DEBUG "gpg output: ${DEC_ERR}"
  exit 1
fi

OVERWRITTEN="false"
[[ -e "$TARGET" ]] && OVERWRITTEN="true"

# Copied as MFTE_GPG_USER, not as whatever identity is running this script
# (root, in production) -- same reasoning as every other passphrase copy
# in this framework (see mfte_gpg_copy_passphrase_as_user's own comment).
if ! mfte_gpg_copy_passphrase_as_user "$FILE" "$TARGET"; then
  log_system ERROR "filing failed fp=${FP} source=${FILE} target=${TARGET}"
  echo "ERROR: passphrase validated correctly but the copy to ${TARGET} failed." >&2
  exit 1
fi

log_system INFO "complete fp=${FP} target=${TARGET} overwritten=${OVERWRITTEN}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG passphrase import complete
  fingerprint       : $FP
  uid               : $UID_STR
  validated         : true (encrypt/decrypt round trip against ${FP})
  filed             : $TARGET
  overwritten       : $OVERWRITTEN
REPORT
fi

exit 0
