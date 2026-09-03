# ctm_client.py

A minimal Control-M Automation API (AAPI) client - the three read-only
calls the job report pipeline needs (job status, job log, job output) plus
two write calls used to mark a processed alert as read in Control-M itself
(update its comment, set its status to `Reviewed`), all implemented as
plain `requests` calls. Used exclusively by `ctm_job_report.py`;
`ctm_to_snow_incident.py` doesn't import it at all - see
`docs/ctm_to_snow_incident.md` for how that script gets job detail without
ever calling this module (a best-effort local file read, not an AAPI call).

All five calls are also in
[`postman/Control-M Automation API.postman_collection.json`](../postman/Control-M%20Automation%20API.postman_collection.json)
as stand-alone requests, for exercising them against a real Control-M/EM
before wiring up the pipeline.

## Why not the controlm_py SDK

The `ctm-engineer` project's `engineer_ctm.py` wraps the `controlm_py` SDK
via a `CtmConnection` class. That connection/session model pulls in
`project.py`'s config loader, which in turn requires `jsonschema`,
`jsonpath_ng`, and `pycryptodome` (for its `CRYPTO_FILE`-based secrets
handling) - none of which this project uses anywhere else, and none of
which are in `requirements.txt` (just `requests` + `python-dotenv`).
Pulling in that whole dependency chain to reach three GET endpoints wasn't
worth it; talking to them directly keeps this project on its existing
footprint.

This was a deliberate choice, not an oversight: `git+https://github.com/dcompane/controlm_py.git`
was actually in `requirements.txt` at one point during development and was
removed once this module made it unnecessary.

## Auth model: persistent API key, not a login session

Every request sends a Control-M Automation API token as the `x-api-key`
header:

```python
def _headers(config: dict) -> dict:
    return {
        "x-api-key": config["CONTROLM_API_KEY"],
        "Accept": "application/json",
    }
```

No `/session/login` call, no token expiry/renewal handling, no logout.
This matches how `engineer_ctm.py`'s own `CtmConnection` actually
authenticates too, on inspection - it sets the same `x-api-key` header via
`additional_login_header` and never calls a login endpoint despite having a
`session_api` object and a `logout()` method. A persistent AAPI token is
meant to be used exactly this way; there's no session to manage for a
script that runs once per Control-M alert.

## The three job-detail functions

All three take `(config, ctm_server, order_id)` (`get_job_output` also
takes `run_no`, default `0`) and build the same `job_id` internally:

```python
def _job_id(ctm_server: str, order_id: str) -> str:
    return f"{ctm_server}:{order_id}"
```

This matches the `ctmServer + ":" + ctmOrderID` convention used throughout
`engineer_ctm.py` (`getCtmJobStatus`, `getCtmJobInfo`, etc.) - it's
Control-M's own job identifier format, not something invented for this
project.

| Function | Endpoint | Notes |
|---|---|---|
| `get_job_status()` | `GET /run/job/<job_id>/status` | Returns the AAPI response directly (the full job status object - `status`, `startTime`, `endTime`, etc.). |
| `get_job_log()` | `GET /run/job/<job_id>/log` | Control-M's own run log, not job stdout. |
| `get_job_output()` | `GET /run/job/<job_id>/output?runNo=<run_no>` | Job stdout/sysout for a specific run. `ctm_job_report.py` passes the alert's own `run_counter` here (leading zeros stripped) - see `docs/ctm_job_report.md`. |

All three raise `RuntimeError` on a non-200 response, including the status
code and response body - `ctm_job_report.py`'s `build_job_report()` is
responsible for catching these per-call and degrading gracefully; this
module itself doesn't swallow failures.

### get_job_status: switched from the bulk list to the single-job endpoint

`get_job_status()` originally called `GET /run/jobs/status?jobid=<job_id>`
(plural `jobs`, a query param) and filtered the response's `"statuses"`
list down to the matching entry, returning `{}` if not found. That endpoint
turned out to only cover Control-M's **active** pipeline - once a job
finished (which is the common case here, since Control-M alerts fire after
a job has already ended), it silently returned nothing, so `job_status`
came back empty for most real alerts in production.

Switched to `GET /run/job/<job_id>/status` (singular `job`, a path param)
after confirming via direct testing (see `docs/ctm_alert_order.md`, Step 1)
that this endpoint still returns full status - including a final `status`
like `"Ended Not OK"` and real `startTime`/`endTime` - for a job that's
already finished. The response is now returned as-is; there's no
`"statuses"` list to filter anymore.

### Endpoint paths for the read calls were verified, not guessed

