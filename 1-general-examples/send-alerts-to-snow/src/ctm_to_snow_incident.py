#!/usr/bin/env python3
# Filename: ctm_to_snow_incident.py
"""
Control-M alert -> ServiceNow incident (with routed assignment_group + cmdb_ci)

Minimal reference implementation. No retries, no archival, no logging
framework - just enough to demonstrate the flow: Control-M passes alert
fields as CLI arguments, this script reformats them into JSON, resolves
routing, and creates a ServiceNow incident + worklog entry via REST.

Requires: pip install requests python-dotenv

Config is loaded from ./config/.env relative to this script's own location.
See config/.env.example for the required variables.

Version History
Date (YMD)    Version    What
--------      -------    ------------------------
20260723      1.0.0      Initial versioned release: alert parsing (incl.
                          real Control-M whitespace/omitted-token quirks),
                          lifecycle gating (I/Not_Noticed vs U updates),
                          job/agent_unavailable/agent_available
                          classification, mapping-based routing, agent
                          correlation with message-hostname fallback,
                          duplicate-delivery tracking ledger, -v/-q/--version
20260723      1.0.1      MAPPING_FILE: a relative path value (default or
                          explicit) now resolves against this script's own
                          directory, not the caller's cwd at invocation
                          time - fixes "Mapping file not found" when
                          invoked via sudo -u from a different working
                          directory than expected.
20260723      1.0.2      find_open_incident_by_correlation now excludes
                          state=6 (Resolved) from its lookup query - caught
                          from real production evidence that ServiceNow
                          leaves active=true even after Resolved, causing
                          every subsequent agent_available alert for the
                          same host to keep re-matching and re-resolving
                          the same already-resolved incident.
20260723      1.0.3      short_description and work_notes no longer render
                          a bare leading ": " or "on job " with nothing
                          after it for agent alerts - job_name (and other
                          fields) exist as empty strings, not missing
                          keys, for these alerts, so .get(key, default)
                          never triggered its fallback. Caught from a real
                          production incident's short_description.
20260804      1.1.0      Job alerts now get a local report file
                          (data/job_reports/<alert_id>.json) containing the
                          raw alert plus live Control-M job status/log/output,
                          fetched via the new ctm_client.py (plain requests
                          against the AAPI - see that module's docstring for
                          why this doesn't use the controlm_py SDK). Each of
                          the three AAPI calls is best-effort: a failure
                          (Control-M unreachable, CONTROLM_URL unset, job
                          already aged out, etc.) is logged and degrades the
                          report - it never blocks incident creation, which
                          remains this script's actual job.
20260804      1.2.0      Reverted: job report generation moved OUT to its
                          own independent script, ctm_job_report.py (own
                          CLI, own dedup ledger, own wrapper script). This
                          script no longer imports ctm_client or talks to
                          the Control-M AAPI at all - the two pipelines
                          (create incident / write job report) must be able
                          to run, fail, and be redelivered-and-retried
                          independently of each other. Long-term goal is for
                          the ServiceNow worklog to eventually incorporate
                          the job report's detail, but the two stay
                          decoupled until that's actually built.
20260814      1.3.0      Job alerts' worklog now includes ctm_job_report.py's
                          status/log/output, each as its own separate work_notes
                          entry (see add_job_report_worklogs). NOT a repeat of
                          v1.1.0: this script still never imports ctm_client or
                          calls the Control-M AAPI - load_job_report() only does
                          a best-effort local read of the JSON file
                          ctm_job_report.py already wrote for this alert_id, so
                          a missing/stale/corrupt report just means the
                          worklog has no job detail this run, same as before.
                          Control-M EM only supports one script per alert
                          action, so ctm_alerts.sh now runs ctm_job_report.sh
                          (time-boxed) before this script, specifically so
                          the file exists in the common case by the time this
                          runs.
20260814      2.0.0      Coordinated version bump across all scripts in
                          this project (ctm_client.py, ctm_job_report.py,
                          ctm_to_snow_incident.py, ctm_alerts.sh,
                          ctm_job_report.sh all now at 2.0.0).
20260815      2.1.0      Step-numbered log banners renumbered to match
                          docs/ctm_alert_order.md's global pipeline order:
                          Step 0 (alert received) plus Steps 4-7 here
                          (SNOW OAuth/Create Incident/Add Worklog/Add Job
                          Report Worklog) - Steps 1-3 (Get Job
                          Status/Output/Log) are logged the same way in
                          ctm_job_report.py.
20260815      2.2.0      Added build_ctm_monitoring_url() - a cross-launch
                          link into Control-M's own Monitoring >
                          Neighborhood view for a job, reverse-engineered
                          from one real captured link. ctm_job_report.py
                          saves it into the report JSON as
                          ctm_monitoring_url; add_job_report_worklogs
                          posts it as its own ServiceNow worklog entry
                          when present.
20260815      2.3.0      The "Control-M job status" worklog entry is now
                          human-readable text (_format_job_status) instead
                          of a raw JSON dump - job/folder, status, host,
                          start/end time (formatted from Control-M's bare
                          YYYYMMDDHHMMSS), application, description. Falls
                          back to the raw JSON if the response doesn't
                          have the expected fields.
20260815      2.3.1      _format_job_status now renders every field the
                          AAPI response actually has, not a curated
                          subset - generic camelCase label formatting
                          (with a small override map for jobId/folderId/
                          ctm/outputURI/logURI) plus date/time reformatting
                          (_format_ctm_timestamp, now handling both the
                          14-digit start/end timestamps and orderDate's
                          6-digit YYMMDD) applied uniformly across all
                          fields, including list-valued ones.
"""

import os
import sys
import json
import re
from datetime import datetime
from urllib.parse import urlsplit, urlencode, quote

import requests
from dotenv import load_dotenv

