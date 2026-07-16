#!/usr/bin/env python3
# Filename: ctm_engineer.py
"""
Control-M Automation API client - Python port of the Postman collection /
ctm-preflight.ps1 pair.

This module holds all the reusable Control-M integration code (CtmClient,
config loading) so it can be imported from other scripts/tools later, e.g.:

    from ctm_engineer import build_client
    client = build_client()
    client.get_servers()

Running it directly (`python ctm_engineer.py`) does a basic connectivity
check; `python ctm_engineer.py --folder SOME_FOLDER` runs the full preflight
check against that Control-M folder (see CtmClient.run_preflight).

Talks to the Automation API directly over REST (x-api-key header), the same
way the PowerShell script and Postman collection do. It intentionally does not
use the controlm_py SDK or the old project.py config framework from
src/archive - those pulled in unrelated integrations (MySQL, SMTP, Kafka,
Flask) that this standalone tool has no use for.

Configuration is read from .engineer/config/.env next to this script
(see .engineer/config/.env.sample):
    baseUrl=https://your-ctm-em/automation-api
    apiKey=your-api-key
    CTM_SERVER=ctm-lin-srv

Also includes non-Control-M checks that run from wherever this executes,
without touching Control-M or its credentials:
  - test_network_endpoint, CtmClient.resolve_connection_profile_endpoint,
    CtmClient.test_connection_profile_network - ping/TCP-connect a connection
    profile's real endpoint.
  - get_ssl_certificate - reads a host:port's LIVE SSL/TLS certificate and
    expiration via openssl, since an expired cert fails Control-M's own agent
    test but Control-M won't proactively warn you it's about to.
  - get_ssh_fingerprint - reads a host's LIVE SSH host key fingerprint via
    ssh-keyscan/ssh-keygen, to catch host-key drift.
See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup
including caveats.
"""

import argparse
import json
import logging
import platform
import socket
import subprocess
import sys
import tempfile
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

import requests
import urllib3
from dotenv import dotenv_values

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_ENV_FILE = SCRIPT_DIR / ".engineer" / "config" / ".env"
DEFAULT_LOG_FOLDER = SCRIPT_DIR / ".engineer" / "logs"
REQUIRED_KEYS = ("baseUrl", "apiKey", "CTM_SERVER")

# Fallback ports used only when a connection profile's own Port field is
# absent (meaning "use the type's default") - matched against the last
# colon-separated segment of the profile's Type string (e.g. "SFTP" out of
# "ConnectionProfile:FileTransfer:SFTP"), an exact match rather than a
# substring check so "FTP" can't accidentally match "SFTP" (it's a substring
# of it) or vice versa.
#
# These are the respective protocol's own standard default port - note that
# BMC's MFTE file transfer service's FTP/FTPS and SFTP listeners commonly
# default to 1221/1222 instead (confirmed via Control-M's own Server
# Configuration screen for the File Transfer plugin), which is a DIFFERENT
# default than the protocol standard used here. A connection profile pointed
# at MFTE with no explicit Port is genuinely ambiguous between the two: use
# an explicit default_port (test_connection_profile_network) or the CCP's own
# Port when it has one (it usually will, whenever it differs from whichever
# default Control-M itself assumes).
DEFAULT_PORTS_BY_CCP_TYPE = {
    "SFTP": 22,
    "FTP": 21,
    "PostgreSQL": 5432,
    "SQLServer": 1433,
    "MSSQL": 1433,
    "Oracle": 1521,
    "MySQL": 3306,
    "DB2": 50000,
    "Sybase": 5000,
}


def _default_port_for_ccp_type(ccp_type):
    if not ccp_type:
        return None
    type_suffix = ccp_type.rsplit(":", 1)[-1]
    return DEFAULT_PORTS_BY_CCP_TYPE.get(type_suffix)

logger = logging.getLogger("ctm-engineer")


class _ExcludeRawApiLogFilter(logging.Filter):
    """Keeps CtmClient._request's raw "CTM API request/response/error: ..." lines off a handler.

    Applied to the console handler only, not the file one: those lines are
    the low-level HTTP layer's own record of every call (useful for the
    persistent log file / -v tracing), but they duplicate what the
    human-readable --output verbose report already prints via plain print()
    for a preflight run - showing both is just repetition of the same
    failure, once as a raw log line and once in the report's own
    "Connection-profile failures:" section.
    """

    def filter(self, record):
        return not record.getMessage().startswith("CTM API ")


def configure_logging(verbose=False, log_folder=DEFAULT_LOG_FOLDER):
    """Set up console + file logging - a log file is always written, verbose or not.

    Console and file both get INFO (or DEBUG when verbose) - the same level,
    so the file is always at least a persistent record of what the console
    showed (summaries, and any real errors like a genuine connection-profile
    failure), not something you only get by remembering to pass -v. With -v,
    both additionally capture every API URL and its response body (see
    CtmClient._request) for full tracing.

    The console handler additionally excludes _request's raw "CTM API ..."
    lines (see _ExcludeRawApiLogFilter) - those still go to the log file
    always, they just don't clutter the console on top of the human-readable
    report/summary that's already printed there.
    """
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    level = logging.DEBUG if verbose else logging.INFO

    console_handler = logging.StreamHandler()
    console_handler.setLevel(level)
    console_handler.setFormatter(fmt)
    console_handler.addFilter(_ExcludeRawApiLogFilter())
    logger.addHandler(console_handler)

    log_folder = Path(log_folder)
    log_folder.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_folder / f"ctm_engineer_{timestamp}.log"

    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setLevel(level)
    file_handler.setFormatter(fmt)
    logger.addHandler(file_handler)
    logger.debug("Log file: %s", log_file)

    return log_file


def test_network_endpoint(host, port, timeout=3):
    """ICMP ping + TCP port-connect test against a host/port - run from THIS machine, NOT the Control-M agent.

    See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup.

    Python port of ctm-preflight.ps1's Test-NetworkEndpoint. This is a
    GLOBAL CHECK ONLY: it proves reachability from wherever this check
    happens to run, not from the agent that would actually perform the
    transfer - the agent's real network path (segment, firewall, NAT) may
    differ entirely. Treat it as an early warning signal, not proof the
    agent-side transfer will succeed.

    ICMP uses the system `ping` binary rather than a raw socket, since raw
    ICMP sockets need root/admin privileges on most platforms; ping's flags
    differ between Windows and everything else, so both are handled.

    :return: dict with keys: host, port, ping_ok, ping_message, port_ok, port_message
    """
    if platform.system() == "Windows":
        ping_cmd = ["ping", "-n", "1", "-w", str(timeout * 1000), host]
    else:
        ping_cmd = ["ping", "-c", "1", "-W", str(timeout), host]

    try:
        ping_result = subprocess.run(ping_cmd, capture_output=True, timeout=timeout + 2)
        ping_ok = ping_result.returncode == 0
        ping_message = "ICMP reply received" if ping_ok else "no ICMP reply"
    except (subprocess.TimeoutExpired, OSError) as exp:
        ping_ok = False
        ping_message = f"ICMP test error: {exp}"

    try:
        with socket.create_connection((host, port), timeout=timeout):
            port_ok = True
            port_message = f"TCP port {port} open"
    except OSError as exp:
        port_ok = False
        port_message = f"TCP port {port} closed, filtered, or timed out: {exp}"

    return {
        "host": host,
        "port": port,
        "ping_ok": ping_ok,
        "ping_message": ping_message,
        "port_ok": port_ok,
        "port_message": port_message,
    }


