#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.export.key.sh
# purpose : Export a public key (to hand to a partner) or, with -s, a
#           private key (e.g. to migrate mftgpg's identity to another
#           host) from the mftgpg keyring.
#
# origin  : Hardened, production-like-demo version of a training script
#           that generated a random passphrase on demand and printed it,
#           and wrote it into a plaintext dsse.gpg.info.json. This version
#           never generates a passphrase -- export only ever uses the
#           passphrase already on file for an existing key (see
#           werkstatt.gpg.generate.key.sh / werkstatt.gpg.import.private.key.sh for
#           where that file comes from) -- and never prints or logs it.
#
# note    : Public key export needs no passphrase (verified against this
#           gpg version). Secret key export DOES require one -- gpg's
#           agent won't hand over secret key material for export without
#           it, confirmed by reproducing "error receiving key from agent"
#           without --passphrase-file and a clean export with it. So -s
#           follows the same --pinentry-mode loopback --passphrase-file
#           pattern as werkstatt.gpg.decrypt.file.sh, not a plain --export.
#
# -W      : By default, -s exports ONLY the private key -- the passphrase
#           that protects it stays where it is, transferred separately
#           and out of band (see werkstatt.gpg.import.private.key.sh -P).
#           That split is deliberate: bundling a private key export with
#           its own passphrase in the same output undoes the reason the
#           passphrase is a separate file at all -- anyone who gets the
#           export folder gets both the lock and the key to it. -W is an
#           explicit opt-in to bundle them anyway (writes a sibling
#           <fingerprint>.passphrase file next to the key export), for
#           cases where the whole bundle is already being handled as one
#           sensitive unit (e.g. a controlled hub-to-hub migration). Not
#           the default, so this tradeoff is a decision each time, not
#           something that happens silently.

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
  -k  key         fingerprint to export, default: fingerprint in default-key.json
  -s  secret      export the PRIVATE key instead of the public key
  -o  output      output path, default: \$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.<public|private>.asc
  -b  binary      write binary OpenPGP output instead of ASCII-armored
  -W  with-pass   secret export only (-s): also write the key's passphrase
                   file alongside it, as <output-dir>/<fingerprint>.passphrase.
                   WEAKENS the two-channel transfer design -- see the -W
                   note near the top of this file before using it. Ignored
                   (with a warning) if -s wasn't also given.
  -q  quiet
  -h  help

Exporting a private key (-s) produces sensitive material. Verified against
this gpg version: gpg itself writes secret-key export output at mode 600
regardless of the process umask, so the file starts locked down. That's
gpg's own safety default, not something this script enforces -- don't
rely on it if you copy/move the file elsewhere (e.g. staging it for
werkstatt.gpg.import.private.key.sh on another host); set permissions
explicitly at the destination too. The same applies to the -W passphrase
sibling file: it's written at 600, but treat the whole export -- key and
passphrase together -- as one sensitive unit from that point on.

Recommended Run Command:
  $SCRIPT_NAME -q
  $SCRIPT_NAME -k "<fingerprint>" -s -o "/secure/staging/key.private.asc" -q
USAGE
}

KEY_FP=""
SECRET="false"
OUTPUT=""
ARMOR="true"
WITH_PASSPHRASE="false"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':k:o:sbWqh' opt; do
  case "$opt" in
    k) KEY_FP="$(mfte_gpg_sanitize_key_id "$(mfte_unquote "$OPTARG")")" ;;
    o) OUTPUT="$(mfte_unquote "$OPTARG")" ;;
    s) SECRET="true" ;;
    b) ARMOR="false" ;;
    W) WITH_PASSPHRASE="true" ;;
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

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

if [[ "$WITH_PASSPHRASE" == "true" && "$SECRET" != "true" ]]; then
  log_system WARN "-W given without -s -- ignored (nothing to bundle for a public key export)"
  echo "WARNING: -W only applies to a secret key export (-s) -- ignored." >&2
  WITH_PASSPHRASE="false"
fi

if [[ -z "$KEY_FP" ]]; then
  KEY_FP="$(mfte_gpg_default_fingerprint)"
