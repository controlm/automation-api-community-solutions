#!/bin/bash

# file name: mfte.sh
# purpose : Shared helpers sourced by every MFTE script (Control-M rule/
#           action scripts and GPG operation scripts alike) -- log_system()
#           execution-trace logging, Control-M-safe argument parsing
#           (mfte_unquote, mfte_dump_argv, mfte_check_no_leftover_args),
#           hand-rolled JSON field builders, and BMC Processing Rule
#           Variable derivation -- so no script has to redefine any of it
#           independently.
#
# origin  : The argument-parsing helpers exist because of real production
#           incidents on mfte.rule.vars.all.jsonl.sh (2026-07-09) caused by
#           how this environment's Control-M agent invokes Run Commands --
#           see mfte_check_no_leftover_args() below for the specifics. The
#           JSON helpers and BMC-variable derivation moved here once a
#           second script (werkstatt.gpg.receive.file.sh) needed the exact
#           same logic mfte.rule.vars.all.jsonl.sh already had.

require_command() {
    local cmd="$1"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Required command not found: ${cmd}" >&2
        exit 1
    fi
}
require_command jq
require_command sha256sum
require_command file
require_command hostname
require_command flock
CONFIG_FILE="/opt/werkstatt/ops/config/.env"
if [[ -r "${CONFIG_FILE}" ]]; then
    set -a
    source "${CONFIG_FILE}"
    set +a
else
    echo "ERROR: ${CONFIG_FILE} not found or not readable -- every MFTE_* variable" >&2
    echo "this script needs (MFTE_SYSTEM_LOG_DIR, MFTE_GPG_*, etc.) comes from that" >&2
    echo "file, so nothing downstream will work without it. Deploy your .env to" >&2
    echo "exactly that path (a locally-named copy like vse.env must be placed there" >&2
    echo "AS .env, not under its working-copy name) and re-run." >&2
    exit 1
fi

###############################################################################
# Shared system-log helper for MFTE scripts
###############################################################################
# Every MFTE script (rule/action scripts, GPG operation scripts, etc.) gets
# the same execution-trace logging by sourcing this file, instead of each
# one redefining log_system()/_log_level_rank() independently. This writes
# to the script's own execution trace (start, arg errors, completion) — it
# is never the sink for business/event data (e.g. cluster.jsonl), which
# each script handles separately.
#
# SCRIPT_NAME honors a value the caller already set (e.g. if it wants a log
# file name that differs from $0) instead of always recomputing it here.
SCRIPT_NAME="${SCRIPT_NAME:-$(basename "$0")}"

: "${MFTE_SYSTEM_LOG_DIR:?MFTE_SYSTEM_LOG_DIR is not set — check that mfte.sh sourced the .env}"
SYSTEM_LOG_FILE="${MFTE_SYSTEM_LOG_DIR}/${SCRIPT_NAME}.log"

_log_level_rank() {
  case "$1" in
    DEBUG) printf '0' ;;
    WARN|WARNING) printf '2' ;;
    ERROR) printf '3' ;;
    *) printf '1' ;; # INFO and anything unrecognized
  esac
}

log_system() {
  local level="$1"; shift
  local threshold msg_rank
  threshold="$(_log_level_rank "${MFTE_LOG_LEVEL:-INFO}")"
  msg_rank="$(_log_level_rank "$level")"
  [[ "$msg_rank" -lt "$threshold" ]] && return 0
  mkdir -p "$(dirname "$SYSTEM_LOG_FILE")" 2>/dev/null
  printf '%s [%s] [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$level" "$SCRIPT_NAME" "$*" >> "$SYSTEM_LOG_FILE"
}

###############################################################################
# Shared argument-parsing helpers for MFTE Control-M rule/action scripts
###############################################################################
# These exist because of real production incidents on
# mfte.rule.vars.all.jsonl.sh (2026-07-09) caused by how this environment's
# Control-M agent invokes Run Commands:
#   - it does NOT strip the quote characters used to group a substituted
#     value; it only uses them to find argument boundaries, then passes the
#     quote characters through as literal text in the argv element
#   - it appends exactly one trailing empty argv element after every real
#     flag, on every invocation, regardless of the file being processed
# Any script parsing $$VAR$$-substituted getopts flags from this agent
# should use these instead of re-deriving the same fixes independently.
###############################################################################

# mfte_unquote VALUE
# Strips one layer of surrounding double quotes, if present. Apply this to
# every OPTARG when parsing a Run Command that quotes its $$VAR$$ tokens --
# this Control-M agent passes the quote characters through literally rather
# than stripping them itself, so -r "Data Upload" arrives as OPTARG value
# "Data Upload" (12 characters, quotes included) unless unquoted.
mfte_unquote() {
    local v="$1"
    v="${v#\"}"
    v="${v%\"}"
    printf '%s' "$v"
}

