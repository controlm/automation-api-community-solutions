#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.import.private.key.sh
# purpose : Import a PRIVATE key (e.g. migrating mftgpg's own identity
#           from another host, or provisioning a partner-supplied
#           decrypt-only key) into the mftgpg keyring.
#
# origin  : Hardened, production-like-demo version of a training script
#           that read a passphrase out of a plaintext dsse.gpg.info.json
#           and printed it in cleartext. The imported key's protection
#           passphrase is not something this script generates -- it
#           already exists, set on whatever system the key came from -- so
#           this version requires it be staged in a locked-down file
#           (mode 600, owned by mftgpg) via -P *before* running, the same
#           way a human would hand over a physical key rather than saying
#           the combination out loud. This script then files it under the
#           framework's standard fingerprint-keyed name so
#           werkstatt.gpg.decrypt.file.sh can find it later.

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
  $SCRIPT_NAME [-f "<file>"] [options]

Optional:
  -f  file        path to the private key file to import (armored or binary).
                   Default: the one file matching *.private.* in
                   \$MFTE_GPG_EXCHANGE_DIR, if exactly one exists -- error if
                   zero or more than one, since guessing which key to import
                   is not a safe default.
  -P  passphrase file for the imported key -- must already exist, mode
      600, owned by \$MFTE_GPG_USER. If given, it is copied into this
      framework's standard fingerprint-keyed location
      (\$MFTE_GPG_PASSPHRASE_DIR/<fingerprint>.passphrase) after import so
      werkstatt.gpg.decrypt.file.sh can find it. If omitted, this script
      also looks for \$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase (the
      name werkstatt.gpg.export.passphrase.sh's own default writes) once
      the fingerprint is known from the import, and uses it automatically
      if it passes the same mode-600 lockdown check -- for demo
      convenience, since this framework's export/import pair already
      agrees on that filename. If neither -P nor that default file is
      usable, the key is imported but nothing is filed for it -- decrypt
      will fail against it until a passphrase file is provided some other
      way.
  -D  set the imported key as the default (used by werkstatt.gpg.decrypt.file.sh
      and werkstatt.gpg.export.key.sh when no -k/-r is given). Off by default --
      importing a private key doesn't automatically make it "the" identity.
  -q  quiet
  -h  help

\$MFTE_GPG_EXCHANGE_DIR is the conventional place to stage the inbound key
file (it's where werkstatt.gpg.export.key.sh writes its output on the
source host) -- -f accepts any path if you'd rather point elsewhere. This
demo also defaults -P to a matching passphrase file in the same
directory (see -P above) -- production use should keep the passphrase on
a genuinely separate channel instead, per the risk notes in README.md.

The passphrase itself is never a flag on this script and is never echoed
or logged -- only its file path is.

Recommended Run Command:
  $SCRIPT_NAME -f "\$\$FILE_ABS_PATH\$\$" -P "/secure/staged.passphrase" -D -q
USAGE
}

FILE=""
PASSPHRASE_FILE=""
SET_DEFAULT="false"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':f:P:Dqh' opt; do
  case "$opt" in
    f) FILE="$(mfte_unquote "$OPTARG")" ;;
    P) PASSPHRASE_FILE="$(mfte_unquote "$OPTARG")" ;;
    D) SET_DEFAULT="true" ;;
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

if [[ -z "$FILE" ]]; then
  FILE="$(mfte_gpg_find_single_file "${MFTE_GPG_EXCHANGE_DIR}" '*.private.*')" || {
    log_system ERROR "no -f given and no single unambiguous *.private.* match in ${MFTE_GPG_EXCHANGE_DIR}"
    echo "ERROR: -f not given, and \$MFTE_GPG_EXCHANGE_DIR (${MFTE_GPG_EXCHANGE_DIR}) does not contain exactly one *.private.* file to default to." >&2
    usage
    exit 2
  }
  log_system INFO "defaulted -f to ${FILE} (single *.private.* match in MFTE_GPG_EXCHANGE_DIR)"
fi

if [[ ! -f "$FILE" || ! -r "$FILE" ]]; then
  log_system ERROR "file not found or unreadable: ${FILE}"
  echo "ERROR: file not found or unreadable: ${FILE}" >&2
  exit 1
fi

if [[ -n "$PASSPHRASE_FILE" ]] && ! mfte_gpg_require_locked_down "$PASSPHRASE_FILE" 600; then
  log_system ERROR "supplied -P passphrase file failed lockdown check: ${PASSPHRASE_FILE}"
  echo "ERROR: -P passphrase file must exist, mode 600, owned by ${MFTE_GPG_USER}." >&2
  exit 1
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

log_system INFO "start file=${FILE} passphrase_staged=$([[ -n "$PASSPHRASE_FILE" ]] && echo true || echo false)"

if ! IMPORT_OUTPUT="$(mfte_gpg_import_key "$FILE" private 2>&1)"; then
  log_system ERROR "private key import failed file=${FILE}"
  echo "ERROR: import failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

FINGERPRINT="$(mfte_gpg_import_fingerprint "$IMPORT_OUTPUT")"
if [[ -z "$FINGERPRINT" ]]; then
  log_system ERROR "import produced no IMPORT_OK status file=${FILE}"
  echo "ERROR: gpg did not report an imported key (already present with no change, or not valid key material?)." >&2
  log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
  exit 1
fi

UID_STR="$(mfte_gpg_uid_for_fingerprint "$FINGERPRINT" secret)"
FILED_PASSPHRASE="false"

if [[ -z "$PASSPHRASE_FILE" ]]; then
  CANDIDATE_PASSPHRASE="${MFTE_GPG_EXCHANGE_DIR}/${FINGERPRINT}.passphrase"
  if [[ -f "$CANDIDATE_PASSPHRASE" ]]; then
    if mfte_gpg_require_locked_down "$CANDIDATE_PASSPHRASE" 600; then
      PASSPHRASE_FILE="$CANDIDATE_PASSPHRASE"
      log_system INFO "defaulted -P to ${PASSPHRASE_FILE} (fingerprint-matched file in MFTE_GPG_EXCHANGE_DIR)"
    else
      log_system WARN "found ${CANDIDATE_PASSPHRASE} but it failed the mode-600 lockdown check -- not auto-filing, pass -P explicitly if you intend to use it"
    fi
  fi
fi

if [[ -n "$PASSPHRASE_FILE" ]]; then
  TARGET="$(mfte_gpg_passphrase_file "$FINGERPRINT")"
  runuser -u "${MFTE_GPG_USER}" -- mkdir -p "${MFTE_GPG_PASSPHRASE_DIR}"
  runuser -u "${MFTE_GPG_USER}" -- chmod 700 "${MFTE_GPG_PASSPHRASE_DIR}"
  runuser -u "${MFTE_GPG_USER}" -- cp "$PASSPHRASE_FILE" "$TARGET"
  runuser -u "${MFTE_GPG_USER}" -- chmod 600 "$TARGET"
  FILED_PASSPHRASE="true"
fi

if [[ "$SET_DEFAULT" == "true" ]]; then
  mfte_gpg_write_default_key_json "$FINGERPRINT" "$UID_STR" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fi

log_system INFO "complete file=${FILE} fingerprint=${FINGERPRINT} uid=\"${UID_STR}\" passphrase_filed=${FILED_PASSPHRASE} default_updated=${SET_DEFAULT}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG private key import complete
  input             : $FILE
  fingerprint       : $FINGERPRINT
  uid               : $UID_STR
  passphrase filed  : $FILED_PASSPHRASE
  default updated   : $SET_DEFAULT
REPORT
fi

exit 0
