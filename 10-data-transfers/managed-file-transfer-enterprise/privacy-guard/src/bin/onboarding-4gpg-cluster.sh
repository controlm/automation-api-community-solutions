#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: onboarding-4gpg-cluster.sh
# purpose : Companion to onboarding-4gpg-server.sh -- run on EACH hub in
#           the cluster (the one onboarding-4gpg-server.sh already ran on
#           included; it's harmless there, see below) to pick up every
#           customer key staged in $MFTE_GPG_ONBOARDING_PRIVACY_DIR and
#           import BOTH the private key AND its passphrase into this
#           node's own keyring in one pass.
#
# why this ISN'T just werkstatt.gpg.import.all.private.sh: that script
# deliberately does NOT file passphrases -- scanning an arbitrary
# directory of key files gives it no reliable way to know which
# passphrase file (if any) belongs to which of N keys, so it requires an
# explicit werkstatt.gpg.import.passphrase.sh follow-up per key instead of
# guessing. This script doesn't have that problem: it only ever looks at
# $MFTE_GPG_ONBOARDING_PRIVACY_DIR, where onboarding-4gpg-server.sh
# guarantees every <fingerprint>.private.asc has a matching
# <fingerprint>.passphrase sibling (same naming convention as
# werkstatt.gpg.export.key.sh -s -W). That guarantee is exactly what
# makes it safe for this script to file passphrases automatically where
# import.all.private.sh can't.
#
# idempotent: a fingerprint whose secret half is already present on this
# node is skipped, not re-imported or re-filed -- safe to run repeatedly,
# including re-running it on a node that already has some (or all) of the
# keys in the directory, e.g. after onboarding several new customers in a
# row and wanting to sync all of them to every hub in one pass.
#
# each file is inspected (never imported blind) the same way
# werkstatt.gpg.import.all.public.sh / .private.sh do, via
# mfte_gpg_file_show_only/mfte_gpg_file_fingerprint/mfte_gpg_file_has_secret
# -- filenames are a convention here, not trusted on their own.
#
# exit codes:
#   0  ran to completion with zero real failures (individual files may
#      still have been skipped for any of the reasons above -- see the
#      per-file report and the summary counts)
#   1  at least one file that should have imported cleanly did not (import
#      failure, missing passphrase sibling, or a passphrase file that
#      failed its lockdown check); other files in the same run were still
#      attempted -- see the report for which one(s) failed
#   2  usage error (bad/missing flags, directory doesn't exist, or
#      $MFTE_GPG_USER cannot read the directory at all)

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

# Same optional-with-default convention as onboarding-4gpg-server.sh --
# see that script's header comment for why this isn't in mfte.gpg.sh's
# hard-required ":?" block, and why the default nests under
# $MFTE_GPG_EXCHANGE_DIR (already required, already mftgpg-writable)
# rather than a freshly-invented path. Must resolve to the SAME directory
# onboarding-4gpg-server.sh wrote to -- if you override one with -P
# there, override this with -d here to match.
MFTE_GPG_ONBOARDING_PRIVACY_DIR="${MFTE_GPG_ONBOARDING_PRIVACY_DIR:-${MFTE_GPG_EXCHANGE_DIR}/onboarding}"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Optional:
  -d  directory   default: \$MFTE_GPG_ONBOARDING_PRIVACY_DIR
  -q  quiet       suppress the per-file + summary report (errors for real
                   failures still print). Skips are never printed to
                   stderr regardless of -q -- they aren't errors.
  -h  help

Run this on every hub in the cluster after onboarding-4gpg-server.sh
generates a new customer key on one of them -- including that same hub is
harmless, the key it just generated locally is already present and will
simply be skipped as "already present".

Recommended Run Command (once per hub):
  $SCRIPT_NAME -q
USAGE
}

DIR="${MFTE_GPG_ONBOARDING_PRIVACY_DIR}"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':d:qh' opt; do
  case "$opt" in
    d) DIR="$(mfte_unquote "$OPTARG")" ;;
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

if [[ ! -d "$DIR" ]]; then
  log_system ERROR "directory not found: ${DIR}"
  echo "ERROR: directory not found: ${DIR}" >&2
  exit 2
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

# Check this up front, as mftgpg specifically -- not as whatever identity
# is running this script (root, typically, per no_root_squash) -- so a
# permission problem surfaces as one clear error here instead of N
# confusing per-file failures below. See the README's "NFS / shared-
# storage considerations for GPG" section; this is the same class of
# mistake that cost a full day of debugging werkstatt.gpg.receive.file.sh
# earlier in this project.
if ! runuser -u "${MFTE_GPG_USER}" -- test -r "$DIR"; then
  log_system ERROR "${MFTE_GPG_USER} cannot read directory: ${DIR}"
  echo "ERROR: ${MFTE_GPG_USER} cannot read ${DIR}. A root shell succeeding here proves nothing --" >&2
  echo "this export very likely has no_root_squash set, which makes root's own access" >&2
  echo "meaningless as a permission test. See the README's \"NFS / shared-storage" >&2
  echo "considerations for GPG\" section." >&2
  exit 2
fi

log_system INFO "start dir=${DIR}"

# Top-level *.private.asc files only, sorted for a stable/repeatable run
# order -- matches onboarding-4gpg-server.sh's own naming convention
# exactly (<fingerprint>.private.asc + sibling <fingerprint>.passphrase).
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "$DIR" -maxdepth 1 -type f -name '*.private.asc' -print0 | sort -z)

SCANNED=0
IMPORTED=0
ALREADY_PRESENT=0
SKIPPED_OTHER=0
FAILED=0
REPORT_LINES=()

