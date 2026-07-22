#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.list.keys.sh
# purpose : List every identity in the mftgpg keyring -- fingerprint,
#           primary uid, created/expires, whether a secret key is present
#           (i.e. an identity you can decrypt/sign with, vs. an imported
#           partner's public-only key), and whether it's the current
#           default key.
#
# origin  : Not one of the original nine training scripts -- added once
#           real usage surfaced the gap (no way to see what's actually in
#           the keyring without hand-rolling gpg --with-colons parsing
#           each time). Same argument-parsing and logging conventions as
#           the rest of this framework.
#
# parsing : gpg's --with-colons output repeats "fpr" and "uid" lines for
#           every subkey, not just the primary key -- the same trap
#           mfte_gpg_lookup_fingerprint() had to be fixed for. This script
#           only captures the fpr/uid immediately following a pub/sec
#           record, and stops capturing once a sub/ssb record starts,
#           so multi-subkey identities (see werkstatt.gpg.generate.key.sh)
#           show up as ONE row, not three.

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
  $SCRIPT_NAME [options]

Optional:
  -k  filter      only show identities matching this search term (email,
                   uid substring, or fingerprint) -- passed through to gpg
  -j  json        print a JSON array instead of a human-readable report
  -h  help

Each identity is reported once, even if it has multiple subkeys (sign +
encrypt, see werkstatt.gpg.generate.key.sh) -- capability letters shown
are gpg's own (c=certify, s=sign, e=encrypt, a=auth), taken from the
primary key record.

Recommended Run Command:
  $SCRIPT_NAME -q
  $SCRIPT_NAME -k "partner@example.com"
USAGE
}

FILTER=""
JSON_OUT="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:jh' opt; do
  case "$opt" in
    k) FILTER="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
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

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start filter=${FILTER:-<none>} json=${JSON_OUT}"

# One row per identity: fingerprint \x01 uid \x01 created_epoch \x01 expires_epoch \x01 caps
_parse_primary_rows() {
  awk -F: '
    BEGIN { in_primary=0; fpr=""; uid=""; created=""; expires=""; caps="" }
    $1=="pub" || $1=="sec" {
      if (fpr != "") { printf "%s\x01%s\x01%s\x01%s\x01%s\n", fpr, uid, created, expires, caps }
      fpr=""; uid=""; created=$6; expires=$7; caps=$12; in_primary=1
      next
    }
    $1=="fpr" && in_primary==1 && fpr=="" { fpr=$10; next }
    $1=="uid" && in_primary==1 && uid=="" { uid=$10; next }
    $1=="sub" || $1=="ssb" { in_primary=0; next }
    END { if (fpr != "") { printf "%s\x01%s\x01%s\x01%s\x01%s\n", fpr, uid, created, expires, caps } }
  '
}

_epoch_to_date() {
  local epoch="$1"
  if [[ -z "$epoch" || "$epoch" == "0" ]]; then
    printf 'unknown'
    return
  fi
  date -u -d "@${epoch}" '+%Y-%m-%d' 2>/dev/null || date -u -r "${epoch}" '+%Y-%m-%d' 2>/dev/null || printf '%s' "$epoch"
}

PUB_LISTING="$(mfte_gpg_run --batch --with-colons --list-keys ${FILTER:+"$FILTER"} 2>/dev/null)"
SEC_LISTING="$(mfte_gpg_run --batch --with-colons --list-secret-keys 2>/dev/null)"
SEC_FPRS="$(printf '%s\n' "$SEC_LISTING" | _parse_primary_rows | awk -F'\x01' '{print $1}')"
DEFAULT_FP="$(mfte_gpg_default_fingerprint)"

ROWS="$(printf '%s\n' "$PUB_LISTING" | _parse_primary_rows)"

if [[ -z "$ROWS" ]]; then
  log_system INFO "complete count=0 filter=${FILTER:-<none>}"
  if [[ "$JSON_OUT" == "true" ]]; then
    printf '[]\n'
  else
    if [[ -n "$FILTER" ]]; then
      echo "No keys matching \"${FILTER}\" found in ${MFTE_GPG_HOME}."
    else
      echo "No keys found in ${MFTE_GPG_HOME}."
    fi
  fi
  exit 0
fi

COUNT=0
JSON_ITEMS=()
REPORT_LINES=""

while IFS=$'\x01' read -r fpr uid created expires caps; do
  [[ -z "$fpr" ]] && continue
  COUNT=$((COUNT + 1))

  has_secret="false"
  printf '%s\n' "$SEC_FPRS" | grep -qx "$fpr" && has_secret="true"

  is_default="false"
  [[ -n "$DEFAULT_FP" && "$fpr" == "$DEFAULT_FP" ]] && is_default="true"

  created_h="$(_epoch_to_date "$created")"
  if [[ -z "$expires" ]]; then
    expires_h="never"
  else
    expires_h="$(_epoch_to_date "$expires")"
  fi

  if [[ "$JSON_OUT" == "true" ]]; then
    item="$(jq -n \
      --arg fingerprint "$fpr" \
      --arg uid "$uid" \
      --arg created "$created_h" \
      --arg expires "$expires_h" \
      --arg capabilities "$caps" \
      --argjson has_secret "$has_secret" \
      --argjson is_default "$is_default" \
      '{fingerprint: $fingerprint, uid: $uid, created: $created, expires: $expires, capabilities: $capabilities, has_secret: $has_secret, is_default: $is_default}')"
    JSON_ITEMS+=("$item")
  else
    REPORT_LINES="${REPORT_LINES}
[${COUNT}] ${uid}
    fingerprint : ${fpr}
    created     : ${created_h}
    expires     : ${expires_h}
    capabilities: ${caps}
    secret key  : ${has_secret}
    default key : ${is_default}
"
  fi
done <<< "$ROWS"

log_system INFO "complete count=${COUNT} filter=${FILTER:-<none>}"

if [[ "$JSON_OUT" == "true" ]]; then
  printf '%s\n' "${JSON_ITEMS[@]}" | jq -s '.'
else
  echo "GPG keyring: ${COUNT} identit$([[ $COUNT -eq 1 ]] && echo y || echo ies)"
  printf '%s\n' "$REPORT_LINES"
fi

exit 0
