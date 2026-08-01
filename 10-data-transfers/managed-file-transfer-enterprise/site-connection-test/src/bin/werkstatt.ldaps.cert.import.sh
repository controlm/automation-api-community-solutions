#!/usr/bin/env bash
set -o pipefail
umask 022

# file name: werkstatt.ldaps.cert.import.sh
# purpose : Fetch the TLS certificate an LDAPS server presents during the
#           handshake, save it as a PEM file, and optionally trust it
#           system-wide on RHEL via update-ca-trust -- the shell-script
#           equivalent of the manual steps in
#           ../../docs/ldaps-certificate-trust.md.
#
# origin  : Follows the "no Java truststore/keytool needed on RHEL" finding
#           in that doc -- openssl is the only dependency, and
#           update-ca-trust already assumes it's present. Fetch-only by
#           default; -i is required to actually touch the system trust
#           store, since that's a shared/system-wide change.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
if ! source "${SRC_DIR}/lib/bash/werkstatt.cert.trust.common.sh"; then
  echo "ERROR: could not source ${SRC_DIR}/lib/bash/werkstatt.cert.trust.common.sh" >&2
  exit 1
fi

_CONTROLM_ENV="${CONTROLM:-}"
if [[ -n "$_CONTROLM_ENV" ]]; then
  DEFAULT_PROPS_PATH="${_CONTROLM_ENV}/cm/AFT/data/hub_config.properties"
else
  DEFAULT_PROPS_PATH="hub_config.properties"
fi
DEFAULT_ENV_PATH="${SRC_DIR}/config/.env"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [-s host[:port]] [options]

Optional:
  -s  server      LDAPS target: host, host:port, or ldaps://host:port.
                   Default port: 636. If omitted, looked up as
                   hub.ldap.ldap-url in -f/-e, then prompted for.
  -f  file        hub_config.properties path for -s auto-detection
                   (default: ${DEFAULT_PROPS_PATH})
  -e  env-file    .env path for -s auto-detection (default: ${DEFAULT_ENV_PATH})
  -o  output      output PEM path (default: ./<host>.pem)
  -i  import      also copy into ${TRUST_ANCHOR_DIR} and run
                   'update-ca-trust extract' (requires sudo). Without this,
                   the certificate is only fetched and saved.
  -y  yes         assume yes to all prompts (overwrite, import) -- for
                   unattended/Control-M use
  -q  quiet       suppress non-essential output
  -V  version
  -h  help

Recommended Run Command (fetch + import, unattended):
  $SCRIPT_NAME -s "\$\$hub.ldap.ldap-url\$\$" -i -y -q
USAGE
}

SERVER=""
PROPS_FILE="$DEFAULT_PROPS_PATH"
ENV_FILE="$DEFAULT_ENV_PATH"
OUTPUT=""
DO_IMPORT="false"
ASSUME_YES="false"
QUIET="false"

while getopts ':s:f:e:o:iyqVh' opt; do
  case "$opt" in
    s) SERVER="$OPTARG" ;;
    f) PROPS_FILE="$OPTARG" ;;
    e) ENV_FILE="$OPTARG" ;;
    o) OUTPUT="$OPTARG" ;;
    i) DO_IMPORT="true" ;;
    y) ASSUME_YES="true" ;;
    q) QUIET="true" ;;
    V) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
    h) usage; exit 0 ;;
    :) echo "Missing value for -$OPTARG" >&2; usage; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
if [[ $# -gt 0 ]]; then
  echo "ERROR: unexpected extra arguments: $*" >&2
  usage
  exit 2
fi

require_command openssl
require_command timeout

# Auto-detect SERVER from hub_config.properties / .env if not given on the
# command line -- same key werkstatt.ldap.smtp.test.py's LDAP_PREFIX_MAP reads.
if [[ -z "$SERVER" && -f "$PROPS_FILE" ]]; then
  SERVER="$(grep -E '^hub\.ldap\.ldap-url[[:space:]]*=' "$PROPS_FILE" | head -1 | cut -d'=' -f2- | sed 's/^ *//;s/ *$//')"
  [[ -n "$SERVER" ]] && log INFO "using LDAP URL from ${PROPS_FILE}: ${SERVER}"
fi
if [[ -z "$SERVER" && -f "$ENV_FILE" ]]; then
  SERVER="$(grep -E '^(LDAP_URL|hub\.ldap\.ldap-url)[[:space:]]*=' "$ENV_FILE" | head -1 | cut -d'=' -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//')"
  [[ -n "$SERVER" ]] && log INFO "using LDAP URL from ${ENV_FILE}: ${SERVER}"
fi
if [[ -z "$SERVER" ]]; then
  read -r -p "LDAPS server (host, host:port, or ldaps://host:port): " SERVER
fi
if [[ -z "$SERVER" ]]; then
  echo "ERROR: no LDAPS target given." >&2
  exit 2
fi

read -r HOST PORT < <(ct_parse_host_port "$SERVER" 636) || exit 1

log INFO "connecting to ${HOST}:${PORT}"
PEM="$(ct_fetch_cert "$HOST" "$PORT")" || exit 1

TMP_PEM="$(mktemp)"
trap 'rm -f "$TMP_PEM"' EXIT
printf '%s\n' "$PEM" > "$TMP_PEM"

if [[ "$QUIET" != "true" ]]; then
  echo "Retrieved certificate:"
  ct_print_cert_info "$TMP_PEM"
fi
FINGERPRINT="$(ct_fingerprint "$TMP_PEM")"

OUTPUT="${OUTPUT:-./${HOST}.pem}"
if [[ -f "$OUTPUT" ]]; then
  if ! confirm "${OUTPUT} already exists -- overwrite?"; then
    echo "Aborted -- not overwriting ${OUTPUT}." >&2
    exit 1
  fi
fi
mkdir -p "$(dirname "$OUTPUT")"
cp "$TMP_PEM" "$OUTPUT"
log INFO "saved certificate to ${OUTPUT}"

IMPORTED_PATH=""
if [[ "$DO_IMPORT" == "true" ]]; then
  require_command sudo
  require_command update-ca-trust

  if EXISTING="$(ct_already_trusted "$FINGERPRINT")"; then
    log INFO "already trusted at ${EXISTING} -- skipping import"
    IMPORTED_PATH="$EXISTING (already present)"
  else
    if confirm "Import into ${TRUST_ANCHOR_DIR} and run update-ca-trust extract?"; then
      IMPORTED_PATH="$(ct_import_to_trust_store "$TMP_PEM" "${HOST}.pem")" || exit 1
      log INFO "imported into system trust store: ${IMPORTED_PATH}"
    else
      echo "Skipped system trust import." >&2
    fi
  fi
fi

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT

LDAPS certificate export complete
  server            : ${HOST}:${PORT}
  saved to          : ${OUTPUT}
  sha256 fingerprint: ${FINGERPRINT}
  system trust store: ${IMPORTED_PATH:-not imported (use -i to import)}
REPORT
fi

exit 0
