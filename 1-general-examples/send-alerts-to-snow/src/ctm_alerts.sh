#!/bin/bash

# CTM Alerts Wrapper Script
# The single entry point Control-M EM calls (EM only supports one script per
# alert action). Runs ctm_job_report.sh first (time-boxed, best-effort),
# then ctm_to_snow_incident.py (via its dedicated venv) with the raw
# Control-M alert arguments, both as the 'oversight' user. This script's own
# exit code reflects ctm_to_snow_incident.py's - the job report step can
# never fail this run, only delay it by up to CTM_JOB_REPORT_TIMEOUT.

WRAPPER_VERSION="2.1.1"

# --- --version: check and exit immediately, no sudo/python invocation needed ---
if [ "$1" = "--version" ]; then
    echo "ctm_alerts.sh version ${WRAPPER_VERSION}"
    exit 0
fi

# Check if any arguments were provided
if [ $# -eq 0 ]; then
    echo "Error: No Control-M alert arguments provided"
    echo "Usage: $0 <alert_arguments>"
    exit 1
fi

# --- Paths (production location) ---
# Remove/adjust comments below to match your actual deployment layout.
CTM_ALERTS_DIR="/opt/bmc/alerting"
CTM_ALERTS_VENV="${CTM_ALERTS_DIR}/.venv"
CTM_ALERTS_PYTHON="${CTM_ALERTS_VENV}/bin/python3"
CTM_ALERTS_SCRIPT="${CTM_ALERTS_DIR}/ctm_to_snow_incident.py"
CTM_ALERTS_LOG="${CTM_ALERTS_DIR}/alerts.log"
CTM_ALERTS_USER="oversight"

# ctm_job_report.sh is the sibling wrapper for ctm_job_report.py - deployed
# side by side with this script (see that wrapper's own comments). Run from
# here, time-boxed, because Control-M EM only supports one script per alert
# action: this is the only entry point EM calls, so both pipelines have to
# be triggered from it. See the note above Step 1 below for why this must
# never be allowed to block Step 2 (incident creation).
CTM_JOB_REPORT_WRAPPER="${CTM_ALERTS_DIR}/ctm_job_report.sh"
CTM_JOB_REPORT_TIMEOUT="60s"

# --- Sanity checks: fail loudly and specifically, not with a generic error ---
if [ ! -x "${CTM_ALERTS_PYTHON}" ]; then
    echo "Error: venv Python not found or not executable at ${CTM_ALERTS_PYTHON}"
    echo "Create it with: python3 -m venv ${CTM_ALERTS_VENV} && ${CTM_ALERTS_VENV}/bin/pip install requests python-dotenv"
    exit 1
fi

if [ ! -f "${CTM_ALERTS_SCRIPT}" ]; then
    echo "Error: ctm_to_snow_incident.py not found at ${CTM_ALERTS_SCRIPT}"
    echo "Please ensure the script has been deployed correctly."
    exit 1
fi

# --- Run the script as the 'oversight' user ---
#
# NOTE: this deliberately uses `sudo -u ... --` rather than the previous
# `su - oversight -c "string"` + printf '%q' approach. The old approach
# rebuilt a single shell string from the arguments and had a second shell
# re-parse it - exactly the kind of extra string-reassembly step that can
# silently corrupt an alert field containing a quote, backslash, or space.
# `sudo -u user -- cmd "$@"` passes the original argument array straight
# through with no re-parsing step and no manual escaping required.
#
# If your environment specifically requires oversight's full login shell
# (profile/env sourcing), use `sudo -u "${CTM_ALERTS_USER}" -i --` instead.

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# --- Log the raw Control-M invocation arguments verbatim (original behavior) ---
# Kept as its own simple, greppable line, separate from the script's own
# structured output below. Uses the same sudo -u invocation style as the
# rest of this script (see note below) rather than a second, different
# sudo pattern - one sudoers rule shape to maintain instead of two.
echo "${TIMESTAMP} - Arguments: $*" | sudo -u "${CTM_ALERTS_USER}" -- tee -a "${CTM_ALERTS_LOG}"

# --- Bail out early on anything that isn't a genuinely new alert ---
#
# Control-M EM re-invokes this same script (the single entry point it
# knows about) for every lifecycle transition of an alert_id, including
# ones WE cause: ctm_job_report.py's own mark_alert_read() sets the
# alert's comment and status="Reviewed" via the AAPI, and each of those
# writes generates its own call_type='U' echo back through EM. Both Python
# scripts already gate on this internally (describe_ctm_lifecycle -
# "initial" requires call_type='I' AND status='Not_Noticed', see that
# function's docstring in ctm_to_snow_incident.py) and no-op cleanly, so
# nothing incorrect ever happened - but every echo still paid for a full
# sudo + venv Python startup for both scripts to reach that same
# conclusion. This check is the exact same condition, just applied before
# any of that spins up, using $@ directly rather than the alert.get()
# dict describe_ctm_lifecycle uses - equivalent because both read the
# same raw Control-M 'key:' 'value' tokens.
_ctm_trim() {
    # Control-M pads some values with a trailing space (e.g. "Not_Noticed ")
    # - same quirk parse_ctm_args_to_json's docstring documents and handles
    # via Python's .strip(). Without this, "Not_Noticed " != "Not_Noticed"
    # would silently skip a genuine new alert.
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "${s}"
}

_ctm_arg_value() {
    local key="$1"
    shift
    local prev="" val="" cur
    for raw_arg in "$@"; do
        cur="$(_ctm_trim "${raw_arg}")"
        if [ "${prev}" = "${key}" ]; then
            case "${cur}" in
                *:) val="" ;;
                *) val="${cur}" ;;
            esac
            break
        fi
        prev="${cur}"
    done
    printf '%s' "${val}"
}

