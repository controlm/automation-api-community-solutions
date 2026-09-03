#!/bin/bash

# CTM Job Report Wrapper Script
# Executes ctm_job_report.py (via its dedicated venv) with the raw
# Control-M alert arguments, running as the 'oversight' user.
#
# A separate wrapper from ctm_alerts.sh, with its own log file and its own
# dedup ledger, so the job report and the ServiceNow incident are created,
# retried, and can fail, independently of each other. Since Control-M EM
# only supports one script per alert action, ctm_alerts.sh is the one
# actually registered with EM and calls this script itself (time-boxed) as
# its first step - see ctm_alerts.sh's own comments. This script still
# works standalone too (e.g. manual runs, or if you register it as its own
# separate EM alert action instead).

WRAPPER_VERSION="2.0.0"

# --- --version: check and exit immediately, no sudo/python invocation needed ---
if [ "$1" = "--version" ]; then
    echo "ctm_job_report.sh version ${WRAPPER_VERSION}"
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
# Same CTM_ALERTS_DIR/venv/user as ctm_alerts.sh - both scripts are
# deployed side by side and share config/.env. ctm_alerts.sh is the one
# EM actually calls; it invokes this script as a subprocess (see its
# CTM_JOB_REPORT_WRAPPER/CTM_JOB_REPORT_TIMEOUT).
CTM_ALERTS_DIR="/opt/bmc/alerting"
CTM_ALERTS_VENV="${CTM_ALERTS_DIR}/.venv"
CTM_ALERTS_PYTHON="${CTM_ALERTS_VENV}/bin/python3"
CTM_JOB_REPORT_SCRIPT="${CTM_ALERTS_DIR}/ctm_job_report.py"
CTM_JOB_REPORT_LOG="${CTM_ALERTS_DIR}/job_report.log"
CTM_ALERTS_USER="oversight"

# --- Sanity checks: fail loudly and specifically, not with a generic error ---
if [ ! -x "${CTM_ALERTS_PYTHON}" ]; then
    echo "Error: venv Python not found or not executable at ${CTM_ALERTS_PYTHON}"
    echo "Create it with: python3 -m venv ${CTM_ALERTS_VENV} && ${CTM_ALERTS_VENV}/bin/pip install requests python-dotenv"
    exit 1
fi

if [ ! -f "${CTM_JOB_REPORT_SCRIPT}" ]; then
    echo "Error: ctm_job_report.py not found at ${CTM_JOB_REPORT_SCRIPT}"
    echo "Please ensure the script has been deployed correctly."
    exit 1
fi

# --- Run the script as the 'oversight' user ---
#
# Same `sudo -u user -- cmd "$@"` approach as ctm_alerts.sh (see that
# script's comments for why: passes the original argument array straight
# through with no re-parsing step and no manual escaping required).
#
# If your environment specifically requires oversight's full login shell
# (profile/env sourcing), use `sudo -u "${CTM_ALERTS_USER}" -i --` instead.

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# --- Log the raw Control-M invocation arguments verbatim ---
echo "${TIMESTAMP} - Arguments: $*" | sudo -u "${CTM_ALERTS_USER}" -- tee -a "${CTM_JOB_REPORT_LOG}"

# --- Run the script as the 'oversight' user, logging its own output too ---
{
    echo "=== ${TIMESTAMP} - Running ctm_job_report.py (wrapper v${WRAPPER_VERSION}) ==="
    sudo -u "${CTM_ALERTS_USER}" -- "${CTM_ALERTS_PYTHON}" "${CTM_JOB_REPORT_SCRIPT}" "$@"
} 2>&1 | sudo -u "${CTM_ALERTS_USER}" tee -a "${CTM_JOB_REPORT_LOG}"

# --- Propagate the actual exit code ---
# PIPESTATUS[0] is the exit code of the { ... } block (the python script),
# PIPESTATUS[1] would be the trailing `tee`'s exit code.
EXIT_CODE="${PIPESTATUS[0]}"

if [ "${EXIT_CODE}" -ne 0 ]; then
    echo "Error: ctm_job_report.py exited with code ${EXIT_CODE}. See ${CTM_JOB_REPORT_LOG} for details."
fi

exit "${EXIT_CODE}"