SCRIPT_VERSION = "2.3.1"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, "config", ".env")
ALERT_TRACKING_FILE = os.path.join(SCRIPT_DIR, "data", "alert_tracking.json")

# Own copy of ctm_job_report.py's JOB_REPORT_DIR constant, not an import of
# it - this script only ever does a best-effort read of a file that script
# may have already written (see load_job_report below), never a runtime
# dependency on that module. Same "own copy" reasoning as ctm_client.py's
# docstring.
JOB_REPORT_DIR = os.path.join(SCRIPT_DIR, "data", "job_reports")
JOB_REPORT_WORK_NOTES_LIMIT = 4000  # keep each worklog entry a reasonable size for this demo

# Verbosity levels: 0 = quiet, 1 = normal (default), 2 = verbose
LEVEL_QUIET = 0
LEVEL_NORMAL = 1
LEVEL_VERBOSE = 2
_log_level = LEVEL_NORMAL


def set_log_level(level: int) -> None:
    global _log_level
    _log_level = level


def log(level: str, message: str) -> None:
    """
    Minimal timestamped console logging - no logging framework needed.

    Filtering by current verbosity:
      - WARN, ERROR, RESULT: always printed, regardless of -q/-v.
        (RESULT is used for the one line Control-M EM actually needs -
        the CTM_EM_INCIDENT_JSON summary - so it can never be silenced.)
      - INFO: printed at normal and verbose, hidden in quiet mode.
      - DEBUG: only printed in verbose mode.
    """
    if level == "INFO" and _log_level < LEVEL_NORMAL:
        return
    if level == "DEBUG" and _log_level < LEVEL_VERBOSE:
        return

    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [{level}] {message}")


def load_config() -> dict:
    """Load required configuration from config/.env."""
    if os.path.exists(ENV_FILE):
        load_dotenv(ENV_FILE)
        log("INFO", f"Loaded environment from: {ENV_FILE}")
    else:
        log("ERROR", f"No .env file found at {ENV_FILE}")

    required_vars = [
        "SERVICENOW_INSTANCE",
        "SERVICENOW_CLIENT_ID",
        "SERVICENOW_CLIENT_SECRET",
        "SERVICENOW_CALLER_ID",
    ]
    config = {}
    for var in required_vars:
        value = os.getenv(var, "")
        if not value:
            log("WARN", f"Required config variable '{var}' is empty.")
        config[var] = value

    # Resolve MAPPING_FILE against this script's own directory when a
    # relative path is given (default, or an explicit relative value in
    # .env) - NOT the caller's current working directory, which is not
    # guaranteed to be this script's folder depending on how it's invoked
    # (e.g. via sudo -u from the wrapper). Only a genuinely absolute path
    # is used as-is. This makes a plain "config/mapping.json" value in
    # .env work correctly regardless of invocation context, rather than
    # requiring anyone to hand-edit .env to an absolute path.
    raw_mapping_file = os.getenv("MAPPING_FILE", os.path.join("config", "mapping.json"))
    if os.path.isabs(raw_mapping_file):
        config["MAPPING_FILE"] = raw_mapping_file
    else:
        config["MAPPING_FILE"] = os.path.join(SCRIPT_DIR, raw_mapping_file)

    return config


def parse_ctm_args_to_json(args: list) -> dict:
    """
    Reformat Control-M's alternating 'key:' 'value' CLI arguments into a
    plain JSON-serializable dict.

    Control-M passes fields as separate tokens: ['call_type:', 'I',
    'alert_id:', '2256', ...]. Two real behaviors, both confirmed against
    actual production Control-M output (not hypothetical):

    1. When a field has no value, Control-M sometimes omits the value
       token entirely rather than passing an empty string - so the very
       next token is immediately the next key. A naive positional read
       desyncs the instant one field is empty, so this looks ahead
       before consuming a value.
    2. Other times, Control-M instead sends a literal single-space
       string (' ') as the "empty" value, and non-empty values
       frequently carry a trailing space (e.g. 'ZZM BMC ', '2256 ').
       Left unstripped, this bleeds into things like short_description
       ("ZZM PreFlight Check : Ended not OK (Alert 2256 )"). Both keys
       and values are stripped to handle this cleanly.
    """
    alert = {}
    i = 0
    n = len(args)

    while i < n:
        key = args[i].strip().rstrip(":").strip()

        value = ""
        if i + 1 < n and not args[i + 1].strip().endswith(":"):
            value = args[i + 1].strip()
            i += 2
        else:
            i += 1

        alert[key] = value

    return alert


# A built-in sample alert for running the script without live Control-M args
DEMO_ALERT_ARGS = [
    "call_type:", "I",
    "alert_id:", "2256",
    "data_center:", "ctm-lin-srv",
    "memname:", "zzm.pre.flight.sh",
    "order_id:", "0039s",
    "severity:", "V",
    "status:", "Not_Noticed",
    "send_time:", "20260722144043",
    "message:", "Ended not OK",
    "run_as:", "mftuser",
    "sub_application:", "Multipath Cloud Demo",
    "application:", "ZZM BMC",
    "job_name:", "ZZM PreFlight Check",
    "host_id:", "ctm-lin-agt.werkstatt.local",
    "alert_type:", "R",
    "run_counter:", "00001",
]


