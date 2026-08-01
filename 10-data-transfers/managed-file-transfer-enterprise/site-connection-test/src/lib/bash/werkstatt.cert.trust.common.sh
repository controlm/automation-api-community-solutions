#!/usr/bin/env bash

# file name: werkstatt.cert.trust.common.sh
# purpose : Shared helpers for werkstatt.ldaps.cert.import.sh and
#           werkstatt.smtp.cert.import.sh --
#           fetching a server's TLS certificate via openssl, checking whether
#           it's already trusted, and importing it into the RHEL system trust
#           store. Deliberately standalone: this tool tree (site-connection-test)
#           does not source mfte.sh or depend on any of privacy-guard's bash
#           logic, so it still runs on a host without that framework deployed.
#           It does share config/.env's *path and key-naming convention*
#           (bash-safe LDAP_*/SMTP_* vars) with privacy-guard, so the same
#           file can be sourced by mfte.sh once both tool trees are merged
#           onto a hub -- see the "Site Connection Test" section in
#           privacy-guard/src/config/sample.env.
#
# scope   : RHEL/Fedora-family only -- relies on update-ca-trust and the
#           /etc/pki/ca-trust/source/anchors/ layout. Other distros use a
#           different trust-anchor mechanism entirely.

TRUST_ANCHOR_DIR="/etc/pki/ca-trust/source/anchors"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  fi
}

# log LEVEL message...
# Plain stderr logging -- no log file, since there's no MFTE_SYSTEM_LOG_DIR
# in this standalone tool tree. Respects a $QUIET="true" set by the caller,
# except ERROR lines always print.
log() {
  local level="$1"; shift
  if [[ "$QUIET" == "true" && "$level" != "ERROR" ]]; then
    return 0
  fi
  printf '[%s] %s\n' "$level" "$*" >&2
}

# confirm "prompt text"
# Returns 0 (proceed) if $ASSUME_YES="true", otherwise prompts and returns
# the user's y/N answer. Default is "no" -- every caller of this is gating
# either an overwrite or a system trust-store change.
confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" == "true" ]]; then
    return 0
  fi
  local ans
  read -r -p "${prompt} [y/N]: " ans
  [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ct_parse_host_port TARGET DEFAULT_PORT
# Accepts a bare host, host:port, or scheme://host:port (ldaps://, ldap://,
# smtp://, smtps://). Prints "host port" on success. Rejects ldap:// (no TLS
# to export) with a non-zero return.
ct_parse_host_port() {
  local target="$1" default_port="$2" host port scheme rest

  if [[ "$target" == *"://"* ]]; then
    scheme="${target%%://*}"
    rest="${target#*://}"
    if [[ "$(printf '%s' "$scheme" | tr '[:upper:]' '[:lower:]')" == "ldap" ]]; then
      log ERROR "plain ldap:// has no TLS certificate to export -- use ldaps://"
      return 1
    fi
    target="$rest"
  fi

  if [[ "$target" == *:* ]]; then
    host="${target%%:*}"
    port="${target##*:}"
  else
    host="$target"
    port="$default_port"
  fi

  if [[ -z "$host" || ! "$port" =~ ^[0-9]+$ ]]; then
    log ERROR "could not parse host/port from: $1"
    return 1
  fi

  printf '%s %s\n' "$host" "$port"
}

# ct_fetch_cert HOST PORT [STARTTLS_PROTO] > pem-on-stdout
# STARTTLS_PROTO, if given, is passed as `openssl s_client -starttls <proto>`
# (e.g. "smtp"). Omit it for a port that's TLS from the first byte (LDAPS,
# SMTPS/465). Fails loudly rather than silently writing an empty/partial
# file -- openssl s_client can exit 0 even on a failed handshake when its
# stdin is closed via the leading `echo`, so success is judged by whether a
# PEM block actually came out, not by the exit code alone.
ct_fetch_cert() {
  local host="$1" port="$2" starttls="${3:-}"
  local -a args=(-connect "${host}:${port}" -servername "$host")
  [[ -n "$starttls" ]] && args+=(-starttls "$starttls")

  local raw
  if ! raw="$(echo | timeout 15 openssl s_client "${args[@]}" 2>/dev/null)"; then
    log ERROR "openssl s_client failed connecting to ${host}:${port}"
    return 1
  fi

  local pem
  pem="$(printf '%s\n' "$raw" | openssl x509 2>/dev/null)"
  if [[ -z "$pem" ]]; then
    log ERROR "no certificate returned by ${host}:${port} (wrong port, STARTTLS mismatch, or unreachable)"
    return 1
  fi

  printf '%s\n' "$pem"
}

# ct_fingerprint PEM_FILE
ct_fingerprint() {
  openssl x509 -in "$1" -noout -fingerprint -sha256 2>/dev/null | sed -E 's/^.*Fingerprint=//; s/://g'
}

# ct_print_cert_info PEM_FILE
ct_print_cert_info() {
  local f="$1"
  echo "  subject   : $(openssl x509 -in "$f" -noout -subject 2>/dev/null | sed 's/^subject=//')"
  echo "  issuer    : $(openssl x509 -in "$f" -noout -issuer 2>/dev/null | sed 's/^issuer=//')"
  echo "  not before: $(openssl x509 -in "$f" -noout -startdate 2>/dev/null | sed 's/^notBefore=//')"
  echo "  not after : $(openssl x509 -in "$f" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')"
  echo "  sha256 fp : $(ct_fingerprint "$f")"
}

# ct_already_trusted FINGERPRINT
# Prints the matching anchor file path and returns 0 if a certificate with
# this fingerprint is already present in the trust anchor directory.
ct_already_trusted() {
  local fp="$1" f existing_fp
  [[ -d "$TRUST_ANCHOR_DIR" ]] || return 1
  for f in "$TRUST_ANCHOR_DIR"/*.pem "$TRUST_ANCHOR_DIR"/*.crt; do
    [[ -f "$f" ]] || continue
    existing_fp="$(ct_fingerprint "$f")"
    if [[ -n "$existing_fp" && "$existing_fp" == "$fp" ]]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}

# ct_import_to_trust_store PEM_FILE DEST_BASENAME
# Copies PEM_FILE into the trust anchor directory as DEST_BASENAME and runs
# update-ca-trust extract. Both steps require root -- uses sudo, which will
# prompt on its own if this shell doesn't already have a cached ticket.
ct_import_to_trust_store() {
  local pem_file="$1" dest_name="$2"
  local dest_path="${TRUST_ANCHOR_DIR}/${dest_name}"

  if ! sudo cp "$pem_file" "$dest_path"; then
    log ERROR "sudo cp to ${dest_path} failed"
    return 1
  fi
  if ! sudo update-ca-trust extract; then
    log ERROR "update-ca-trust extract failed"
    return 1
  fi
  printf '%s\n' "$dest_path"
}
