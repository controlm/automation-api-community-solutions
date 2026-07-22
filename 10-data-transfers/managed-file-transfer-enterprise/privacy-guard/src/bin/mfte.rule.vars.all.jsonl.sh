#!/usr/bin/env bash
set -o pipefail

# cluster.jsonl is a shared, multi-writer log by design (its own name says
# "cluster") — different rules, actions, or hub nodes may all append to it
# under different OS users. Default root umask (022) creates files as 644,
# which makes the "controlm" group ownership read-only in practice and
# silently blocks every writer except whoever created the file first. 002
# keeps files group-writable (664) so the controlm group is actually
# functional as a shared-access mechanism, not just cosmetic ownership.
umask 002

# file name: mfte.rule.vars.all.jsonl.sh
# purpose : Capture ALL BMC Control-M MFT Enterprise Processing Rule Action Rule Variables as JSONL.
# style   : small Run Command, short flags, one JSON object per rule action/run.
#
###############################################################################
# WHY THE ARGUMENT PARSING LOOKS LIKE THIS (read before templating this script)
###############################################################################
#
# If you copy this script for another rule, keep the three defenses below.
# All three were added after real production failures on this exact script,
# not speculative hardening -- each one has a reproduced incident behind it.
#
# 1. EVERY $$VAR$$ TOKEN IN THE RUN COMMAND MUST BE DOUBLE-QUOTED.
#    bash's getopts stops parsing options the instant it hits a bareword
#    that doesn't start with "-". BMC substitutes $$FILE_NAME$$ etc. as raw
#    text into the Run Command with no quoting of its own -- so an unquoted
#    filename containing a space (e.g. "Generative AI for VSE.PPTX") splits
#    into multiple shell words, getopts hits "AI" as an unrecognized
#    bareword, and EVERY flag after that point in the command line is never
#    parsed. This happened in production: the resulting JSONL record had
#    one truncated field and every other field blank, with exit code 0 --
#    a silently near-empty audit record reported as a success. Quoting
#    every $$VAR$$ token (-p "$$FILE_PATH$$", not -p $$FILE_PATH$$) is what
#    prevents word-splitting from happening in the first place.
#
# 2. OPTARG VALUES ARE UNQUOTED VIA mfte_unquote() (FROM mfte.sh).
#    Quoting the Run Command (fix #1) stops the word-splitting, but this
#    Control-M agent's own Run Command tokenizer does NOT strip the quote
#    characters it uses to find argument boundaries -- it passes them
#    through as literal characters. Confirmed by dumping raw argv in
#    production: -r "Data Upload" arrived as the literal 12-character
#    string  "Data Upload"  (quotes included), and -s "" arrived as the
#    literal 2-character string  ""  rather than a true empty string.
#    Without stripping, every field in the JSON output would carry stray
#    leading/trailing quote characters. mfte_unquote() removes exactly one
#    layer of surrounding double quotes from each OPTARG so stored values
#    match what was actually substituted, independent of this quirk. It
#    lives in mfte.sh, not here, so every MFTE rule/action script gets the
#    fix by sourcing the shared lib instead of re-deriving it.
#
# 3. LEFTOVER POSITIONAL ARGUMENTS AFTER getopts ARE TREATED AS FATAL,
#    WITH ONE SPECIFIC EXCEPTION -- CHECKED VIA mfte_check_no_leftover_args()
#    (FROM mfte.sh).
#    This script takes flags only -- there is no legitimate positional
#    argument, ever. If getopts stops early (see #1), whatever it didn't
#    consume is left in "$@" and silently ignored by default, which is
#    exactly how the near-empty record above shipped with exit 0. So any
#    leftover argument is now fatal (exit 2) UNLESS it is exactly one
#    trailing empty string -- this Control-M agent consistently appends
#    one empty argv element after every real flag, confirmed across
#    multiple separate production runs regardless of which file was being
#    processed. That specific, well-evidenced pattern is discarded; any
#    other leftover (multiple args, or a non-empty one) still fails loudly
#    rather than completing with partial data. This check also lives in
#    mfte.sh so every rule/action script shares one definition of "known
#    benign" vs. "actually broken." If you template this script for a Run
#    Command invoked by something other than this Control-M agent,
#    re-verify whether that trailing-empty-argument tolerance still
#    applies -- it's an artifact of this specific caller, not a general
#    getopts behavior.
#
# mfte_unquote(), mfte_dump_argv(), and mfte_check_no_leftover_args() are
# defined in mfte.sh, sourced below via MFTE_LIB_DIR -- not redefined in
# this file. If mfte.sh doesn't provide them (older copy, wrong
# MFTE_LIB_DIR), this script will fail with "command not found" rather than
# silently falling back to unsafe parsing.
#
# The ARGV[...] log line (system log always; stderr only on the failure
# path) exists so a future parsing mismatch can be diagnosed from the exact
# bytes the process received, rather than trusting Control-M's "Running
# command:" display, which is a reconstruction, not proof of real argv.
###############################################################################

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="controlm_mfte_processing_rule_variables_v1"