def load_mapping(mapping_file: str) -> list:
    """
    Load the routing rules table: a list of rules, evaluated in order,
    first match wins. Each rule is:
        {"service_name": str, "pattern": str,
         "assignment_group_name": str, "assignment_group_sys_id": str,
         "cmdb_ci_name": str, "cmdb_ci_sys_id": str}
    PATTERN* is a case-insensitive prefix match against the alert's
    Control-M "application" field; a bare "*" matches everything and
    should be the last rule, acting as the catch-all default.

    The *_name fields are kept alongside the *_sys_id fields purely for
    human readability when inspecting this file - the runtime script
    only ever uses the *_sys_id values; it does not re-look-up names.

    This file is meant to be generated by setup_resolve_mapping.py from
    the human-readable config/mapping_source.json - it should not
    normally need hand-editing.
    """
    if not os.path.exists(mapping_file):
        log("ERROR", f"Mapping file not found: {mapping_file}")
        return []

    with open(mapping_file, "r") as f:
        raw_rules = json.load(f)

    # Filter out the "_do_not_edit" sentinel marker written by
    # setup_resolve_mapping.py. Deliberately keyed on a distinct field
    # name rather than a missing/empty "pattern" - resolve_route() is
    # called with application="" for every agent alert (they have no
    # 'application' field at all), and a marker with no pattern would
    # default to pattern="", which would incorrectly MATCH that empty
    # string before the real catch-all rule ever gets checked, silently
    # breaking agent-alert routing.
    rules = [r for r in raw_rules if not r.get("_do_not_edit")]

    log("INFO", f"Loaded {len(rules)} routing rule(s) from {mapping_file}")
    return rules


def resolve_route(application: str, rules: list) -> dict:
    """
    Return the first matching rule for the given application, or an
    empty dict if nothing matches (including no catch-all rule present).
    """
    app_upper = (application or "").upper()

    for rule in rules:
        pattern = rule.get("pattern", "")
        pattern_upper = pattern.upper()

        if pattern_upper.endswith("*"):
            if app_upper.startswith(pattern_upper[:-1]):
                return rule
        elif app_upper == pattern_upper:
            return rule

    return {}


# Cache sys_id lookups for the life of this run - if the same name is
# reused across rules (or looked up twice), don't hit the API again.
_sys_id_cache = {}


def lookup_sys_id(config: dict, access_token: str, table: str, name: str) -> str:
    """
    Resolve a human-readable 'name' to its sys_id by querying ServiceNow's
    Table API directly. Returns "" (with a logged reason) if the name is
    empty, matches nothing, or the request fails. If more than one record
    matches, the first is used and a warning is logged - names should be
    unique enough to disambiguate, or use a more specific value.
    """
    if not name:
        return ""

    cache_key = (table, name)
    if cache_key in _sys_id_cache:
        return _sys_id_cache[cache_key]

    url = f"https://{config['SERVICENOW_INSTANCE']}.service-now.com/api/now/table/{table}"
    resp = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
        params={
            "sysparm_query": f"name={name}",
            "sysparm_fields": "sys_id,name",
            "sysparm_limit": "2",  # only need to know if there's more than one match
        },
    )

    if resp.status_code != 200:
        log("ERROR", f"Lookup failed for {table} name='{name}': HTTP {resp.status_code} - {resp.text}")
        return ""

    results = resp.json().get("result", [])

    if not results:
        log("WARN", f"No {table} record found with name='{name}'. Check spelling/case in mapping.json.")
        return ""

    if len(results) > 1:
        log("WARN", f"Multiple {table} records match name='{name}' - using the first one "
                     f"(sys_id={results[0]['sys_id']}). Use a more specific name to avoid ambiguity.")

    sys_id = results[0]["sys_id"]
    log("INFO", f"Resolved {table} name='{name}' -> sys_id={sys_id}")
    _sys_id_cache[cache_key] = sys_id
    return sys_id


def describe_ctm_lifecycle(alert: dict) -> str:
    """
    Control-M's EM sends a separate alert invocation for every lifecycle
    transition of the SAME underlying alert_id, not just once:
      call_type='I', status='Not_Noticed'  -> initial alert (new)
      call_type='U', status='Noticed'      -> someone acknowledged it in Control-M's own alert console
      call_type='U', status='Handled'      -> closed in Control-M's own alert console

    Only the initial alert should ever create/resolve a ServiceNow
    incident. We never write the ServiceNow incident number back to
    Control-M, so a later 'U' update has no way to be mapped back to
    which incident it would correspond to - full bi-directional sync is
    explicitly out of scope for this demo (professional services work).
    Processing 'U' alerts as if they were new would create duplicate
    incidents every time someone reviews/handles the alert in Control-M.
    """
    call_type = alert.get("call_type", "").strip()
    status = alert.get("status", "").strip()

    if call_type == "I" and status == "Not_Noticed":
        return "initial"
    if call_type == "U" and status == "Noticed":
        return "acknowledged_in_ctm"
    if call_type == "U" and status == "Handled":
        return "closed_in_ctm"
    return "unknown_lifecycle_state"


def build_ctm_monitoring_url(ctm_config: dict, alert: dict) -> str:
    """
    Cross-launch link into Control-M's own Monitoring > Neighborhood view
    for this job, so a ServiceNow agent can click straight from the
    incident into Control-M. Reverse-engineered from one real captured
    link (not documented anywhere else, so nothing to cite beyond that
    sample):

      https://ctm.werkstatt.local/ControlM/Monitoring/Neighborhood/003i7_3_1_%2520
        ?name=ZZM%20PreFlight%20Check&ctm=ctm-lin-srv&odate=%20&direction=1
        &radius=3&orderId=003i7&mapView=TileView

    order_id/job_name/data_center come from the alert; radius=3,
    direction=1, and mapView=TileView are fixed UI defaults matched from
    that sample, not alert-derived. odate is always left blank (a single
    space, matching the sample) - no real per-alert odate source was
    available (Control-M's job-status response does have an orderDate
    field, but the sample link itself used a blank odate, not that).

    The trailing path segment is that same blank odate encoded TWICE -
    once the way the query string would ("%20"), then again because it's
    embedded as a literal substring of the path rather than its own path
    component - hence the hardcoded "%2520" below rather than a second
    quote() call, which would read as a mistake out of context.

    Returns "" if CONTROLM_URL isn't configured (nothing to derive the
    Control-M host from) or order_id is missing - this is a nice-to-have
    link, not something worth failing a report or incident over.
    """
    controlm_url = ctm_config.get("CONTROLM_URL", "")
    order_id = alert.get("order_id", "").strip()
    if not controlm_url or not order_id:
        return ""

    parsed = urlsplit(controlm_url)
    base = f"{parsed.scheme}://{parsed.netloc}"

    job_name = alert.get("job_name", "").strip()
    data_center = alert.get("data_center", "").strip()

    path = f"{quote(order_id, safe='')}_3_1_%2520"
    query = urlencode({
        "name": job_name,
        "ctm": data_center,
        "odate": " ",
        "direction": "1",
        "radius": "3",
        "orderId": order_id,
        "mapView": "TileView",
    }, quote_via=quote)

    return f"{base}/ControlM/Monitoring/Neighborhood/{path}?{query}"


