#!/usr/bin/env bash
set -o pipefail
umask 002

# file name: werkstatt.gpg.receive.file.sh
# purpose : Given an inbound encrypted file, figure out which of possibly
#           many keys in this keyring it was encrypted to, decrypt it with
#           that one, and record a full audit entry for the attempt --
#           invoked directly by a Control-M Processing Rule the same way
#           mfte.rule.vars.all.jsonl.sh is, not chained after it.
#
# origin  : Built for the "one dedicated key per customer" pattern -- N
#           customers, N keypairs, all N secret halves held by mftgpg, each
#           customer only ever seeing their own public key. A file arrives
#           encrypted to exactly one of those N keys, and nothing upstream
#           tells this script which one -- that's the whole reason it
#           exists, rather than always using werkstatt.gpg.decrypt.file.sh's
#           -k or its single default-key.json fallback. Fuses
#           werkstatt.gpg.fingerprint.file.sh's recipient discovery
#           (--list-packets) with werkstatt.gpg.decrypt.file.sh's actual
#           decrypt logic, sharing the same mfte.gpg.sh helpers both of
#           those use.
#
# scope   : Takes the SAME full set of BMC Processing Rule Variables as
#           mfte.rule.vars.all.jsonl.sh (identical flag letters), and its
#           JSON record includes the same "variables":{...} block via the
#           shared mfte_json_bmc_variables_block() function. These two
#           scripts are never attached to the same rule -- a GPG-receive
#           rule runs this script only, a plain file-arrival rule runs
#           mfte.rule.vars.all.jsonl.sh only -- so there is no sibling
#           record to join against, ever, for a GPG event. This script's
#           JSONL entry has to be the complete record for that event on
#           its own: the same variables{} block mfte.rule.vars.all.jsonl.sh
#           would have written, plus this script's own "gpg":{...} block.
#
#           This script does NOT use mfte.rule.vars.all.jsonl.sh's output
#           as input -- Control-M cannot hand one script's output to
#           another as input across separate rule actions even if they
#           were on the same rule, which they aren't here.
#
#           Also does NOT touch customer onboarding (matching an inbound
#           sender to a customer record, provisioning a new customer's
#           keypair, anything email-address-based). This script only ever
#           looks at what's already IN the keyring against what the file
#           itself says it needs. A file from a not-yet-onboarded customer
#           is expected to hit the exit-3 case below.
#
# note    : gpg itself already auto-selects the matching secret key from a
#           file's own packet headers when you run --decrypt -- it does not
#           need to be told which key via --recipient/--local-user. What it
#           DOES need is the correct --passphrase-file for whichever secret
#           key it ends up using, and with N distinct keys there is no
#           single passphrase file that works for all of them. So the real
#           job here is: identify the recipient key ID from the file,
#           resolve it to a fingerprint THIS keyring holds the secret half
#           of, locate THAT fingerprint's own passphrase file, and only
#           then call --decrypt.
#
# file    : -a FILE_ABS_PATH is used for the actual gpg operations when
#           given (guaranteed-absolute), falling back to -p FILE_PATH if
#           -a wasn't passed. -p is the only required flag either way --
#           pass both in the Run Command (see the recommended command
#           below) rather than relying on the fallback in production.
#
# return  : The now-processed ENCRYPTED ORIGINAL is ALWAYS relocated to its
#           final "return" destination (-K, or computed from
#           $MFTE_GPG_RETURN_DIR if not given) -- on EVERY outcome, not
#           just a successful decrypt. Staging is only reachable by
#           mftgpg/root; leaving the file there after a no_key/skipped/
#           error outcome would strand it somewhere nobody else can ever
#           get to it again, and the whole point of archiving is that the
#           admin always has a place to look. The DECRYPTED output only
#           ever exists when the decrypt actually succeeded, so its move
#           (-R, or computed from $MFTE_GPG_RETURN_DIR) stays conditional
#           on GPG_STATUS == decrypted -- there's nothing to move
#           otherwise. Retention of the return destinations themselves is
#           deliberately NOT this script's job -- once a file lands there,
#           keeping that filesystem clean is on whoever owns it (the
#           admin), same as any other B2B exchange folder.
#
#           This final move runs as whatever this whole script is already
#           running as (root, per Control-M's invocation model) -- NOT via
#           runuser -u mftgpg like the gpg calls above. That's deliberate:
#           this environment's NFS exports have no_root_squash set (see the
#           README's "NFS / shared-storage considerations for GPG" section
#           and ISSUES.md), so root already has unrestricted read/write
#           across every export reachable from this host. Doing the final
#           move as root means it works without requesting a NEW mftgpg
#           permission grant on the return destination -- mftgpg's own
#           reach stays limited to its keyring, the staging directory, and
#           $MFTE_GPG_OUTPUT_DIR, consistent with why it's a separate
#           least-privilege account in the first place.
#
# exit codes:
#   0  decrypted successfully (even if the audit write itself failed --
#      the customer's file already exists on disk at that point; see
#      audit_write in the stdout status line)
#   1  technical error: file resolves to MORE than one usable secret key in
#      this keyring (ambiguous -- ruled out on purpose, not guessed),
#      preflight failure, or the gpg --decrypt call itself failed
#   2  usage error (bad/missing flags)
#   3  file's recipient(s) resolved, but NONE are a key this keyring holds
#      the secret half of -- the "customer not onboarded yet (or onboarded
#      on a different hub)" condition. Distinct from 1 so a Control-M job
#      can branch on "waiting on onboarding" vs "actually broken" from the
#      exit code alone.
#   4  file is not a public-key-encrypted OpenPGP message at all -- nothing
#      for this script to do. Not an error: the file just isn't in this
#      script's domain (e.g. a plaintext manifest, a signature-only file, a
#      file this rule shouldn't have matched). Distinct from 1 so a
#      not-actually-encrypted file doesn't mark the Control-M job failed.
#
# stdout  : default = one short "TOKEN key=value ..." line. -j = full JSON
#           record (same one written to the audit log). -q = nothing.
#           Mutually exclusive; -q wins if both given.
#
###############################################################################
# WHY THE ARGUMENT PARSING LOOKS LIKE THIS (read before templating this script)
###############################################################################
# Same three defenses as mfte.rule.vars.all.jsonl.sh, for the same
# real-production reasons documented in that script's own header comment:
# every $$VAR$$ token in the Run Command must be quoted, every OPTARG is
# run through mfte_unquote() (this Control-M agent passes literal quote
# characters through as part of the value, doesn't strip them itself), and
# mfte_check_no_leftover_args() tolerates exactly one trailing empty argv
# element and fails loudly on anything else. All three live in mfte.sh.
###############################################################################

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="controlm_mfte_gpg_receive_v1"

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

