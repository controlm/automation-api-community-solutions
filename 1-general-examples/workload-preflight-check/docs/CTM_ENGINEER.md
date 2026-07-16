# ctm_engineer.py

A Python port of the same idea behind `ctm-preflight.ps1` (see the [project README](../README.md) for the "why"). Both a full CLI tool (`--folder`) and a reusable client module for importing into other scripts/notebooks.

Talks to the Automation API directly via `requests` (no `controlm_py` SDK — see the project README for why that's a deliberate choice here), so all three implementations (this, the PowerShell script, and the Postman collection) hit the exact same endpoints.

## Installation

```bash
pip install -r requirements-engineer.txt
```

## Configuration

Reads `.engineer/config/.env` next to the script by default (a `.env.sample` is provided), same format as `ctm-preflight.ps1`:

```dotenv
baseUrl=https://your-ctm-em/automation-api
apiKey=your-api-key
CTM_SERVER=ctm-lin-srv
LOG_FOLDER=.engineer/logs   # optional, defaults shown
```

## Usage

Without `--folder`, the CLI just runs a basic connectivity check (`GET /config/servers`):

```bash
python ctm_engineer.py            # basic connectivity check (always logs to .engineer/logs too)
python ctm_engineer.py -v         # also traces every API URL and its response, in the console and that log file
python ctm_engineer.py --env-file /path/to/other.env
```

With `--folder` (or its shorthand `-f`), it runs the full preflight check against that Control-M folder:

```bash
python ctm_engineer.py --folder ZZM_UC_MULTIPATH_CLOUD
python ctm_engineer.py -f ZZM_UC_MULTIPATH_CLOUD
```

This walks every job across all nested SubFolders and, for each one: resolves its `Host` and tests every resolved agent, tests `ConnectionProfileSrc`/`ConnectionProfileDest` (FileTransfer jobs) or `ConnectionProfile` (Database jobs) against every resolved agent, and confirms any externally-referenced `RuleBasedCalendar` actually exists. Nothing is ordered, held, or modified — every call is a read or a built-in test/diagnostic operation, same as `ctm-preflight.ps1`.

### Output modes

`--output` mirrors `ctm-preflight.ps1`'s `-Output` parameter — controls what's printed to stdout. The JSON report file is **always** written to `LOG_FOLDER`, in every mode.

| Mode | Behavior |
| --- | --- |
| `verbose` (default) | Human-readable console report: per-job table, failure counts, then each failure's detail, then the JSON report path. Color-coded (green=OK, red=ERROR, yellow=SKIPPED/UNKNOWN) when stdout is a real terminal. |
| `json` | Prints only the JSON report content to stdout — nothing else. Useful for piping into `jq` or another tool. |
| `file` | Prints only the path to the JSON report file — nothing else. |

```bash
python ctm_engineer.py --folder ZZM_UC_MULTIPATH_CLOUD --output json | jq '.jobs[] | select(.agent_status == "ERROR")'
python ctm_engineer.py --folder ZZM_UC_MULTIPATH_CLOUD --output file
```

Color is auto-detected via `sys.stdout.isatty()` (see `_color_enabled`) — redirecting or piping `verbose` output (e.g. `> report.txt`) automatically turns it off, so files never end up with raw escape codes. Uses explicit 24-bit RGB ANSI escapes rather than the basic named colors, same reasoning as `ctm-preflight.ps1`'s `Write-Badge`/`Write-ColorText`: some terminals remap the basic 16-color palette in ways that flatten red/green/yellow toward the same hue.

Console/log messages (`logger.info`/`.error`/`.debug`) go to **stderr**, not stdout (see `configure_logging`) — that's what keeps `--output json`/`file` pipeable even without needing to suppress anything.

A JSON report is always written to `{LOG_FOLDER}/ctm_preflight_{folder}_{yyyyMMdd_HHmmss}.json` (same naming as the PS1 script), regardless of `-v` or `--output`. Exit code is `1` if any job has an agent or connection-profile failure (or the initial folder fetch itself failed), else `0` — calendar failures are reported but don't affect the exit code, since a broken external calendar reference doesn't itself indicate a resource is unreachable the way an agent/CCP failure does.

The underlying client is just as importable for other scripts/notebooks:

```python
from ctm_engineer import build_client, CtmApiError

client = build_client()  # reads .engineer/config/.env
servers = client.get_servers()
result = client.run_preflight("ZZM_UC_MULTIPATH_CLOUD")  # same walk the CLI runs
```

## What's in `CtmClient`

| Method | Purpose |
| --- | --- |
| `get_servers()` | Every Control-M/Server visible to this Automation API endpoint. |
| `get_deployed_jobs(folder, server=None)` | Every deployed job in a folder, all types, nested SubFolders included. |
| `get_hostgroup_agents(hostgroup, server=None)` | Resolve a Host Group to its member agents. |
| `get_agents(server=None, agent=None)` | Agents known to the server, optionally filtered to one name. |
| `resolve_host(host, server=None)` | The composite: resolves a job's `Host` field to the real agent(s) that would run it, regardless of whether it's a Host Group, a bare agent name, or an Agentless Host (see below). |
| `test_agent(agent, server=None)` | Control-M's own "Test Availability" action for an agent. |
| `get_agent_crt_expiration(agent, server=None)` | An agent's certificate expiration date. |
| `get_agent_params(agent, server=None, extended_data=True)` | All configuration parameters of an agent. |
| `get_agentless_host(agentlesshost, server=None)` | An Agentless Host's connection config (remote host, port, connection type, associated agents). |
| `test_agentless_host(agentlesshost, server=None)` | Control-M's own connectivity test for an Agentless Host. |
| `get_host_restrictions(server=None)` | Per-agent max-concurrent-jobs / max-CPU% limits (Control-M's "Agent (Host) Restrictions"). |
| `get_deployed_calendars(name=None, server=None, calendar_type=None, alias=None)` | Deployed calendar definitions matching a search — confirms a job's `RuleBasedCalendars` reference is real (see caveat below). |
| `get_centralized_connection_profile(name, ccp_type="FileTransfer")` | A centralized connection profile's live config (host, port, type, ...). |
| `test_centralized_connection_profile(ccp_type, name, agent, server=None)` | Control-M's own authoritative connection-profile test. |
| `run_preflight(folder, server=None)` | The composite: walks every job in a deployed folder (all nested SubFolders) and runs `resolve_host` + `test_agent` + connection-profile tests + calendar-existence checks against each one. What the `--folder` CLI flag runs. |

### `resolve_host` — Host Group vs. bare agent vs. Agentless Host

A job's `Host` field is always just a plain string — nothing in the deployed-job JSON says whether it's a Host Group, a literal agent name, or an Agentless Host (a Control-M admin can point a job's `Host` at any of the three). `resolve_host` tries them in order and always returns the **real agent(s)** that would actually run the job:

```python
result = client.resolve_host("ZZM_AGT_01")
# {"host_type": "hostgroup" | "agent" | "agentless_host" | None,
#  "agents": [...],   # real agent hostnames - never the Agentless Host's own name
#  "error": None or a message}
```

Key gotcha this uncovered: `get_agents(agent=...)`'s `status` field is **not** a reliable "does this exist" signal — a genuine agent or Agentless Host can legitimately report `status: "Discovering"` too (e.g. an Agentless Host briefly shows it when the real agent behind it goes down, since Control-M can't verify connectivity through a dead agent). The reliable signal is whether the entry carries extra metadata (`tag`/`hostgroups`/`operatingSystem`/...) — a name Control-M has never heard of comes back as a bare 3-key placeholder (`nodeid`, `status`, `type`) and nothing else.

### Calendar existence — inline vs. shared

A job's schedule sits under `When`. If `RuleBasedCalendars.Included` references a name other than the literal `"USE PARENT"` sentinel (which just means "inherit the folder's calendar"), that name is either:

- **embedded inline** as a sibling key in the same `RuleBasedCalendars` dict (a folder-private calendar definition) — always exists, nothing to check, or
- a reference to a **shared** calendar deployed separately — confirm it exists with `get_deployed_calendars(name=X, calendar_type="RuleBasedCalendar")`.

## Outside-of-Control-M tests

These do **not** call the Automation API for the actual test — they run a plain ICMP ping and TCP port-connect from wherever the check happens to execute, using only information the Automation API already exposes. **No credentials are ever touched** — those are Control-M's to manage, not this tool's.

| Function | What it does |
| --- | --- |
| `test_network_endpoint(host, port, timeout=3)` | The primitive: ICMP ping (via the system `ping` binary) + TCP connect test against any host/port. Returns `{host, port, ping_ok, ping_message, port_ok, port_message}`. |
| `client.resolve_connection_profile_endpoint(name, ccp_type="FileTransfer")` | Resolves a centralized connection profile's live endpoint via `GET /deploy/connectionprofiles/centralized`. Handles both `HostName` (FileTransfer/SFTP-family) and `Host` (Database-family) key naming. Returns `{host_name, port, type, error}` — `host_name` is `None` for profile types with no literal network endpoint at all (see below). |

> **Only FileTransfer/SFTP (`HostName`) and Database (`Host`) key naming are currently handled.** BMC supports ~160 other centralized connection profile types, each of which can use its own field name for the endpoint (or have no literal endpoint at all). See [`CCP_TYPES_REFERENCE.md`](CCP_TYPES_REFERENCE.md) for the full catalog — every type's endpoint field name(s), pulled from BMC's own documentation samples — before considering extending this. **Don't extend the key list without also confirming against a real CCP JSON sample** - every existing default/key mapping in this file was verified against a live profile on `ctm.werkstatt.local`, not just documentation (which `CCP_TYPES_REFERENCE.md` itself is, and says so).
| `client.test_connection_profile_network(name, ccp_type="FileTransfer", default_port=None)` | Combines the two: resolves the profile, then runs `test_network_endpoint` against it. Falls back to a built-in default port per profile type (`DEFAULT_PORTS_BY_CCP_TYPE`: PostgreSQL→5432, MSSQL/SQLServer→1433, Oracle→1521, MySQL→3306, DB2→50000) when the profile itself doesn't specify one. **Deliberately no default for FTP or SFTP** — see below. |

**Only meaningful for profile types with a literal host:port** — MFT/SFTP and Database connection profiles, mainly. SDK/API-based profiles (S3, GCS, Azure Blob, ...) authenticate purely through the cloud provider's API with no direct network endpoint in their config at all, and `Local`-type profiles have none either — `test_connection_profile_network` detects this and returns `{"skipped": True, "reason": ...}` rather than an error.

```python
result = client.test_connection_profile_network("ZZM_SFTP_AGT2")
# {"host": "ctm-lin-srv.werkstatt.local", "port": 1222, "ping_ok": True, "ping_message": "...",
#  "port_ok": True, "port_message": "...", "skipped": False, "port_is_default": False}
```

> **Same caveat as the PowerShell script's SFTP network test:** this proves reachability *from the machine running the check*, not from the Control-M agent that would actually use the connection profile — the agent's real network path (segment, firewall, NAT) may differ entirely. Treat it as an early warning signal, not proof the agent-side operation will succeed.

### SSL certificate expiration and SSH host key fingerprint

Two more outside-of-Control-M checks, for the same reason as the network test above but a different failure mode: **an expired SSL certificate makes Control-M's own agent test fail**, but Control-M doesn't proactively warn you a cert is *about to* expire, and its own reported expiration (`client.get_agent_crt_expiration()`) reflects what Control-M has on record — not necessarily what's actually being presented on the wire right now (e.g. after a cert was rotated outside Control-M's knowledge). These connect directly and read the real, live cert/host key instead. No credentials are used — an SSL check is a plain TLS handshake up to reading the peer certificate, an SSH check is the same unauthenticated host-key exchange any SSH client sees before ever offering credentials. Since neither ever logs in, fields like the CCP's `User`, `Password`, and `HomeDirectory` are irrelevant to these checks - they only ever come into play post-authentication, which these deliberately never reach.

| Function | What it does |
| --- | --- |
| `get_ssl_certificate(host, port, timeout=5)` | Connects via TLS (using the system `openssl` binary — `s_client` + `x509`, no extra pip dependency) and reads the live certificate. Returns `{host, port, not_before, not_after, expired, days_until_expiry, subject, issuer, fingerprint_sha256, error}`. |
| `get_ssh_fingerprint(host, port=22, timeout=5)` | Runs `ssh-keyscan` + `ssh-keygen -lf` to retrieve the live SSH host key fingerprint — useful for catching host-key drift (e.g. a redeployed/reimaged agent host now presenting a different key than expected). Returns `{host, port, key_type, fingerprint_sha256, error}`. |
| `client.get_connection_profile_ssh_fingerprint(name, ccp_type="FileTransfer")` | Composite: resolves the profile's real host **and port** via the CCP endpoint, then runs `get_ssh_fingerprint` against it. Skips cleanly for non-SFTP profile types (Database, SDK-based, Local). |

```python
cert = get_ssl_certificate("ctm-lin-em.werkstatt.local", 8443)
# {"host": "ctm-lin-em.werkstatt.local", "port": 8443, "not_before": "Jan 13 08:21:03 2026 GMT",
#  "not_after": "Oct 16 08:21:03 2039 GMT", "expired": False, "days_until_expiry": 4840,
#  "subject": "...", "issuer": "...", "fingerprint_sha256": "...", "error": None}
```

An agent's SSL/Zone 2-3 port is normally its `ATCMNDATA` (Agent-to-Server communication) parameter — see `client.get_agent_params()` — rather than a fixed default, so pass whatever port the agent is actually configured for. Background: [Introduction to SSL](https://documents.bmc.com/supportu/9.0.22/en-US/Documentation/Introduction_to_SSL.htm), [Zone 2 and 3 SSL configuration](https://documents.bmc.com/supportu/9.0.22/en-US/Documentation/Zone_2_and_3_SSL_configuration.htm).

**Never assume port 21/22 for FTP/SFTP connection profiles.** A plain OS-level `ftpd`/`sshd` and BMC's own MFTE file transfer service are entirely separate implementations, not the same daemon on a different port — confirmed via Control-M's own Server Configuration screen for the File Transfer plugin, where MFTE's FTP/FTPS listener defaults to port **1221** and its SFTP listener to port **1222** (`ctm-lin-srv.werkstatt.local` presents a completely different **ECDSA** SSH key on port 1222 than the **RSA** key its OS `sshd` presents on port 22 — two independent SSH implementations, not just two ports). The connection profile could be pointing at either the OS-level service or MFTE's, and the CCP itself is the only reliable source for which port that actually is. On Windows agents specifically, there may be no OS-level `ftpd`/`sshd` at all — only the MFT FTS on whatever port the CCP shows. Also worth knowing: BMC's FTP/FTPS listener is commonly left disabled entirely (SFTP-only is a common real-world configuration), so don't assume an FTP-typed profile has a live endpoint to test just because the CCP exists.

### HTTPS endpoints, for connection profile types beyond FileTransfer/Database

`resolve_connection_profile_endpoint` only checks for `HostName`/`Host`. Per `CCP_TYPES_REFERENCE.md`, most of BMC's other ~160 connection profile types instead put their endpoint in a URL-shaped string, under a different field name per type (FileTransfer:Azure's is `AzureEndpoint`, SAP's `Host` is nested two levels down, etc.) — impractical to keep adding key names for one at a time. Instead:

| Function | What it does |
| --- | --- |
| `extract_url_endpoints(data)` | Recursively scans any dict/list for string values starting with `http://`/`https://`, wherever they live (including nested), and returns `{field_path, url, scheme, host, port}` for each — port comes from the URL if explicit, else the scheme's standard default (443/80). |
| `client.test_connection_profile_https_endpoints(name, ccp_type="FileTransfer")` | Fetches the profile, runs `extract_url_endpoints` on it, then runs `test_network_endpoint` on every URL found, plus `get_ssl_certificate` for the `https://` ones. Returns `{error, endpoints: [...]}`. |

```python
result = client.test_connection_profile_https_endpoints("SOME_AZURE_CCP")
# {"error": None, "endpoints": [
#   {"field_path": "AzureEndpoint", "url": "https://devAccount.blob.core.windows.net",
#    "scheme": "https", "host": "devaccount.blob.core.windows.net", "port": 443,
#    "network": {...test_network_endpoint's result...},
#    "ssl": {...get_ssl_certificate's result...}}
# ]}
```

This is a genuinely different strategy from `resolve_connection_profile_endpoint`'s exact-key matching — it doesn't need to know the field name at all, just that *some* value looks like a URL. That's also its limit: a profile with no URL-shaped value at all (most DB engines use a bare hostname, not a URL) returns `endpoints: []`, not an error — check that list's length before assuming nothing was found versus nothing was there to find.

For this reason:

- Always use `client.get_connection_profile_ssh_fingerprint(name)` rather than calling `get_ssh_fingerprint(host, port=22)` directly, so the port always comes from the CCP itself.
- `test_connection_profile_network` has **no built-in default port for FTP or SFTP** (unlike the DB engines, whose default ports are OS-independent protocol standards) — if an FTP/SFTP-typed profile has no explicit `Port`, both functions `skip` rather than silently guessing 21/22, since a wrong guess would look like a definitive connectivity failure rather than an honest "couldn't determine the port."

## Caching

Python port of `ctm-preflight.ps1`'s `$cacheHostgroupAgent`/`$cacheAgentTest`/`$cacheCcpTest`/`$cacheCcpProfile`/`$cacheNetEndpoint`. Walking a real folder hits the same agent, hostgroup, or connection profile over and over (many jobs share one `Host`, or one `ConnectionProfileSrc`/`Dest`) — re-running the same agent test or ping for every job that happens to share a resource is both slow and pointless once the first result is known. Each `CtmClient` instance memoizes:

| Method | Cache key |
| --- | --- |
| `resolve_host` | `(server, host)` |
| `test_agent` | `(server, agent)` |
| `test_centralized_connection_profile` | `(ccp_type, name, agent, server)` |
| `resolve_connection_profile_endpoint` | `(name, ccp_type)` |
| `test_connection_profile_network` / `test_connection_profile_https_endpoints` (network check) | `(host, port)` |
| `get_connection_profile_ssh_fingerprint` | `(host, port)` |
| `test_connection_profile_https_endpoints` (SSL check) | `(host, port)` |

**`test_centralized_connection_profile` is deliberately keyed on `(CCP, agent)`, not just the CCP name** — some connection profiles only work from a specific agent, so the same CCP tested against a *different* agent is a genuinely different result, not a cache hit; confirmed this holds correctly even when the same CCP name is reused across agents.

A cache is per-`CtmClient` instance — a fresh `build_client()` call gets an empty cache, the same lifetime as one `ctm-preflight.ps1` run. Call `client.clear_cache()` to reset it explicitly (e.g. reusing one client across multiple independent runs in a long-lived process).

## Error handling and logging

`CtmApiError` carries structured `method`/`url`/`status_code`/`message` attributes rather than a flattened string, with the real Control-M error message extracted from the response body (`{"message": ...}` or `{"errors": [...]}`) instead of raw response text. A connection/DNS/timeout failure has `status_code is None`; an HTTP error has it set.

A timestamped log file (`ctm_engineer_{yyyyMMdd_HHmmss}.log`) is **always** written to `.engineer/logs` (or wherever `LOG_FOLDER` in `.env` points), not just with `-v` — so a genuine failure (e.g. a connection-profile test error) is always on record, not lost once the terminal session ends. `-v`/`--verbose` (or `configure_logging(verbose=True)` when importing) raises both the console's and that file's level from INFO to DEBUG, adding full tracing of every API URL and its response body (see `CtmClient._request`).

Every 4xx/5xx is logged at `ERROR` by default - except when the caller passes `quiet_statuses=(...)` (e.g. `get_hostgroup_agents(..., quiet_statuses=(404,))`, used internally by `resolve_host`) to say "this particular status is an expected, handled branch, not a real problem" - those log at `DEBUG` instead (still visible with `-v`), so `--folder`'s console/log output isn't cluttered with resolve_host's routine "not a hostgroup, falling back to agent" 404s alongside genuine failures.

`CtmClient._request`'s own raw `"CTM API request/response/error: ..."` log lines are always written to the log file, but never printed to the console (filtered out there by `_ExcludeRawApiLogFilter`) - a `--folder` run's console output is the human-readable report alone (or the raw JSON/path, in `json`/`file` mode), not that report *plus* a duplicate raw log line for every failure it already lists in its own "Connection-profile failures:" section. Check the log file (or add `-v`) if you need the underlying HTTP-level detail.