def load_alert_tracking() -> dict:
    """
    Load the alert tracking ledger: a single JSON object keyed by
    alert_id, recording what action was taken for each alert this
    script has ever seen. Simpler than alerts.py's per-alert JSON file
    + processed/delayed/failed folder-move mechanism, but serves the
    same purpose: an on-disk record of alert_id -> what happened.
    Missing or unreadable file is treated as "no history yet", not an
    error - this is a demo script, not a production audit system.
    """
    if not os.path.exists(ALERT_TRACKING_FILE):
        return {}
    try:
        with open(ALERT_TRACKING_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        log("WARN", f"Could not read alert tracking file ({e}) - treating as empty.")
        return {}


def record_alert_action(alert_id: str, action: str, extra: dict = None) -> None:
    """Record what this script did for a given alert_id."""
    if not alert_id:
        return

    os.makedirs(os.path.dirname(ALERT_TRACKING_FILE), exist_ok=True)
    tracking = load_alert_tracking()

    record = {"action": action, "timestamp": datetime.now().isoformat()}
    if extra:
        record.update(extra)
    tracking[alert_id] = record

    try:
        with open(ALERT_TRACKING_FILE, "w") as f:
            json.dump(tracking, f, indent=2)
        log("INFO", f"Recorded alert_id={alert_id} action='{action}' in tracking file.")
    except OSError as e:
        log("ERROR", f"Could not write alert tracking file: {e}")


def classify_alert(alert: dict) -> str:
    """
    Classify a Control-M alert into one of: 'job', 'agent_unavailable',
    'agent_available', or 'other'.

    Mirrors the original alerts.py exactly:
      - order_id and order_id != '00000' and job_name -> 'job'
      - 'STATUS OF AGENT PLATFORM' + 'CHANGED TO UNAVAILABLE' in message -> 'agent_unavailable'
      - 'STATUS OF AGENT PLATFORM' + 'CHANGED TO AVAILABLE' in message -> 'agent_available'
      - everything else (server disconnection, x-alerts, unrecognized
        order_id=00000 messages) -> 'other', explicitly out of scope for
        this demo per project decision - logged and skipped, not built out.
    """
    order_id = alert.get("order_id", "").strip()
    job_name = alert.get("job_name", "").strip()
    message_upper = alert.get("message", "").upper()

    if order_id and order_id != "00000" and job_name:
        return "job"
    if "STATUS OF AGENT PLATFORM" in message_upper and "CHANGED TO UNAVAILABLE" in message_upper:
        return "agent_unavailable"
    if "STATUS OF AGENT PLATFORM" in message_upper and "CHANGED TO AVAILABLE" in message_upper:
        return "agent_available"
    return "other"


def extract_agent_hostname_from_message(message: str) -> str:
    """
    For 'STATUS OF AGENT PLATFORM <hostname> CHANGED TO (UN)?AVAILABLE'
    alerts, Control-M leaves the structured host_id field empty and puts
    the actual agent hostname only in the free-text message - confirmed
    against real production alerts (2257/2258), where host_id was ''
    but message contained 'ctm-lin-em.werkstatt.local'. Without this, every
    agent alert from the same data_center collapses onto one
    correlation_id, unable to distinguish between different agents.
    """
    match = re.search(r"STATUS OF AGENT PLATFORM\s+(\S+)\s+CHANGED TO", message, re.IGNORECASE)
    return match.group(1) if match else ""


def build_agent_correlation_id(alert: dict) -> str:
    """
    data_center + host_id, not host_id alone - in newer Control-M
    releases one host_id can sit under more than one CTM Server, so
    host_id alone isn't guaranteed unique.

    host_id itself is frequently empty for these alerts (confirmed from
    real production data) - falls back to extracting the hostname from
    the message text when that happens.
    """
    data_center = alert.get("data_center", "").strip()
    host_id = alert.get("host_id", "").strip()
    if not host_id:
        host_id = extract_agent_hostname_from_message(alert.get("message", ""))
    return f"{data_center}:{host_id}"


def get_oauth_token(config: dict) -> str:
    log("INFO", "--- Step 4: SNOW Get OAuth Token ---")
    url = f"https://{config['SERVICENOW_INSTANCE']}.service-now.com/oauth_token.do"
    resp = requests.post(url, data={
        "grant_type": "client_credentials",
        "client_id": config["SERVICENOW_CLIENT_ID"],
        "client_secret": config["SERVICENOW_CLIENT_SECRET"],
    })
    log("INFO", f"Response status: {resp.status_code}")

    if resp.status_code != 200:
        log("ERROR", f"OAuth token request failed: {resp.text}")
        raise RuntimeError("OAuth token request failed")

    body = resp.json()
    access_token = body.get("access_token", "")
    if not access_token:
        log("ERROR", f"No access_token in response: {body}")
        raise RuntimeError("No access_token in response")

    # Deliberately redacted even in verbose mode - this is a live credential,
    # not just diagnostic detail, and shouldn't land in a log file in full.
    redacted_body = {**body, "access_token": f"{access_token[:12]}...(redacted)"}
    log("DEBUG", f"Full token response (access_token redacted): {json.dumps(redacted_body)}")

    log("INFO", f"Token stored: {access_token[:12]}...")
    return access_token


def build_short_description(alert: dict) -> str:
    """
    job_name is a KEY THAT EXISTS with an empty string value for agent
    alerts (not a missing key) - alert.get('job_name', 'unknown job')
    never triggers its default in that case, producing a bare leading
    ": " with nothing before it. Caught from a real production log.
    Omits the "X: " prefix entirely when there's no job_name, rather than
    substituting a filler label that would read oddly on a non-job alert.
    """
    job_name = alert.get("job_name", "").strip()
    message = alert.get("message", "no message")
    alert_id = alert.get("alert_id", "unknown")
    if job_name:
        return f"{job_name}: {message} (Alert {alert_id})"
    return f"{message} (Alert {alert_id})"


def build_work_notes(alert: dict) -> str:
    """
    Same class of bug as build_short_description: these fields exist
    with empty string values for agent alerts, not missing keys, so
    .get(key, default) never triggers its fallback. Uses truthy checks
    instead, and omits "on job X" entirely when there's no job_name
    rather than rendering "on job " with nothing after it.
    """
    alert_id = alert.get("alert_id", "unknown")
    job_name = alert.get("job_name", "").strip()
    job_clause = f" on job {job_name}" if job_name else ""
    application = alert.get("application", "").strip() or "unknown"
    sub_application = alert.get("sub_application", "").strip() or "unknown"
    host_id = alert.get("host_id", "").strip() or "unknown"
    data_center = alert.get("data_center", "").strip() or "unknown"
    message = alert.get("message", "").strip() or "none"

    return (
        f"Control-M alert {alert_id}{job_clause}\n"
        f"Application: {application} / Sub-application: {sub_application}\n"
        f"Host: {host_id} | Data center: {data_center}\n"
        f"Message: {message}"
    )


def create_incident(config: dict, alert: dict, rules: list, access_token: str, correlation_id: str = "") -> tuple:
    log("INFO", "--- Step 5: SNOW Create Incident ---")

    application = alert.get("application", "")
    rule = resolve_route(application, rules)

    if rule:
        log("INFO", f"Application '{application}' matched rule -> "
                     f"service='{rule.get('service_name', '')}' pattern='{rule.get('pattern', '')}'")
    else:
        log("WARN", f"Application '{application}' matched no rule (check for a catch-all '*' rule in mapping.json).")

    assignment_group = rule.get("assignment_group_sys_id", "")
    cmdb_ci = rule.get("cmdb_ci_sys_id", "")
    assignment_group_name = rule.get("assignment_group_name", "")
    cmdb_ci_name = rule.get("cmdb_ci_name", "")

    if assignment_group:
        log("INFO", f"Resolved assignment_group: '{assignment_group_name}' ({assignment_group})")
    else:
        log("WARN", "No assignment_group_sys_id in matched rule - incident will be created without a group.")

    if cmdb_ci:
        log("INFO", f"Resolved cmdb_ci: '{cmdb_ci_name}' ({cmdb_ci})")
    else:
        log("INFO", "No cmdb_ci resolved for this alert.")

    severity = alert.get("severity", "")
    urgency = "1" if severity == "V" else "3"
    impact = "1" if severity == "V" else "3"

    payload = {
        "short_description": build_short_description(alert),
        "caller_id": config["SERVICENOW_CALLER_ID"],
        "urgency": urgency,
        "impact": impact,
    }
    if assignment_group:
        payload["assignment_group"] = assignment_group
    if cmdb_ci:
        payload["cmdb_ci"] = cmdb_ci
    if correlation_id:
        payload["correlation_id"] = correlation_id
        log("INFO", f"Setting correlation_id: {correlation_id}")

    log("INFO", f"Final incident payload built: {json.dumps(payload)}")

    url = f"https://{config['SERVICENOW_INSTANCE']}.service-now.com/api/now/table/incident"
    resp = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        json=payload,
    )
    log("INFO", f"Response status: {resp.status_code}")

    if resp.status_code != 201:
        log("ERROR", f"Incident creation failed: {resp.text}")
        raise RuntimeError("Incident creation failed")

    result = resp.json().get("result", {})
    log("DEBUG", f"Full incident record from ServiceNow: {json.dumps(result)}")

    sys_id = result.get("sys_id", "")
    number = result.get("number", "")
    if not sys_id:
        log("ERROR", f"No sys_id in response: {result}")
        raise RuntimeError("No sys_id in response")

    log("INFO", f"Incident created: {number} ({sys_id})")

    # Curated summary, not the full raw ServiceNow record - that record
    # has 50+ mostly-empty fields (seen firsthand during testing) that
    # would just clutter Control-M EM's log. Single-line JSON, clearly
    # marked, so it's easy to grep/parse out of a log that also contains
    # the plain [INFO]/[WARN] narrative lines around it.
    summary = {
        "incident_number": number,
        "incident_sys_id": sys_id,
        "short_description": payload.get("short_description", ""),
        "assignment_group_sys_id": payload.get("assignment_group", ""),
        "cmdb_ci_sys_id": payload.get("cmdb_ci", ""),
        "urgency": payload.get("urgency", ""),
        "impact": payload.get("impact", ""),
        "caller_id": payload.get("caller_id", ""),
    }
    log("RESULT", f"CTM_EM_INCIDENT_JSON: {json.dumps(summary)}")

    return sys_id, number