: "${MFTE_JSONL_FILE:?MFTE_JSONL_FILE is not set — check that mfte.sh sourced the .env}"
: "${MFTE_JSON_DIR:?MFTE_JSON_DIR is not set — check that mfte.sh sourced the .env}"
JSONL_FILE="${MFTE_JSONL_FILE}"
JSON_DIR="${MFTE_JSON_DIR}"
OUTPUT_MODE="${MFTE_LOG_FORMAT:-jsonl}"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME -p "\$\$FILE_PATH\$\$" [options]

Required:
  -p  FILE_PATH             \$\$FILE_PATH\$\$

Short options mapped to BMC MFT Enterprise Action Rule Variables -- same
letters as mfte.rule.vars.all.jsonl.sh, all optional except -p, all folded
into this record's own "variables":{...} block:
  -a  FILE_ABS_PATH         \$\$FILE_ABS_PATH\$\$   used for the actual gpg
                             calls when given -- see "file" in the header comment
  -d  FILE_DIR              \$\$FILE_DIR\$\$
  -D  FILE_ABS_DIR          \$\$FILE_ABS_DIR\$\$
  -n  FILE_NAME             \$\$FILE_NAME\$\$
  -N  FILE_NAME_NO_EXT      \$\$FILE_NAME_NO_EXT\$\$
  -e  FILE_EXT              \$\$FILE_EXT\$\$
  -E  FILE_EXT_NO_DOT       \$\$FILE_EXT_NO_DOT\$\$
  -x  FILE_DATE             \$\$FILE_DATE\$\$          UTC YYYYMMDD
  -X  FILE_DATE_LOCAL       \$\$FILE_DATE_LOCAL\$\$    Agent local YYYYMMDD
  -y  FILE_TIME             \$\$FILE_TIME\$\$          UTC HHmmSS
  -Y  FILE_TIME_LOCAL       \$\$FILE_TIME_LOCAL\$\$    Agent local HHmmSS
  -z  FILE_SIZE             \$\$FILE_SIZE\$\$          bytes
  -u  USER                  \$\$USER\$\$
  -c  COMPANY                \$\$COMPANY\$\$
  -v  VIRTUAL_FOLDER        \$\$VIRTUAL_FOLDER\$\$
  -m  EMAIL                 \$\$EMAIL\$\$
  -t  PHONE_NUMBER          \$\$PHONE_NUMBER\$\$
  -s  SUB_DIR_PATH          \$\$SUB_DIR_PATH\$\$
  -g  STAGING_FILE_NAME     \$\$STAGING_FILE_NAME\$\$
  -G  STAGING_FILE_PATH     \$\$STAGING_FILE_PATH\$\$

Metadata, not BMC variables:
  -r  rule name
  -A  action name
  -k  event name/type                         default: gpg_receive_file

