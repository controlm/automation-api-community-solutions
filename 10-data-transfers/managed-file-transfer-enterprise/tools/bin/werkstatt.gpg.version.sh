#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.version.sh
# purpose : Print the version of every werkstatt.*.sh / mfte.*.sh script
#           and library actually deployed on THIS node, in one command --
#           built directly to answer "do we have the wrong/outdated script
#           on this server", node by node, without having to check each
#           file's SCRIPT_VERSION by hand or trust that a deploy actually
#           reached every cluster member.
#
# scope   : Reads SCRIPT_VERSION="..." out of every bin/*.sh next to this
#           script, and the three known *_VERSION constants out of the lib
#           files this framework currently has. Pure static grep against
#           file contents -- runs no other script, executes no gpg or
#           vault calls, has no dependency beyond what mfte.sh itself
#           already requires.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"

# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.sh" >&2
  exit 1
fi

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Optional:
  -j  json        emit as JSON instead of a plain table
  -V  version     print this script's own name and version, then exit
  -h  help

Prints:
  - this node's hostname (so output copy-pasted between nodes is
    unambiguous about which node it came from)
  - every bin/*.sh script's SCRIPT_VERSION
  - the version of every lib/bash/*.sh library currently deployed

Recommended Run Command:
  $SCRIPT_NAME
USAGE
}

JSON="false"

while getopts ':jVh' opt; do
  case "$opt" in
    j) JSON="true" ;;
    V) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
    h) usage; exit 0 ;;
    :) echo "Missing value for -$OPTARG" >&2; usage; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
if ! mfte_check_no_leftover_args "$@"; then
  echo "ERROR: unexpected extra arguments." >&2
  exit 2
fi

BIN_DIR="${SCRIPT_DIR}"
LIB_BASH_DIR="${MFTE_LIB_DIR}/bash"

declare -a SCRIPT_NAMES SCRIPT_VERSIONS
for f in "${BIN_DIR}"/*.sh; do
  [[ -f "$f" ]] || continue
  v="$(grep -m1 '^SCRIPT_VERSION=' "$f" | sed -E 's/^SCRIPT_VERSION="?([^"]*)"?/\1/')"
  SCRIPT_NAMES+=("$(basename "$f")")
  SCRIPT_VERSIONS+=("${v:-<no version found>}")
done

declare -a LIB_NAMES LIB_VERSIONS
for f in "${LIB_BASH_DIR}"/*.sh; do
  [[ -f "$f" ]] || continue
  v="$(grep -m1 -E '^MFTE_[A-Z_]*_VERSION=' "$f" | sed -E 's/^[A-Z_]+_VERSION="?([^"]*)"?/\1/')"
  LIB_NAMES+=("$(basename "$f")")
  LIB_VERSIONS+=("${v:-<no version found>}")
done

if [[ "$JSON" == "true" ]]; then
  printf '{"host":"%s","scripts":{' "$(hostname -f 2>/dev/null || hostname)"
  for i in "${!SCRIPT_NAMES[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s":"%s"' "${SCRIPT_NAMES[$i]}" "${SCRIPT_VERSIONS[$i]}"
  done
  printf '},"libraries":{'
  for i in "${!LIB_NAMES[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s":"%s"' "${LIB_NAMES[$i]}" "${LIB_VERSIONS[$i]}"
  done
  printf '}}\n'
else
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  echo
  echo "=== bin/ scripts ==="
  for i in "${!SCRIPT_NAMES[@]}"; do
    printf '  %-45s %s\n' "${SCRIPT_NAMES[$i]}" "${SCRIPT_VERSIONS[$i]}"
  done
  echo
  echo "=== lib/bash/ libraries ==="
  for i in "${!LIB_NAMES[@]}"; do
    printf '  %-45s %s\n' "${LIB_NAMES[$i]}" "${LIB_VERSIONS[$i]}"
  done
fi

exit 0