# mfte_dump_argv "$@"
# Returns a "{1:val} {2:val} ..." style string of the given arguments
# exactly as received -- each one bracketed so an empty string is visible
# as {} rather than invisible whitespace. Log or echo this when diagnosing
# an argument-parsing mismatch; it's ground truth for what a process
# actually received, independent of how Control-M's job log chooses to
# display the "Running command" text (a reconstruction, not proof of the
# literal argv bytes).
mfte_dump_argv() {
    local i=0 a dump=""
    for a in "$@"; do
        i=$((i + 1))
        dump="${dump}{${i}:${a}} "
    done
    printf '%s' "$dump"
}

# mfte_check_no_leftover_args "$@"
# Call this after your own getopts loop and `shift $((OPTIND - 1))`, passing
# whatever remains in "$@". A getopts-based script that takes flags only
# (no legitimate positional arguments) should treat any leftover as a sign
# that parsing broke -- almost always an unquoted $$VAR$$ token upstream
# causing getopts to stop early and silently leave every later flag unset.
#
# Exactly one trailing empty-string argument is tolerated and treated as
# success (return 0): this Control-M agent's own command construction
# consistently appends one empty argv element after every real flag,
# confirmed across multiple separate production runs regardless of which
# file was being processed. Anything else leftover -- multiple arguments,
# or a non-empty one -- returns 1 and prints a diagnostic to stderr; the
# caller decides how to log/exit from there.
#
# This function cannot shift your positional parameters for you (a bash
# function can't mutate its caller's "$@"); it only reports. If nothing
# downstream of your getopts loop relies on "$@", you don't need to shift
# after calling this -- just check the return status.
mfte_check_no_leftover_args() {
    if [[ $# -eq 0 ]]; then
        return 0
    fi
    if [[ $# -eq 1 && -z "$1" ]]; then
        return 0
    fi
    local leftover
    leftover="$(mfte_dump_argv "$@")"
    echo "ERROR: unexpected positional arguments (count=$#): ${leftover}" >&2
    echo "getopts stopped parsing flags early -- check for unquoted \$\$VAR\$\$" >&2
    echo "tokens in the Run Command (most commonly a filename with a space)." >&2
    return 1
}

###############################################################################
# Shared JSON-building helpers for MFTE rule/action scripts
###############################################################################
# Originated in mfte.rule.vars.all.jsonl.sh, moved here once a second script
# (werkstatt.gpg.receive.file.sh) needed the exact same hand-rolled JSON
# construction -- same reasoning as log_system()'s move into this file.
# Hand-rolled rather than built with jq because these get called many times
# per record (one call per field); jq is used elsewhere in this framework
# for one-shot construction/parsing, not for assembling a record field by
# field in a hot loop.

# mfte_json_escape <value>
mfte_json_escape() {
    local s="${1:-}"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

# mfte_json_kv_string <key> <value>
mfte_json_kv_string() {
    local key="$1"
    local value="$2"
    printf '"%s":"%s"' "$(mfte_json_escape "$key")" "$(mfte_json_escape "$value")"
}

# mfte_json_kv_bool <key> <"true"|anything else>
mfte_json_kv_bool() {
    local key="$1"
    local value="$2"
    if [[ "$value" == "true" ]]; then
        printf '"%s":true' "$(mfte_json_escape "$key")"
    else
        printf '"%s":false' "$(mfte_json_escape "$key")"
    fi
}

# mfte_json_kv_raw <key> <already-valid-json-value>
# Caller's responsibility that <value> is valid JSON already (e.g. a
# sub-object built by the same field-at-a-time approach, or "null").
mfte_json_kv_raw() {
    local key="$1"
    local value="$2"
    printf '"%s":%s' "$(mfte_json_escape "$key")" "$value"
}

# mfte_json_kv_number_or_raw <key> <value>
# Emits a bare JSON number if <value> is all digits, null if empty, or both
# a null AND a "<key>_raw" string field if it's something else entirely
# (e.g. FILE_SIZE arriving as something non-numeric) -- degrades instead of
# either lying with a wrong type or dropping the field silently.
mfte_json_kv_number_or_raw() {
    local key="$1"
    local value="$2"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '"%s":%s' "$(mfte_json_escape "$key")" "$value"
    elif [[ -z "$value" ]]; then
        printf '"%s":null' "$(mfte_json_escape "$key")"
    else
        printf '"%s":null,"%s_raw":"%s"' "$(mfte_json_escape "$key")" "$(mfte_json_escape "$key")" "$(mfte_json_escape "$value")"
    fi
}

# mfte_derive_bmc_file_vars <best_available_path>
###############################################################################
# Fills in FILE_NAME / FILE_ABS_DIR / FILE_EXT / FILE_EXT_NO_DOT /
# FILE_NAME_NO_EXT / FILE_SIZE from whatever BMC variables the caller
# already has set as globals (FILE_ABS_PATH, FILE_PATH, FILE_NAME, ...) --
# never overwrites a value MFT actually supplied, only fills gaps. Shared
# by mfte.rule.vars.all.jsonl.sh and werkstatt.gpg.receive.file.sh, which
# both parse the same set of BMC $$VAR$$ flags but differ in which path is
# "the" reliable one to stat() -- rule.vars.sh only ever had FILE_ABS_PATH
# for this; receive.file.sh's -p is its one required flag, so it also
# needs a FILE_PATH fallback when FILE_ABS_PATH wasn't given. Rather than
# hardcode either script's assumption, the caller passes whichever path it
# considers authoritative as <best_available_path> (receive.file.sh's
# OPERATE_PATH, rule.vars.sh's FILE_ABS_PATH).
#
# The getopts parsing loop itself deliberately stays per-script, NOT
# shared here -- a "shared" getopts pass with a restricted optstring
# doesn't just ignore flags outside it, it silently treats the following
# argument as a stray positional and stops parsing everything after that
# point (confirmed by testing: -O "/a/path" against a getopts call that
# only knows -p leaves "/a/path" as a leftover positional and never even
# reaches a -q that came after it). Splitting parsing into "shared common
# flags + script-specific flags" isn't just less readable, it's unsafe.
mfte_derive_bmc_file_vars() {
    local best_path="$1"
    if [[ -n "$FILE_ABS_PATH" ]]; then
        [[ -z "$FILE_NAME" ]] && FILE_NAME="$(basename "$FILE_ABS_PATH")"
        [[ -z "$FILE_ABS_DIR" ]] && FILE_ABS_DIR="$(dirname "$FILE_ABS_PATH")"
    elif [[ -z "$FILE_NAME" && -n "$FILE_PATH" ]]; then
        FILE_NAME="$(basename "$FILE_PATH")"
    fi
    if [[ -n "$FILE_NAME" ]]; then
        [[ -z "$FILE_EXT" && "$FILE_NAME" == *.* ]] && FILE_EXT=".${FILE_NAME##*.}"
        [[ -z "$FILE_EXT_NO_DOT" && -n "$FILE_EXT" ]] && FILE_EXT_NO_DOT="${FILE_EXT#.}"
        [[ -z "$FILE_NAME_NO_EXT" ]] && FILE_NAME_NO_EXT="${FILE_NAME%$FILE_EXT}"
    fi
    if [[ -n "$best_path" && -f "$best_path" && -z "$FILE_SIZE" ]]; then
        FILE_SIZE="$(stat -c '%s' "$best_path" 2>/dev/null || stat -f '%z' "$best_path" 2>/dev/null || true)"
    fi
}

# mfte_json_bmc_variables_block
###############################################################################
# Emits the `"variables":{...}` JSON fragment (no surrounding braces on the
# object itself -- caller wraps it, matching how every other build_json()
# fragment in this framework composes) for the 20 BMC Processing Rule
# Variables, reading them as globals. Shared by the same two scripts as
# mfte_derive_bmc_file_vars above, for the same reason -- this exact block
# was byte-for-byte identical between them before being pulled out here.
mfte_json_bmc_variables_block() {
  printf '"variables":{'
  mfte_json_kv_string 'FILE_PATH' "$FILE_PATH"
  printf ','; mfte_json_kv_string 'FILE_ABS_PATH' "$FILE_ABS_PATH"
  printf ','; mfte_json_kv_string 'FILE_DIR' "$FILE_DIR"
  printf ','; mfte_json_kv_string 'FILE_ABS_DIR' "$FILE_ABS_DIR"
  printf ','; mfte_json_kv_string 'FILE_NAME' "$FILE_NAME"
  printf ','; mfte_json_kv_string 'FILE_NAME_NO_EXT' "$FILE_NAME_NO_EXT"
  printf ','; mfte_json_kv_string 'FILE_EXT' "$FILE_EXT"
  printf ','; mfte_json_kv_string 'FILE_EXT_NO_DOT' "$FILE_EXT_NO_DOT"
  printf ','; mfte_json_kv_string 'FILE_DATE' "$FILE_DATE"
  printf ','; mfte_json_kv_string 'FILE_DATE_LOCAL' "$FILE_DATE_LOCAL"
  printf ','; mfte_json_kv_string 'FILE_TIME' "$FILE_TIME"
  printf ','; mfte_json_kv_string 'FILE_TIME_LOCAL' "$FILE_TIME_LOCAL"
  printf ','; mfte_json_kv_number_or_raw 'FILE_SIZE' "$FILE_SIZE"
  printf ','; mfte_json_kv_string 'USER' "$MFT_USER"
  printf ','; mfte_json_kv_string 'COMPANY' "$COMPANY"
  printf ','; mfte_json_kv_string 'VIRTUAL_FOLDER' "$VIRTUAL_FOLDER"
  printf ','; mfte_json_kv_string 'EMAIL' "$EMAIL"
  printf ','; mfte_json_kv_string 'PHONE_NUMBER' "$PHONE_NUMBER"
  printf ','; mfte_json_kv_string 'SUB_DIR_PATH' "$SUB_DIR_PATH"
  printf ','; mfte_json_kv_string 'STAGING_FILE_NAME' "$STAGING_FILE_NAME"
  printf ','; mfte_json_kv_string 'STAGING_FILE_PATH' "$STAGING_FILE_PATH"
  printf '}'
}