GPG / audit options:
  -w  decrypt output path (write here)   default: derived from the file
                             under \$MFTE_GPG_OUTPUT_DIR
  -R  final path for the DECRYPTED file, applied only after a successful
                             decrypt (moved here from -w's location)
                             default: computed from \$MFTE_GPG_RETURN_DIR
                             (see below) with the placeholder replaced by
                             "decrypted"; if that's also unset, the file
                             simply stays wherever -w put it (today's
                             behavior, unchanged)
  -K  final path for the now-processed ENCRYPTED original -- applied on
                             EVERY outcome (decrypted, no_key, skipped, or
                             a technical error), not just a successful
                             decrypt, so nothing is ever left behind in a
                             staging directory nobody but mftgpg/root can
                             reach (moved here from wherever -a pointed)
                             default: computed from \$MFTE_GPG_RETURN_DIR
                             with the placeholder replaced by "encrypted";
                             if that's also unset, the encrypted original
                             is left where -a found it
  -o  report mode: jsonl | json-file | both   default: \$MFTE_LOG_FORMAT
                             (from .env), else jsonl
  -l  custom log directory                    default: \$MFTE_LOG_DIR /
                             \$MFTE_JSONL_FILE / \$MFTE_JSON_DIR (from .env)

\$MFTE_GPG_RETURN_DIR (.env, optional) is a single path used for both -R
and -K's defaults, in either of two forms:
  MFTE_GPG_RETURN_DIR="/mnt/ftshome/b2bhome/secureTransport/{TYPE}"
  MFTE_GPG_RETURN_DIR="/mnt/ftshome/b2bhome/secureTransport"
With the literal text "{TYPE}" included (not shell syntax -- this is a
plain string substitution this script does itself, NOT a \$VARIABLE the
.env's own source step would try to expand), it's replaced with
"encrypted" or "decrypted" depending on which file is being placed.
Without it, the value is treated as a base directory and "/encrypted" or
"/decrypted" is appended automatically -- either form always lands the
two file types in separate subfolders, never dumped together into the
same directory, and the subfolder doesn't need to pre-exist (created on
first use). Neither -R/-K nor this variable are required -- if nothing is
configured, both files are left exactly where earlier flags/defaults
already put them, matching this script's original behavior before this
feature existed.

The ENCRYPTED original's move (-K) happens on EVERY outcome -- decrypted,
no_key (exit 3), skipped/not_gpg_message (exit 4), or a technical error
(exit 1) -- as long as the file was actually found at start. Staging is
only reachable by mftgpg/root, so leaving it there on anything but a
clean decrypt would strand it somewhere the admin can't reach; archiving
it regardless of outcome means a not-yet-onboarded customer's file (or
one that turned out not to be a GPG message at all) still lands
somewhere reachable, ready for a manual retry once the underlying issue
is resolved. The DECRYPTED output's move (-R) only ever runs when the
decrypt actually succeeded -- there's nothing to move otherwise. A move
failure does NOT change the exit code (the decrypt/receive step already
determined it) -- see "return" in the JSON record and the ERROR lines on
stderr if a relocation itself fails.

Output:
  -j  json        print the full JSON record to stdout instead of the
                   short status line
  -q  quiet       print nothing to stdout (errors still go to stderr; the
                   log always gets the full record). Wins over -j if both given.
  -h  help