def _parse_openssl_date(value):
    """Parse an openssl x509 -enddate/-startdate value (e.g. "Oct 21 20:18:36 2034 GMT") to an aware datetime."""
    if not value:
        return None
    try:
        return datetime.strptime(value, "%b %d %H:%M:%S %Y GMT").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def get_ssl_certificate(host, port, timeout=5):
    """Retrieve a host:port's LIVE SSL/TLS certificate and its expiration - outside Control-M, via openssl.

    See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup.

    Uses the system `openssl` binary (s_client + x509) rather than a Python TLS
    library, so it works wherever openssl is installed with no extra pip
    dependency. The reason this needs to happen outside Control-M at all:
    Control-M's own agent test can fail on an expired SSL cert, but Control-M
    doesn't proactively tell you a cert is *about* to expire, and its own
    reported expiration (CtmClient.get_agent_crt_expiration) reflects what
    Control-M has on record - not necessarily what's actually being presented
    on the wire right now (e.g. after a cert was rotated outside Control-M's
    knowledge). This connects directly and reads the real, current cert.

    No credentials are used or needed - this is a plain TLS handshake up to
    the point of reading the peer's certificate, nothing more.

    Background: https://documents.bmc.com/supportu/9.0.22/en-US/Documentation/Introduction_to_SSL.htm
    and https://documents.bmc.com/supportu/9.0.22/en-US/Documentation/Zone_2_and_3_SSL_configuration.htm
    - an agent's SSL/Zone 2-3 port is normally its ATCMNDATA (Agent-to-Server
    communication) port parameter (see CtmClient.get_agent_params).

    :return: dict with keys: host, port, not_before, not_after (raw openssl date strings),
        expired (bool), days_until_expiry (int, negative if already expired),
        subject, issuer, fingerprint_sha256, error (None on success)
    """
    def _error(message):
        return {
            "host": host, "port": port, "not_before": None, "not_after": None,
            "expired": None, "days_until_expiry": None, "subject": None,
            "issuer": None, "fingerprint_sha256": None, "error": message,
        }

    connect_cmd = ["openssl", "s_client", "-connect", f"{host}:{port}", "-servername", host]
    try:
        s_client = subprocess.run(connect_cmd, input=b"", capture_output=True, timeout=timeout)
    except (subprocess.TimeoutExpired, OSError) as exp:
        return _error(f"TLS connection error: {exp}")

    if b"BEGIN CERTIFICATE" not in s_client.stdout:
        stderr_text = s_client.stderr.decode(errors="replace").strip()
        return _error(f"no certificate received (openssl: {stderr_text[:300] or 'no response'})")

    parse_cmd = ["openssl", "x509", "-noout", "-enddate", "-startdate", "-subject", "-issuer", "-fingerprint", "-sha256"]
    try:
        x509 = subprocess.run(parse_cmd, input=s_client.stdout, capture_output=True, timeout=timeout)
    except (subprocess.TimeoutExpired, OSError) as exp:
        return _error(f"certificate parse error: {exp}")

    if x509.returncode != 0:
        return _error(f"openssl x509 failed: {x509.stderr.decode(errors='replace').strip()}")

    # openssl's key casing for the fingerprint line varies by version (e.g.
    # "SHA256 Fingerprint=" vs "sha256 Fingerprint="), so match case-insensitively.
    fields = {}
    for line in x509.stdout.decode(errors="replace").splitlines():
        key, _, value = line.partition("=")
        fields[key.strip().lower()] = value.strip()

    not_after_raw = fields.get("notafter")
    not_after = _parse_openssl_date(not_after_raw)

    days_until_expiry = None
    expired = None
    if not_after:
        delta = not_after - datetime.now(timezone.utc)
        days_until_expiry = delta.days
        expired = delta.total_seconds() < 0

    return {
        "host": host,
        "port": port,
        "not_before": fields.get("notbefore"),
        "not_after": not_after_raw,
        "expired": expired,
        "days_until_expiry": days_until_expiry,
        "subject": fields.get("subject"),
        "issuer": fields.get("issuer"),
        "fingerprint_sha256": fields.get("sha256 fingerprint"),
        "error": None,
    }


def get_ssh_fingerprint(host, port=22, timeout=5):
    """Retrieve a host's LIVE SSH host key fingerprint - outside Control-M, via ssh-keyscan + ssh-keygen.

    See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup.

    A read-only "banner grab": no authentication and no credentials touched -
    just what any SSH client sees before it ever offers credentials. Useful
    for catching host-key drift (e.g. a redeployed/reimaged agent host now
    presenting a different key than expected) the same way get_ssl_certificate
    catches cert drift/expiry - both are things Control-M's own connectivity
    tests can fail on without explaining why.

    :return: dict with keys: host, port, key_type, fingerprint_sha256, error (None on success)
    """
    def _error(message):
        return {"host": host, "port": port, "key_type": None, "fingerprint_sha256": None, "error": message}

    scan_cmd = ["ssh-keyscan", "-p", str(port), "-T", str(timeout), host]
    try:
        scan = subprocess.run(scan_cmd, capture_output=True, timeout=timeout + 2)
    except (subprocess.TimeoutExpired, OSError) as exp:
        return _error(f"ssh-keyscan error: {exp}")

    host_key_lines = [
        line for line in scan.stdout.decode(errors="replace").splitlines()
        if line and not line.startswith("#")
    ]
    if not host_key_lines:
        stderr_text = scan.stderr.decode(errors="replace").strip()
        return _error(f"no SSH host key received (ssh-keyscan: {stderr_text[:300] or 'no response'})")

    # ssh-keygen -lf needs a real file (a pipe/fd isn't reliably accepted across
    # platforms), so the scanned key is written to a temp file first.
    with tempfile.NamedTemporaryFile(mode="w", suffix=".pub") as tmp:
        tmp.write("\n".join(host_key_lines) + "\n")
        tmp.flush()
        try:
            fp = subprocess.run(["ssh-keygen", "-lf", tmp.name], capture_output=True, timeout=timeout)
        except (subprocess.TimeoutExpired, OSError) as exp:
            return _error(f"ssh-keygen error: {exp}")

    if fp.returncode != 0:
        return _error(f"ssh-keygen failed: {fp.stderr.decode(errors='replace').strip()}")

    # Output format: "<bits> SHA256:<fingerprint> <comment> (<key-type>)"
    first_line = fp.stdout.decode(errors="replace").strip().splitlines()[0]
    parts = first_line.split()
    fingerprint = next((p for p in parts if p.startswith("SHA256:")), None)
    key_type = parts[-1].strip("()") if parts else None

    return {"host": host, "port": port, "key_type": key_type, "fingerprint_sha256": fingerprint, "error": None}


