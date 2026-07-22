#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: onboarding-4gpg-server.sh
# purpose : Demo/convenience wrapper for onboarding one new customer onto
#           the "one dedicated key per customer" GPG pattern in a single
#           step: generate a fresh keypair for them, then export both
#           halves to where the rest of the workflow expects to find them
#             - PRIVATE key + its passphrase file -> $MFTE_GPG_ONBOARDING_PRIVACY_DIR
#               (shared NFS, /opt/werkstatt/... by default) for
#               onboarding-4gpg-cluster.sh to pick up on every hub
#             - PUBLIC key only               -> $MFTE_GPG_ONBOARDING_B2B_DIR/<email>/
#               (/mnt/ftshome/... by default) for the customer to collect
#               and use to encrypt files back to us
#
# NOT a replacement for werkstatt.gpg.generate.key.sh / export.key.sh --
# this script duplicates their core gpg sequences inline rather than
# invoking them as subprocesses, the same way werkstatt.gpg.import.all.*.sh
# duplicate rather than chain werkstatt.gpg.import.*.key.sh. Every actual
# gpg call still goes through the same mfte_gpg_run/mfte.gpg.sh helpers
# those scripts use, so the result is identical -- a normal key this
# framework's other scripts can use without knowing it came from here.
#
# NEVER sets this key as the default (no default-key.json update, ever --
# unlike werkstatt.gpg.generate.key.sh, there's no -N flag to skip it here
# because skipping it is the ONLY behavior). The whole point of the
# one-key-per-customer pattern (see werkstatt.gpg.receive.file.sh's own
# header comment) is that there is no single default identity -- every
# onboarded customer's key exists purely to be found by its own recipient
# match at decrypt time.
#
# two different NFS exports, two different write paths:
#   $MFTE_GPG_ONBOARDING_PRIVACY_DIR defaults to a subdirectory of
#   $MFTE_GPG_EXCHANGE_DIR specifically so it inherits a write path
#   mftgpg is ALREADY proven to use (export.key.sh's own default output
#   location) rather than needing fresh NFS ACL/ownership setup of its
#   own -- see the README's "NFS / shared-storage considerations for GPG"
#   section for what that setup looks like if you override -P to
#   somewhere new instead. The private key + its passphrase are written
#   there DIRECTLY by gpg running as mftgpg.
#
#   $MFTE_GPG_ONBOARDING_B2B_DIR lives under /mnt/ftshome/... instead --
#   root-only from mftgpg's perspective, same as every other /mnt/ftshome
#   path in this framework (see werkstatt.gpg.receive.file.sh's "return"
#   section and ISSUES.md). So the PUBLIC key is exported by mftgpg to a
#   staging file under $MFTE_GPG_EXCHANGE_DIR first (mftgpg-writable,
#   already an existing grant), then relocated to its final
#   /mnt/ftshome/.../<email>/ destination by THIS script's own identity
#   (root, per Control-M's invocation model / however this is actually
#   run) -- no new mftgpg permission grant needed on /mnt/ftshome, exactly
#   the same reasoning as receive.file.sh's return-path relocation.
#
# risk    : $MFTE_GPG_ONBOARDING_PRIVACY_DIR ends up holding a private key
#           AND its passphrase together, unencrypted-at-rest beyond
#           filesystem permissions, on shared NFS storage, specifically so
#           onboarding-4gpg-cluster.sh can pick both up on every hub
#           without a human relaying the passphrase out of band. That is a
#           real weakening of the two-channel transfer design every other
#           script in this framework goes out of its way to preserve (see
#           export.key.sh's own -W warning) -- accepted here deliberately,
#           for demo convenience, not a mistake. Clean up
#           $MFTE_GPG_ONBOARDING_PRIVACY_DIR once every hub has imported;
#           this script does not do that for you.
#
# resume  : If a secret key already resolves for the given email, this
#           script does NOT always refuse outright -- it checks whether
#           BOTH exports (private+passphrase in the privacy dir, public
#           key at the B2B destination) are actually present first. If
#           either is missing, it treats this as an INTERRUPTED prior run
#           (e.g. the export step failed after key generation already
#           succeeded -- a real failure mode, not hypothetical: a stray
#           root-owned onboarding directory did exactly this once) and
#           resumes from the export step using the existing key, rather
#           than generating a brand new one. Only a FULLY already-staged
#           customer is refused outright (exit 3, see below) -- that's the
#           "did you mean -F" case, not the "let me finish what already
#           started" case.
#
# exit codes:
#   0  onboarded successfully -- key generated (or reused, see "resume"
#      above), both exports placed
#   1  technical error (key generation, export, or relocation failed)
#   2  usage error (bad/missing flags, invalid email)
#   3  a secret key already resolves for this email AND both exports are
#      already fully staged -- refused without -F. Distinct from 1 so a
#      re-run against a genuinely-already-complete customer can be told
#      apart from an actual failure. A PARTIALLY staged customer does not
#      hit this code -- see "resume" above.

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