def build_correlation_lookup_query(correlation_id: str) -> str:
    """
    Query string for finding an incident to resolve by correlation_id.

    active=true alone is NOT sufficient: confirmed via a real Postman test
    on a real incident that ServiceNow leaves active=true even after state
    is set to Resolved (6) - only Closed/Canceled typically flip it to
    false. Without excluding state=6 explicitly, every subsequent
    agent_available alert for the same host would keep re-matching and
    re-resolving the SAME already-resolved incident indefinitely, rather
    than correctly finding nothing. This was caught from real production
    evidence: the same incident's resolved_at timestamp didn't change
    between two separate resolve attempts, proving ServiceNow silently
    no-op'd a redundant resolve rather than us noticing a real problem.

    Deliberately excludes only state=6 (Resolved) - the one value actually
    confirmed via a live Postman test earlier in this project - rather than
    also guessing at Closed/Canceled's numeric values, which have not been
    similarly verified against this instance.
    """
    return f"correlation_id={correlation_id}^active=true^state!=6"


def find_open_incident_by_correlation(config: dict, access_token: str, correlation_id: str) -> tuple:
    """
    Find an active, not-yet-resolved incident matching a given
    correlation_id. Returns (sys_id, number) or ("", "") if none is
    found - callers should treat "no match" as a normal, expected outcome,
    not an error (e.g. an agent_available alert arriving with no
    corresponding open incident, because it was already resolved, closed
    manually, or the unavailable alert was never processed).
    """
    log("INFO", f"Looking for an open incident with correlation_id={correlation_id}")

    url = f"https://{config['SERVICENOW_INSTANCE']}.service-now.com/api/now/table/incident"
    resp = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
        params={
            "sysparm_query": build_correlation_lookup_query(correlation_id),
            "sysparm_fields": "sys_id,number",
            "sysparm_limit": "1",
        },
    )
    log("INFO", f"Response status: {resp.status_code}")

    if resp.status_code != 200:
        log("ERROR", f"Correlation lookup failed: {resp.text}")
        raise RuntimeError("Correlation lookup failed")

    results = resp.json().get("result", [])
    if not results:
        log("WARN", f"No open incident found with correlation_id={correlation_id}. Nothing to resolve.")
        return "", ""

    sys_id = results[0].get("sys_id", "")
    number = results[0].get("number", "")
    log("INFO", f"Found open incident to resolve: {number} ({sys_id})")
    return sys_id, number


