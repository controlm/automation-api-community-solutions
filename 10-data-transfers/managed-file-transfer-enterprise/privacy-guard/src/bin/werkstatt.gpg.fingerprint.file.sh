#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.fingerprint.file.sh
# purpose : Given an ENCRYPTED FILE, list the key(s) it was encrypted to
#           -- i.e. which key(s) you may need to decrypt it -- and
#           whether each one is present in this keyring with its secret
#           half (meaning you can actually decrypt with it right now, vs.
#           it's a recipient key you don't hold).
#
# origin  : This used to inspect standalone KEY files instead (fingerprint
#           a public/private key before importing it). Real usage showed
#           that's not what "fingerprint file" means to whoever's
#           actually running these scripts -- the natural reach was
#           straight for an encrypted message, wanting to know what it
#           takes to open it. That capability didn't go away, it just
#           moved to werkstatt.gpg.inspect.key.file.sh, which does exactly
#           what this script used to do. Two different operations, kept
#           under two different names now instead of one name doing
#           double duty.
#
# note    : gpg --list-packets reads OpenPGP packet headers only -- it
#           does not decrypt anything and needs no passphrase. It DOES,
#           as a side effect, attempt a session-key decryption and print
#           "public key decryption failed" / "no secret key" lines to
#           stderr when it can't complete that attempt -- harmless noise,
#           not an error condition for this script's purpose, and
#           deliberately not surfaced as one below.

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
  -f  file        path to the encrypted file to inspect

Optional:
  -j  json        print a JSON array instead of a human-readable report
  -h  help

For each recipient key the file was encrypted to, reports: the key ID
from the message itself, whether that key is present in this keyring (and
if so, its full fingerprint and uid), and whether the secret half is
present too -- i.e. whether THIS keyring can actually decrypt with it, not
just recognize it. A file encrypted to a key you don't hold shows up with
in_keyring=false -- you'd need to obtain/import that key (or have someone
who holds it decrypt it) before werkstatt.gpg.decrypt.file.sh can work.

This inspects an ENCRYPTED MESSAGE. If you have a KEY file instead and
want its fingerprint before importing it, use
werkstatt.gpg.inspect.key.file.sh -- different operation, different kind
of input file.

Recommended Run Command:
  $SCRIPT_NAME -f "\$\$FILE_ABS_PATH\$\$"
USAGE
}

FILE=""
JSON_OUT="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':f:jh' opt; do
  case "$opt" in
    f) FILE="$(mfte_unquote "$OPTARG")" ;;
    j) JSON_OUT="true" ;;
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

log_system INFO "start file=${FILE}"

# --pinentry-mode cancel: skip any real pinentry interaction (this never
# needs one -- we're only listing packet headers) rather than let a
# leftover agent prompt attempt hang the script. The "public key
# decryption failed" / "no secret key" lines this still prints are a
# harmless side effect of gpg's own --list-packets implementation, not
# something this script treats as failure.
LIST_OUTPUT="$(mfte_gpg_run --batch --pinentry-mode cancel --list-packets "$FILE" 2>&1)"

KEY_IDS="$(printf '%s\n' "$LIST_OUTPUT" | sed -n 's/^:pubkey enc packet:.*keyid \([0-9A-Fa-f]*\).*/\1/p')"

if [[ -z "$KEY_IDS" ]]; then
  log_system ERROR "no pubkey-encrypted recipient packets found file=${FILE}"
  echo "ERROR: ${FILE} doesn't appear to be a public-key-encrypted OpenPGP message" >&2
  echo "(no ':pubkey enc packet:' entries found). If it's symmetrically encrypted" >&2
  echo "(passphrase-only, no recipient keys) there's nothing for this script to report." >&2
  log_system DEBUG "gpg output: ${LIST_OUTPUT}"
  exit 1
fi

COUNT=0
DECRYPTABLE_COUNT=0
JSON_ITEMS=()
REPORT_LINES=""

while IFS= read -r keyid; do
  [[ -z "$keyid" ]] && continue
  COUNT=$((COUNT + 1))

  fpr="$(mfte_gpg_lookup_fingerprint "$keyid" public 2>/dev/null || true)"
  in_keyring="false"
  has_secret="false"
  uid=""

  if [[ -n "$fpr" ]]; then
    in_keyring="true"
    uid="$(mfte_gpg_uid_for_fingerprint "$fpr" public)"
    sec_fpr="$(mfte_gpg_lookup_fingerprint "$keyid" secret 2>/dev/null || true)"
    [[ -n "$sec_fpr" ]] && has_secret="true"
  fi

  [[ "$has_secret" == "true" ]] && DECRYPTABLE_COUNT=$((DECRYPTABLE_COUNT + 1))

  if [[ "$JSON_OUT" == "true" ]]; then
    item="$(jq -n \
      --arg key_id "$keyid" \
      --arg fingerprint "$fpr" \
      --arg uid "$uid" \
      --argjson in_keyring "$in_keyring" \
      --argjson has_secret "$has_secret" \
      '{key_id: $key_id, fingerprint: ($fingerprint // ""), uid: ($uid // ""), in_keyring: $in_keyring, can_decrypt_here: $has_secret}')"
    JSON_ITEMS+=("$item")
  else
    REPORT_LINES="${REPORT_LINES}
[${COUNT}] key ID: ${keyid}
    in this keyring : ${in_keyring}"
    if [[ "$in_keyring" == "true" ]]; then
      REPORT_LINES="${REPORT_LINES}
    fingerprint     : ${fpr}
    uid             : ${uid}"
    fi
    REPORT_LINES="${REPORT_LINES}
    can decrypt here: ${has_secret}
"
  fi
done <<< "$KEY_IDS"

log_system INFO "complete file=${FILE} recipients=${COUNT} decryptable=${DECRYPTABLE_COUNT}"

if [[ "$JSON_OUT" == "true" ]]; then
  printf '%s\n' "${JSON_ITEMS[@]}" | jq -s '.'
else
  echo "GPG recipient key(s) needed to decrypt: $FILE"
  printf '%s\n' "$REPORT_LINES"
  echo "$DECRYPTABLE_COUNT of $COUNT recipient key(s) can be decrypted with in this keyring."
fi

exit 0