# Optional .env overrides, both with built-in defaults -- deliberately NOT
# added to mfte.gpg.sh's hard-required ":?" block, since that block is
# sourced by every werkstatt.gpg.*.sh script already deployed and in use;
# making these required would break every one of them on hosts whose .env
# predates this script.
#
# PRIVACY_DIR's default nests under $MFTE_GPG_EXCHANGE_DIR (already
# hard-required, already an established mftgpg-writable location -- see
# import.all.public.sh/.private.sh, export.key.sh's own default output)
# rather than a brand-new path, specifically so onboarding doesn't need
# its own fresh NFS ACL/ownership setup on top of what's already working.
# find -maxdepth 1 in the batch import scripts never descends into this
# "onboarding" subdirectory, so nesting here doesn't leak into their scans.
#
# B2B_DIR's default composes from $MFTE_B2B_HOME if set (not itself
# required anywhere in this framework -- purely a convenience so this
# path and any other B2B-rooted path in your own .env share one base
# instead of repeating the literal /mnt/ftshome/b2bhome).
MFTE_GPG_ONBOARDING_PRIVACY_DIR="${MFTE_GPG_ONBOARDING_PRIVACY_DIR:-${MFTE_GPG_EXCHANGE_DIR}/onboarding}"
MFTE_GPG_ONBOARDING_B2B_DIR="${MFTE_GPG_ONBOARDING_B2B_DIR:-${MFTE_B2B_HOME:-/mnt/ftshome/b2bhome}/secureTransport/onboarding}"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME -n "<name>" -m "<email>" [options]

Required:
  -n  name        customer/user display name, e.g. "ACME Finance"
  -m  email       customer email address, e.g. "finance@acme.example.com"
                   -- also used as a directory segment under the B2B
                   export path, so it's validated as a plain email
                   (no "/", no whitespace) before anything happens

Optional:
  -t  key type      default: rsa4096
  -x  expire        default: 0 (never expires) -- gpg expiry syntax, e.g. 2y
  -F  force         generate an ADDITIONAL key even if this email is
                     already fully onboarded (normally refused, exit 3 --
                     see exit codes in the header comment). You will
                     likely need to disambiguate fingerprints manually
                     afterward (export.key.sh -k). NOT needed to resume an
                     INCOMPLETE prior onboarding (existing key, missing
                     export(s)) -- that happens automatically, see the
                     header comment's "resume" section.
  -P  dir           override \$MFTE_GPG_ONBOARDING_PRIVACY_DIR
                     default: \$MFTE_GPG_EXCHANGE_DIR/onboarding
  -B  dir           override \$MFTE_GPG_ONBOARDING_B2B_DIR
                     default: \${MFTE_B2B_HOME:-/mnt/ftshome/b2bhome}/secureTransport/onboarding
  -q  quiet
  -h  help

On success, prints the new fingerprint and both export locations -- never
the passphrase itself (same guarantee as werkstatt.gpg.generate.key.sh).
This key is NOT written to default-key.json -- see the header comment.