No -k for "which key to decrypt with" here -- deliberately (-k here means
event name/type, matching mfte.rule.vars.all.jsonl.sh's own -k). The whole
point of this script is figuring out which key applies from the file
itself. If you already know which key to use,
werkstatt.gpg.decrypt.file.sh -k is the more direct tool for that case.

This script's JSON record carries the same "variables":{...} BMC-variable
block mfte.rule.vars.all.jsonl.sh writes, PLUS its own "gpg":{...} block.
GPG-receive rules and plain file-arrival rules are never the same rule, so
this script's record is always the only record for its event -- it does
not rely on mfte.rule.vars.all.jsonl.sh ever having run. See the header
comment's "scope" section.

Recommended Run Command with all BMC variables:
  $SCRIPT_NAME -r "<rule_name>" -A "<action_name>" -p "\$\$FILE_PATH\$\$" -a "\${MFTE_GPG_RECEIVE_STAGING_DIR}/\$\$FILE_NAME\$\$" -d "\$\$FILE_DIR\$\$" -D "\$\$FILE_ABS_DIR\$\$" -n "\$\$FILE_NAME\$\$" -N "\$\$FILE_NAME_NO_EXT\$\$" -e "\$\$FILE_EXT\$\$" -E "\$\$FILE_EXT_NO_DOT\$\$" -x "\$\$FILE_DATE\$\$" -X "\$\$FILE_DATE_LOCAL\$\$" -y "\$\$FILE_TIME\$\$" -Y "\$\$FILE_TIME_LOCAL\$\$" -z "\$\$FILE_SIZE\$\$" -u "\$\$USER\$\$" -c "\$\$COMPANY\$\$" -v "\$\$VIRTUAL_FOLDER\$\$" -m "\$\$EMAIL\$\$" -t "\$\$PHONE_NUMBER\$\$" -s "\$\$SUB_DIR_PATH\$\$" -g "\$\$STAGING_FILE_NAME\$\$" -G "\$\$STAGING_FILE_PATH\$\$" -q

\${MFTE_GPG_RECEIVE_STAGING_DIR} above is a shell/.env variable reference,
not a BMC \$\$VAR\$\$ token -- substitute its actual resolved value (.env
default: \$MFTE_TMP_DIR/mfte-gpg-receive-staging) when building the real
Run Command, since Control-M's agent does not expand plain shell variables
itself.

NOTE on -a above: this is deliberately NOT "\$\$FILE_ABS_PATH\$\$". If a
prior action in the same rule moves the inbound file (e.g. a native
"Move File" post-processing step relocating it out of a root-only landing
directory into a staging directory mftgpg can actually read -- see the
README's "NFS / shared-storage considerations for GPG" section for why
that's often necessary), \$\$FILE_ABS_PATH\$\$ is the ONE variable that
actually gets read (OPERATE_PATH prefers it over -p), so it's the one
worth hand-building from the known, fixed staging directory (\$MFTE_GPG_RECEIVE_STAGING_DIR)
plus \$\$FILE_NAME\$\$ (which the move doesn't change) rather than trusting
Control-M's post-Move recomputation of it.

Every other flag here -- including -p, -d, -D -- is left as the raw BMC
token on purpose, even \$\$FILE_PATH\$\$/\$\$FILE_DIR\$\$, which are known
to come back CORRUPTED after this kind of Move (a real leading "/mnt/"
replaced with a broken "/../" -- see ISSUES.md, MFTE-001, a BMC product
issue). None of these flags are read by this script for anything
operational -- they only feed the "variables":{...} block in the JSONL
audit record via mfte_json_bmc_variables_block(). Hand-building them to
paper over MFTE-001 would hide the real product bug's actual output from
that record, which is exactly the evidence BMC support needs to diagnose
and fix it -- so the broken value is captured as-is, deliberately, not
corrected. -a is the sole exception because it's the one flag this
script actually depends on to function.

-R/-K aren't in the command above -- with \$MFTE_GPG_RETURN_DIR set in the
.env, both default correctly with no per-rule flags needed at all. Add
them explicitly only for a rule that needs a DIFFERENT return location
than the .env default, e.g.:
  -R "/mnt/ftshome/b2bhome/otherPartner/decrypted/\$\$FILE_NAME_NO_EXT\$\$"

IMPORTANT: every \$\$VAR\$\$ token above MUST stay quoted. BMC frequently
substitutes an empty string for optional fields (phone, email, company,
sub-dir path); an unquoted empty substitution collapses its flag directly
against the next flag on the line and getopts silently swallows the next
flag as this one's argument, corrupting both fields with no error.
USAGE
}

# Initialize all BMC variables (identical set to mfte.rule.vars.all.jsonl.sh).
FILE_PATH=""
FILE_ABS_PATH=""
FILE_DIR=""
FILE_ABS_DIR=""
FILE_NAME=""
FILE_NAME_NO_EXT=""
FILE_EXT=""
FILE_EXT_NO_DOT=""
FILE_DATE=""
FILE_DATE_LOCAL=""
FILE_TIME=""
FILE_TIME_LOCAL=""
FILE_SIZE=""
MFT_USER=""
COMPANY=""
VIRTUAL_FOLDER=""
EMAIL=""
PHONE_NUMBER=""
SUB_DIR_PATH=""
STAGING_FILE_NAME=""
STAGING_FILE_PATH=""

RULE_NAME=""
ACTION_NAME=""
EVENT="gpg_receive_file"
DEC_OUTPUT_OVERRIDE=""
RETURN_DECRYPTED_OVERRIDE=""
RETURN_ENCRYPTED_OVERRIDE=""
JSON_OUT="false"
QUIET="false"

ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':p:a:d:D:n:N:e:E:x:X:y:Y:z:u:c:v:m:t:s:g:G:r:A:k:w:R:K:o:l:jqh' opt; do
  case "$opt" in
    p) FILE_PATH="$(mfte_unquote "$OPTARG")" ;;
    a) FILE_ABS_PATH="$(mfte_unquote "$OPTARG")" ;;
    d) FILE_DIR="$(mfte_unquote "$OPTARG")" ;;
    D) FILE_ABS_DIR="$(mfte_unquote "$OPTARG")" ;;
    n) FILE_NAME="$(mfte_unquote "$OPTARG")" ;;
    N) FILE_NAME_NO_EXT="$(mfte_unquote "$OPTARG")" ;;
    e) FILE_EXT="$(mfte_unquote "$OPTARG")" ;;
    E) FILE_EXT_NO_DOT="$(mfte_unquote "$OPTARG")" ;;
    x) FILE_DATE="$(mfte_unquote "$OPTARG")" ;;
    X) FILE_DATE_LOCAL="$(mfte_unquote "$OPTARG")" ;;
    y) FILE_TIME="$(mfte_unquote "$OPTARG")" ;;
    Y) FILE_TIME_LOCAL="$(mfte_unquote "$OPTARG")" ;;
    z) FILE_SIZE="$(mfte_unquote "$OPTARG")" ;;
    u) MFT_USER="$(mfte_unquote "$OPTARG")" ;;
    c) COMPANY="$(mfte_unquote "$OPTARG")" ;;
    v) VIRTUAL_FOLDER="$(mfte_unquote "$OPTARG")" ;;
    m) EMAIL="$(mfte_unquote "$OPTARG")" ;;
    t) PHONE_NUMBER="$(mfte_unquote "$OPTARG")" ;;
    s) SUB_DIR_PATH="$(mfte_unquote "$OPTARG")" ;;
    g) STAGING_FILE_NAME="$(mfte_unquote "$OPTARG")" ;;
    G) STAGING_FILE_PATH="$(mfte_unquote "$OPTARG")" ;;
    r) RULE_NAME="$(mfte_unquote "$OPTARG")" ;;
    A) ACTION_NAME="$(mfte_unquote "$OPTARG")" ;;
    k) EVENT="$(mfte_unquote "$OPTARG")" ;;
    w) DEC_OUTPUT_OVERRIDE="$(mfte_unquote "$OPTARG")" ;;
    R) RETURN_DECRYPTED_OVERRIDE="$(mfte_unquote "$OPTARG")" ;;
    K) RETURN_ENCRYPTED_OVERRIDE="$(mfte_unquote "$OPTARG")" ;;
    o) OUTPUT_MODE="$(mfte_unquote "$OPTARG")" ;;
    l)
      LOG_DIR_OVERRIDE="$(mfte_unquote "$OPTARG")"
      JSONL_FILE="${LOG_DIR_OVERRIDE}/mfte-rule-vars.jsonl"
      JSON_DIR="${LOG_DIR_OVERRIDE}/mfte-rule-vars.d"
      ;;
    j) JSON_OUT="true" ;;
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