# Determine the framework home relative to this script. Honor MFTE_OPS_HOME
# if it's already exported (e.g. sourced from the framework .env) instead of
# recomputing it, so the script stays correct if it's ever relocated/symlinked.
export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# MFTE_LIB_DIR is also defined by the .env (as ${MFTE_OPS_HOME}/lib). Honor it
# if already set instead of hardcoding the "lib" path segment here too.
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"

# Load the shared library
# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.sh" >&2
  echo "If MFTE_OPS_HOME/MFTE_LIB_DIR were already exported in this shell (e.g. from an earlier" >&2
  echo "'source .env' in the same session), they override this script's own location-based" >&2
  echo "derivation -- a stale value from a different host/mount can point here at nothing." >&2
  echo "Try: unset MFTE_OPS_HOME MFTE_LIB_DIR" >&2
  exit 1
fi

# LOG_DIR is owned by the framework .env (MFTE_LOG_DIR) — no local fallback
# tiers. If mfte.sh didn't load MFTE_LOG_DIR, fail loudly instead of silently
# writing somewhere the .env doesn't say.
: "${MFTE_LOG_DIR:?MFTE_LOG_DIR is not set — check that mfte.sh sourced the .env}"
LOG_DIR="${MFTE_LOG_DIR}"

# JSONL_FILE / JSON_DIR are also owned by the framework .env — same fail-loud
# treatment as MFTE_LOG_DIR above. OUTPUT_MODE reads MFTE_LOG_FORMAT (the
# "Logging Mode" section of the .env) — that's the framework's one source of
# truth for output format, so this script doesn't carry a second env key for
# the same concept. It keeps a default since it's a run-mode switch
# (validated below), not a path, and -o can override it either way.
: "${MFTE_JSONL_FILE:?MFTE_JSONL_FILE is not set — check that mfte.sh sourced the .env}"
: "${MFTE_JSON_DIR:?MFTE_JSON_DIR is not set — check that mfte.sh sourced the .env}"
JSONL_FILE="${MFTE_JSONL_FILE}"
JSON_DIR="${MFTE_JSON_DIR}"
OUTPUT_MODE="${MFTE_LOG_FORMAT:-jsonl}"
QUIET="false"
EVENT="file_rule_action"
RULE_NAME=""
ACTION_NAME=""
SKIP_ENRICH="false"

# System log — the script's own execution trace (start, arg errors,
# completion), kept separate from the MFTE event JSONL above, which is
# business file-processing data, not script diagnostics. SYSTEM_LOG_FILE,
# _log_level_rank(), and log_system() are now defined in mfte.sh (shared by
# every MFTE script) rather than redefined here — see mfte.sh if you're
# looking for that implementation.
usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [short options]

Short options mapped to ALL BMC MFT Enterprise Action Rule Variables:
  -p  FILE_PATH             \$\$FILE_PATH\$\$
  -a  FILE_ABS_PATH         \$\$FILE_ABS_PATH\$\$
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
  -c  COMPANY               \$\$COMPANY\$\$
  -v  VIRTUAL_FOLDER        \$\$VIRTUAL_FOLDER\$\$
  -m  EMAIL                 \$\$EMAIL\$\$
  -t  PHONE_NUMBER          \$\$PHONE_NUMBER\$\$
  -s  SUB_DIR_PATH          \$\$SUB_DIR_PATH\$\$
  -g  STAGING_FILE_NAME     \$\$STAGING_FILE_NAME\$\$
  -G  STAGING_FILE_PATH     \$\$STAGING_FILE_PATH\$\$