After this runs, the customer's PRIVATE key + passphrase exist only on
THIS node's keyring plus the shared \$MFTE_GPG_ONBOARDING_PRIVACY_DIR
export -- run onboarding-4gpg-cluster.sh on every other hub (safe to also
run it on this one; it will just skip an already-present key) before this
customer's files can be decrypted anywhere else in the cluster.

Recommended Run Command:
  $SCRIPT_NAME -n "ACME Finance" -m "finance@acme.example.com" -q
USAGE
}

NAME=""
EMAIL=""
KEY_TYPE="rsa4096"
EXPIRE="0"
FORCE="false"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':n:m:t:x:P:B:Fqh' opt; do
  case "$opt" in
    n) NAME="$(mfte_unquote "$OPTARG")" ;;
    m) EMAIL="$(mfte_unquote "$OPTARG")" ;;
    t) KEY_TYPE="$(mfte_unquote "$OPTARG")" ;;
    x) EXPIRE="$(mfte_unquote "$OPTARG")" ;;
    P) MFTE_GPG_ONBOARDING_PRIVACY_DIR="$(mfte_unquote "$OPTARG")" ;;
    B) MFTE_GPG_ONBOARDING_B2B_DIR="$(mfte_unquote "$OPTARG")" ;;
    F) FORCE="true" ;;
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

if [[ -z "$NAME" ]]; then
  log_system ERROR "missing required -n (name)"
  echo "ERROR: -n name is required." >&2
  usage
  exit 2
fi

if [[ -z "$EMAIL" ]]; then
  log_system ERROR "missing required -m (email)"
  echo "ERROR: -m email is required." >&2
  usage
  exit 2
fi

if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  log_system ERROR "invalid -m email: ${EMAIL}"
  echo "ERROR: -m '${EMAIL}' doesn't look like a plain email address (it becomes a directory" >&2
  echo "segment under the B2B export path, so no '/' or whitespace is accepted)." >&2
  exit 2
fi

if ! mfte_gpg_preflight; then
  log_system ERROR "preflight failed"
  exit 1
fi

# mfte_onboarding_is_staged <fingerprint>
# True only if BOTH exports this script produces already exist and are
# non-empty: private key + passphrase in the privacy dir, public key at
# the B2B destination. Anything less means a prior run generated the key
# but didn't finish -- see the header comment's "resume" section.
mfte_onboarding_is_staged() {
  local fp="$1"
  [[ -s "${MFTE_GPG_ONBOARDING_PRIVACY_DIR}/${fp}.private.asc" \
    && -s "${MFTE_GPG_ONBOARDING_PRIVACY_DIR}/${fp}.passphrase" \
    && -s "${MFTE_GPG_ONBOARDING_B2B_DIR}/${EMAIL}/${fp}.public.asc" ]]
}

RESUME="false"
FINGERPRINT=""
if [[ "$FORCE" != "true" ]]; then
  if EXISTING_FP="$(mfte_gpg_lookup_fingerprint "$EMAIL" secret)"; then
    if mfte_onboarding_is_staged "$EXISTING_FP"; then
      log_system ERROR "already onboarded email=${EMAIL} fingerprint=${EXISTING_FP}"
      echo "ERROR: a secret key already resolves for ${EMAIL} (fingerprint ${EXISTING_FP})," >&2
      echo "and both exports are already staged. This customer already appears fully onboarded" >&2
      echo "on this node. Re-run with -F to force an additional key anyway (you'll likely need" >&2
      echo "to disambiguate fingerprints manually afterward), or use" >&2
      echo "werkstatt.gpg.export.key.sh -k ${EXISTING_FP} directly if you just need another copy" >&2
      echo "of the existing key." >&2
      exit 3
    fi
    log_system INFO "resuming incomplete onboarding email=${EMAIL} fingerprint=${EXISTING_FP}"
    if [[ "$QUIET" != "true" ]]; then
      echo "NOTE: a secret key already exists for ${EMAIL} (fingerprint ${EXISTING_FP}) but one or" >&2
      echo "both exports were never completed -- resuming from the export step using the existing" >&2
      echo "key rather than generating a new one." >&2
    fi
    RESUME="true"
    FINGERPRINT="$EXISTING_FP"
  fi
