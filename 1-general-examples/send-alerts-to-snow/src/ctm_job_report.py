#!/usr/bin/env python3
# Filename: ctm_job_report.py
"""
Control-M job alert -> local job report (status + log + output)

Deliberately independent of ctm_to_snow_incident.py's ServiceNow incident
pipeline: same Control-M alert CLI arguments in, but this script only ever
writes a local JSON report to data/job_reports/<alert_id>.json - it never
talks to ServiceNow. The two pipelines must be able to run, fail, and be
retried (on Control-M's own alert redelivery) independently of each other -
Control-M being down for a status lookup here must never be able to block
an incident from being created there, and a ServiceNow outage there must
never stop this report from being written here.

As of ctm_to_snow_incident.py v1.3.0, that script does pull this same
status/log/output detail into its worklog - but only via a best-effort
local read of the JSON file this script writes (load_job_report() there),
never a call into this module or the Control-M AAPI. That keeps the
decoupling above intact: a report write failure here still can't block an
incident from being created there, and a missing/stale report there just
means that run's worklog has no job detail, not a failure.

Shares only the pure, already-tested Control-M alert parsing/classification
functions with ctm_to_snow_incident.py (parse_ctm_args_to_json,
classify_alert, describe_ctm_lifecycle) - importing those is a dependency
on stable, side-effect-free parsing logic, not a runtime coupling between
the two pipelines. Everything with actual side effects (config loading,
logging, tracking ledger, main()) is its own copy, on purpose: see
ctm_client.py's docstring for the same reasoning applied to the AAPI client
itself.

Requires: pip install requests python-dotenv (same as ctm_to_snow_incident.py)

Config is loaded from ./config/.env relative to this script's own
location - the same file ctm_to_snow_incident.py loads its config from.
See config/.env.example for the required variables (CONTROLM_URL,
CONTROLM_API_KEY).

Version History
Date (YMD)    Version    What
--------      -------    ------------------------
20260804      1.0.0      Initial release: split out of
                          ctm_to_snow_incident.py to run as its own,
                          independently retryable pipeline. Own dedup
                          ledger (data/job_report_tracking.json, separate
                          from ctm_to_snow_incident.py's alert_tracking.json)
                          so a redelivered alert can retry just this piece
                          without needing the incident to also be retried
                          (or vice versa).
20260814      2.0.0      Coordinated version bump across all scripts in
                          this project (ctm_client.py, ctm_job_report.py,
                          ctm_to_snow_incident.py, ctm_alerts.sh,
                          ctm_job_report.sh all now at 2.0.0) - covers the
                          alert mark-as-read/comment support added to
                          ctm_client.py and this script's mark_alert_read().
20260815      2.1.0      Fixed against docs/ctm_alert_order.md: get_job_output
                          now passes the alert's run_counter (leading zeros
                          stripped) as runNo instead of always requesting
                          run 0 (see ctm_client.py's matching get_job_status
                          fix). Step-numbered log banners (Step 0-3) added,
                          matching that doc's documented pipeline order -
                          Steps 4-7 (the ServiceNow side) are logged the
                          same way in ctm_to_snow_incident.py.
20260815      2.2.0      Report now includes ctm_monitoring_url - a
                          cross-launch link into Control-M's own
                          Monitoring > Neighborhood view for this job (see
                          build_ctm_monitoring_url in
                          ctm_to_snow_incident.py, shared the same way as
                          the other pure alert-parsing functions).
"""

import os
import sys
import json
from datetime import datetime

import ctm_client
from ctm_to_snow_incident import (
    parse_ctm_args_to_json,
    classify_alert,
    describe_ctm_lifecycle,
    build_ctm_monitoring_url,
    DEMO_ALERT_ARGS,
)

SCRIPT_VERSION = "2.2.0"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
JOB_REPORT_DIR = os.path.join(SCRIPT_DIR, "data", "job_reports")
JOB_REPORT_TRACKING_FILE = os.path.join(SCRIPT_DIR, "data", "job_report_tracking.json")

# Verbosity levels: 0 = quiet, 1 = normal (default), 2 = verbose
LEVEL_QUIET = 0
LEVEL_NORMAL = 1
LEVEL_VERBOSE = 2
_log_level = LEVEL_NORMAL


def set_log_level(level: int) -> None:
    global _log_level
    _log_level = level


def log(level: str, message: str) -> None:
    """Same minimal timestamped console logging as ctm_to_snow_incident.py."""
    if level == "INFO" and _log_level < LEVEL_NORMAL:
        return
    if level == "DEBUG" and _log_level < LEVEL_VERBOSE:
        return

    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [{level}] {message}")