Optional metadata, not BMC variables:
  -r  rule name
  -A  action name
  -k  event name/type                         default: file_rule_action
  -o  output mode: jsonl | json-file | both   default: \$MFTE_LOG_FORMAT (from .env), else jsonl
  -l  custom log directory                    default: \$MFTE_LOG_DIR (from .env); overrides JSONL_FILE/JSON_DIR too
  -T  skip enrichment (sha256 + tika)         default: enabled when file + \$MFTE_TIKA_JAR are reachable
  -q  quiet mode
  -h  help

Tika enrichment (mime + version + metadata) can be turned off persistently
via \$MFTE_TIKA_ENABLED=false in the .env, independent of -T (which also
skips sha256). sha256 is unaffected by \$MFTE_TIKA_ENABLED.

Script execution trace (start/errors/completion, not MFTE event data) is
written to \$MFTE_SYSTEM_LOG_DIR/$SCRIPT_NAME.log, filtered by \$MFTE_LOG_LEVEL.

Recommended Run Command with all BMC variables:
  $SCRIPT_NAME -r "<rule_name>" -A "<action_name>" -p "\$\$FILE_PATH\$\$" -a "\$\$FILE_ABS_PATH\$\$" -d "\$\$FILE_DIR\$\$" -D "\$\$FILE_ABS_DIR\$\$" -n "\$\$FILE_NAME\$\$" -N "\$\$FILE_NAME_NO_EXT\$\$" -e "\$\$FILE_EXT\$\$" -E "\$\$FILE_EXT_NO_DOT\$\$" -x "\$\$FILE_DATE\$\$" -X "\$\$FILE_DATE_LOCAL\$\$" -y "\$\$FILE_TIME\$\$" -Y "\$\$FILE_TIME_LOCAL\$\$" -z "\$\$FILE_SIZE\$\$" -u "\$\$USER\$\$" -c "\$\$COMPANY\$\$" -v "\$\$VIRTUAL_FOLDER\$\$" -m "\$\$EMAIL\$\$" -t "\$\$PHONE_NUMBER\$\$" -s "\$\$SUB_DIR_PATH\$\$" -g "\$\$STAGING_FILE_NAME\$\$" -G "\$\$STAGING_FILE_PATH\$\$" -q

IMPORTANT: every \$\$VAR\$\$ token above MUST stay quoted. BMC frequently
substitutes an empty string for optional fields (phone, email, company,
sub-dir path). An unquoted empty substitution collapses its flag directly
against the next flag on the line (e.g. "-t -s" instead of "-t '' -s"), and
getopts silently swallows the next flag as this one's argument -- corrupting
both fields with no error. Quoting turns an empty substitution into an
explicit empty argument token instead of nothing at all.
USAGE
}

# Initialize all BMC variables.
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

# Log the raw argv exactly as received, before getopts interprets any of it.
# This is the ground truth for what the invoker (Control-M or a human)
# actually passed -- independent of how Control-M's own job log chooses to
# display the "Running command" text, which is a reconstruction, not proof
# of the literal bytes that hit this process's argument list. Always kept in
# the system log (cheap, useful history); only echoed to stderr on the
# failure path below, not on every successful run.
# mfte_dump_argv and mfte_unquote come from mfte.sh (shared across MFTE
# rule/action scripts, not redefined here) -- see the comment block near the
# top of this file for why they exist.
ARGV_DUMP="$(mfte_dump_argv "$@")"
ARGV_COUNT="$#"
log_system INFO "argv[$#]: ${ARGV_DUMP}"

