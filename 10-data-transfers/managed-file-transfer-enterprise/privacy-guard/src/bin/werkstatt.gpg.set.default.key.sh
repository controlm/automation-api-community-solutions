#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.set.default.key.sh
# purpose : Point default-key.json at a key that's ALREADY present in this
#           node's own keyring, without re-generating or re-importing
#           anything. Fills a real gap: werkstatt.gpg.generate.key.sh sets
#           a default as a side effect of creating a key, and
#           werkstatt.gpg.import.private.key.sh -D sets one as a side
#           effect of importing a key -- neither works when the key is
#           already fully present and unchanged, since gpg's own --import
#           reports "no change" for that case (no IMPORT_OK status line),
#           which import.private.key.sh treats as a hard failure before it
#           ever reaches its -D handling. This script has no import step
#           to trip over that -- it only ever reads the keyring and writes
#           default-key.json, via the same mfte_gpg_write_default_key_json
#           helper those two scripts already use.
#
# origin  : Not one of the original nine. Surfaced by a real 3-hub cluster
#           where mftgpg's own identity ("Werkstatt MFTE") ended up the
#           default on one hub (set during that hub's original
#           generate.key.sh run) but not the other two (which received it
#           via export/import during hub-to-hub setup, without -D) --
#           there was no clean way to fix the other two without this.
#
# scope   : Local to THIS node only -- default-key.json lives under
#           $MFTE_GPG_META_DIR, which is NOT shared across hubs (same as
#           the keyring itself -- see the README's "Why a dedicated
#           service account" section). Run this once per hub you want the
#           same default on, same as onboarding-4gpg-cluster.sh.
#
# exit codes:
#   0  default-key.json now points at the given fingerprint
#   1  technical error (default-key.json write failed)
#   2  usage error (bad/missing flags)
#   3  the given fingerprint has no SECRET key in this node's keyring --
#      can't be set as this node's default (a public-only key isn't
#      something this node can decrypt/sign with, which is the whole
#      point of "default"). Distinct from 1 so "wrong/unknown fingerprint"
#      can be told apart from "default-key.json itself is broken"

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
  $SCRIPT_NAME -k "<fingerprint>" [options]

Required:
  -k  fingerprint   full 40-hex fingerprint of a key ALREADY present in
                     this node's own keyring, with its secret half here
                     (not just the public half -- see exit code 3)

Optional:
  -q  quiet
  -h  help

Local to this node only -- default-key.json is not shared across hubs.
Run once per hub you want the same default on. Does not touch the
keyring itself, does not import or generate anything -- only reads it to
confirm the fingerprint + uid, then writes default-key.json.

Recommended Run Command (once per hub):
  $SCRIPT_NAME -k "A2314D02AE03DB3B2562ABAAAD3F85A14853BDCF" -q
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

if [[ -z "$KEY_FP" ]]; then
  log_system ERROR "missing required -k (fingerprint)"
  echo "ERROR: -k fingerprint is required." >&2
  usage
  exit 2
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

if ! RESOLVED_FP="$(mfte_gpg_lookup_fingerprint "$KEY_FP" secret)"; then
  log_system ERROR "no secret key for fingerprint=${KEY_FP} on this node"
  echo "ERROR: ${KEY_FP} does not resolve to a key with a secret half in this node's own keyring." >&2
  echo "Check werkstatt.gpg.list.keys.sh -- either the fingerprint is wrong, this node only has" >&2
  echo "the public half (a partner's key, not one this node can decrypt/sign with), or the key" >&2
  echo "hasn't been imported here yet (see onboarding-4gpg-cluster.sh / import.private.key.sh)." >&2
  exit 3
fi

UID_STR="$(mfte_gpg_uid_for_fingerprint "$RESOLVED_FP" secret)"
PREVIOUS_FP="$(mfte_gpg_default_fingerprint)"

log_system INFO "start fingerprint=${RESOLVED_FP} uid=\"${UID_STR}\" previous_default=${PREVIOUS_FP:-none}"

if ! mfte_gpg_write_default_key_json "$RESOLVED_FP" "$UID_STR" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; then
  log_system ERROR "failed to write default-key.json fingerprint=${RESOLVED_FP}"
  echo "ERROR: failed to write default-key.json. See ${SYSTEM_LOG_FILE} for details." >&2
  exit 1
fi

log_system INFO "complete fingerprint=${RESOLVED_FP} uid=\"${UID_STR}\" previous_default=${PREVIOUS_FP:-none}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
Default key updated
  host              : $(hostname -f 2>/dev/null || hostname)
  fingerprint       : $RESOLVED_FP
  uid               : $UID_STR
  previous default  : ${PREVIOUS_FP:-none}
REPORT
fi

exit 0