fi

UID_STR="${NAME} <${EMAIL}>"
log_system INFO "start name=\"${NAME}\" email=${EMAIL} uid=\"${UID_STR}\" type=${KEY_TYPE} expire=${EXPIRE} force=${FORCE} resume=${RESUME}"

CLEANUP_TMP_PASSPHRASE=""
cleanup() {
  if [[ -n "$CLEANUP_TMP_PASSPHRASE" ]]; then
    runuser -u "${MFTE_GPG_USER}" -- rm -f "$CLEANUP_TMP_PASSPHRASE" 2>/dev/null
  fi
}
trap cleanup EXIT

if [[ "$RESUME" == "true" ]]; then
  # Reuse the existing key -- do NOT generate a new one. Pull the real uid
  # off the key itself rather than trusting this run's -n/-m match what
  # was used originally (doesn't matter functionally, just keeps the
  # report honest).
  FINAL_PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$FINGERPRINT")"
  if ! mfte_gpg_require_locked_down "$FINAL_PASSPHRASE_FILE" 600; then
    log_system ERROR "resume: passphrase file failed lockdown check fingerprint=${FINGERPRINT}"
    echo "ERROR: ${EMAIL} resolves to an existing key (${FINGERPRINT}) on this node, but its" >&2
    echo "passphrase file is missing or not properly locked down -- cannot resume automatically." >&2
    exit 1
  fi
  UID_STR="$(mfte_gpg_uid_for_fingerprint "$FINGERPRINT" secret)"
  log_system INFO "resume: reusing fingerprint=${FINGERPRINT} uid=\"${UID_STR}\""
else
  # Same generation sequence as werkstatt.gpg.generate.key.sh: certify-only
  # primary, then separate sign and encrypt subkeys -- required on this gpg
  # version (a "default" usage quick-generate produces a sign+cert key with
  # NO encrypt capability).
  TMP_IDENT="onboard-$$-$(date -u +%Y%m%dT%H%M%SZ)"
  GEN_PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$TMP_IDENT")"
  mfte_gpg_write_passphrase_file "$TMP_IDENT" "$(mfte_gpg_generate_passphrase)"
  CLEANUP_TMP_PASSPHRASE="$GEN_PASSPHRASE_FILE"

  GEN_OUTPUT="$(mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$GEN_PASSPHRASE_FILE" --status-fd 1 --quick-generate-key "$UID_STR" "$KEY_TYPE" cert "$EXPIRE" 2>&1)"
  GEN_STATUS=$?
  FINGERPRINT="$(printf '%s\n' "$GEN_OUTPUT" | awk '/\[GNUPG:\] KEY_CREATED/{print $NF}')"

  if [[ $GEN_STATUS -ne 0 || -z "$FINGERPRINT" ]]; then
    log_system ERROR "primary key generation failed uid=\"${UID_STR}\" status=${GEN_STATUS}"
    echo "ERROR: key generation failed (gpg exit ${GEN_STATUS}). See ${SYSTEM_LOG_FILE} for details." >&2
    log_system DEBUG "gpg output: ${GEN_OUTPUT}"
    exit 1
  fi

  if ! SUB_OUTPUT="$(mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$GEN_PASSPHRASE_FILE" --quick-add-key "$FINGERPRINT" "$KEY_TYPE" sign "$EXPIRE" 2>&1)"; then
    log_system ERROR "sign subkey generation failed fingerprint=${FINGERPRINT}"
    echo "ERROR: sign subkey generation failed. See ${SYSTEM_LOG_FILE} for details." >&2
    log_system DEBUG "gpg output: ${SUB_OUTPUT}"
    exit 1
  fi
  if ! SUB_OUTPUT="$(mfte_gpg_run --batch --pinentry-mode loopback --passphrase-file "$GEN_PASSPHRASE_FILE" --quick-add-key "$FINGERPRINT" "$KEY_TYPE" encr "$EXPIRE" 2>&1)"; then
    log_system ERROR "encrypt subkey generation failed fingerprint=${FINGERPRINT}"
    echo "ERROR: encrypt subkey generation failed. See ${SYSTEM_LOG_FILE} for details." >&2
    log_system DEBUG "gpg output: ${SUB_OUTPUT}"
    exit 1
  fi

  # File the passphrase under its permanent, fingerprint-keyed name -- same
  # as generate.key.sh. This node's own keyring is fully usable from this
  # point on, independent of anything below.
  FINAL_PASSPHRASE_FILE="$(mfte_gpg_passphrase_file "$FINGERPRINT")"
  runuser -u "${MFTE_GPG_USER}" -- mv "$GEN_PASSPHRASE_FILE" "$FINAL_PASSPHRASE_FILE"
  CLEANUP_TMP_PASSPHRASE=""

  log_system INFO "key generated fingerprint=${FINGERPRINT} uid=\"${UID_STR}\""