while getopts ':p:a:d:D:n:N:e:E:x:X:y:Y:z:u:c:v:m:t:s:g:G:r:A:k:o:l:Tqh' opt; do
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
    o) OUTPUT_MODE="$(mfte_unquote "$OPTARG")" ;;
    l)
      LOG_DIR="$(mfte_unquote "$OPTARG")"
      JSONL_FILE="${LOG_DIR}/mfte-rule-vars.jsonl"
      JSON_DIR="${LOG_DIR}/mfte-rule-vars.d"
      ;;
    T) SKIP_ENRICH="true" ;;
    q) QUIET="true" ;;
    h) usage; exit 0 ;;
    :) log_system ERROR "missing value for -$OPTARG"; echo "Missing value for -$OPTARG" >&2; usage; exit 2 ;;
    \?) log_system ERROR "unknown option -$OPTARG"; echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done

# Every argument to this script is a flag — there is no legitimate positional
# argument. If anything is left over after getopts, it means an unquoted
# $$VAR$$ substitution (most commonly a filename with a space) broke word
# splitting and getopts silently stopped parsing partway through, leaving
# every remaining -flag unset. That already happened once in production
# (Data Upload rule, filenames with spaces) and produced a near-empty JSON
# record with exit code 0. Fail loudly instead of repeating that.
#
# mfte_check_no_leftover_args (from mfte.sh) tolerates exactly one trailing
# empty argv element -- a confirmed, benign artifact of how this Control-M
# agent builds its command line -- and fails on anything else. Nothing below
# this point uses "$@", so there's no need to shift after the check.
shift $((OPTIND - 1))
if ! mfte_check_no_leftover_args "$@"; then
  log_system ERROR "unexpected positional arguments after parsing (OPTIND=${OPTIND}, count=$#): $(mfte_dump_argv "$@")"
  echo "Full raw argv as received: ARGV[${ARGV_COUNT:-?}]: ${ARGV_DUMP}" >&2
  exit 2
fi

case "$OUTPUT_MODE" in
  jsonl|json-file|both) ;;
  *) log_system ERROR "invalid -o output mode: $OUTPUT_MODE"; echo "Invalid -o output mode: $OUTPUT_MODE" >&2; exit 2 ;;
esac

# JSONL_FILE and JSON_DIR are independent .env values now (not derived from
# LOG_DIR), so create their actual parent dirs rather than assuming they sit
# under LOG_DIR.
mkdir -p "$LOG_DIR" "$(dirname "$JSONL_FILE")" "$JSON_DIR" "$MFTE_SYSTEM_LOG_DIR"

log_system INFO "start rule=${RULE_NAME:-none} action=${ACTION_NAME:-none} file=${FILE_ABS_PATH:-${FILE_NAME:-none}} mode=${OUTPUT_MODE}"

RUN_TS_LOCAL="$(date '+%Y-%m-%d %H:%M:%S')"
RUN_TS_ISO="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-$$"
# Prefer the FQDN the .env already resolved (MFTE_HOST_FQDN); only shell out
# to hostname if the framework env didn't provide one.
HOST_FQDN="${MFTE_HOST_FQDN:-$(hostname -f 2>/dev/null || hostname)}"
RUN_USER="$(whoami 2>/dev/null || printf unknown)"

# Derive missing convenience values only when MFT did not pass them.
if [[ -n "$FILE_ABS_PATH" ]]; then
  [[ -z "$FILE_NAME" ]] && FILE_NAME="$(basename "$FILE_ABS_PATH")"
  [[ -z "$FILE_ABS_DIR" ]] && FILE_ABS_DIR="$(dirname "$FILE_ABS_PATH")"
fi
if [[ -n "$FILE_NAME" ]]; then
  [[ -z "$FILE_EXT" && "$FILE_NAME" == *.* ]] && FILE_EXT=".${FILE_NAME##*.}"
  [[ -z "$FILE_EXT_NO_DOT" && -n "$FILE_EXT" ]] && FILE_EXT_NO_DOT="${FILE_EXT#.}"
  [[ -z "$FILE_NAME_NO_EXT" ]] && FILE_NAME_NO_EXT="${FILE_NAME%$FILE_EXT}"
fi
if [[ -n "$FILE_ABS_PATH" && -f "$FILE_ABS_PATH" && -z "$FILE_SIZE" ]]; then
  FILE_SIZE="$(stat -c '%s' "$FILE_ABS_PATH" 2>/dev/null || stat -f '%z' "$FILE_ABS_PATH" 2>/dev/null || true)"
fi