if [[ -z "$FILE_PATH" ]]; then
  log_system ERROR "missing required -p (FILE_PATH)"
  echo "ERROR: -p FILE_PATH is required." >&2
  usage
  exit 2
fi

case "$OUTPUT_MODE" in
  jsonl|json-file|both) ;;
  *) log_system ERROR "invalid -o output mode: $OUTPUT_MODE"; echo "Invalid -o output mode: $OUTPUT_MODE" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$JSONL_FILE")" "$JSON_DIR" "$MFTE_SYSTEM_LOG_DIR"

# The path gpg actually operates on: prefer the guaranteed-absolute
# FILE_ABS_PATH when given. FILE_PATH is the only REQUIRED flag (per
# spec), but a relative/virtual FILE_PATH handed straight to gpg could
# fail to open depending on this process's cwd -- pass -a in the Run
# Command in production, don't rely on this fallback.
OPERATE_PATH="${FILE_ABS_PATH:-$FILE_PATH}"

# Derive missing convenience values only when MFT did not pass them --
# same shared function mfte.rule.vars.all.jsonl.sh uses, given whichever
# path this script considers authoritative for gpg operations.
mfte_derive_bmc_file_vars "$OPERATE_PATH"

log_system INFO "start rule=${RULE_NAME:-none} action=${ACTION_NAME:-none} file=${OPERATE_PATH} mode=${OUTPUT_MODE}"

RUN_TS_LOCAL="$(date '+%Y-%m-%d %H:%M:%S')"
RUN_TS_ISO="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-$$"
HOST_FQDN="${MFTE_HOST_FQDN:-$(hostname -f 2>/dev/null || hostname)}"
RUN_USER="$(whoami 2>/dev/null || printf unknown)"

###############################################################################
# Receive + decrypt. Sets GPG_STATUS/GPG_REASON/EXIT_CODE and, on success,
# MATCHED_KEYID/KEY_FP/MATCHED_UID/DEC_OUTPUT/CHECKSUM -- then returns,
# rather than exiting directly, so every path (success or failure) still
# reaches the single audit-record block below.
###############################################################################
GPG_STATUS="error"
GPG_REASON=""
EXIT_CODE=1
MATCHED_KEYID=""
KEY_FP=""
MATCHED_UID=""
DEC_OUTPUT=""
CHECKSUM=""

