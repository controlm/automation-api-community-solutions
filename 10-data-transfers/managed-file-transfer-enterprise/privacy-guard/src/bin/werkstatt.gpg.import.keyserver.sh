#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.import.keyserver.sh
# purpose : Fetch a PUBLIC key from a keyserver by its full fingerprint and
#           import it into the mftgpg keyring -- the keyserver-sourced
#           equivalent of werkstatt.gpg.import.public.key.sh, for partners
#           who publish rather than email/portal a key file.
#
# trust   : Fetching from a keyserver changes the TRANSPORT, not the trust
#           model. keys.openpgp.org verifies email ownership before binding
#           a uid, but that does not prove the fingerprint you ask for is
#           genuinely the partner's -- you still need the correct
#           fingerprint from a channel independent of the keyserver itself
#           (their site, a signed message, a phone call) before running
#           this, exactly like werkstatt.gpg.inspect.key.file.sh's role for
#           a file-based import. That's why -k only accepts a full 40-hex
#           fingerprint here -- never an email or short key ID. Short IDs
#           are trivially collision-attackable against public keyservers
#           (a well documented historical PGP weakness); accepting one here
#           would undo the whole point of requiring a fingerprint at all.
#
# network : This is the only script in this family that touches the
#           network. gpg's dirmngr component performs the actual fetch, not
#           this script directly -- if it hangs or fails, check whether this
#           host has outbound HTTPS (443) to the keyserver at all before
#           assuming anything is wrong with the fingerprint or the key
#           itself. A proxy, if needed, belongs in mftgpg's own
#           ~/.gnupg/dirmngr.conf, not something this script sets. Wrapped
#           in `timeout` below so a blocked/filtered network fails within a
#           bounded time instead of hanging the calling job indefinitely.

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
  $SCRIPT_NAME -k "<40-hex-fingerprint>" [options]

Required:
  -k  key         full 40-character fingerprint to fetch -- NOT an email
                   address or short key ID, deliberately (see header comment).
                   Everything that isn't a hex digit is discarded automatically
                   (spaces, non-breaking spaces, colons, a leading 0x), so
                   pasting straight out of GPG Keychain, "gpg --list-keys", or
                   a keyserver's web UI works as-is regardless of how that
                   source formats it.

Optional:
  -s  keyserver   default: \${MFTE_GPG_KEYSERVER:-hkps://keys.openpgp.org}
  -t  timeout     seconds before giving up on the network call, default: 20
  -q  quiet
  -h  help

Get the fingerprint from the partner through a channel independent of the
keyserver itself before running this -- fetching a key does not verify who
it belongs to, only that a key with this exact fingerprint exists there.

Recommended Run Command:
  $SCRIPT_NAME -k "<fingerprint>" -q
USAGE
}

KEY=""
KEYSERVER="${MFTE_GPG_KEYSERVER:-hkps://keys.openpgp.org}"
TIMEOUT_SECS="20"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:s:t:qh' opt; do
  case "$opt" in
    k) KEY="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
    s) KEYSERVER="$(mfte_unquote "$OPTARG")" ;;
    t) TIMEOUT_SECS="$(mfte_unquote "$OPTARG")" ;;
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
  echo "ERROR: -k fingerprint is required." >&2
  usage
  exit 2
fi

# Normalize before validating, not instead of it: GPG Keychain, "gpg
# --list-keys", and most keyserver web UIs all display a fingerprint
# space-separated in groups of 4 -- that's the natural copy-paste source, so
# strip separators rather than rejecting exactly the input every real user
# will actually have. Deliberately an ALLOW-list (keep only hex digits),
# not a deny-list of specific separator characters: GPG Keychain's own
# table UI renders that gap with a non-breaking space (U+00A0), which
# bash's [[:space:]] class does NOT match in the default locale -- a
# deny-list has to correctly anticipate every separator variant a given
# tool might use; an allow-list doesn't care what the separator is. Strip
# a leading 0x/0X FIRST, before the general hex-only filter -- otherwise
# the "0" survives the filter (it's a valid hex digit) while only the "x"
# gets dropped, silently corrupting the result with a stray leading zero.
# Still requires exactly 40 hex characters after normalization -- an email
# or short key ID is rejected either way.
FP="${KEY^^}"
FP="${FP#0X}"
FP="${FP//[^0-9A-F]/}"
if [[ ! "$FP" =~ ^[0-9A-F]{40}$ ]]; then
  log_system ERROR "-k is not a full 40-hex fingerprint after normalization: ${KEY}"
  echo "ERROR: -k must be the full 40-character fingerprint, not an email address or short key ID." >&2
  echo "Got: \"${KEY}\" -> normalized \"${FP}\" (${#FP} hex characters after discarding everything else)." >&2
  echo "If you only have an email, find the fingerprint some other way first and verify it out of" >&2
  echo "band -- don't fetch by email/short-id from a keyserver." >&2
  exit 2
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start fingerprint=${FP} keyserver=${KEYSERVER} timeout=${TIMEOUT_SECS}"

IMPORT_OUTPUT="$(timeout "${TIMEOUT_SECS}" runuser -u "${MFTE_GPG_USER}" -- gpg --homedir "${MFTE_GPG_HOME}" --batch --status-fd 1 --keyserver "$KEYSERVER" --recv-keys "$FP" 2>&1)"
FETCH_STATUS=$?

if [[ "$FETCH_STATUS" -eq 124 ]]; then
  log_system ERROR "keyserver fetch timed out after ${TIMEOUT_SECS}s fingerprint=${FP} keyserver=${KEYSERVER}"
  echo "ERROR: timed out after ${TIMEOUT_SECS}s reaching ${KEYSERVER}." >&2
  echo "Check this host has outbound HTTPS (443) to the keyserver before assuming the fingerprint" >&2
  echo "or key is the problem -- many production hosts don't have general internet egress. A proxy," >&2
  echo "if this network requires one, goes in \$MFTE_GPG_HOME/dirmngr.conf, not a flag on this script." >&2
  exit 1
fi

if [[ "$FETCH_STATUS" -ne 0 ]]; then
  log_system ERROR "keyserver fetch failed fingerprint=${FP} keyserver=${KEYSERVER} status=${FETCH_STATUS}"
  echo "ERROR: fetch from ${KEYSERVER} failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

FETCHED_FP="$(mfte_gpg_import_fingerprint "$IMPORT_OUTPUT")"
if [[ -z "$FETCHED_FP" ]]; then
  log_system ERROR "fetch produced no IMPORT_OK status fingerprint=${FP} keyserver=${KEYSERVER}"
  echo "ERROR: ${KEYSERVER} returned nothing importable for ${FP} (not found, or already present with no change)." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

# Defense in depth: confirm the key gpg actually imported carries the exact
# fingerprint requested, not merely that --recv-keys exited 0. Guards
# against relying on --status-fd parsing alone if some future gpg/keyserver
# edge case ever returns something unexpected.
if [[ "${FETCHED_FP^^}" != "$FP" ]]; then
  log_system ERROR "fetched fingerprint mismatch requested=${FP} got=${FETCHED_FP}"
  echo "ERROR: fetched key's fingerprint (${FETCHED_FP}) does not match what was requested (${FP})." >&2
  exit 1
fi

UID_STR="$(mfte_gpg_uid_for_fingerprint "$FP" public)"

log_system INFO "complete fingerprint=${FP} keyserver=${KEYSERVER} uid=\"${UID_STR}\""

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG keyserver import complete
  fingerprint       : $FP
  uid               : $UID_STR
  keyserver         : $KEYSERVER
REPORT
fi

exit 0