def load_report_tracking() -> dict:
    """
    Own dedup ledger, separate from ctm_to_snow_incident.py's
    alert_tracking.json - this pipeline's redelivery/retry history must
    not be entangled with the incident pipeline's.
    """
    if not os.path.exists(JOB_REPORT_TRACKING_FILE):
        return {}
    try:
        with open(JOB_REPORT_TRACKING_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        log("WARN", f"Could not read job report tracking file ({e}) - treating as empty.")
        return {}


def record_report_action(alert_id: str, action: str, extra: dict = None) -> None:
    if not alert_id:
        return

    os.makedirs(os.path.dirname(JOB_REPORT_TRACKING_FILE), exist_ok=True)
    tracking = load_report_tracking()

    record = {"action": action, "timestamp": datetime.now().isoformat()}
    if extra:
        record.update(extra)
    tracking[alert_id] = record

    try:
        with open(JOB_REPORT_TRACKING_FILE, "w") as f:
            json.dump(tracking, f, indent=2)
        log("INFO", f"Recorded alert_id={alert_id} action='{action}' in job report tracking file.")
    except OSError as e:
        log("ERROR", f"Could not write job report tracking file: {e}")


def _parse_run_counter(run_counter: str) -> int:
    """
    Control-M's run_counter arrives as a zero-padded string (e.g. "00002").
    get_job_output's runNo param needs the numeric value with those leading
    zeros stripped (see docs/ctm_alert_order.md, Step 2's note) - int()
    does that for free. Missing/non-numeric -> 0 (get_job_output's own
    prior default), rather than raising - a malformed run_counter
    shouldn't crash the whole report.
    """
    try:
        return int(run_counter.strip())
    except (ValueError, AttributeError):
        return 0


def build_job_report(ctm_config: dict, alert: dict) -> dict:
    """
    Fetch a job alert's current status, execution log, and output from the
    Control-M AAPI. Superset of what engineer_ctm.py's getCtmJobStatusAdv()
    does - it just re-filters get_job_status's "statuses" list down to the
    one matching job_id, which ctm_client.get_job_status() already does
    directly; no separate function needed for that part. (getCtmJobStatusAdv
    also calls a project.jsonTranslateValues() that doesn't actually exist
    anywhere in ctm-engineer - dead code there - so nothing lost by not
    porting it.)

    Each of the three AAPI calls is independent and allowed to fail on its
    own - Control-M being unreachable, the job having already aged out of
    the active pipeline, etc. should degrade the report, not crash the
    whole run. Step numbers/order below match docs/ctm_alert_order.md
    (Step 0 is the alert itself, logged in main() before this is called).
    """
    report = {
        "alert": alert,
        "retrieved_at": datetime.now().isoformat(),
    }

    if not ctm_config.get("CONTROLM_URL"):
        log("WARN", "CONTROLM_URL not configured - job report will contain the raw alert only.")
        return report

    report["ctm_monitoring_url"] = build_ctm_monitoring_url(ctm_config, alert)

    ctm_server = alert.get("data_center", "").strip()
    order_id = alert.get("order_id", "").strip()
    run_no = _parse_run_counter(alert.get("run_counter", ""))

    for step_num, step_name, key, fetch in (
        (1, "Get Job Status", "job_status",
         lambda: ctm_client.get_job_status(ctm_config, ctm_server, order_id)),
        (2, "Get Job Output", "job_output",
         lambda: ctm_client.get_job_output(ctm_config, ctm_server, order_id, run_no=run_no)),
        (3, "Get Job Log", "job_log",
         lambda: ctm_client.get_job_log(ctm_config, ctm_server, order_id)),
    ):
        log("INFO", f"--- Step {step_num}: {step_name} ---")
        try:
            report[key] = fetch()
            log("INFO", f"Fetched {key} for {ctm_server}:{order_id}")
        except Exception as e:
            log("WARN", f"Could not fetch {key} for {ctm_server}:{order_id}: {e}")
            report[key] = None
            report[f"{key}_error"] = str(e)

    return report


def mark_alert_read(ctm_config: dict, alert: dict, report_path: str) -> dict:
    """
    Update the Control-M alert once its job log has actually been fetched
    and written into the report: put the report's filename in the alert's
    own comment/text (so anyone looking at the alert in Control-M can see
    where the log landed) and mark it as read (AAPI status "Reviewed").

    The two AAPI calls are independent and allowed to fail on their own -
    same "degrade, don't crash" handling as build_job_report's three fetch
    calls - a Control-M hiccup on either one shouldn't turn an
    already-saved report into a failed run.

    Returns a dict with each call's outcome and Control-M's actual
    response body, meant to be persisted into the tracking ledger (see
    record_report_action below) rather than just printed - the AAPI has
    been seen to return HTTP 200 "ok" without the update actually taking
    effect, so a log line saying "success" isn't enough to later verify
    what really happened; the raw response has to be kept on disk.
    """
    result = {
        "comment_set": False, "comment_response": None,
        "status_set": False, "status_response": None,
    }

    if not ctm_config.get("CONTROLM_URL"):
        return result

    alert_id = alert.get("alert_id", "")
    if not alert_id:
        return result

    comment = f"Job log saved: {os.path.basename(report_path)}"
    try:
        resp = ctm_client.update_alert(ctm_config, alert_id, comment=comment)
        result["comment_set"] = True
        result["comment_response"] = resp
        log("INFO", f"Set alert_id={alert_id} comment to '{comment}' - Control-M response: {resp}")
    except Exception as e:
        log("WARN", f"Could not update alert_id={alert_id} comment: {e}")

    try:
        resp = ctm_client.set_alert_status(ctm_config, alert_id, "Reviewed")
        result["status_set"] = True
        result["status_response"] = resp
        log("INFO", f"Marked alert_id={alert_id} as read (status='Reviewed') - Control-M response: {resp}")
    except Exception as e:
        log("WARN", f"Could not mark alert_id={alert_id} as read in Control-M: {e}")

    return result


def save_job_report(alert: dict, report: dict) -> str:
    """
    Write the job report to data/job_reports/<alert_id>.json. Returns ""
    (logged, not raised) on a write failure - matches
    record_report_action's own error handling below.
    """
    alert_id = alert.get("alert_id", "unknown")
    path = os.path.join(JOB_REPORT_DIR, f"{alert_id}.json")

    try:
        os.makedirs(JOB_REPORT_DIR, exist_ok=True)
        with open(path, "w") as f:
            json.dump(report, f, indent=2)
        log("INFO", f"Job report saved: {path}")
        return path
    except OSError as e:
        log("ERROR", f"Could not write job report file: {e}")
        return ""


def main() -> int:
    if "--version" in sys.argv[1:]:
        print(f"ctm_job_report.py version {SCRIPT_VERSION}")
        return 0

    raw_argv = sys.argv[1:]
    verbose_flag = False
    quiet_flag = False
    argv = []
    for tok in raw_argv:
        if tok in ("-v", "--verbose"):
            verbose_flag = True
        elif tok in ("-q", "--quiet"):
            quiet_flag = True
        else:
            argv.append(tok)

    if verbose_flag and quiet_flag:
        print("Error: -v/--verbose and -q/--quiet cannot both be specified.")
        return 1

    if verbose_flag:
        set_log_level(LEVEL_VERBOSE)
    elif quiet_flag:
        set_log_level(LEVEL_QUIET)

    log("INFO", f"=== Control-M Job Report Pipeline : START (version {SCRIPT_VERSION}) ===")

    ctm_config = ctm_client.load_ctm_config()

    if argv:
        alert = parse_ctm_args_to_json(argv)
    elif os.getenv("CTM_JOB_REPORT_DEMO_MODE", "false").lower() == "true":
        log("WARN", "CTM_JOB_REPORT_DEMO_MODE is enabled and no arguments were passed - using built-in sample alert.")
        alert = parse_ctm_args_to_json(DEMO_ALERT_ARGS)
    else:
        log("ERROR", "No Control-M alert arguments provided and CTM_JOB_REPORT_DEMO_MODE is not 'true'.")
        return 1

    log("INFO", "--- Step 0: Alert Received ---")
    log("INFO", f"Parsed alert (JSON):\n{json.dumps(alert, indent=2)}")

    lifecycle = describe_ctm_lifecycle(alert)
    if lifecycle != "initial":
        log("INFO", f"Control-M update alert (lifecycle='{lifecycle}'), not a new alert - skipping.")
        log("INFO", "=== Control-M Job Report Pipeline : DONE (skipped, update alert) ===")
        return 0

    alert_id = alert.get("alert_id", "")
    tracking = load_report_tracking()
    if alert_id and alert_id in tracking:
        prior = tracking[alert_id]
        log("WARN", f"alert_id={alert_id} was already processed for a job report "
                     f"(action='{prior.get('action')}' at {prior.get('timestamp')}). Skipping.")
        log("INFO", "=== Control-M Job Report Pipeline : DONE (skipped, duplicate alert_id) ===")
        return 0

    alert_type = classify_alert(alert)
    if alert_type != "job":
        log("INFO", f"Alert classified as '{alert_type}', not 'job' - no report to write. Skipping.")
        record_report_action(alert_id, "skipped_not_a_job_alert", {"alert_classification": alert_type})
        log("INFO", "=== Control-M Job Report Pipeline : DONE (skipped, not a job alert) ===")
        return 0

    report = build_job_report(ctm_config, alert)
    path = save_job_report(alert, report)

    alert_read_result = None
    if path and report.get("job_log") is not None:
        alert_read_result = mark_alert_read(ctm_config, alert, path)

    if path:
        extra: dict = {"job_report": path}
        if alert_read_result is not None:
            extra["alert_marked_read"] = alert_read_result
        record_report_action(alert_id, "wrote_job_report", extra)
    else:
        record_report_action(alert_id, "failed_to_write_job_report")

    log("INFO", "=== Control-M Job Report Pipeline : DONE ===")
    return 0 if path else 1


if __name__ == "__main__":
    sys.exit(main())