CALL_TYPE="$(_ctm_arg_value "call_type:" "$@")"
STATUS="$(_ctm_arg_value "status:" "$@")"

if [ "${CALL_TYPE}" != "I" ] || [ "${STATUS}" != "Not_Noticed" ]; then
    echo "${TIMESTAMP} - call_type='${CALL_TYPE}' status='${STATUS}' is not a new alert (describe_ctm_lifecycle's 'initial' needs call_type=I and status=Not_Noticed) - skipping both pipelines without starting Python. Expected for Control-M's own echo of our alert comment/status updates, and for genuine Noticed/Handled transitions." \
        | sudo -u "${CTM_ALERTS_USER}" -- tee -a "${CTM_ALERTS_LOG}"
    exit 0
fi

# --- Step 1: Run ctm_job_report.sh first, time-boxed ---
#
# Runs before incident creation so ctm_to_snow_incident.py can fold its
# output (data/job_reports/<alert_id>.json) into the incident's worklog.
# Wrapped in `timeout` so a slow/unreachable Control-M can only ever delay
# THIS step, never Step 2 below - if it times out or fails outright, that's
# logged and we fall through to incident creation regardless. This is the
# same "must never block incident creation" invariant that's been true of
# this whole pipeline from the start, just now enforced by a wall-clock
# limit instead of by running as a fully separate process.
if [ -x "${CTM_JOB_REPORT_WRAPPER}" ]; then
    {
        echo "=== ${TIMESTAMP} - Running ctm_job_report.sh (timeout ${CTM_JOB_REPORT_TIMEOUT}) ==="
        timeout "${CTM_JOB_REPORT_TIMEOUT}" "${CTM_JOB_REPORT_WRAPPER}" "$@"
    } 2>&1 | sudo -u "${CTM_ALERTS_USER}" tee -a "${CTM_ALERTS_LOG}"
    JOB_REPORT_EXIT_CODE="${PIPESTATUS[0]}"

    if [ "${JOB_REPORT_EXIT_CODE}" -eq 124 ]; then
        echo "Warning: ctm_job_report.sh timed out after ${CTM_JOB_REPORT_TIMEOUT} - proceeding to incident creation without job report data." \
            | sudo -u "${CTM_ALERTS_USER}" -- tee -a "${CTM_ALERTS_LOG}"
    elif [ "${JOB_REPORT_EXIT_CODE}" -ne 0 ]; then
        echo "Warning: ctm_job_report.sh exited with code ${JOB_REPORT_EXIT_CODE} - proceeding to incident creation regardless." \
            | sudo -u "${CTM_ALERTS_USER}" -- tee -a "${CTM_ALERTS_LOG}"
    fi
else
    echo "Warning: ctm_job_report.sh not found or not executable at ${CTM_JOB_REPORT_WRAPPER} - skipping job report, proceeding to incident creation." \
        | sudo -u "${CTM_ALERTS_USER}" -- tee -a "${CTM_ALERTS_LOG}"
fi

# --- Step 2: Run ctm_to_snow_incident.py as the 'oversight' user, logging its own output too ---
#
# NOTE: this deliberately uses `sudo -u ... --` rather than the previous
# `su - oversight -c "string"` + printf '%q' approach for actually running
# the script (as opposed to the raw-argument log line above). The old
# approach rebuilt a single shell string from the arguments and had a
# second shell re-parse it - exactly the kind of extra string-reassembly
# step that can silently corrupt an alert field containing a quote,
# backslash, or space. `sudo -u user -- cmd "$@"` passes the original
# argument array straight through with no re-parsing step and no manual
# escaping required.
#
# If your environment specifically requires oversight's full login shell
# (profile/env sourcing), use `sudo -u "${CTM_ALERTS_USER}" -i --` instead.
{
    echo "=== ${TIMESTAMP} - Running ctm_to_snow_incident.py (wrapper v${WRAPPER_VERSION}) ==="
    sudo -u "${CTM_ALERTS_USER}" -- "${CTM_ALERTS_PYTHON}" "${CTM_ALERTS_SCRIPT}" "$@"
} 2>&1 | sudo -u "${CTM_ALERTS_USER}" tee -a "${CTM_ALERTS_LOG}"

# --- Propagate the actual exit code ---
#
# The original script never did this - its own exit status only ever
# reflected whether the logging `tee` command succeeded, not whether
# ctm-alerts itself succeeded. Control-M would see "success" even on a
# hard failure. PIPESTATUS[0] is the exit code of the { ... } block
# (which resolves to the exit code of the last command inside it - the
# python script), PIPESTATUS[1] would be the trailing `tee`'s exit code.
EXIT_CODE="${PIPESTATUS[0]}"

if [ "${EXIT_CODE}" -ne 0 ]; then
    echo "Error: ctm_to_snow_incident.py exited with code ${EXIT_CODE}. See ${CTM_ALERTS_LOG} for details."
fi

exit "${EXIT_CODE}"