def extract_url_endpoints(data):
    """Find every http(s):// URL value anywhere in a (possibly nested) dict/list, with host/port/scheme.

    See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup.

    Generalizes across BMC's ~160 connection profile types (see
    CCP_TYPES_REFERENCE.md) without needing to know each one's specific field
    name for its endpoint - most of them put it in a URL-shaped string
    somewhere (e.g. FileTransfer:Azure's "AzureEndpoint",
    "https://devAccount.blob.core.windows.net"), just under a different key
    per type, sometimes nested (SAP's is two levels down). Rather than
    maintaining a per-type key list, this scans every string value in the
    structure and picks out whichever look like URLs, wherever they live.

    Port comes from the URL itself if explicit (e.g. ":8443"), otherwise the
    scheme's standard default (443 for https, 80 for http) - not from
    DEFAULT_PORTS_BY_CCP_TYPE, which is keyed by CCP Type, not URL scheme.

    :return: list of dicts, one per URL found: {field_path, url, scheme, host, port}
    """
    results = []

    def walk(obj, path=""):
        if isinstance(obj, dict):
            for key, value in obj.items():
                walk(value, f"{path}.{key}" if path else key)
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                walk(item, f"{path}[{i}]")
        elif isinstance(obj, str):
            stripped = obj.strip()
            if stripped.startswith("http://") or stripped.startswith("https://"):
                parsed = urllib.parse.urlparse(stripped)
                if parsed.hostname:
                    port = parsed.port or (443 if parsed.scheme == "https" else 80)
                    results.append({
                        "field_path": path,
                        "url": stripped,
                        "scheme": parsed.scheme,
                        "host": parsed.hostname,
                        "port": port,
                    })

    walk(data)
    return results


class CtmApiError(Exception):
    """Raised when a Control-M Automation API call fails.

    Carries enough structure (method, url, status_code, message) for a caller
    to branch on the failure, rather than just a flattened string - e.g. a
    caller can check `exp.status_code is None` to distinguish a network/
    connection failure from an HTTP error response.
    """

    def __init__(self, method, url, status_code=None, message=None):
        self.method = method
        self.url = url
        self.status_code = status_code
        self.message = message or "no error message returned"
        status_label = status_code if status_code is not None else "no response"
        super().__init__(f"{method} {url} -> {status_label}: {self.message}")


def _extract_error_message(resp):
    """Pull the human-readable message out of a Control-M error response.

    The Automation API reports errors as either {"message": "..."} or
    {"errors": [{"message": "..."}, ...]}. Falls back to raw response text
    (truncated) when the body isn't JSON or doesn't match either shape.
    """
    try:
        body = resp.json()
    except ValueError:
        text = resp.text.strip() if resp.text else ""
        return text[:500] if text else f"HTTP {resp.status_code} with empty body"

    if isinstance(body, dict):
        if body.get("message"):
            return body["message"]
        errors = body.get("errors")
        if errors:
            return errors[0].get("message", str(errors[0]))

    return str(body)[:500]


def _walk_deployed_folder_jobs(node, parent="Root"):
    """Yield (job_dict, parent_name) for every Job across all nested SubFolders.

    Python port of ctm-preflight.ps1's Get-AllJobs/Get-AllNodes recursive walk,
    matching the shape get_deployed_jobs actually returns: {"Folders": [{"Jobs":
    [...], "SubFolders": [{"Jobs": [...], ...}, ...], ...}, ...]}.
    """
    if isinstance(node, list):
        for item in node:
            yield from _walk_deployed_folder_jobs(item, parent)
        return
    if not isinstance(node, dict):
        return

    name = node.get("Name", parent)

    for sub_folder in node.get("SubFolders", []) or []:
        yield from _walk_deployed_folder_jobs(sub_folder, sub_folder.get("Name", name))

    for job in node.get("Jobs", []) or []:
        yield job, name

    for key, value in node.items():
        if key in ("Jobs", "SubFolders", "Name", "Type"):
            continue
        if isinstance(value, (list, dict)):
            yield from _walk_deployed_folder_jobs(value, name)


def _rule_based_calendar_refs(when_block):
    """Names in a job's When.RuleBasedCalendars.Included that reference an external, shared calendar.

    Excludes the literal "USE PARENT" sentinel (inherit the folder's calendar -
    nothing to check) and any name that's also an inline sibling key in the
    same RuleBasedCalendars dict (a folder-private calendar definition,
    embedded right there - it can't go missing independently of the job
    itself). See CTM_ENGINEER.md, "Calendar existence".
    """
    if not when_block:
        return []
    rule_based = when_block.get("RuleBasedCalendars")
    if not isinstance(rule_based, dict):
        return []
    included = rule_based.get("Included") or []
    return [name for name in included if name != "USE PARENT" and name not in rule_based]


def _interpret_ccp_test_message(result):
    """Classify a test_centralized_connection_profile result as OK/ERROR/UNKNOWN from its message.

    Mirrors ctm-preflight.ps1's Test-CtmConnectionProfile: the Automation API
    returns HTTP 200 with a message either way (soft pass/fail, not a 4xx/5xx),
    so the message text itself is the only signal - a message starting with
    "error" is a failure, one containing "successfully" is a pass; anything
    else is UNKNOWN rather than guessed at.
    """
    message = (result or {}).get("message") or ""
    lower = message.strip().lower()
    if lower.startswith("error"):
        return "ERROR"
    if "successfully" in lower:
        return "OK"
    return "UNKNOWN"