# Enrichment: sha256 checksum + Apache Tika MIME/version/metadata detection.
# Best-effort — requires the file to actually be reachable on this host.
# Skip entirely with -T (each Tika call is a JVM cold start). Tika
# specifically (not sha256) can also be turned off persistently via
# MFTE_TIKA_ENABLED in the .env, independent of the per-run -T flag --
# useful if Tika should stay off by default on a given host without every
# caller having to remember to pass -T.
HASH_ALGORITHM="${MFTE_HASH_ALGORITHM:-sha256}"
TIKA_JAR="${MFTE_TIKA_JAR:-}"
TIKA_ENABLED="${MFTE_TIKA_ENABLED:-true}"
ENRICH_FILE="false"
ENRICH_SHA256="false"
ENRICH_TIKA="false"
ENRICH_TIKA_METADATA="false"
CHECKSUM=""
MIME_TYPE=""
TIKA_VERSION=""
TIKA_METADATA_JSON="null"

if [[ "$SKIP_ENRICH" != "true" && -n "$FILE_ABS_PATH" && -f "$FILE_ABS_PATH" && -r "$FILE_ABS_PATH" ]]; then
  ENRICH_FILE="true"

  case "$HASH_ALGORITHM" in
    sha256)
      CHECKSUM="$(sha256sum "$FILE_ABS_PATH" 2>/dev/null | awk '{print $1}')"
      [[ -z "$CHECKSUM" ]] && CHECKSUM="$(shasum -a 256 "$FILE_ABS_PATH" 2>/dev/null | awk '{print $1}')"
      [[ -n "$CHECKSUM" ]] && ENRICH_SHA256="true"
      ;;
    *)
      : # MFTE_HASH_ALGORITHM isn't sha256 — no matching command wired up, skip rather than guess
      ;;
  esac

  TIKA_AVAILABLE="false"
  if [[ "$TIKA_ENABLED" == "true" ]] && command -v java >/dev/null 2>&1 && [[ -n "$TIKA_JAR" && -f "$TIKA_JAR" && -r "$TIKA_JAR" ]]; then
    TIKA_AVAILABLE="true"
  fi

  if [[ "${TIKA_AVAILABLE}" == "true" ]]; then
    MIME_TYPE="$(java -jar "${TIKA_JAR}" --detect "${FILE_ABS_PATH}" 2>/dev/null)"
    TIKA_VERSION="$(java -jar "${TIKA_JAR}" --version 2>/dev/null)"
    [[ -n "$MIME_TYPE" ]] && ENRICH_TIKA="true"

    # -j/--metadata gives document metadata (author, title, created/modified
    # dates embedded in the file itself, page counts, etc.) -- a different,
    # generally richer thing than the --detect mime type above. jq is a hard
    # dependency of mfte.sh (require_command jq) so it's guaranteed present
    # here. Tika's -j output for a single non-recursive file is normally a
    # plain JSON object, but the jq filter below also unwraps a one-element
    # array just in case, so a format difference degrades to "no metadata"
    # rather than a shell error.
    _tika_metadata_raw="$(java -jar "${TIKA_JAR}" -j "${FILE_ABS_PATH}" 2>/dev/null)"
    if [[ -n "$_tika_metadata_raw" ]]; then
      _tika_metadata_compact="$(printf '%s' "$_tika_metadata_raw" | jq -c 'if type=="array" then .[0] else . end' 2>/dev/null)"
      if [[ -n "$_tika_metadata_compact" && "$_tika_metadata_compact" != "null" ]]; then
        TIKA_METADATA_JSON="$_tika_metadata_compact"
        ENRICH_TIKA_METADATA="true"
      fi
    fi
    unset _tika_metadata_raw _tika_metadata_compact
  fi
fi