fi

# --- Private key + passphrase -> $MFTE_GPG_ONBOARDING_PRIVACY_DIR -----------
# Same NFS export as mftgpg's own home/keyring dirs -- written directly by
# mftgpg, no relocation step needed. See the header comment's "two
# different NFS exports" note.
#
# `mkdir -p` on a directory that already exists is a silent no-op -- it
# does NOT fix ownership. If this directory was ever pre-created by hand
# (e.g. a root `mkdir -p` while poking around, or a setgid dir inherited
# from a parent's default ACL) it can end up owned by someone other than
# mftgpg, and every mkdir -p after that "succeeds" while mftgpg still
# can't write a single file into it -- confirmed as a real failure mode,
# not a hypothetical one. Check ownership explicitly, after the mkdir,
# rather than only finding out indirectly when the gpg --output call
# below fails with an unhelpful generic error.
runuser -u "${MFTE_GPG_USER}" -- mkdir -p "${MFTE_GPG_ONBOARDING_PRIVACY_DIR}" 2>/dev/null
DIR_OWNER="$(stat -c '%U' "${MFTE_GPG_ONBOARDING_PRIVACY_DIR}" 2>/dev/null || stat -f '%Su' "${MFTE_GPG_ONBOARDING_PRIVACY_DIR}" 2>/dev/null)"
if [[ "$DIR_OWNER" != "${MFTE_GPG_USER}" ]]; then
  log_system ERROR "onboarding privacy dir wrong owner dir=${MFTE_GPG_ONBOARDING_PRIVACY_DIR} owner=${DIR_OWNER:-unknown} expected=${MFTE_GPG_USER}"
  echo "ERROR: ${MFTE_GPG_ONBOARDING_PRIVACY_DIR} exists but is owned by '${DIR_OWNER:-unknown}', not" >&2
  echo "${MFTE_GPG_USER}. This key was generated successfully (fingerprint ${FINGERPRINT}, still in" >&2
  echo "this node's own keyring) but couldn't be staged for the cluster because of this. 'mkdir -p'" >&2
  echo "does not fix ownership on a directory that already exists -- someone/something created it" >&2
  echo "before this script got to it. Fix with:" >&2
  echo "  chown ${MFTE_GPG_USER} ${MFTE_GPG_ONBOARDING_PRIVACY_DIR}" >&2
  echo "then re-run this command." >&2
  exit 1
fi

PRIVATE_EXPORT="${MFTE_GPG_ONBOARDING_PRIVACY_DIR}/${FINGERPRINT}.private.asc"

if ! EXPORT_OUTPUT="$(mfte_gpg_run --batch --yes --armor --output "$PRIVATE_EXPORT" --pinentry-mode loopback --passphrase-file "$FINAL_PASSPHRASE_FILE" --export-secret-keys "$FINGERPRINT" 2>&1)"; then
  log_system ERROR "private key export failed fingerprint=${FINGERPRINT} target=${PRIVATE_EXPORT}"
  echo "ERROR: private key export failed. Key exists in this node's own keyring (fingerprint" >&2
  echo "${FINGERPRINT}) but was not staged for the cluster. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${EXPORT_OUTPUT}"
  echo "Directory ownership checked out (${MFTE_GPG_USER}) -- this is a different failure, see the" >&2
  echo "gpg output logged above." >&2
  exit 1