def resolve_incident(config: dict, access_token: str, incident_sys_id: str, incident_number: str, alert: dict) -> None:
    """
    Resolve an incident as "agent is back up" - state and close_code
    values below are confirmed against this instance via a real Postman
    test (not guessed): state=6 round-tripped correctly as ServiceNow's
    stored value for Resolved, and close_code stores the label itself
    as its value.
    """
    log("INFO", "--- Resolving Incident (agent_available) ---")

    payload = {
        "state": "6",
        "close_code": "Solution provided",
        "close_notes": f"Agent is up and running again. (Control-M Alert ID: {alert.get('alert_id', 'unknown')})",
    }
    log("INFO", f"Resolve payload: {json.dumps(payload)}")

    url = f"https://{config['SERVICENOW_INSTANCE']}.service-now.com/api/now/table/incident/{incident_sys_id}"
    resp = requests.patch(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        json=payload,
    )
    log("INFO", f"Response status: {resp.status_code}")

    if resp.status_code != 200:
        log("ERROR", f"Incident resolution failed: {resp.text}")
        raise RuntimeError("Incident resolution failed")

    result = resp.json().get("result", {})
    log("DEBUG", f"Full incident record from ServiceNow: {json.dumps(result)}")

    summary = {
        "incident_number": incident_number,
        "incident_sys_id": incident_sys_id,
        "state": result.get("state", ""),
        "close_code": result.get("close_code", ""),
        "resolved_at": result.get("resolved_at", ""),
    }
    log("RESULT", f"CTM_EM_INCIDENT_RESOLVED_JSON: {json.dumps(summary)}")


def add_worklog(config: dict, alert: dict, access_token: str, incident_sys_id: str) -> None:
    log("INFO", "--- Step 6: SNOW Add Worklog Entry ---")

    work_notes = build_work_notes(alert)

    url = f"https://{config['SERVICENOW_INSTANCE']}.service-now.com/api/now/table/incident/{incident_sys_id}"
    resp = requests.patch(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        json={"work_notes": work_notes},
    )
    log("INFO", f"Response status: {resp.status_code}")

    if resp.status_code != 200:
        log("ERROR", f"Worklog update failed: {resp.text}")
        raise RuntimeError("Worklog update failed")

    result = resp.json().get("result", {})
    log("DEBUG", f"Full worklog response from ServiceNow: {json.dumps(result)}")

    sys_mod_count = result.get("sys_mod_count", "")
    log("INFO", f"Worklog added. sys_mod_count (should have incremented): {sys_mod_count}")


def load_job_report(alert_id: str) -> dict:
    """
    Best-effort read of the report ctm_job_report.py may have already
    written for this alert_id (data/job_reports/<alert_id>.json). Missing
    or unreadable file -> {}, same graceful-degrade pattern as
    load_alert_tracking() above - this is a plain filesystem read, not a
    call into ctm_client/the Control-M AAPI, so it can't hang and doesn't
    reintroduce the coupling the v1.2.0 revert removed.
    """
    if not alert_id:
        return {}
    path = os.path.join(JOB_REPORT_DIR, f"{alert_id}.json")
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        log("WARN", f"Could not read job report for alert_id={alert_id} ({e}) - continuing without it.")
        return {}


def _truncate(text: str, limit: int = JOB_REPORT_WORK_NOTES_LIMIT) -> str:
    if len(text) <= limit:
        return text
    return text[:limit] + f"\n...[truncated, {len(text)} chars total]"


_CTM_DATETIME_RE = re.compile(r"^\d{14}$")  # startTime/endTime: YYYYMMDDHHMMSS
_CTM_DATE_RE = re.compile(r"^\d{6}$")        # orderDate: YYMMDD