do_receive() {
  if [[ ! -f "$OPERATE_PATH" || ! -r "$OPERATE_PATH" ]]; then
    log_system ERROR "file not found or unreadable: ${OPERATE_PATH}"
    echo "ERROR: file not found or unreadable: ${OPERATE_PATH}" >&2
    GPG_REASON="not_found_or_unreadable"; EXIT_CODE=1
    return
  fi

  if ! mfte_gpg_preflight; then
    log_system ERROR "preflight failed"
    GPG_REASON="preflight_failed"; EXIT_CODE=1
    return
  fi

  # Step 1: which key(s) is this file encrypted to?
  local list_output key_ids
  list_output="$(mfte_gpg_run --batch --pinentry-mode cancel --list-packets "$OPERATE_PATH" 2>&1)"
  key_ids="$(printf '%s\n' "$list_output" | sed -n 's/^:pubkey enc packet:.*keyid \([0-9A-Fa-f]*\).*/\1/p')"

  if [[ -z "$key_ids" ]]; then
    # Not an error -- this file just isn't a public-key-encrypted OpenPGP
    # message, so there's nothing for this script to decrypt. See exit
    # code 4 in the header comment.
    log_system INFO "not a pubkey-encrypted OpenPGP message, nothing to do file=${OPERATE_PATH}"
    log_system DEBUG "gpg list-packets output: ${list_output}"
    GPG_STATUS="skipped"; GPG_REASON="not_gpg_message"; EXIT_CODE=4
    return
  fi

  # Step 2: of those, which does THIS keyring hold the secret half of?
  local candidates=() all_keyids=() seen_report="" keyid pub_fpr sec_fpr uid
  while IFS= read -r keyid; do
    [[ -z "$keyid" ]] && continue
    all_keyids+=("$keyid")

    pub_fpr="$(mfte_gpg_lookup_fingerprint "$keyid" public 2>/dev/null || true)"
    sec_fpr="$(mfte_gpg_lookup_fingerprint "$keyid" secret 2>/dev/null || true)"

    if [[ -n "$sec_fpr" ]]; then
      uid="$(mfte_gpg_uid_for_fingerprint "$sec_fpr" secret)"
      candidates+=("${keyid}|${sec_fpr}|${uid}")
      seen_report="${seen_report}
  key ID ${keyid}: in keyring, secret key present, uid \"${uid}\" -- usable"
      log_system DEBUG "recipient keyid=${keyid} in_keyring=true has_secret=true fingerprint=${sec_fpr} uid=\"${uid}\""
    elif [[ -n "$pub_fpr" ]]; then
      uid="$(mfte_gpg_uid_for_fingerprint "$pub_fpr" public)"
      seen_report="${seen_report}
  key ID ${keyid}: in keyring as PUBLIC key only, uid \"${uid}\" -- no secret half, cannot decrypt here"
      log_system DEBUG "recipient keyid=${keyid} in_keyring=true has_secret=false fingerprint=${pub_fpr} uid=\"${uid}\""
    else
      seen_report="${seen_report}
  key ID ${keyid}: not in this keyring at all"
      log_system DEBUG "recipient keyid=${keyid} in_keyring=false has_secret=false"
    fi
  done <<< "$key_ids"

  RECIPIENT_KEYIDS_CSV="$(IFS=,; echo "${all_keyids[*]}")"
  log_system INFO "recipients checked file=${OPERATE_PATH} total=${#all_keyids[@]} usable=${#candidates[@]} keyids=${RECIPIENT_KEYIDS_CSV}"

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    log_system ERROR "no usable secret key for any recipient file=${OPERATE_PATH} keyids=${RECIPIENT_KEYIDS_CSV}"
    echo "ERROR: no key in this keyring can decrypt ${OPERATE_PATH}." >&2
    printf '%s\n' "$seen_report" >&2
    echo "If this is a new customer, their key needs to be provisioned in this keyring first --" >&2
    echo "that's a separate step, not something this script does." >&2
    MATCHED_KEYID="$RECIPIENT_KEYIDS_CSV"
    GPG_STATUS="no_key"; GPG_REASON="not_onboarded"; EXIT_CODE=3
    return
  fi

  if [[ "${#candidates[@]}" -gt 1 ]]; then
    log_system ERROR "ambiguous: multiple usable secret keys for file=${OPERATE_PATH} count=${#candidates[@]}"
    echo "ERROR: ${OPERATE_PATH} resolves to more than one usable secret key in this keyring --" >&2
    echo "refusing to guess which one to decrypt with." >&2
    printf '%s\n' "$seen_report" >&2
    GPG_REASON="ambiguous_recipients"; EXIT_CODE=1
    return
  fi

  IFS='|' read -r MATCHED_KEYID KEY_FP MATCHED_UID <<< "${candidates[0]}"

  # Step 3: decrypt
  local passphrase_file
  passphrase_file="$(mfte_gpg_passphrase_file "$KEY_FP")"
  if ! mfte_gpg_require_locked_down "$passphrase_file" 600; then
    log_system ERROR "passphrase file failed lockdown check for key=${KEY_FP} file=${OPERATE_PATH}"
    echo "ERROR: passphrase file for key ${KEY_FP} is missing or not properly locked down." >&2
    GPG_REASON="passphrase_not_locked_down"; EXIT_CODE=1
    return
  fi

  if [[ -n "$DEC_OUTPUT_OVERRIDE" ]]; then
    DEC_OUTPUT="$DEC_OUTPUT_OVERRIDE"
    mkdir -p "$(dirname "$DEC_OUTPUT")"
  else
    mkdir -p "${MFTE_GPG_OUTPUT_DIR}"
    local base_name="$FILE_NAME"
    case "$base_name" in
      *.asc|*.gpg|*.pgp) base_name="${base_name%.*}" ;;
      *) base_name="${base_name}.decrypted" ;;
    esac
    DEC_OUTPUT="$(mfte_increment_filename "${MFTE_GPG_OUTPUT_DIR}/${base_name}")"
  fi

  local dec_output_log
  if ! dec_output_log="$(mfte_gpg_run --batch --yes --pinentry-mode loopback --passphrase-file "$passphrase_file" --output "$DEC_OUTPUT" --decrypt "$OPERATE_PATH" 2>&1)"; then
    log_system ERROR "decryption failed file=${OPERATE_PATH} key=${KEY_FP}"
    log_system DEBUG "gpg output: ${dec_output_log}"
    echo "ERROR: decryption failed. See ${SYSTEM_LOG_FILE} for details." >&2
    GPG_REASON="decrypt_failed"; EXIT_CODE=1
    return
  fi

  if [[ -f "$DEC_OUTPUT" ]]; then
    CHECKSUM="$(sha256sum "$DEC_OUTPUT" 2>/dev/null | awk '{print $1}')"
    [[ -z "$CHECKSUM" ]] && CHECKSUM="$(shasum -a 256 "$DEC_OUTPUT" 2>/dev/null | awk '{print $1}')"
  fi

  log_system INFO "complete file=${OPERATE_PATH} recipient_keyid=${MATCHED_KEYID} key=${KEY_FP} uid=\"${MATCHED_UID}\" output=${DEC_OUTPUT} sha256=${CHECKSUM}"
  GPG_STATUS="decrypted"; GPG_REASON=""; EXIT_CODE=0
}

RECIPIENT_KEYIDS_CSV=""
do_receive

###############################################################################
# Relocate to final "return" destinations. The ENCRYPTED original moves on
# EVERY outcome -- decrypted, no_key, skipped/not_gpg_message, or a
# technical error -- because staging is only reachable by mftgpg/root, and
# a file left there after anything but a clean decrypt would be invisible
# to the admin with no way to retry it later. The DECRYPTED output only
# ever exists after a successful decrypt, so its move stays conditional on
# that. See the header comment's "return" section for the full reasoning
# (why this runs as root rather than via runuser -u mftgpg, why retention
# past this point is deliberately not this script's job).
#
# Resolution order for each file: explicit -R/-K override, else computed
# from $MFTE_GPG_RETURN_DIR with the "{TYPE}" placeholder substituted,
# else skip entirely (leave the decrypted file wherever -w put it, leave
# the encrypted original wherever -a found it). Neither flag nor the env
# var are required.
###############################################################################
RETURN_DECRYPTED_PATH=""
RETURN_ENCRYPTED_PATH=""
RETURN_MOVE_OK="true"

