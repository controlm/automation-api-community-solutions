#!/usr/bin/env bash
set -o pipefail
umask 022

# file name: smtp-tls-import-cert.sh
# purpose : Fetch the TLS certificate an SMTP server presents (via STARTTLS
#           on the submission port, or implicit TLS on 465), save it as a
#           PEM file, and optionally trust it system-wide on RHEL via
#           update-ca-trust -- the shell-script equivalent of the manual
#           steps in ../../docs/smtp-tls-certificate-trust.md.
#
# origin  : Companion to ldaps-import-cert.sh. The only real difference
#           from the LDAPS case is that SMTP negotiates TLS in-band
#           (STARTTLS) rather than being encrypted from the first byte, so
#           this needs to know which mode the target port speaks.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
if ! source "${SRC_DIR}/lib/bash/cert_trust_common.sh"; then
  echo "ERROR: could not source ${SRC_DIR}/lib/bash/cert_trust_common.sh" >&2
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
  -s  server      SMTP target: host, host:port. Default port: 587
                   (STARTTLS). If omitted, looked up as spring.mail.host /
                   spring.mail.port in -f/-e, then prompted for.
  -I  implicit    use implicit TLS (no STARTTLS negotiation) -- the usual
                   mode for port 465. Default is STARTTLS, unless
                   spring.mail.properties.mail.smtp.starttls.enable=false
                   is found while auto-detecting -s from config.
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
  $SCRIPT_NAME -s "\$\$spring.mail.host\$\$" -i -y -q
USAGE
}

SERVER=""
PROPS_FILE="$DEFAULT_PROPS_PATH"
ENV_FILE="$DEFAULT_ENV_PATH"
OUTPUT=""
DO_IMPORT="false"
ASSUME_YES="false"
QUIET="false"
IMPLICIT_TLS="false"
IMPLICIT_TLS_EXPLICIT="false"

while getopts ':s:f:e:o:iIyqVh' opt; do
  case "$opt" in
    s) SERVER="$OPTARG" ;;
    f) PROPS_FILE="$OPTARG" ;;
    e) ENV_FILE="$OPTARG" ;;
    o) OUTPUT="$OPTARG" ;;
    i) DO_IMPORT="true" ;;
    I) IMPLICIT_TLS="true"; IMPLICIT_TLS_EXPLICIT="true" ;;
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

# Auto-detect SERVER (and, if -I wasn't given explicitly, the STARTTLS
# setting) from hub_config.properties / .env -- same keys ldap_smtp_test.py
# reads via its SMTP_PREFIX_MAP.
if [[ -z "$SERVER" && -f "$PROPS_FILE" ]]; then
  P_HOST="$(grep -E '^spring\.mail\.host[[:space:]]*=' "$PROPS_FILE" | head -1 | cut -d'=' -f2- | sed 's/^ *//;s/ *$//')"
  P_PORT="$(grep -E '^spring\.mail\.port[[:space:]]*=' "$PROPS_FILE" | head -1 | cut -d'=' -f2- | sed 's/^ *//;s/ *$//')"
  if [[ -n "$P_HOST" ]]; then
    SERVER="${P_HOST}${P_PORT:+:${P_PORT}}"
    log INFO "using SMTP host from ${PROPS_FILE}: ${SERVER}"
  fi
  if [[ "$IMPLICIT_TLS_EXPLICIT" != "true" ]]; then
    P_STARTTLS="$(grep -E '^spring\.mail\.properties\.mail\.smtp\.starttls\.enable[[:space:]]*=' "$PROPS_FILE" | head -1 | cut -d'=' -f2- | sed 's/^ *//;s/ *$//')"
    if [[ "$(printf '%s' "$P_STARTTLS" | tr '[:upper:]' '[:lower:]')" == "false" ]]; then
      IMPLICIT_TLS="true"
      log INFO "starttls.enable=false in ${PROPS_FILE} -- using implicit TLS"
    fi
  fi
fi
if [[ -z "$SERVER" && -f "$ENV_FILE" ]]; then
  E_HOST="$(grep -E '^(SMTP_HOST|spring\.mail\.host)[[:space:]]*=' "$ENV_FILE" | head -1 | cut -d'=' -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//')"
  E_PORT="$(grep -E '^(SMTP_PORT|spring\.mail\.port)[[:space:]]*=' "$ENV_FILE" | head -1 | cut -d'=' -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//')"
  if [[ -n "$E_HOST" ]]; then
    SERVER="${E_HOST}${E_PORT:+:${E_PORT}}"
    log INFO "using SMTP host from ${ENV_FILE}: ${SERVER}"
  fi
fi
if [[ -z "$SERVER" ]]; then
  read -r -p "SMTP server (host or host:port): " SERVER
fi
if [[ -z "$SERVER" ]]; then
  echo "ERROR: no SMTP target given." >&2
  exit 2
fi

read -r HOST PORT < <(ct_parse_host_port "$SERVER" 587) || exit 1

STARTTLS_PROTO=""
if [[ "$IMPLICIT_TLS" != "true" ]]; then
  STARTTLS_PROTO="smtp"
fi

log INFO "connecting to ${HOST}:${PORT} ($( [[ -n "$STARTTLS_PROTO" ]] && echo "STARTTLS" || echo "implicit TLS" ))"
PEM="$(ct_fetch_cert "$HOST" "$PORT" "$STARTTLS_PROTO")" || exit 1

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

SMTP TLS certificate export complete
  server            : ${HOST}:${PORT}
  mode              : $( [[ -n "$STARTTLS_PROTO" ]] && echo "STARTTLS" || echo "implicit TLS" )
  saved to          : ${OUTPUT}
  sha256 fingerprint: ${FINGERPRINT}
  system trust store: ${IMPORTED_PATH:-not imported (use -i to import)}
REPORT
fi

exit 0