class CtmClient:
    """Thin REST wrapper around the Control-M Automation API."""

    def __init__(self, base_url, api_key, server, verify_ssl=False, timeout=15):
        self.base_url = base_url.rstrip("/")
        self.server = server
        self.timeout = timeout

        self.session = requests.Session()
        self.session.headers.update({
            "x-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        })
        self.session.verify = verify_ssl
        if not verify_ssl:
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        # Per-client memoization, mirroring ctm-preflight.ps1's $cacheHostgroupAgent/
        # $cacheAgentTest/$cacheCcpTest/$cacheCcpProfile/$cacheNetEndpoint - a real
        # folder walk hits the same agent/hostgroup/CCP/network-endpoint repeatedly
        # (many jobs share one Host or one connection profile), and re-running an
        # agent test or a ping for each job is both slow and pointless once the
        # first result is known. Cleared by re-instantiating the client (each
        # build_client() call gets a fresh cache, same lifetime as a ps1 run) or
        # by calling clear_cache() explicitly.
        self._cache = {}

    def clear_cache(self):
        """Drop all memoized resolve_host/test_agent/CCP-test/CCP-profile/network-endpoint results."""
        self._cache = {}

    def _memoize(self, namespace, key, compute):
        """Return the cached value for (namespace, key), computing and storing it on a miss.

        :param namespace: str bucket name, e.g. "resolve_host" - keeps different
            kinds of cached calls from colliding even if their keys overlap.
        :param key: hashable key within that namespace (e.g. (server, host))
        :param compute: zero-arg callable producing the value on a cache miss
        """
        bucket = self._cache.setdefault(namespace, {})
        if key in bucket:
            return bucket[key]
        value = compute()
        bucket[key] = value
        return value

    def _request(self, method, path, quiet_statuses=(), **kwargs):
        """:param quiet_statuses: status codes to log at DEBUG instead of ERROR - for callers
        that treat a particular 4xx as an expected, handled outcome (e.g. resolve_host's
        hostgroup lookup, where a 404 just means "try the next branch," not a real problem).
        Still raises CtmApiError as normal either way - this only affects log severity.
        """
        url = f"{self.base_url}{path}"
        logger.debug("CTM API request: %s %s", method, url)

        try:
            resp = self.session.request(method, url, timeout=self.timeout, **kwargs)
        except requests.Timeout as exp:
            logger.error("CTM API timeout: %s %s (%ss)", method, url, self.timeout)
            raise CtmApiError(method, url, message=f"timed out after {self.timeout}s") from exp
        except requests.ConnectionError as exp:
            logger.error("CTM API connection error: %s %s (%s)", method, url, exp)
            raise CtmApiError(method, url, message=f"connection error: {exp}") from exp
        except requests.RequestException as exp:
            logger.error("CTM API request failed: %s %s (%s)", method, url, exp)
            raise CtmApiError(method, url, message=str(exp)) from exp

        logger.debug("CTM API response: %s %s -> %s %s", method, url, resp.status_code, resp.text[:1000])

        if resp.status_code >= 400:
            message = _extract_error_message(resp)
            log = logger.debug if resp.status_code in quiet_statuses else logger.error
            log("CTM API error: %s %s -> %s: %s", method, url, resp.status_code, message)
            raise CtmApiError(method, url, status_code=resp.status_code, message=message)

        return resp

    def _request_json(self, method, path, quiet_statuses=(), **kwargs):
        resp = self._request(method, path, quiet_statuses=quiet_statuses, **kwargs)
        if not resp.text:
            return None
        return resp.json()

    def get_servers(self):
        """GET /config/servers - names/hostnames of every Server in the system."""
        return self._request_json("GET", "/config/servers")

    def get_deployed_jobs(self, folder, server=None):
        """GET /deploy/jobs - every deployed job in a folder, all types, nested SubFolders included."""
        params = {
            "format": "json",
            "folder": folder,
            "server": server or self.server,
            "useArrayFormat": "true",
        }
        return self._request_json("GET", "/deploy/jobs", params=params)

    def get_deployed_calendars(self, name=None, server=None, calendar_type=None, alias=None):
        """GET /deploy/calendars - deployed calendar definitions matching the search criteria.

        Useful for checking whether a job's schedule holds up: a job's `When`
        block only references a Rule-Based Calendar by name in its
        RuleBasedCalendars.Included list (a literal "USE PARENT" there just
        means "inherit the folder's calendar," not a real calendar name) -
        this confirms that named calendar is actually deployed on the
        server, the same way resolve_host confirms a Host reference is real.
        404s (via CtmApiError) when nothing matches.

        :param calendar_type: one of "Regular", "Periodic", "RuleBasedCalendar"
        """
        server = server or self.server
        params = {"server": server}
        if name:
            params["name"] = name
        if calendar_type:
            params["type"] = calendar_type
        if alias:
            params["alias"] = alias
        return self._request_json("GET", "/deploy/calendars", params=params)

    def get_host_restrictions(self, server=None):
        """GET /config/server/{server}/hostRestrictions - per-agent max concurrent jobs / max CPU% limits.

        Response items look like {"nodePrefix": <agent>, "maxJobsAllowed": <str, "UNLIMITED" or a count>,
        "maxCPUPct": <str, "UNLIMITED" or a percentage>} - matches Control-M's own
        Configuration > Agents > "Agent (Host) Restrictions" screen.
        """
        server = server or self.server
        return self._request_json("GET", f"/config/server/{server}/hostRestrictions")

    def get_hostgroup_agents(self, hostgroup, server=None, quiet_statuses=()):
        """GET /config/server/{server}/hostgroup/{hostgroup}/agents - resolve a Host Group to its member agents.

        :param quiet_statuses: see CtmClient._request - resolve_host passes
            (404,) here since a 404 just means "not a hostgroup, try agent
            next," not a real problem worth an ERROR-level log line.
        """
        server = server or self.server
        return self._request_json(
            "GET", f"/config/server/{server}/hostgroup/{hostgroup}/agents", quiet_statuses=quiet_statuses,
        )

    def get_agents(self, server=None, agent=None):
        """GET /config/server/{server}/agents - agents known to the server, optionally filtered to one name.

        Note: filtering by a name that isn't a real, already-discovered agent
        does NOT 404 - the API returns a bare 3-key placeholder instead
        ({"nodeid", "status": "Discovering", "type"}, nothing else). Don't use
        status to decide whether a match is real (see resolve_host): a
        genuine agent or agentless host can ALSO report "Discovering" - e.g.
        an agentless host briefly shows it too when the real agent behind it
        is down, since Control-M can't verify connectivity through a dead
        agent. The reliable signal is whether the entry carries the extra
        metadata (tag/hostgroups/operatingSystem/...) real entries always
        have, placeholders never do.
        """
        server = server or self.server
        params = {"agent": agent} if agent else None
        result = self._request_json("GET", f"/config/server/{server}/agents", params=params)
        return result.get("agents", []) if result else []

    def get_agentless_host(self, agentlesshost, server=None):
        """GET /config/server/{server}/agentlesshost/{agentlesshost} - a single agentless/remote host's config."""
        server = server or self.server
        return self._request_json("GET", f"/config/server/{server}/agentlesshost/{agentlesshost}")

    def test_agentless_host(self, agentlesshost, server=None):
        """POST /config/server/{server}/agentlesshost/{agentlesshost}/test - test agentless host connectivity."""
        server = server or self.server
        path = f"/config/server/{server}/agentlesshost/{agentlesshost}/test"
        return self._request_json("POST", path, json={"parameters": []})

    def resolve_host(self, host, server=None):
        """Resolve a job's Host field to the real agent(s) that would actually run it.

        The deployed-job JSON only ever shows Host as a plain string - nothing
        distinguishes a hostgroup, a literal agent name, or an agentless/
        remote host (a Control-M admin can point a job's Host at any of the
        three). Try the hostgroup lookup first since that's the common case;
        a 404 there means the name isn't a hostgroup, so fall back to
        get_agents(agent=host) to see whether it's a registered agent or an
        agentless host instead. Any other error (auth, connection, wrong
        server, etc.) is returned as-is rather than masked by a further
        doomed-to-fail lookup.

        An agentless host is NOT itself testable via test_agent - only the
        real agent(s) behind it are (see the "Associated Agents" field in
        Control-M's own Agentless Host config screen). get_agents(agent=host)
        is only used here to classify the name (hostgroup/agent/agentless
        host all show up in it); once it's identified as an agentless host,
        the connecting agent(s) are fetched from get_agentless_host(), the
        endpoint actually dedicated to that config, rather than trusting
        get_agents' own associatedAgents summary field.

        get_agents(agent=host) is used for classification rather than a
        per-agent lookup because an unrecognized name there comes back as a
        200 with a placeholder rather than a 404 - see get_agents' docstring.
        Note this checks for that placeholder's shape (a bare 3-key entry),
        NOT status == "Discovering" - a real agent or agentless host can
        legitimately report "Discovering" too (e.g. an agentless host whose
        backing agent just went down), and that must still resolve, not be
        mistaken for an unknown name.

        Memoized per (server, host) - see CtmClient's cache docstring in __init__.

        :return: dict with keys:
            host_type - "hostgroup", "agent", "agentless_host", or None if nothing resolved
            agents - list of real agent hostnames backing this host (never the agentless host's own name)
            error - None on success, else a message explaining the failure
        """
        server = server or self.server

        def _compute():
            try:
                members = self.get_hostgroup_agents(hostgroup=host, server=server, quiet_statuses=(404,))
                agents = [entry["host"] for entry in members] if members else []
                if agents:
                    return {"host_type": "hostgroup", "agents": agents, "error": None}
                return {"host_type": None, "agents": [], "error": f"hostgroup '{host}' has no member agents"}
            except CtmApiError as hostgroup_exp:
                if hostgroup_exp.status_code != 404:
                    return {"host_type": None, "agents": [], "error": f"hostgroup lookup failed: {hostgroup_exp.message}"}

            try:
                matches = self.get_agents(agent=host, server=server)
            except CtmApiError as agent_exp:
                return {"host_type": None, "agents": [], "error": f"agent lookup failed: {agent_exp.message}"}

            match = next((entry for entry in matches if entry.get("nodeid", "").lower() == host.lower()), None)
            # A placeholder for an unknown name is exactly {nodeid, status, type} - nothing more.
            if match is not None and len(match) > 3:
                if match.get("type") == "Agentless Host":
                    try:
                        profile = self.get_agentless_host(agentlesshost=host, server=server)
                    except CtmApiError as agentless_exp:
                        return {"host_type": None, "agents": [], "error": f"agentless host lookup failed: {agentless_exp.message}"}
                    connecting_agents = (profile.get("agents") or []) if profile else []
                    if connecting_agents:
                        return {"host_type": "agentless_host", "agents": connecting_agents, "error": None}
                    return {"host_type": None, "agents": [], "error": f"agentless host '{host}' has no connecting agents"}
                return {"host_type": "agent", "agents": [host], "error": None}

            return {
                "host_type": None,
                "agents": [],
                "error": f"'{host}' is neither a valid hostgroup, a registered agent, nor an agentless host",
            }

        return self._memoize("resolve_host", (server, host), _compute)

    def test_agent(self, agent, server=None):
        """POST /config/server/{server}/agent/{agent}/test - Control-M's 'Test Availability' action.

        Memoized per (server, agent) - the same agent backs many jobs in a
        real folder, and there's no reason to re-test it for each one.
        """
        server = server or self.server
        return self._memoize(
            "test_agent", (server, agent),
            lambda: self._request_json("POST", f"/config/server/{server}/agent/{agent}/test", json={"parameters": []}),
        )

    def get_agent_crt_expiration(self, agent, server=None):
        """GET /config/server/{server}/agent/{agent}/crt/expiration - the agent's certificate expiration."""
        server = server or self.server
        return self._request_json("GET", f"/config/server/{server}/agent/{agent}/crt/expiration")

    def get_agent_params(self, agent, server=None, extended_data=True):
        """GET /config/server/{server}/agent/{agent}/params - all parameters of the specified agent."""
        server = server or self.server
        params = {"extendedData": "true" if extended_data else "false"}
        return self._request_json("GET", f"/config/server/{server}/agent/{agent}/params", params=params)

    def get_centralized_connection_profile(self, name, ccp_type="FileTransfer"):
        """GET /deploy/connectionprofiles/centralized - live HostName/Port/Type for a centralized connection profile."""
        params = {"type": ccp_type, "name": name}
        return self._request_json("GET", "/deploy/connectionprofiles/centralized", params=params)

    def test_centralized_connection_profile(self, ccp_type, name, agent, server=None):
        """POST /deploy/connectionprofile/centralized/test/{type}/{name}/{server}/{agent} - authoritative CCP test.

        Memoized per (ccp_type, name, agent, server) - deliberately keyed on
        the (CCP, agent) pair, not just the CCP name: some connection profiles
        only work from a specific agent, so the same CCP tested against a
        different agent is a genuinely different result, not a cache hit.
        """
        server = server or self.server
        path = f"/deploy/connectionprofile/centralized/test/{ccp_type}/{name}/{server}/{agent}"
        return self._memoize(
            "test_centralized_connection_profile", (ccp_type, name, agent, server),
            lambda: self._request_json("POST", path),
        )

    def resolve_connection_profile_endpoint(self, name, ccp_type="FileTransfer"):
        """Resolve a centralized connection profile's live host/port/Type.

        See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup.

        Python port of ctm-preflight.ps1's Get-CtmConnectionProfile, generalized
        beyond FileTransfer/SFTP: FileTransfer-family profiles key their host as
        "HostName" (e.g. SFTP), Database-family profiles key it as "Host" (e.g.
        PostgreSQL) - both are checked. SDK/API-based profiles (S3, GCS, Azure
        Blob, etc.) have neither key at all - they authenticate purely through
        the cloud provider's API using stored keys/tokens, so there is no
        literal host:port for them to resolve; host_name comes back None for
        those, which callers (see test_connection_profile_network) treat as
        "nothing to network-test," not an error.

        Port is only present on the profile when it differs from the type's
        default - absent means "use the default," so callers needing a port
        must supply their own fallback (see DEFAULT_PORTS_BY_CCP_TYPE below).

        Only "HostName" and "Host" are checked. BMC has ~160 centralized
        connection profile types (see CCP_TYPES_REFERENCE.md for the full
        catalog) and each can use its own field name/shape for the endpoint -
        e.g. RabbitMQ's is "RabbitMQ URL" (needs the scheme stripped), SAP's
        is nested two levels down ("ApplicationServerLogon": {"Host": ...}),
        and most (AWS/Azure/GCP-family types) have no literal endpoint at
        all. Don't add more key names here without a real CCP JSON sample
        confirming the actual field name; every key/default in this module
        was verified against a live profile, not guessed from documentation.

        Memoized per (name, ccp_type) - a connection profile's own definition
        doesn't depend on which agent is asking, so once resolved it's reused
        for every job that references the same CCP.

        :return: dict with keys: host_name, port (None if not explicitly set), type, error (None on success)
        """
        def _compute():
            try:
                profile = self.get_centralized_connection_profile(name=name, ccp_type=ccp_type)
            except CtmApiError as exp:
                return {"host_name": None, "port": None, "type": None, "error": f"CCP lookup failed: {exp.message}"}

            entry = (profile or {}).get(name)
            if entry is None:
                return {"host_name": None, "port": None, "type": None, "error": f"CCP response did not contain expected key '{name}'"}

            port = entry.get("Port")
            return {
                "host_name": entry.get("HostName") or entry.get("Host"),
                "port": int(port) if port else None,
                "type": entry.get("Type"),
                "error": None,
            }

        return self._memoize("resolve_connection_profile_endpoint", (name, ccp_type), _compute)

    def test_connection_profile_network(self, name, ccp_type="FileTransfer", default_port=None):
        """Non-intrusive, outside-of-Control-M network test for a connection profile's real endpoint.

        See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup.

        Resolves the profile's live host/port via the CCP endpoint (not job
        Variables) and runs test_network_endpoint (ping + TCP connect only -
        no protocol handshake, no credentials, since those are Control-M's to
        manage, not ours) against it. Works for any profile type that resolves
        to a literal host - MFT/SFTP and Database profiles, mainly - and
        cleanly SKIPS (not an error) profile types that have no literal
        host:port to test at all, like SDK/API-based cloud storage profiles
        (S3, GCS, Azure Blob). This is a GLOBAL CHECK from THIS machine, not
        the Control-M agent - see test_network_endpoint's docstring.

        Also memoized per (host, port) for the actual ping/TCP check - the
        same server is frequently reached via more than one connection
        profile (or the same profile shared by many jobs), and there's no
        reason to ping it again once its reachability is already known.

        :param default_port: explicit fallback port; if None, falls back to
            DEFAULT_PORTS_BY_CCP_TYPE matched against the profile's Type string.
        :return: dict with keys: skipped (bool), reason (str, only if skipped),
            and on a non-skipped result, everything test_network_endpoint returns
        """
        resolved = self.resolve_connection_profile_endpoint(name=name, ccp_type=ccp_type)
        if resolved["error"]:
            return {"skipped": True, "reason": resolved["error"]}
        if not resolved["host_name"]:
            return {"skipped": True, "reason": f"profile type '{resolved['type']}' has no literal host/port to test (local, or API/SDK-based connection profile)"}

        port = resolved["port"] or default_port or _default_port_for_ccp_type(resolved["type"])
        if not port:
            return {"skipped": True, "reason": f"no port specified on profile and no known default for type '{resolved['type']}'"}

        result = dict(self._memoize(
            "test_network_endpoint", (resolved["host_name"], port),
            lambda: test_network_endpoint(host=resolved["host_name"], port=port),
        ))
        result["skipped"] = False
        result["port_is_default"] = resolved["port"] is None
        return result

    def get_connection_profile_ssh_fingerprint(self, name, ccp_type="FileTransfer"):
        """Outside-of-Control-M SSH host key fingerprint for a connection profile's real endpoint.

        Resolves the profile's live host/port via the CCP endpoint (same
        resolution as test_connection_profile_network) and runs
        get_ssh_fingerprint against it - critically, using whatever port the
        CCP itself reports, NOT a hardcoded 22. An OS-level SSH daemon (port
        22) and an MFTE SFTP listener (whatever port the CCP specifies, e.g.
        1222) are genuinely different services with different host keys -
        fingerprinting port 22 when the profile actually uses 1222 silently
        checks the wrong thing.

        Only meaningful for SFTP/SSH-family connection profiles - Database
        profiles, SDK/API-based cloud profiles (S3, GCS, Azure Blob), and
        Local profiles have no SSH host key to fingerprint, so this SKIPS
        (not an error) for anything that isn't SFTP-typed.

        If the CCP has no explicit Port, falls back to SFTP's standard
        protocol default (22, via DEFAULT_PORTS_BY_CCP_TYPE) - same as
        test_connection_profile_network's default_port fallback. Note this
        may still be wrong for a profile actually pointed at BMC's MFTE file
        transfer service, whose SFTP listener commonly defaults to 1222
        instead - there is no way to tell the two apart from the CCP's Type
        alone when Port is absent.

        Also memoized per (host, port) for the actual fingerprint lookup -
        see test_connection_profile_network's caching note.

        :return: dict with keys: skipped (bool), reason (str, only if skipped),
            and on a non-skipped result, everything get_ssh_fingerprint returns
        """
        resolved = self.resolve_connection_profile_endpoint(name=name, ccp_type=ccp_type)
        if resolved["error"]:
            return {"skipped": True, "reason": resolved["error"]}
        if not resolved["host_name"]:
            return {"skipped": True, "reason": f"profile type '{resolved['type']}' has no literal host/port to test (local, or API/SDK-based connection profile)"}
        if not resolved["type"] or "SFTP" not in resolved["type"]:
            return {"skipped": True, "reason": f"profile type '{resolved['type']}' is not SSH/SFTP-based - no SSH host key to fingerprint"}

        port = resolved["port"] or _default_port_for_ccp_type(resolved["type"])
        result = dict(self._memoize(
            "get_ssh_fingerprint", (resolved["host_name"], port),
            lambda: get_ssh_fingerprint(host=resolved["host_name"], port=port),
        ))
        result["skipped"] = False
        result["port_is_default"] = resolved["port"] is None
        return result

    def test_connection_profile_https_endpoints(self, name, ccp_type="FileTransfer"):
        """Find and test every http(s) URL embedded anywhere in a connection profile.

        See CTM_ENGINEER.md, "Outside-of-Control-M tests", for the full writeup.

        Generalizes well beyond FileTransfer/SFTP and Database: rather than
        needing a per-type key name (~160 different ones across BMC's plugin
        catalog - see CCP_TYPES_REFERENCE.md), this fetches the raw profile
        and runs extract_url_endpoints on it to find every URL-shaped value,
        wherever it lives in the profile (including nested, e.g. SAP's).
        Each URL found gets test_network_endpoint (ping + TCP connect), plus
        get_ssl_certificate for https ones - reading the real, live cert the
        same way get_ssl_certificate always does. No credentials are used.

        Also memoized per (host, port) for both the network check and the SSL
        certificate read - see test_connection_profile_network's caching note.

        :return: dict with keys: error (str or None), endpoints (list of dicts,
            each extract_url_endpoints' fields plus "network" and "ssl" - ssl
            is None for http:// URLs)
        """
        try:
            profile = self.get_centralized_connection_profile(name=name, ccp_type=ccp_type)
        except CtmApiError as exp:
            return {"error": f"CCP lookup failed: {exp.message}", "endpoints": []}

        entry = (profile or {}).get(name)
        if entry is None:
            return {"error": f"CCP response did not contain expected key '{name}'", "endpoints": []}

        found = extract_url_endpoints(entry)
        results = []
        for ep in found:
            network = self._memoize(
                "test_network_endpoint", (ep["host"], ep["port"]),
                lambda ep=ep: test_network_endpoint(host=ep["host"], port=ep["port"]),
            )
            ssl = self._memoize(
                "get_ssl_certificate", (ep["host"], ep["port"]),
                lambda ep=ep: get_ssl_certificate(host=ep["host"], port=ep["port"]),
            ) if ep["scheme"] == "https" else None
            results.append({**ep, "network": network, "ssl": ssl})

        return {"error": None, "endpoints": results}

    def run_preflight(self, folder, server=None):
        """Walk every job in a deployed folder and run the checks this module already knows how to do.

        The Python equivalent of ctm-preflight.ps1's whole run: fetch the
        folder (get_deployed_jobs), walk every job across all nested
        SubFolders (_walk_deployed_folder_jobs), and for each one:
          - resolve its Host (resolve_host) and test_agent every resolved agent
          - for FileTransfer jobs, test ConnectionProfileSrc/Dest; for
            Database jobs, test ConnectionProfile - against every resolved agent
          - confirm any externally-referenced RuleBasedCalendar exists
            (get_deployed_calendars, via _rule_based_calendar_refs)
        Nothing is ordered, held, or modified - every call here is a read or
        a built-in test/diagnostic operation, same as the PS1 script.

        :return: dict with keys:
            folder, server, error (str or None - only set if the initial
            folder fetch itself failed, in which case jobs is empty),
            jobs (list of per-job dicts - see _check_preflight_job)
        """
        server = server or self.server
        try:
            folder_data = self.get_deployed_jobs(folder=folder, server=server)
        except CtmApiError as exp:
            return {"folder": folder, "server": server, "error": f"failed to fetch folder: {exp.message}", "jobs": []}

        jobs = [
            self._check_preflight_job(job, parent, server)
            for job, parent in _walk_deployed_folder_jobs(folder_data)
        ]
        return {"folder": folder, "server": server, "error": None, "jobs": jobs}

    def _check_preflight_job(self, job, parent, server):
        """Run every applicable check against a single job dict from get_deployed_jobs. See run_preflight."""
        job_type_raw = job.get("Type", "")
        result = {
            "job": job.get("Name"),
            "parent": parent,
            "type": job_type_raw.replace("Job:", ""),
            "host": job.get("Host"),
            "host_resolution": None,
            "agent_status": "SKIPPED",
            "agent_tests": {},
            "connection_profiles": {},
            "calendars": {},
        }

        agents = []
        if result["host"]:
            resolved = self.resolve_host(result["host"], server=server)
            result["host_resolution"] = resolved
            agents = resolved.get("agents") or []
            if not agents:
                result["agent_status"] = "ERROR"
            else:
                for agent in agents:
                    try:
                        test_result = self.test_agent(agent, server=server)
                        result["agent_tests"][agent] = {"ok": True, "result": test_result}
                    except CtmApiError as exp:
                        result["agent_tests"][agent] = {"ok": False, "error": exp.message}
                agent_oks = [entry["ok"] for entry in result["agent_tests"].values()]
                result["agent_status"] = "OK" if all(agent_oks) else "ERROR"

        ccp_type = "Database" if job_type_raw.startswith("Job:Database") else "FileTransfer"
        ccp_fields = {}
        if job.get("ConnectionProfileSrc"):
            ccp_fields["Src"] = job["ConnectionProfileSrc"]
        if job.get("ConnectionProfileDest"):
            ccp_fields["Dest"] = job["ConnectionProfileDest"]
        if job.get("ConnectionProfile"):
            ccp_fields["ConnectionProfile"] = job["ConnectionProfile"]

        for label, ccp_name in ccp_fields.items():
            tests = {}
            for agent in agents:
                try:
                    test_result = self.test_centralized_connection_profile(ccp_type, ccp_name, agent, server=server)
                    tests[agent] = {"status": _interpret_ccp_test_message(test_result), "result": test_result}
                except CtmApiError as exp:
                    tests[agent] = {"status": "ERROR", "error": exp.message}
            result["connection_profiles"][label] = {"name": ccp_name, "ccp_type": ccp_type, "tests": tests}

        for calendar_name in _rule_based_calendar_refs(job.get("When")):
            try:
                calendar = self.get_deployed_calendars(name=calendar_name, server=server, calendar_type="RuleBasedCalendar")
                result["calendars"][calendar_name] = {"ok": True, "result": calendar}
            except CtmApiError as exp:
                result["calendars"][calendar_name] = {"ok": False, "error": exp.message}

        return result


def load_config(env_file=DEFAULT_ENV_FILE):
    env_path = Path(env_file)
    if not env_path.is_file():
        raise FileNotFoundError(f"Could not find .env file at: {env_path}")

    config = dotenv_values(env_path)
    missing = [key for key in REQUIRED_KEYS if not config.get(key)]
    if missing:
        raise ValueError(f"Missing required key(s) {missing} in {env_path}")

    return config


def build_client(env_file=DEFAULT_ENV_FILE):
    config = load_config(env_file)
    return CtmClient(base_url=config["baseUrl"], api_key=config["apiKey"], server=config["CTM_SERVER"])


def _classify_preflight_failures(jobs):
    """Split run_preflight's job list into agent/connection-profile/calendar failure subsets."""
    agent_failures = [j for j in jobs if j["agent_status"] == "ERROR"]
    ccp_failures = [
        j for j in jobs
        if any(t["status"] == "ERROR" for cp in j["connection_profiles"].values() for t in cp["tests"].values())
    ]
    calendar_failures = [j for j in jobs if any(not c["ok"] for c in j["calendars"].values())]
    return agent_failures, ccp_failures, calendar_failures


_ANSI_RESET = "\033[0m"
_ANSI_RGB = {
    # Explicit 24-bit RGB escapes rather than basic ANSI color names - same
    # reasoning as ctm-preflight.ps1's Write-Badge/Write-ColorText: some
    # terminals (confirmed: Terminus) remap the basic 16-color palette in
    # ways that flatten red/green/yellow toward the same hue, while true RGB
    # escapes render correctly.
    "red": "220;0;0",
    "green": "0;200;0",
    "yellow": "230;180;0",
    "purple": "170;0;220",
    "light_blue": "80;170;255",
}
_STATUS_COLOR = {"OK": "green", "ERROR": "red", "SKIPPED": "yellow", "UNKNOWN": "yellow"}


def _colorize(text, color, enabled):
    """Wrap text in an ANSI color escape - a no-op unless enabled (see _color_enabled)."""
    if not enabled or color not in _ANSI_RGB:
        return text
    return f"\033[38;2;{_ANSI_RGB[color]}m{text}{_ANSI_RESET}"


def _color_enabled():
    """Only color when stdout is a real terminal - never inject escape codes into redirected/piped output."""
    return sys.stdout.isatty()


def _print_preflight_report(folder, result, agent_failures, ccp_failures, calendar_failures, report_path):
    """Human-readable console report for `--output verbose` (the default) - printed to stdout.

    Deliberately plain print(), not logger.info: logger's console handler
    writes to stderr (see configure_logging), so this stays out of its way
    and out of the way of `--output json`/`file`'s piping-friendly stdout.

    Color-codes status (green=OK, red=ERROR, yellow=SKIPPED/UNKNOWN) when
    stdout is a real terminal - see _color_enabled/_colorize.
    """
    color = _color_enabled()
    jobs = result["jobs"]
    print(f"=== CTM Preflight Check: '{folder}' on '{result['server']}' ===")
    print(f"Total jobs: {len(jobs)}\n")

    row = "{:<32} {:<16} {:<18} {}"
    print(row.format("Job", "Type", "Host", "Agents"))
    for job in jobs:
        status = _colorize(job["agent_status"], _STATUS_COLOR.get(job["agent_status"], "yellow"), color)
        print(row.format(job["job"][:32], job["type"][:16], (job["host"] or "-")[:18], status))

    def _count_line(label, count):
        return f"{label}: {_colorize(count, 'red' if count else 'green', color)}"

    print()
    print(_count_line("Agent failures", len(agent_failures)))
    print(_count_line("Connection-profile failures", len(ccp_failures)))
    print(_count_line("Calendar failures", len(calendar_failures)))

    if agent_failures:
        print("\nAgent failures:")
        for job in agent_failures:
            print(_colorize(f"  - {job['job']} (Host: {job['host']})", "red", color))

    if ccp_failures:
        print("\nConnection-profile failures:")
        for job in ccp_failures:
            for label, cp in job["connection_profiles"].items():
                for agent, test in cp["tests"].items():
                    if test["status"] == "ERROR":
                        message = test.get("error") or (test.get("result") or {}).get("message")
                        print(_colorize(f"  - {job['job']} {label} ({cp['name']} on {agent}): {message}", "red", color))

    if calendar_failures:
        print("\nCalendar failures:")
        for job in calendar_failures:
            for calendar_name, entry in job["calendars"].items():
                if not entry["ok"]:
                    print(_colorize(f"  - {job['job']} calendar '{calendar_name}': {entry['error']}", "red", color))

    print(f"\nJSON report: {report_path}")


def _run_preflight_cli(client, folder, log_folder, output="verbose"):
    """CLI entry point for `--folder`: run run_preflight, report the result, write a JSON report.

    `output` mirrors ctm-preflight.ps1's -Output parameter:
      verbose (default) - full human-readable console report (see _print_preflight_report)
      json    - prints only the JSON report content to stdout - nothing else
      file    - prints only the path to the JSON report file - nothing else
    The JSON report file is always written to log_folder regardless of this setting.

    Exit code is 1 if any job has an agent or connection-profile failure (or
    the initial folder fetch itself failed), else 0 - matching ctm-preflight.ps1.
    Calendar failures are reported but don't affect the exit code, same
    reasoning as the PS1 script's network-test failures: informational, not gating.
    """
    result = client.run_preflight(folder)
    if result["error"]:
        logger.error("Preflight check failed: %s", result["error"])
        return 1

    jobs = result["jobs"]
    agent_failures, ccp_failures, calendar_failures = _classify_preflight_failures(jobs)

    logger.debug(
        "Folder '%s': %d job(s) - agent failures: %d, connection-profile failures: %d, calendar failures: %d",
        folder, len(jobs), len(agent_failures), len(ccp_failures), len(calendar_failures),
    )

    log_folder.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = log_folder / f"ctm_preflight_{folder}_{timestamp}.json"
    report_json = json.dumps(result, indent=2, default=str)
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report_json)

    if output == "json":
        print(report_json)
    elif output == "file":
        print(report_path)
    else:
        _print_preflight_report(folder, result, agent_failures, ccp_failures, calendar_failures, report_path)

    return 1 if (agent_failures or ccp_failures) else 0


def main():
    parser = argparse.ArgumentParser(description="Control-M Automation API - connectivity check / folder preflight check")
    parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE), help="Path to .env file (default: %(default)s)")
    parser.add_argument(
        "-f", "--folder", default=None,
        help="Run the full preflight check against this Control-M folder (e.g. ZZM_UC_MULTIPATH_CLOUD). "
             "Without this, just runs a basic connectivity check.",
    )
    parser.add_argument(
        "--output", choices=("verbose", "json", "file"), default="verbose",
        help="Only used with --folder. verbose (default): human-readable console report. "
             "json: print only the JSON report content. file: print only the JSON report's path. "
             "The JSON report file is always written to LOG_FOLDER regardless of this setting.",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true",
        help="Enable debug-level logging, tracing every API URL and its response "
             "(a log file is always written to .engineer/logs regardless of this flag)",
    )
    args = parser.parse_args()

    # Peek LOG_FOLDER from the .env before full config validation, so a custom
    # log location (matching ctm-preflight.ps1's optional LOG_FOLDER key) is
    # honored even if the rest of the .env turns out to be invalid.
    log_folder = DEFAULT_LOG_FOLDER
    env_values = dotenv_values(args.env_file)
    log_folder_value = env_values.get("LOG_FOLDER")
    if log_folder_value:
        candidate = Path(log_folder_value)
        log_folder = candidate if candidate.is_absolute() else SCRIPT_DIR / candidate

    configure_logging(verbose=args.verbose, log_folder=log_folder)

    try:
        client = build_client(args.env_file)
    except (FileNotFoundError, ValueError) as exp:
        logger.error(str(exp))
        return 1

    if args.folder:
        return _run_preflight_cli(client, args.folder, log_folder, output=args.output)

    logger.info("Testing connectivity to %s (server=%s)", client.base_url, client.server)
    try:
        servers = client.get_servers()
    except CtmApiError as exp:
        logger.error("Connectivity test failed: %s", exp)
        return 1

    count = len(servers) if isinstance(servers, list) else 1
    logger.info("Connectivity OK - %d server(s) visible", count)
    print(json.dumps(servers, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