fi

if ! mfte_gpg_copy_passphrase_as_user "$FINAL_PASSPHRASE_FILE" "${MFTE_GPG_ONBOARDING_PRIVACY_DIR}/${FINGERPRINT}.passphrase"; then
  log_system ERROR "passphrase copy to onboarding privacy dir failed fingerprint=${FINGERPRINT}"
  echo "ERROR: private key export succeeded but copying its passphrase file to" >&2
  echo "${MFTE_GPG_ONBOARDING_PRIVACY_DIR} failed. onboarding-4gpg-cluster.sh cannot complete" >&2
  echo "this key's import on other nodes without it." >&2
  exit 1
fi

# --- Public key -> $MFTE_GPG_ONBOARDING_B2B_DIR/<email>/ -------------------
# /mnt/ftshome is root-only from mftgpg's perspective (same as every other
# /mnt/ftshome path in this framework) -- stage under the mftgpg-writable
# exchange dir first, then relocate as THIS script's own identity. See the
# header comment's "two different NFS exports" note.
mkdir -p "${MFTE_GPG_EXCHANGE_DIR}"
STAGED_PUBLIC="${MFTE_GPG_EXCHANGE_DIR}/${FINGERPRINT}.public.asc"

if ! EXPORT_OUTPUT="$(mfte_gpg_run --batch --yes --armor --output "$STAGED_PUBLIC" --export "$FINGERPRINT" 2>&1)"; then
  log_system ERROR "public key export failed fingerprint=${FINGERPRINT} target=${STAGED_PUBLIC}"
  echo "ERROR: public key export failed. See ${SYSTEM_LOG_FILE} for details." >&2
  log_system DEBUG "gpg output: ${EXPORT_OUTPUT}"
  exit 1
fi

PUBLIC_DEST_DIR="${MFTE_GPG_ONBOARDING_B2B_DIR}/${EMAIL}"
PUBLIC_DEST="${PUBLIC_DEST_DIR}/${FINGERPRINT}.public.asc"

if ! mkdir -p "$PUBLIC_DEST_DIR" 2>/dev/null || ! mv -f "$STAGED_PUBLIC" "$PUBLIC_DEST" 2>/dev/null; then
  log_system ERROR "failed to relocate public key export from=${STAGED_PUBLIC} to=${PUBLIC_DEST}"
  echo "ERROR: public key generated and exported, but relocating it to ${PUBLIC_DEST} failed." >&2
  echo "The exported public key remains at ${STAGED_PUBLIC} -- move it manually." >&2
  exit 1
fi
chmod 644 "$PUBLIC_DEST" 2>/dev/null

log_system INFO "complete fingerprint=${FINGERPRINT} uid=\"${UID_STR}\" resume=${RESUME} private_export=${PRIVATE_EXPORT} public_export=${PUBLIC_DEST}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT
GPG customer onboarding complete$([[ "$RESUME" == "true" ]] && echo " (resumed -- existing key reused)")
  name              : $NAME
  email             : $EMAIL
  fingerprint       : $FINGERPRINT
  key type          : $KEY_TYPE
  expire            : $EXPIRE
  key generated now : $([[ "$RESUME" == "true" ]] && echo "false -- reused existing key" || echo "true")
  default updated   : false (one-dedicated-key-per-customer pattern has no single default)

  private key       : $PRIVATE_EXPORT
  passphrase        : ${MFTE_GPG_ONBOARDING_PRIVACY_DIR}/${FINGERPRINT}.passphrase (mode 600 -- not displayed here)
  public key        : $PUBLIC_DEST  <-- hand this to the customer

Next step: run onboarding-4gpg-cluster.sh on every hub in the cluster
(including this one is harmless -- it will just skip an already-present
key) before ${EMAIL}'s files can be decrypted anywhere else.
REPORT
fi

exit 0