# A handful of field names the generic camelCase-splitter below would
# otherwise mangle (acronyms, the bare "ctm" abbreviation) - everything
# else falls through to the generic label formatting so every field the
# AAPI returns still gets shown, not just these.
_JOB_STATUS_LABEL_OVERRIDES = {
    "ctm": "Control-M Server",
    "jobId": "Job ID",
    "folderId": "Folder ID",
    "outputURI": "Output URI",
    "logURI": "Log URI",
}


def _format_ctm_timestamp(value: str) -> str:
    """
    Best-effort human-readable rendering of a Control-M date/time-shaped
    string - YYYYMMDDHHMMSS (job start/end times) or YYMMDD (orderDate,
    assumed 21st century - this project's own sample data is 2026).
    Returns the original value unchanged if it doesn't match either shape
    (already blank, or a format that differs on some other AAPI version)
    rather than raising - this is display-only, never worth failing a
    worklog entry over.
    """
    if not isinstance(value, str):
        return value
    v = value.strip()
    if _CTM_DATETIME_RE.match(v):
        try:
            return datetime.strptime(v, "%Y%m%d%H%M%S").strftime("%Y-%m-%d %H:%M:%S")
        except ValueError:
            return value
    if _CTM_DATE_RE.match(v):
        try:
            return datetime.strptime("20" + v, "%Y%m%d").strftime("%Y-%m-%d")
        except ValueError:
            return value
    return value


def _format_job_status_label(key: str) -> str:
    """camelCase/snake_case field name -> "Title Case With Spaces"."""
    if key in _JOB_STATUS_LABEL_OVERRIDES:
        return _JOB_STATUS_LABEL_OVERRIDES[key]
    spaced = re.sub(r"(?<!^)(?=[A-Z])", " ", key.replace("_", " "))
    return spaced.strip().title()


def _format_job_status(status: dict) -> str:
    """
    Human-readable rendering of ctm_client.get_job_status()'s response for
    the ServiceNow worklog, instead of a raw JSON dump - every field the
    AAPI returned, per user request, not a curated subset. Field order
    matches the response's own key order. Date/time-shaped string values
    are reformatted via _format_ctm_timestamp(); lists render each element
    the same way; booleans render as Yes/No; an empty endTime specifically
    renders as "(still running)" since that's genuinely more informative
    than "(empty)" for that one field.
    """
    if not status:
        return json.dumps(status, indent=2)

    lines = []
    for key, value in status.items():
        label = _format_job_status_label(key)

        if key == "endTime" and not value:
            rendered = "(still running)"
        elif isinstance(value, bool):
            rendered = "Yes" if value else "No"
        elif isinstance(value, list):
            items = [_format_ctm_timestamp(v) for v in value]
            rendered = ", ".join(items) if items else "(none)"
        elif value in (None, ""):
            rendered = "(empty)"
        else:
            rendered = _format_ctm_timestamp(value)

        lines.append(f"{label}: {rendered}")

    return "\n".join(lines)


def build_job_report_work_notes(job_report: dict) -> list:
    """
    Turn a ctm_job_report.py report dict into a list of separate work_notes
    entries - one each for the monitoring link/status/log/output, per user
    request, rather than one combined note. A section is only included
    when it's actually present (ctm_job_report.py sets a fetch's key to
    None on failure, and ctm_monitoring_url to "" when it couldn't be
    built - see build_ctm_monitoring_url), so a partial report just
    yields fewer entries.
    """
    entries = []

    monitoring_url = job_report.get("ctm_monitoring_url")
    if monitoring_url:
        entries.append(f"Control-M monitoring link:\n{monitoring_url}")

    status = job_report.get("job_status")
    if status:
        entries.append(f"Control-M job status:\n{_format_job_status(status)}")

    log_text = job_report.get("job_log")
    if log_text:
        entries.append(f"Control-M job log:\n{_truncate(log_text)}")

    output_text = job_report.get("job_output")
    if output_text:
        entries.append(f"Control-M job output:\n{_truncate(output_text)}")

    return entries


def add_job_report_worklogs(config: dict, access_token: str, incident_sys_id: str, job_report: dict) -> int:
    """
    Post each section from build_job_report_work_notes as its own worklog
    PATCH. Best-effort per entry - a failure posting one is logged and
    does not stop the others or fail the run: the incident already
    exists, this is enrichment on top of it. Returns how many entries
    were posted successfully, for the tracking ledger.
    """
    log("INFO", "--- Step 7: SNOW Add Job Report Worklog Entries ---")

    url = f"https://{config['SERVICENOW_INSTANCE']}.service-now.com/api/now/table/incident/{incident_sys_id}"
    posted = 0
    for work_notes in build_job_report_work_notes(job_report):
        try:
            resp = requests.patch(
                url,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
                json={"work_notes": work_notes},
            )
            if resp.status_code == 200:
                posted += 1
                log("INFO", f"Job report worklog entry added ({posted}).")
            else:
                log("WARN", f"Job report worklog entry failed: HTTP {resp.status_code} - {resp.text}")
        except Exception as e:
            log("WARN", f"Could not add job report worklog entry: {e}")

    return posted