# mfte_gpg_resolve_return_path <override> <encrypted|decrypted> <filename>
# Prints the resolved destination path, or nothing (return 1) if neither
# the override nor $MFTE_GPG_RETURN_DIR is set -- callers treat that as
# "skip this file, nothing configured."
#
# $MFTE_GPG_RETURN_DIR supports two forms:
#   - contains the literal token "{TYPE}"       -> substituted with
#     "encrypted"/"decrypted" wherever it appears, e.g.
#     ".../secureTransport/{TYPE}" -> ".../secureTransport/encrypted"
#   - does NOT contain "{TYPE}"                 -> treated as a base
#     directory, with "/encrypted" or "/decrypted" appended as a
#     subfolder automatically, e.g. ".../secureTransport" ->
#     ".../secureTransport/encrypted"
# Either way the two file types always end up in separate subfolders --
# never dumped together into one shared directory -- even if whoever set
# $MFTE_GPG_RETURN_DIR forgot the "{TYPE}" placeholder. The subfolder
# itself doesn't need to pre-exist: the caller's mkdir -p creates it on
# first use.
mfte_gpg_resolve_return_path() {
  local override="$1" type="$2" filename="$3"
  if [[ -n "$override" ]]; then
    printf '%s' "$override"
    return 0
  fi
  [[ -z "$MFTE_GPG_RETURN_DIR" ]] && return 1
  if [[ "$MFTE_GPG_RETURN_DIR" == *'{TYPE}'* ]]; then
    printf '%s/%s' "${MFTE_GPG_RETURN_DIR//\{TYPE\}/$type}" "$filename"
  else
    printf '%s/%s/%s' "$MFTE_GPG_RETURN_DIR" "$type" "$filename"
  fi
}

# Decrypted output -- only exists when the decrypt actually succeeded.
if [[ "$GPG_STATUS" == "decrypted" ]]; then
  TARGET_PATH=""
  if TARGET_PATH="$(mfte_gpg_resolve_return_path "$RETURN_DECRYPTED_OVERRIDE" "decrypted" "$(basename "$DEC_OUTPUT")")"; then
    TARGET_PATH="$(mfte_increment_filename "$TARGET_PATH")"
    if mkdir -p "$(dirname "$TARGET_PATH")" 2>/dev/null && mv -f "$DEC_OUTPUT" "$TARGET_PATH" 2>/dev/null; then
      chmod 644 "$TARGET_PATH" 2>/dev/null
      RETURN_DECRYPTED_PATH="$TARGET_PATH"
      log_system INFO "decrypted output relocated to=${RETURN_DECRYPTED_PATH}"
    else
      log_system ERROR "failed to relocate decrypted output from=${DEC_OUTPUT} to=${TARGET_PATH}"
      echo "ERROR: decrypt succeeded but relocating the output to ${TARGET_PATH} failed. File remains at ${DEC_OUTPUT}." >&2
      RETURN_MOVE_OK="false"
    fi
  fi
fi

# Encrypted original -- ALWAYS archived, on every outcome, as long as the
# file is still actually sitting at OPERATE_PATH (do_receive's very first
# check can fail before the file was ever confirmed present/readable --
# nothing to move in that case, not a failure of this step).
if [[ -f "$OPERATE_PATH" ]]; then
  TARGET_PATH=""
  if TARGET_PATH="$(mfte_gpg_resolve_return_path "$RETURN_ENCRYPTED_OVERRIDE" "encrypted" "$FILE_NAME")"; then
    TARGET_PATH="$(mfte_increment_filename "$TARGET_PATH")"
    if mkdir -p "$(dirname "$TARGET_PATH")" 2>/dev/null && mv -f "$OPERATE_PATH" "$TARGET_PATH" 2>/dev/null; then
      chmod 644 "$TARGET_PATH" 2>/dev/null
      RETURN_ENCRYPTED_PATH="$TARGET_PATH"
      log_system INFO "encrypted original archived to=${RETURN_ENCRYPTED_PATH} gpg_status=${GPG_STATUS}"
    else
      log_system ERROR "failed to relocate encrypted original from=${OPERATE_PATH} to=${TARGET_PATH}"
      echo "ERROR: archiving the encrypted original to ${TARGET_PATH} failed. File remains at ${OPERATE_PATH}." >&2
      RETURN_MOVE_OK="false"
    fi
  fi
fi

