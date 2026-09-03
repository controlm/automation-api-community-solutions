#!/usr/bin/env python3
# Filename: ctm_client.py
"""
Control-M Automation API (AAPI) client - the 3 read-only calls this project
needs (job status, job log, job output), reimplemented as plain requests
calls in the same minimal style as ctm_to_snow_incident.py.

Deliberately NOT built on the controlm_py SDK used by the ctm-engineer
project's engineer_ctm.py: that SDK's connection/session model pulls in
project.py's config loader, which in turn requires jsonschema, jsonpath_ng
and pycryptodome (for its CRYPTO_FILE-based secrets handling) - none of
which this project uses anywhere else. Talking to the 3 needed endpoints
directly keeps this project on its existing "pip install requests
python-dotenv" dependency footprint.

Auth: a Control-M Automation API token, sent as the 'x-api-key' header on
every request. No login/logout session call - this matches how a
persistent AAPI token is meant to be used, and avoids having to manage
session expiry/renewal for a demo script that runs once per Control-M
alert.

Config is loaded from ./config/.env relative to this script's own
location - the same file ctm_to_snow_incident.py loads its ServiceNow
config from. See config/.env.example for the required variables.

Debug logging: set CONTROLM_DEBUG=true in config/.env to have every AAPI
call print the outgoing request and the raw response it got back. This is
its own copy of logging, separate from either pipeline's log()/
set_log_level() (same "no runtime coupling" reasoning as the rest of this
module's docstring) and gated by its own config var rather than either
pipeline's -v/--verbose, so it can be left on independent of how verbose
the calling pipeline's own console output is - useful for confirming
exactly what was sent to/received from Control-M when the AAPI's response
doesn't match what actually happened (e.g. a 200 "ok" that silently didn't
apply the change).
"""

import os
from datetime import datetime
from urllib.parse import quote

import requests
from dotenv import load_dotenv

SCRIPT_VERSION = "2.1.0"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, "config", ".env")


def load_ctm_config() -> dict:
    """Load Control-M AAPI configuration from config/.env."""
    if os.path.exists(ENV_FILE):
        load_dotenv(ENV_FILE)

    return {
        "CONTROLM_URL": os.getenv("CONTROLM_URL", "").rstrip("/"),
        "CONTROLM_API_KEY": os.getenv("CONTROLM_API_KEY", ""),
        "CONTROLM_DEBUG": os.getenv("CONTROLM_DEBUG", "false").lower() == "true",
    }


def _headers(config: dict) -> dict:
    return {
        "x-api-key": config["CONTROLM_API_KEY"],
        "Accept": "application/json",
    }


def _debug_log(message: str) -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [DEBUG] [ctm_client] {message}")


def _request(config: dict, method: str, url: str, **kwargs) -> requests.Response:
    """
    Single choke point for every AAPI call, so CONTROLM_DEBUG logging
    (request in, response out) covers all of them without repeating it in
    each function. Never logs headers - the AAPI key lives there.
    """
    debug = config.get("CONTROLM_DEBUG")
    if debug:
        extra = {k: v for k, v in kwargs.items() if k in ("params", "json")}
        _debug_log(f"-> {method} {url} {extra}")

    resp = requests.request(method, url, headers=_headers(config), **kwargs)

    if debug:
        _debug_log(f"<- {method} {url} HTTP {resp.status_code}: {resp.text}")

    return resp


def _job_id(ctm_server: str, order_id: str) -> str:
    """
    Control-M's own job_id format: '<server>:<order_id>' - matches the
    ctmServer + ":" + ctmOrderID convention used throughout engineer_ctm.py
    (e.g. getCtmJobStatus, getCtmJobInfo).
    """
    return f"{ctm_server}:{order_id}"


def get_job_status(config: dict, ctm_server: str, order_id: str) -> dict:
    """
    Look up a job's status by Control-M server + order_id.

    GET /run/job/<server>%3A<order_id>/status

    Single-job endpoint, not the bulk /run/jobs/status?jobid=<id> list this
    used to call - confirmed via direct testing (see
    docs/ctm_alert_order.md, Step 1) that this one still returns full
    status (status/startTime/endTime etc.) for a job that has already
    finished, whereas the bulk list only covers Control-M's active
    pipeline and returned nothing once the job aged out of it - which is
    the common case here, since Control-M alerts fire once a job has
    already ended.
    """
    url = f"{config['CONTROLM_URL']}/run/job/{quote(_job_id(ctm_server, order_id), safe='')}/status"
    resp = _request(config, "GET", url)

    if resp.status_code != 200:
        raise RuntimeError(f"get_job_status failed: HTTP {resp.status_code} - {resp.text}")

    return resp.json()


def get_job_log(config: dict, ctm_server: str, order_id: str) -> str:
    """
    Get a job's execution log (Control-M's own run log, not job stdout -
    see get_job_output for that).

    GET /run/job/<server>%3A<order_id>/log

    job_id is percent-encoded in the path (':' -> '%3A') to match the AAPI's
    actual expected format - confirmed against controlm_py's api_client.py,
    which encodes path params with safe_chars_for_path_param='' (no chars
    exempted from encoding).
    """
    url = f"{config['CONTROLM_URL']}/run/job/{quote(_job_id(ctm_server, order_id), safe='')}/log"
    resp = _request(config, "GET", url)

    if resp.status_code != 200:
        raise RuntimeError(f"get_job_log failed: HTTP {resp.status_code} - {resp.text}")

    return resp.text


def get_job_output(config: dict, ctm_server: str, order_id: str, run_no: int = 0) -> str:
    """
    Get a job's output (stdout/sysout). run_no=0 (default) gets the most
    recent execution's output.

    GET /run/job/<server>%3A<order_id>/output?runNo=<run_no>
    """
    url = f"{config['CONTROLM_URL']}/run/job/{quote(_job_id(ctm_server, order_id), safe='')}/output"
    resp = _request(config, "GET", url, params={"runNo": run_no})

    if resp.status_code != 200:
        raise RuntimeError(f"get_job_output failed: HTTP {resp.status_code} - {resp.text}")

    return resp.text


def update_alert(config: dict, alert_id: str, urgency: str = None, comment: str = None) -> dict:
    """
    Update an alert's urgency and/or comment (the alert's own free-text
    field, shown alongside it in Control-M).

    POST /run/alerts
    Body: {"alertIds": [<alert_id>], "urgency": <urgency>, "comment": <comment>}

    urgency/comment are only included in the body when given, so a
    caller that only wants to set one doesn't clobber the other.
    """
    url = f"{config['CONTROLM_URL']}/run/alerts"
    body = {"alertIds": [alert_id]}
    if urgency is not None:
        body["urgency"] = urgency
    if comment is not None:
        body["comment"] = comment

    resp = _request(config, "POST", url, json=body)

    if resp.status_code != 200:
        raise RuntimeError(f"update_alert failed: HTTP {resp.status_code} - {resp.text}")

    return resp.json() if resp.text else {}


def set_alert_status(config: dict, alert_id: str, status: str) -> dict:
    """
    Set an alert's status - used to mark an alert as read/acknowledged
    (status="Reviewed") once this pipeline has finished with it.

    POST /run/alerts/status
    Body: {"alertIds": [<alert_id>], "status": <status>}
    """
    url = f"{config['CONTROLM_URL']}/run/alerts/status"
    body = {"alertIds": [alert_id], "status": status}
    resp = _request(config, "POST", url, json=body)

    if resp.status_code != 200:
        raise RuntimeError(f"set_alert_status failed: HTTP {resp.status_code} - {resp.text}")

    return resp.json() if resp.text else {}