fi
if [[ -z "$KEY_FP" ]]; then
  log_system ERROR "no -k key given and no default-key.json found"
  echo "ERROR: no -k key given, and no default key is recorded in ${MFTE_GPG_META_DIR}/default-key.json." >&2
  exit 1
fi

log_system INFO "start key=${KEY_FP} secret=${SECRET} armor=${ARMOR}"

if [[ -z "$OUTPUT" ]]; then
  mkdir -p "${MFTE_GPG_EXCHANGE_DIR}"
  SUFFIX="public"
  [[ "$SECRET" == "true" ]] && SUFFIX="private"
  EXT="asc"
  [[ "$ARMOR" != "true" ]] && EXT="gpg"
  OUTPUT="${MFTE_GPG_EXCHANGE_DIR}/${KEY_FP}.${SUFFIX}.${EXT}"
else
  mkdir -p "$(dirname "$OUTPUT")"
fi

GPG_ARGS=(--batch --yes --output "$OUTPUT")
[[ "$ARMOR" == "true" ]] && GPG_ARGS+=(--armor)

if [[ "$SECRET" == "true" ]]; then
  PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$KEY_FP")"
  if ! mfte_gpg_require_locked_down "$PASSPHRASE_FILE" 600; then
    log_system ERROR "passphrase file failed lockdown check for key=${KEY_FP}"
    echo "ERROR: passphrase file for key ${KEY_FP} is missing or not properly locked down -- cannot export the private key." >&2
    exit 1
  fi
  GPG_ARGS+=(--pinentry-mode loopback --passphrase-file "$PASSPHRASE_FILE" --export-secret-keys "$KEY_FP")
else
  GPG_ARGS+=(--export "$KEY_FP")
fi

if ! EXPORT_OUTPUT="$(mfte_gpg_run "${GPG_ARGS[@]}" 2>&1)"; then
  log_system ERROR "export failed key=${KEY_FP} secret=${SECRET}"
  echo "ERROR: export failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${EXPORT_OUTPUT}"
  exit 1
fi

if [[ ! -s "$OUTPUT" ]]; then
  log_system ERROR "export produced an empty file key=${KEY_FP} secret=${SECRET} output=${OUTPUT}"
  echo "ERROR: export completed with no error but ${OUTPUT} is empty -- was ${KEY_FP} a valid, present key?" >&2
  exit 1
fi

PASSPHRASE_BUNDLED="false"
PASSPHRASE_OUTPUT=""
if [[ "$SECRET" == "true" && "$WITH_PASSPHRASE" == "true" ]]; then
  PASSPHRASE_OUTPUT="$(dirname "$OUTPUT")/${KEY_FP}.passphrase"
  # Copied as MFTE_GPG_USER (mfte_gpg_copy_passphrase_as_user), not as
  # whatever identity is running this script (root, in production) -- a
  # plain `cp` here would leave the bundled file owned by root, unlike
  # its sibling key export, which gpg itself already writes as mftgpg.
  if ! mfte_gpg_copy_passphrase_as_user "$PASSPHRASE_FILE" "$PASSPHRASE_OUTPUT"; then
    log_system ERROR "failed to write bundled passphrase file key=${KEY_FP} target=${PASSPHRASE_OUTPUT}"
    echo "ERROR: key export succeeded but writing the bundled passphrase file failed: ${PASSPHRASE_OUTPUT}" >&2
    exit 1
  fi
  PASSPHRASE_BUNDLED="true"
fi

log_system INFO "complete key=${KEY_FP} secret=${SECRET} output=${OUTPUT} passphrase_bundled=${PASSPHRASE_BUNDLED}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG key export complete
  fingerprint       : $KEY_FP
  type              : $([[ "$SECRET" == "true" ]] && echo "PRIVATE (sensitive)" || echo "public")
  output            : $OUTPUT
REPORT
  if [[ "$PASSPHRASE_BUNDLED" == "true" ]]; then
    cat <<REPORT
  passphrase        : $PASSPHRASE_OUTPUT (mode 600 -- handle together with the key above as one sensitive unit)
REPORT
  fi
fi

exit 0