json_escape() {
  local s="${1:-}"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

json_kv_string() {
  local key="$1"
  local value="$2"
  printf '"%s":"%s"' "$(json_escape "$key")" "$(json_escape "$value")"
}

json_kv_bool() {
  local key="$1"
  local value="$2"
  if [[ "$value" == "true" ]]; then
    printf '"%s":true' "$(json_escape "$key")"
  else
    printf '"%s":false' "$(json_escape "$key")"
  fi
}

json_kv_raw() {
  local key="$1"
  local value="$2"
  printf '"%s":%s' "$(json_escape "$key")" "$value"
}

json_kv_number_or_raw() {
  local key="$1"
  local value="$2"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '"%s":%s' "$(json_escape "$key")" "$value"
  elif [[ -z "$value" ]]; then
    printf '"%s":null' "$(json_escape "$key")"
  else
    printf '"%s":null,"%s_raw":"%s"' "$(json_escape "$key")" "$(json_escape "$key")" "$(json_escape "$value")"
  fi
}

build_json() {
  printf '{'
  json_kv_string schema "$SCHEMA"
  printf ','; json_kv_string run_id "$RUN_ID"
  printf ','; json_kv_string timestamp "$RUN_TS_ISO"
  printf ','; json_kv_string timestamp_local "$RUN_TS_LOCAL"
  printf ','; json_kv_string host "$HOST_FQDN"
  printf ','; json_kv_string run_user "$RUN_USER"
  printf ','; json_kv_string source "controlm_mfte_processing_rule"
  printf ','; json_kv_string event "$EVENT"
  printf ','; json_kv_string rule_name "$RULE_NAME"
  printf ','; json_kv_string action_name "$ACTION_NAME"

  printf ',"variables":{'
  json_kv_string 'FILE_PATH' "$FILE_PATH"
  printf ','; json_kv_string 'FILE_ABS_PATH' "$FILE_ABS_PATH"
  printf ','; json_kv_string 'FILE_DIR' "$FILE_DIR"
  printf ','; json_kv_string 'FILE_ABS_DIR' "$FILE_ABS_DIR"
  printf ','; json_kv_string 'FILE_NAME' "$FILE_NAME"
  printf ','; json_kv_string 'FILE_NAME_NO_EXT' "$FILE_NAME_NO_EXT"
  printf ','; json_kv_string 'FILE_EXT' "$FILE_EXT"
  printf ','; json_kv_string 'FILE_EXT_NO_DOT' "$FILE_EXT_NO_DOT"
  printf ','; json_kv_string 'FILE_DATE' "$FILE_DATE"
  printf ','; json_kv_string 'FILE_DATE_LOCAL' "$FILE_DATE_LOCAL"
  printf ','; json_kv_string 'FILE_TIME' "$FILE_TIME"
  printf ','; json_kv_string 'FILE_TIME_LOCAL' "$FILE_TIME_LOCAL"
  printf ','; json_kv_number_or_raw 'FILE_SIZE' "$FILE_SIZE"
  printf ','; json_kv_string 'USER' "$MFT_USER"
  printf ','; json_kv_string 'COMPANY' "$COMPANY"
  printf ','; json_kv_string 'VIRTUAL_FOLDER' "$VIRTUAL_FOLDER"
  printf ','; json_kv_string 'EMAIL' "$EMAIL"
  printf ','; json_kv_string 'PHONE_NUMBER' "$PHONE_NUMBER"
  printf ','; json_kv_string 'SUB_DIR_PATH' "$SUB_DIR_PATH"
  printf ','; json_kv_string 'STAGING_FILE_NAME' "$STAGING_FILE_NAME"
  printf ','; json_kv_string 'STAGING_FILE_PATH' "$STAGING_FILE_PATH"
  printf '}'

  printf ',"file":{'
  json_kv_string path "$FILE_PATH"
  printf ','; json_kv_string abs_path "$FILE_ABS_PATH"
  printf ','; json_kv_string dir "$FILE_DIR"
  printf ','; json_kv_string abs_dir "$FILE_ABS_DIR"
  printf ','; json_kv_string name "$FILE_NAME"
  printf ','; json_kv_string name_no_ext "$FILE_NAME_NO_EXT"
  printf ','; json_kv_string ext "$FILE_EXT"
  printf ','; json_kv_string ext_no_dot "$FILE_EXT_NO_DOT"
  printf ','; json_kv_number_or_raw size_bytes "$FILE_SIZE"
  printf ','; json_kv_string date_utc "$FILE_DATE"
  printf ','; json_kv_string date_local "$FILE_DATE_LOCAL"
  printf ','; json_kv_string time_utc "$FILE_TIME"
  printf ','; json_kv_string time_local "$FILE_TIME_LOCAL"
  printf '}'

  printf ',"actor":{'
  json_kv_string user "$MFT_USER"
  printf ','; json_kv_string company "$COMPANY"
  printf ','; json_kv_string email "$EMAIL"
  printf ','; json_kv_string phone_number "$PHONE_NUMBER"
  printf '}'

  printf ',"mfte":{'
  json_kv_string virtual_folder "$VIRTUAL_FOLDER"
  printf ','; json_kv_string sub_dir_path "$SUB_DIR_PATH"
  printf '}'

  printf ',"staging":{'
  json_kv_string file_name "$STAGING_FILE_NAME"
  printf ','; json_kv_string file_path "$STAGING_FILE_PATH"
  printf '}'

  printf ',"enrichment":{'
  json_kv_bool file "$ENRICH_FILE"
  printf ','; json_kv_bool sha256 "$ENRICH_SHA256"
  printf ','; json_kv_bool tika "$ENRICH_TIKA"
  printf ','; json_kv_bool tika_metadata "$ENRICH_TIKA_METADATA"
  printf '}'

  printf ',"checksum":{'
  json_kv_string algorithm "$HASH_ALGORITHM"
  printf ','; json_kv_string value "$CHECKSUM"
  printf '}'

  printf ',"tika":{'
  json_kv_string version "$TIKA_VERSION"
  printf ','; json_kv_string mime "$MIME_TYPE"
  printf ','; json_kv_raw metadata "$TIKA_METADATA_JSON"
  printf '}'

  printf '}'
  printf '\n'
}

# Build the record once and reuse it for every sink (jsonl file, json-file,
# and the stdout echo below) rather than calling build_json() repeatedly --
# same content each time since the underlying data is already fixed by this
# point, so recomputing it per sink is just wasted work.
JSON_PAYLOAD="$(build_json)"

write_jsonl_report() {
  printf '%s\n' "$JSON_PAYLOAD" >> "$JSONL_FILE"
}

write_json_file_report() {
  mkdir -p "$JSON_DIR"
  local safe_file="${FILE_NAME:-unknown}"
  safe_file="${safe_file//[^A-Za-z0-9._-]/_}"
  JSON_FILE="${JSON_DIR}/${RUN_ID}-${safe_file}.json"
  printf '%s\n' "$JSON_PAYLOAD" > "$JSON_FILE"
}

# Track write success explicitly. The write redirect failing (e.g.
# permission denied) must not be allowed to silently fall through to a
# "capture complete" report and exit 0 — that would tell Control-M the job
# succeeded while the audit record was never written.
WRITE_OK="true"
case "$OUTPUT_MODE" in
  jsonl) write_jsonl_report || WRITE_OK="false" ;;
  json-file) write_json_file_report || WRITE_OK="false" ;;
  both)
    write_jsonl_report || WRITE_OK="false"
    write_json_file_report || WRITE_OK="false"
    ;;
esac

if [[ "$WRITE_OK" != "true" ]]; then
  log_system ERROR "write failed mode=${OUTPUT_MODE} jsonl=${JSONL_FILE} json_dir=${JSON_DIR}"
  {
    echo "ERROR: failed to write MFT rule variable capture (mode=${OUTPUT_MODE})."
    echo "Check ownership/permissions on:"
    echo "  jsonl    : $JSONL_FILE"
    echo "  json dir : $JSON_DIR"
  } >&2
  exit 1
fi

log_system INFO "complete mode=${OUTPUT_MODE} jsonl=${JSONL_FILE} json_dir=${JSON_DIR} json_file=${JSON_FILE:-none}"

if [[ "$QUIET" != "true" ]]; then
  # Print the actual JSON record to stdout so it lands in whatever captures
  # this script's output (e.g. Control-M's "Action output"), not just the
  # human-readable summary below. Skipped entirely under -q.
  printf '%s\n' "$JSON_PAYLOAD"

  cat <<REPORT
MFT rule variable capture complete
  mode     : $OUTPUT_MODE
  jsonl    : $JSONL_FILE
  json dir : $JSON_DIR
  json file: ${JSON_FILE:-not written}
  file     : $FILE_ABS_PATH
REPORT
fi

exit 0