for FILE in "${FILES[@]}"; do
  SCANNED=$((SCANNED + 1))
  BASE="$(basename "$FILE")"

  if ! SHOW_OUTPUT="$(mfte_gpg_file_show_only "$FILE" 2>&1)"; then
    log_system INFO "skip file=${FILE} reason=not_a_key_file"
    log_system DEBUG "gpg show-only output: ${SHOW_OUTPUT}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=not_a_key_file")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  FP="$(mfte_gpg_file_fingerprint "$SHOW_OUTPUT")"
  if [[ -z "$FP" ]]; then
    log_system INFO "skip file=${FILE} reason=not_a_key_file"
    REPORT_LINES+=("SKIP      ${BASE}  reason=not_a_key_file")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  HAS_SECRET="$(mfte_gpg_file_has_secret "$SHOW_OUTPUT")"
  if [[ "$HAS_SECRET" != "true" ]]; then
    log_system INFO "skip file=${FILE} reason=public_key_file fingerprint=${FP}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=public_key_file  fp=${FP}")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  if mfte_gpg_lookup_fingerprint "$FP" secret >/dev/null 2>&1; then
    log_system INFO "skip file=${FILE} reason=already_present fingerprint=${FP}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=already_present  fp=${FP}")
    ALREADY_PRESENT=$((ALREADY_PRESENT + 1))
    continue
  fi

  PASSPHRASE_SIBLING="${DIR}/${FP}.passphrase"
  if [[ ! -e "$PASSPHRASE_SIBLING" ]]; then
    log_system ERROR "missing passphrase sibling file=${FILE} fingerprint=${FP} expected=${PASSPHRASE_SIBLING}"
    echo "ERROR: ${BASE} (fingerprint ${FP}) has no matching ${FP}.passphrase in ${DIR}." >&2
    REPORT_LINES+=("FAILED    ${BASE}  fp=${FP}  reason=missing_passphrase_sibling")
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! mfte_gpg_require_locked_down "$PASSPHRASE_SIBLING" 600; then
    log_system ERROR "passphrase sibling failed lockdown check file=${PASSPHRASE_SIBLING} fingerprint=${FP}"
    REPORT_LINES+=("FAILED    ${BASE}  fp=${FP}  reason=passphrase_not_locked_down")
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! IMPORT_OUTPUT="$(mfte_gpg_import_key "$FILE" private 2>&1)"; then
    log_system ERROR "import failed file=${FILE} fingerprint=${FP}"
    log_system DEBUG "gpg output: ${IMPORT_OUTPUT}"
    echo "ERROR: import failed for ${FILE} (fingerprint ${FP}). See ${SYSTEM_LOG_FILE} for details." >&2
    REPORT_LINES+=("FAILED    ${BASE}  fp=${FP}  reason=import_failed (see log)")
    FAILED=$((FAILED + 1))
    continue
  fi

  IMPORTED_FP="$(mfte_gpg_import_fingerprint "$IMPORT_OUTPUT")"
  if [[ -z "$IMPORTED_FP" ]]; then
    # gpg ran without error but reported no IMPORT_OK -- the pre-check
    # above already ruled out "already present", so this is most likely a
    # race against another node's import of the same file (unlikely but
    # not impossible if this is run concurrently). Not treated as a
    # failure -- the gpg call itself succeeded.
    log_system INFO "skip file=${FILE} reason=no_change fingerprint=${FP}"
    REPORT_LINES+=("SKIP      ${BASE}  reason=no_change  fp=${FP}")
    SKIPPED_OTHER=$((SKIPPED_OTHER + 1))
    continue
  fi

  # File the passphrase into its standard fingerprint-keyed location --
  # same explicit mkdir+chmod700+cp+chmod600 sequence as
  # werkstatt.gpg.import.private.key.sh's own -P handling, for consistency
  # with that script's established pattern.
  TARGET_PASSPHRASE="$(mfte_gpg_passphrase_file "$IMPORTED_FP")"
  runuser -u "${MFTE_GPG_USER}" -- mkdir -p "${MFTE_GPG_PASSPHRASE_DIR}"
  runuser -u "${MFTE_GPG_USER}" -- chmod 700 "${MFTE_GPG_PASSPHRASE_DIR}"
  runuser -u "${MFTE_GPG_USER}" -- cp "$PASSPHRASE_SIBLING" "$TARGET_PASSPHRASE"
  runuser -u "${MFTE_GPG_USER}" -- chmod 600 "$TARGET_PASSPHRASE"

  UID_STR="$(mfte_gpg_uid_for_fingerprint "$IMPORTED_FP" secret)"
  log_system INFO "imported file=${FILE} fingerprint=${IMPORTED_FP} uid=\"${UID_STR}\" passphrase_filed=true"
  REPORT_LINES+=("IMPORTED  ${BASE}  fp=${IMPORTED_FP}  uid=\"${UID_STR}\"  passphrase: filed")
  IMPORTED=$((IMPORTED + 1))
done

log_system INFO "complete dir=${DIR} scanned=${SCANNED} imported=${IMPORTED} already_present=${ALREADY_PRESENT} skipped_other=${SKIPPED_OTHER} failed=${FAILED}"

if [[ "$QUIET" != "true" ]]; then
  if [[ "${#REPORT_LINES[@]}" -gt 0 ]]; then
    printf '%s\n' "${REPORT_LINES[@]}"
  fi
  cat <<REPORT

GPG cluster onboarding import complete
  host              : $(hostname -f 2>/dev/null || hostname)
  directory         : $DIR
  files scanned     : $SCANNED
  imported          : $IMPORTED
  already present   : $ALREADY_PRESENT
  skipped (other)   : $SKIPPED_OTHER
  failed            : $FAILED
REPORT
fi

[[ "$FAILED" -gt 0 ]] && exit 1
exit 0