###############################################################################
# Build + write the audit record. Carries the same "variables":{...} BMC
# block mfte.rule.vars.all.jsonl.sh writes (via the shared function -- see
# the header comment's "scope" section for why this isn't redundant), plus
# this script's own "gpg":{...} block. Every path reaches here, not just
# success.
###############################################################################
build_json() {
  printf '{'
  mfte_json_kv_string schema "$SCHEMA"
  printf ','; mfte_json_kv_string run_id "$RUN_ID"
  printf ','; mfte_json_kv_string timestamp "$RUN_TS_ISO"
  printf ','; mfte_json_kv_string timestamp_local "$RUN_TS_LOCAL"
  printf ','; mfte_json_kv_string host "$HOST_FQDN"
  printf ','; mfte_json_kv_string run_user "$RUN_USER"
  printf ','; mfte_json_kv_string source "controlm_mfte_processing_rule"
  printf ','; mfte_json_kv_string event "$EVENT"
  printf ','; mfte_json_kv_string rule_name "$RULE_NAME"
  printf ','; mfte_json_kv_string action_name "$ACTION_NAME"

  # mfte_json_bmc_variables_block (mfte.sh) -- shared with
  # mfte.rule.vars.all.jsonl.sh. See the header comment's "scope" section
  # for why this script carries its own full copy of this block instead of
  # relying on that script's record existing for the same event.
  printf ','; mfte_json_bmc_variables_block

  printf ',"file":{'
  mfte_json_kv_string operate_path "$OPERATE_PATH"
  printf '}'

  printf ',"gpg":{'
  mfte_json_kv_string status "$GPG_STATUS"
  printf ','; mfte_json_kv_bool decrypted "$([[ "$GPG_STATUS" == "decrypted" ]] && echo true || echo false)"
  printf ','; mfte_json_kv_string reason "$GPG_REASON"
  printf ','; mfte_json_kv_string recipient_keyid "$MATCHED_KEYID"
  printf ','; mfte_json_kv_string fingerprint "$KEY_FP"
  printf ','; mfte_json_kv_string uid "$MATCHED_UID"
  printf ','; mfte_json_kv_string output "$DEC_OUTPUT"
  printf ','; mfte_json_kv_string sha256 "$CHECKSUM"
  printf '}'

  printf ',"return":{'
  mfte_json_kv_string decrypted_path "$RETURN_DECRYPTED_PATH"
  printf ','; mfte_json_kv_string encrypted_path "$RETURN_ENCRYPTED_PATH"
  printf ','; mfte_json_kv_bool moved "$([[ -n "$RETURN_DECRYPTED_PATH" || -n "$RETURN_ENCRYPTED_PATH" ]] && echo true || echo false)"
  printf ','; mfte_json_kv_bool move_ok "$RETURN_MOVE_OK"
  printf '}'

  printf '}'
  printf '\n'
}

JSON_PAYLOAD="$(build_json)"

write_jsonl_report() { printf '%s\n' "$JSON_PAYLOAD" >> "$JSONL_FILE"; }
write_json_file_report() {
  mkdir -p "$JSON_DIR"
  local safe_file="${FILE_NAME:-unknown}"
  safe_file="${safe_file//[^A-Za-z0-9._-]/_}"
  JSON_FILE="${JSON_DIR}/${RUN_ID}-${safe_file}.json"
  printf '%s\n' "$JSON_PAYLOAD" > "$JSON_FILE"
}

AUDIT_WRITE_OK="true"
case "$OUTPUT_MODE" in
  jsonl) write_jsonl_report || AUDIT_WRITE_OK="false" ;;
  json-file) write_json_file_report || AUDIT_WRITE_OK="false" ;;
  both)
    write_jsonl_report || AUDIT_WRITE_OK="false"
    write_json_file_report || AUDIT_WRITE_OK="false"
    ;;
esac

if [[ "$AUDIT_WRITE_OK" != "true" ]]; then
  log_system ERROR "audit write failed mode=${OUTPUT_MODE} jsonl=${JSONL_FILE} json_dir=${JSON_DIR} gpg_status=${GPG_STATUS}"
  echo "ERROR: failed to write audit record (mode=${OUTPUT_MODE}). Check ownership/permissions on:" >&2
  echo "  jsonl    : $JSONL_FILE" >&2
  echo "  json dir : $JSON_DIR" >&2
  # Deliberately NOT touching EXIT_CODE here -- a successful decrypt stays
  # a successful decrypt even if the audit record failed to write; visible
  # in the log and the stdout audit_write field, not swallowed, just not
  # allowed to overwrite a real success.
fi

if [[ "$QUIET" == "true" ]]; then
  :
elif [[ "$JSON_OUT" == "true" ]]; then
  printf '%s\n' "$JSON_PAYLOAD" | jq .
else
  case "$GPG_STATUS" in
    decrypted)
      printf 'OK file=%s key=%s output=%s return_decrypted=%s return_encrypted=%s move_ok=%s audit_write=%s\n' \
        "$FILE_NAME" "$KEY_FP" "$DEC_OUTPUT" "${RETURN_DECRYPTED_PATH:-none}" "${RETURN_ENCRYPTED_PATH:-none}" "$RETURN_MOVE_OK" "$AUDIT_WRITE_OK"
      ;;
    no_key)
      printf 'NOKEY file=%s recipient_keyids=%s return_encrypted=%s move_ok=%s audit_write=%s\n' \
        "$FILE_NAME" "$MATCHED_KEYID" "${RETURN_ENCRYPTED_PATH:-none}" "$RETURN_MOVE_OK" "$AUDIT_WRITE_OK"
      ;;
    skipped)
      printf 'NOTHING_TO_DO file=%s reason=%s return_encrypted=%s move_ok=%s audit_write=%s\n' \
        "$FILE_NAME" "$GPG_REASON" "${RETURN_ENCRYPTED_PATH:-none}" "$RETURN_MOVE_OK" "$AUDIT_WRITE_OK"
      ;;
    *)
      printf 'ERROR file=%s reason=%s return_encrypted=%s move_ok=%s audit_write=%s\n' \
        "$FILE_NAME" "$GPG_REASON" "${RETURN_ENCRYPTED_PATH:-none}" "$RETURN_MOVE_OK" "$AUDIT_WRITE_OK"
      ;;
  esac
fi

exit "$EXIT_CODE"