The log/output resource paths (`/run/job/{jobId}/log`,
`/run/job/{jobId}/output`) and their parameter names (`jobId`, `runNo`)
were confirmed by reading `controlm_py`'s own generated `run_api.py` source
directly (`get_job_log_with_http_info`, `get_job_output_with_http_info`) -
not inferred from `engineer_ctm.py`'s wrapper functions or from general
AAPI documentation. `get_job_status`'s current endpoint came from a
different source instead: a real captured link/response (see
`docs/ctm_alert_order.md`), since the bulk-list endpoint the SDK pointed at
turned out to have the active-pipeline gap described above.

### job_id is percent-encoded in path segments

```python
quote(_job_id(ctm_server, order_id), safe='')
```

`job_id` contains a literal `:` (e.g. `ctm-lin-srv:0039s`), and it's used as
a path segment (not a query parameter) in all three job-detail endpoints,
including `get_job_status` now that it's a path param too. This matches
`controlm_py`'s own `api_client.py`, which encodes path parameters with
`safe_chars_for_path_param=''` (no characters exempted) - so the real AAPI
expects `%3A`, not a bare `:`, in that position. Getting this wrong would
silently produce a 404 rather than an obvious error, so it was checked
against the SDK's actual encoding behavior rather than assumed.

## Marking an alert as read: update_alert() and set_alert_status()

Two write calls, used together by `ctm_job_report.py`'s `mark_alert_read()`
once a job's log has actually been fetched:

| Function | Endpoint | Notes |
|---|---|---|
| `update_alert()` | `POST /run/alerts` `{"alertIds": [id], "comment": ..., "urgency": ...}` | `urgency`/`comment` are only included in the body when given, so a caller that only wants to set one doesn't clobber the other. `ctm_job_report.py` uses this to set the alert's comment to the saved report's filename. |
| `set_alert_status()` | `POST /run/alerts/status` `{"alertIds": [id], "status": ...}` | `ctm_job_report.py` calls this with `status="Reviewed"` to mark the alert as read. |

Both return the parsed JSON response body (or `{}` if the response had no
body) rather than filtering/discarding it - callers persist the raw
response for later verification, because **the AAPI has been observed to
return `HTTP 200` with `{"message": "... successfully modified"}` without
the change actually taking effect server-side.** A 200 here is not proof
the alert was actually updated; see `docs/ctm_job_report.md`'s
`mark_alert_read()` section for how that gets recorded.

Both raise `RuntimeError` on non-200 the same way the three read calls do.

## Debug logging: CONTROLM_DEBUG

Every AAPI call (all five functions above) routes through a single
`_request()` choke point. When `CONTROLM_DEBUG=true` in `config/.env`, it
logs the outgoing method/URL/params-or-body before the call and the
resulting status code + raw response text after it:

```text
[HH:MM:SS] [DEBUG] [ctm_client] -> POST https://.../run/alerts/status {'json': {'alertIds': ['2418'], 'status': 'Reviewed'}}
[HH:MM:SS] [DEBUG] [ctm_client] <- POST https://.../run/alerts/status HTTP 200: {"message": "[2418] The alert status was successfully modified"}
```

This is its own copy of logging, deliberately separate from either
pipeline's `log()`/`set_log_level()` (same "no runtime coupling" reasoning
as the rest of this module) and gated by its own config var rather than
`-v`/`--verbose` on either script, so it can be left on in an environment
independent of how verbose the calling pipeline's own console output is.
Headers (and therefore the API key) are never logged. Useful for exactly
the case `update_alert()`/`set_alert_status()`'s docs above describe: when
the AAPI's response doesn't match what actually happened.

## Configuration

```python
def load_ctm_config() -> dict:
    return {
        "CONTROLM_URL": os.getenv("CONTROLM_URL", "").rstrip("/"),
        "CONTROLM_API_KEY": os.getenv("CONTROLM_API_KEY", ""),
        "CONTROLM_DEBUG": os.getenv("CONTROLM_DEBUG", "false").lower() == "true",
    }
```

Loaded from the same `config/.env` as `ctm_to_snow_incident.py`'s
ServiceNow config (`CONTROLM_URL` should include the `/automation-api`
path, e.g. `https://ctm-em.example.com:8443/automation-api`). Unlike
`ctm_to_snow_incident.py`'s `load_config()`, this doesn't warn on missing
values at load time - `ctm_job_report.py`'s `build_job_report()` is the
one that decides an empty `CONTROLM_URL` means "skip AAPI calls entirely"
rather than treating it as a hard misconfiguration.
