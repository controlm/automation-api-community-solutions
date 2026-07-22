#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.encrypt.file.sh
# purpose : Encrypt a file to a recipient's public key, held by the
#           mftgpg service account.
#
# origin  : Hardened, production-like-demo version of a training script.
#           One deliberate design change beyond hardening: the original
#           also took a passphrase and did an immediate list-packets
#           round-trip check as a teaching aid, so a student could see
#           encrypt and (partial) decrypt happen back to back. Public-key
#           encryption never actually needs the recipient's passphrase --
#           that's the point of asymmetric crypto -- so this version
#           doesn't touch private key material at all here. Use
#           werkstatt.gpg.decrypt.file.sh separately to verify a round trip.
#
# trust   : Encrypting to a key gpg doesn't yet trust will fail unattended
#           ("It is NOT certain that the key belongs to..."). This script
#           defaults to --trust-model always, which is safe PROVIDED the
#           only public keys ever imported into MFTE_GPG_HOME are keys
#           whose fingerprint was verified out of band (see
#           werkstatt.gpg.fingerprint.file.sh) before import -- at that point
#           every key in the ring is already someone you deliberately
#           trusted, so gpg's separate web-of-trust signing step is
#           redundant, not skipped carelessly. Override with -T if a given
#           deployment wants gpg's normal trust checks instead.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"

# shellcheck source=/dev/null
source "${MFTE_LIB_DIR}/bash/mfte.sh"
# shellcheck source=/dev/null
source "${MFTE_LIB_DIR}/bash/mfte.gpg.sh"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME -f "<file>" -r "<recipient>" [options]

Required:
  -f  file        path to the file to encrypt
  -r  recipient   recipient identifier: email, uid substring, or fingerprint
                   (must resolve to exactly one key already in MFTE_GPG_HOME)

Optional:
  -o  output      output path, default: \$MFTE_GPG_OUTPUT_DIR/<name>.asc (or .gpg with -b)
  -b  binary      write binary OpenPGP output instead of ASCII-armored (.gpg not .asc)
  -T  trust model gpg --trust-model value, default: always (see header comment)
  -q  quiet
  -h  help

Recommended Run Command:
  $SCRIPT_NAME -f "\$\$FILE_ABS_PATH\$\$" -r "partner@example.com" -q
USAGE
}

FILE=""
RECIPIENT=""
OUTPUT=""
ARMOR="true"
TRUST_MODEL="${MFTE_GPG_TRUST_MODEL:-always}"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':f:r:o:T:bqh' opt; do
  case "$opt" in
    f) FILE="$(mfte_unquote "$OPTARG")" ;;
    r) RECIPIENT="$(mfte_unquote "$OPTARG")" ;;
    o) OUTPUT="$(mfte_unquote "$OPTARG")" ;;
    T) TRUST_MODEL="$(mfte_unquote "$OPTARG")" ;;
    b) ARMOR="false" ;;
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

if [[ -z "$FILE" || -z "$RECIPIENT" ]]; then
  log_system ERROR "missing required -f and/or -r"
  echo "ERROR: -f file and -r recipient are both required." >&2
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

log_system INFO "start file=${FILE} recipient=${RECIPIENT} armor=${ARMOR} trust_model=${TRUST_MODEL}"

RECIPIENT_FP="$(mfte_gpg_lookup_fingerprint "$RECIPIENT" public)"
if [[ -z "$RECIPIENT_FP" ]]; then
  log_system ERROR "recipient did not resolve to exactly one key: ${RECIPIENT}"
  echo "ERROR: recipient \"${RECIPIENT}\" did not resolve to exactly one public key in ${MFTE_GPG_HOME}." >&2
  echo "Check spelling, or that the key was imported (werkstatt.gpg.import.public.key.sh)." >&2
  exit 1
fi

if [[ -z "$OUTPUT" ]]; then
  mkdir -p "${MFTE_GPG_OUTPUT_DIR}"
  if [[ "$ARMOR" == "true" ]]; then
    OUTPUT="${MFTE_GPG_OUTPUT_DIR}/$(basename "$FILE").asc"
  else
    OUTPUT="${MFTE_GPG_OUTPUT_DIR}/$(basename "$FILE").gpg"
  fi
else
  mkdir -p "$(dirname "$OUTPUT")"
fi

GPG_ARGS=(--batch --yes --trust-model "$TRUST_MODEL" --recipient "$RECIPIENT_FP" --output "$OUTPUT")
[[ "$ARMOR" == "true" ]] && GPG_ARGS+=(--armor)
GPG_ARGS+=(--encrypt "$FILE")

if ! ENC_OUTPUT="$(mfte_gpg_run "${GPG_ARGS[@]}" 2>&1)"; then
  log_system ERROR "encryption failed file=${FILE} recipient_fp=${RECIPIENT_FP}"
  echo "ERROR: encryption failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${ENC_OUTPUT}"
  exit 1
fi

CHECKSUM=""
if [[ -f "$OUTPUT" ]]; then
  CHECKSUM="$(sha256sum "$OUTPUT" 2>/dev/null | awk '{print $1}')"
  [[ -z "$CHECKSUM" ]] && CHECKSUM="$(shasum -a 256 "$OUTPUT" 2>/dev/null | awk '{print $1}')"
fi

log_system INFO "complete file=${FILE} recipient_fp=${RECIPIENT_FP} output=${OUTPUT} sha256=${CHECKSUM}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG encryption complete
  input             : $FILE
  recipient         : $RECIPIENT
  recipient fpr     : $RECIPIENT_FP
  output            : $OUTPUT
  output sha256     : $CHECKSUM
REPORT
fi

exit 0