def main() -> int:
    # --- --version: check and exit immediately, before touching config,
    # logging level, or anything else. This is the fast, zero-side-effect
    # way to confirm what's actually deployed on a server without
    # triggering a real alert - e.g. `python3 ctm_to_snow_incident.py --version`
    if "--version" in sys.argv[1:]:
        print(f"ctm_to_snow_incident.py version {SCRIPT_VERSION}")
        return 0

    # --- Extract -v/-q before anything else touches sys.argv ---
    # Control-M's own alert tokens always come in 'key:' 'value' pairs -
    # a real field name is never a bare '-v' or '-q' - so it's safe to
    # strip these out up front rather than reaching for argparse, which
    # would try to interpret the positional alert tokens in ways that
    # could collide with this.
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

    cli_flag_given = verbose_flag or quiet_flag
    if verbose_flag:
        set_log_level(LEVEL_VERBOSE)
    elif quiet_flag:
        set_log_level(LEVEL_QUIET)
    # else: leave at the default (LEVEL_NORMAL) until config.LOG_LEVEL is checked below

    log("INFO", f"=== Control-M -> ServiceNow Incident Pipeline : START (version {SCRIPT_VERSION}) ===")

    config = load_config()
    rules = load_mapping(config["MAPPING_FILE"])

    # If no -v/-q flag was given on the command line, fall back to the
    # LOG_LEVEL setting in .env (values: quiet | normal | verbose).
    # NOTE: this means the one "Loaded environment from..." INFO line
    # just above is always shown even if .env says LOG_LEVEL=quiet, since
    # we don't know that setting until after config is loaded - a minor,
    # accepted cosmetic gap rather than added complexity to avoid it.
    if not cli_flag_given:
        env_level = os.getenv("LOG_LEVEL", "normal").strip().lower()
        if env_level == "quiet":
            set_log_level(LEVEL_QUIET)
        elif env_level == "verbose":
            set_log_level(LEVEL_VERBOSE)
        else:
            set_log_level(LEVEL_NORMAL)

    if argv:
        alert = parse_ctm_args_to_json(argv)
    elif os.getenv("SNOW_CTM_DEMO_MODE", "false").lower() == "true":
        log("WARN", "SNOW_CTM_DEMO_MODE is enabled and no arguments were passed - using built-in sample alert.")
        alert = parse_ctm_args_to_json(DEMO_ALERT_ARGS)
    else:
        log("ERROR", "No Control-M alert arguments provided and SNOW_CTM_DEMO_MODE is not 'true'.")
        return 1

    log("INFO", "--- Step 0: Alert Received ---")
    log("INFO", f"Parsed alert (JSON):\n{json.dumps(alert, indent=2)}")

    lifecycle = describe_ctm_lifecycle(alert)
    log("INFO", f"Control-M alert lifecycle state: {lifecycle}")

    if lifecycle != "initial":
        # Loop-prevention: Control-M re-sends this same alert_id as its
        # own status changes (Noticed/Handled in Control-M's console).
        # We have no ServiceNow incident number to map a 'U' update back
        # to, so these are explicitly not processed - logged and skipped,
        # not an error.
        log("INFO", f"This is a Control-M update alert (lifecycle='{lifecycle}'), not a new alert. "
                     f"Skipping - full bi-directional Control-M/ServiceNow sync is out of scope for "
                     f"this demo. No incident will be created or modified.")
        log("INFO", "=== Control-M -> ServiceNow Incident Pipeline : DONE (skipped, update alert) ===")
        return 0

    alert_id = alert.get("alert_id", "")
    tracking = load_alert_tracking()
    if alert_id and alert_id in tracking:
        prior = tracking[alert_id]
        log("WARN", f"alert_id={alert_id} was already processed (action='{prior.get('action')}' "
                     f"at {prior.get('timestamp')}). Skipping to avoid duplicate processing "
                     f"(e.g. Control-M redelivering the same alert).")
        log("INFO", "=== Control-M -> ServiceNow Incident Pipeline : DONE (skipped, duplicate alert_id) ===")
        return 0

    alert_type = classify_alert(alert)
    log("INFO", f"Classified alert as: {alert_type}")

    try:
        access_token = get_oauth_token(config)

        if alert_type == "job":
            incident_sys_id, incident_number = create_incident(config, alert, rules, access_token)
            add_worklog(config, alert, access_token, incident_sys_id)

            job_report = load_job_report(alert_id)
            job_report_worklogs_posted = (
                add_job_report_worklogs(config, access_token, incident_sys_id, job_report)
                if job_report else 0
            )

            record_alert_action(alert_id, "created_incident",
                                 {"incident_number": incident_number, "incident_sys_id": incident_sys_id,
                                  "job_report_worklogs_posted": job_report_worklogs_posted})

        elif alert_type == "agent_unavailable":
            # No 'application' field exists for agent alerts, so routing
            # falls through resolve_route()'s catch-all "*" rule in
            # mapping.json rather than any application-specific match -
            # every agent alert lands in whatever group that catch-all
            # points to. Revisit if agent alerts need their own dedicated
            # routing rule instead of sharing the generic default.
            correlation_id = build_agent_correlation_id(alert)
            incident_sys_id, incident_number = create_incident(
                config, alert, rules, access_token, correlation_id=correlation_id
            )
            add_worklog(config, alert, access_token, incident_sys_id)
            record_alert_action(alert_id, "created_incident",
                                 {"incident_number": incident_number, "incident_sys_id": incident_sys_id,
                                  "correlation_id": correlation_id})

        elif alert_type == "agent_available":
            correlation_id = build_agent_correlation_id(alert)
            incident_sys_id, incident_number = find_open_incident_by_correlation(
                config, access_token, correlation_id
            )
            if incident_sys_id:
                resolve_incident(config, access_token, incident_sys_id, incident_number, alert)
                record_alert_action(alert_id, "resolved_incident",
                                     {"incident_number": incident_number, "incident_sys_id": incident_sys_id,
                                      "correlation_id": correlation_id})
            else:
                log("INFO", "No matching open incident - nothing to resolve. Exiting cleanly.")
                record_alert_action(alert_id, "no_matching_incident", {"correlation_id": correlation_id})

        else:
            # Server disconnection, x-alerts, and any other order_id=00000
            # message that doesn't match a known pattern - explicitly out
            # of scope for this demo per project decision. Logged, not
            # built out, not an error.
            log("INFO", f"Alert type '{alert_type}' is out of scope for this demo - logged and skipped.")
            record_alert_action(alert_id, "skipped_out_of_scope", {"alert_classification": alert_type})

    except RuntimeError as e:
        log("ERROR", f"Aborting: {e}")
        return 1

    log("INFO", "=== Control-M -> ServiceNow Incident Pipeline : DONE ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
