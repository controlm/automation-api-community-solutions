#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.vault.export.all.passphrases.sh
# purpose : Push every secret key's ALREADY-FILED local passphrase into
#           Vault in one pass -- the batch counterpart to
#           werkstatt.gpg.vault.export.passphrase.sh, for a multi-tenant
#           keyring (N customer keys) where exporting one fingerprint at a
#           time doesn't scale, same relationship
#           werkstatt.gpg.import.all.private.sh has to
#           werkstatt.gpg.import.private.key.sh.
#
# scope   : Enumerates every identity in the keyring that HAS a secret key
#           (skips public-only/partner keys entirely -- nothing to export
#           for those). For each one:
#             - if no local passphrase file exists, or it fails the
#               mode-600/mftgpg-ownership lockdown check, that fingerprint
#               is SKIPPED (not failed) -- this is an expected, common
#               state for a key that was just generated/imported and
#               hasn't had its passphrase filed locally yet.
#             - otherwise, the local passphrase file is pushed to Vault at
#               this framework's standard path
#               (kv/onecm/gpg-passphrase/<fingerprint>), same as the
#               single-key script -- unconditionally overwriting whatever
#               (if anything) was already at that Vault path. Export is
#               idempotent by design; there's no "already present in
#               Vault, skip" bucket the way werkstatt.gpg.import.all.
#               private.sh has one for "already present in keyring" --
#               re-exporting the same local file to Vault is harmless and
#               sometimes exactly the point (re-pushing after a local
#               passphrase rotation).
#             - an actual Vault write failure (permission denied, Vault
#               sealed/unreachable mid-run, etc.) is the only thing that
#               counts as FAILED.
#
# NOT done here, deliberately:
#   - Generating or rotating passphrases. This only ever pushes whatever
#     is ALREADY in each key's local passphrase file -- see
#     werkstatt.gpg.generate.key.sh for where that file comes from.
#   - Vault policy/AppRole setup. If every export in this run fails with
#     "permission denied", that's a Vault ACL policy gap
#     (kv/data/onecm/gpg-passphrase/* needs create+update, not just read)
#     -- not something this script can fix for you.
#
# exit codes:
#   0  every attempted export succeeded (including the case where nothing
#      in the keyring had a local passphrase file to export at all -- see
#      the per-fingerprint report and the summary counts)
#   1  at least one export actually failed (a Vault write error on a
#      fingerprint that DID have a valid local passphrase file)
#   2  usage error (bad/missing flags)

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
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
  -k  filter      only consider identities matching this search term
                   (email, uid substring, or fingerprint) -- passed
                   through to gpg, same as werkstatt.gpg.list.keys.sh -k.
                   Default: every secret key in the keyring.
  -q  quiet       suppress the per-fingerprint + summary report (errors
                   for real failures still go to stderr; the log always
                   gets the full record)
  -V  version     print this script's own name and version, then exit
  -h  help

Env (required):
  VAULT_ADDR
  VAULT_TOKEN                 or:
  VAULT_ROLE_ID / VAULT_SECRET_ID

Only fingerprints with a secret key present AND an already-filed, properly
locked-down local passphrase file are exported. Everything else is
reported as SKIPPED, not FAILED -- see the header comment.

Recommended Run Command:
  $SCRIPT_NAME -q
  $SCRIPT_NAME -k "partner@example.com" -q
USAGE
}

FILTER=""
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "version=${SCRIPT_VERSION} argv[$#]: ${ARGV_DUMP}"

while getopts ':k:qVh' opt; do
  case "$opt" in
    k) FILTER="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
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

log_system INFO "start filter=${FILTER:-<none>}"

# Same primary-record parsing idiom werkstatt.gpg.list.keys.sh uses --
# one row per identity (fpr, uid), even for a multi-subkey key (sign +
# encrypt), by only capturing the fpr/uid immediately following a
# pub/sec record and stopping capture once a sub/ssb record starts.
_parse_primary_rows() {
  awk -F: '
    BEGIN { in_primary=0; fpr=""; uid="" }
    $1=="pub" || $1=="sec" {
      if (fpr != "") { printf "%s\x01%s\n", fpr, uid }
      fpr=""; uid=""; in_primary=1
      next
    }
    $1=="fpr" && in_primary==1 && fpr=="" { fpr=$10; next }
    $1=="uid" && in_primary==1 && uid=="" { uid=$10; next }
    $1=="sub" || $1=="ssb" { in_primary=0; next }
    END { if (fpr != "") { printf "%s\x01%s\n", fpr, uid } }
  '
}

SEC_LISTING="$(mfte_gpg_run --batch --with-colons --list-secret-keys ${FILTER:+"$FILTER"} 2>/dev/null)"
ROWS="$(printf '%s\n' "$SEC_LISTING" | _parse_primary_rows)"

if [[ -z "$ROWS" ]]; then
  log_system INFO "complete scanned=0 exported=0 skipped=0 failed=0 filter=${FILTER:-<none>}"
  if [[ "$QUIET" != "true" ]]; then
    if [[ -n "$FILTER" ]]; then
      echo "No secret keys matching \"${FILTER}\" found in ${MFTE_GPG_HOME}."
    else
      echo "No secret keys found in ${MFTE_GPG_HOME}."
    fi
  fi
  exit 0
fi

SCANNED=0
EXPORTED=0
SKIPPED=0
FAILED=0
REPORT_LINES=()

while IFS=$'\x01' read -r FP UID_STR; do
  [[ -z "$FP" ]] && continue
  SCANNED=$((SCANNED + 1))

  PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$FP")"
  if ! mfte_gpg_require_locked_down "$PASSPHRASE_FILE" 600 2>/dev/null; then
    log_system INFO "skip fingerprint=${FP} reason=no_local_passphrase_file"
    REPORT_LINES+=("SKIP      ${FP}  uid=\"${UID_STR}\"  reason=no_local_passphrase_file")
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  VAULT_PATH="$(mfte_gpg_vault_passphrase_path "$FP")"
  if ! mfte_gpg_vault_put_passphrase_from_file "$FP" "$PASSPHRASE_FILE"; then
    log_system ERROR "vault write failed fingerprint=${FP} vault_path=${VAULT_PATH}"
    echo "ERROR: failed to write passphrase to Vault at ${VAULT_PATH} for fingerprint ${FP}. See ${SYSTEM_LOG_FILE} for details." >&2
    REPORT_LINES+=("FAILED    ${FP}  uid=\"${UID_STR}\"  vault_path=${VAULT_PATH}  (see log)")
    FAILED=$((FAILED + 1))
    continue
  fi

  log_system INFO "exported fingerprint=${FP} uid=\"${UID_STR}\" vault_path=${VAULT_PATH}"
  REPORT_LINES+=("EXPORTED  ${FP}  uid=\"${UID_STR}\"  vault_path=${VAULT_PATH}")
  EXPORTED=$((EXPORTED + 1))
done <<< "$ROWS"

log_system INFO "complete scanned=${SCANNED} exported=${EXPORTED} skipped=${SKIPPED} failed=${FAILED} filter=${FILTER:-<none>}"

if [[ "$QUIET" != "true" ]]; then
  if [[ "${#REPORT_LINES[@]}" -gt 0 ]]; then
    printf '%s\n' "${REPORT_LINES[@]}"
  fi
  cat <<REPORT

GPG batch Vault passphrase export complete
  secret keys scanned : $SCANNED
  exported            : $EXPORTED
  skipped (no local)  : $SKIPPED
  failed              : $FAILED
REPORT
fi

[[ "$FAILED" -gt 0 ]] && exit 1
exit 0