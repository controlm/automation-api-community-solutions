# ctm_job_report.py

The job report pipeline's runtime script. Invoked once per Control-M alert
(via `ctm_job_report.sh`), with the same raw alert fields as command-line
arguments that `ctm_to_snow_incident.py` receives. For job alerts only, it
fetches the job's current status, execution log, and output from the
Control-M Automation API and writes them to a local JSON report file.

## Why this is a separate script, not a step inside ctm_to_snow_incident.py

It started as a step inside `ctm_to_snow_incident.py` (best-effort, run
before incident creation) and was deliberately split out. The two jobs -
"create a ServiceNow incident" and "capture Control-M job detail locally" -
need to run, fail, and be retried independently:

- Control-M's Automation API being slow or unreachable must never delay or
  block incident creation, which is the actually time-sensitive half.
- A ServiceNow outage must never prevent a job report from being captured.
- Control-M's own alert redelivery is the only retry mechanism either
  pipeline has (see **Duplicate-delivery guard** below) - if the two
  pipelines shared one dedup ledger, a redelivered alert that only needed to
  retry the job report (because AAPI was briefly down) would be silently
  skipped entirely, since the incident half already succeeded and would
  mark the whole alert as "processed".

Splitting into two independent scripts, each with its own dedup ledger, was
the fix. `ctm_to_snow_incident.py`'s worklog now does incorporate this same
status/log/output detail (see `docs/ctm_to_snow_incident.md`'s
`load_job_report()`/`add_job_report_worklogs()` section) - but as a
**best-effort local read** of `data/job_reports/<alert_id>.json` from the
other side, never a call into this module or into `ctm_client.py`. That
distinction is deliberate: an earlier version of this project actually did
call the Control-M AAPI directly from inside the incident script and
reverted it specifically because it let a slow/unreachable Control-M delay
or block incident creation (see that script's own version history). Don't
assume an incident's worklog reflects this pipeline's state at any given
moment - a report that hasn't been written yet, or that this pipeline's own
`timeout` in `ctm_alerts.sh` cut off, just means that run's worklog has
less detail, not that anything failed.

## Usage

```bash
python3 ctm_job_report.py [-v|-q] call_type: I alert_id: 2256 data_center: ctm-lin-srv order_id: 0039s job_name: "ZZM PreFlight Check" ...
```

- `-v` / `--verbose` / `-q` / `--quiet` - same meaning and same underlying
  log format as `ctm_to_snow_incident.py`.
- With no CLI arguments: if `CTM_JOB_REPORT_DEMO_MODE=true` in `.env`, runs
  against the same built-in sample alert `ctm_to_snow_incident.py` uses
  (`DEMO_ALERT_ARGS`, imported directly - not a second copy).

## What it shares with ctm_to_snow_incident.py, and what it doesn't

Imports four pure, side-effect-free functions directly from
`ctm_to_snow_incident.py`:

- `parse_ctm_args_to_json()` - the same real-world Control-M argument
  parsing quirks (see that script's doc) apply identically here; there was
  no reason to duplicate ~40 lines of carefully-commented, quirk-encoding
  logic just to keep the two scripts looking independent.
- `classify_alert()` - so `'job'` means the same thing in both pipelines.
- `describe_ctm_lifecycle()` - so a Control-M `U`/`Noticed` update alert is
  skipped here the same way it's skipped there.
- `build_ctm_monitoring_url()` - pure URL construction (no HTTP call), so
  it fits the same "stable, side-effect-free" sharing criterion as the
  other three. See **Cross-launch link** below.

This is a dependency on stable, tested parsing logic, **not** a runtime
coupling: running `ctm_job_report.py` never imports or executes anything
from `ctm_to_snow_incident.py`'s `main()`, never touches ServiceNow config,
and has no dependency on `config/.env`'s `SERVICENOW_*` variables at all.
Everything with actual side effects - config loading, logging, the
tracking ledger, `main()` itself - is its own separate implementation,
deliberately not shared (see `ctm_client.py`'s doc for the same reasoning
applied to the Control-M SDK question).

## Alert-type gating

Only alerts that `classify_alert()` returns `'job'` for get a report.
`agent_unavailable`, `agent_available`, and `other` alerts are logged and
skipped - `record_report_action()` still records the skip (as
`skipped_not_a_job_alert`) so it shows up in
`data/job_report_tracking.json`, but no file is written to
`data/job_reports/`. This mirrors `ctm_to_snow_incident.py`'s own
`'other'`-classification handling: an explicit scope decision, not a gap.

## Duplicate-delivery guard: data/job_report_tracking.json

Same shape and same purpose as `ctm_to_snow_incident.py`'s
`alert_tracking.json`, but a **separate file** - see "Why this is a
separate script" above for why sharing one ledger between the two
pipelines would be actively wrong, not just redundant.

## build_job_report(): fetching status, output, log, and the monitoring link

Three independent AAPI calls to `ctm_client.py`, plus one pure URL
computation:

```python
report = {
    "alert": alert,
    "retrieved_at": "<iso timestamp>",
    "ctm_monitoring_url": "https://.../ControlM/Monitoring/Neighborhood/...",  # "" if it couldn't be built
    "job_status": {...} | None,
    "job_output": "<output text>" | None,
    "job_log": "<log text>" | None,
    # present only if the corresponding call failed:
    "job_status_error": "<str(exception)>",
}
```

Each of the three (`get_job_status`, `get_job_output`, `get_job_log`) is
logged with its own `--- Step N: ... ---` banner and wrapped in its own
`try`/`except` - a failure in one (Control-M unreachable, the job having
already aged out, an unexpected AAPI response) degrades only that field,
logs a `WARN`, and never prevents the other two from being attempted or the
report from being written. The step numbers (1/2/3) and fetch order
(status, then output, then log) match `docs/ctm_alert_order.md`'s
documented pipeline order exactly - Step 0 (the alert itself) is logged in
`main()` before `build_job_report()` runs, and Steps 4-7 (the ServiceNow
side) are logged the same way in `ctm_to_snow_incident.py`. Cross-reference
that doc directly against a live log when debugging a specific alert.

`get_job_output`'s `runNo` is computed from the alert's own `run_counter`
field via `_parse_run_counter()`, not left at the default `0` - Control-M
sends `run_counter` zero-padded (e.g. `"00002"`), and `int()` strips the
padding for free. This matters because a job that's been rerun has more
than one run's output, and `docs/ctm_alert_order.md`'s Step 2 note is
explicit that requesting the wrong `runNo` gets you the wrong run's output.
A missing or non-numeric `run_counter` falls back to `0` rather than
raising - a malformed field shouldn't crash the whole report.

If `CONTROLM_URL` isn't configured in `.env` at all, none of the three AAPI
calls are attempted (and `ctm_monitoring_url` is never computed either,
since it also needs `CONTROLM_URL` to derive the Control-M host from) - the
report is written containing only the raw alert and a `WARN` is logged.
This is a deliberately softer failure than `ctm_to_snow_incident.py`'s
equivalent gaps (which are mostly `ERROR`/raise): an unconfigured job
report pipeline is a valid, if incomplete, deployment state, not a
misconfiguration to alarm on every single alert.

### Relationship to engineer_ctm.py's getCtmJobStatusAdv()

The `ctm-engineer` project's `engineer_ctm.py` (built on the `controlm_py`
SDK) has a `getCtmJobStatusAdv()` that re-filters a full job-status list
down to the one entry matching a specific `job_id`. `ctm_client.get_job_status()`
now calls the single-job AAPI endpoint directly and returns its response
as-is, so there's nothing left to filter - no separate "advanced" function
was needed even before that endpoint switch (see `docs/ctm_client.md` for
why the endpoint itself changed). (`getCtmJobStatusAdv()` also calls a
`project.jsonTranslateValues()` that doesn't actually exist anywhere in the
`ctm-engineer` checkout - dead code there - so nothing of value was left
behind by not porting it.)

## Cross-launch link: build_ctm_monitoring_url()

Computes a deep link into Control-M's own Monitoring > Neighborhood view
for the job, so a ServiceNow agent can click straight from an incident's
worklog into Control-M. It's a shared, pure function (see "What it shares
with ctm_to_snow_incident.py" above) since it makes no HTTP call - just
string/URL construction from the alert plus `CONTROLM_URL`.

Reverse-engineered from real captured links, not from any documented API
contract:

```text
https://ctm.werkstatt.local/ControlM/Monitoring/Neighborhood/003i7_3_1_%2520
  ?name=ZZM%20PreFlight%20Check&ctm=ctm-lin-srv&odate=%20&direction=1
  &radius=3&orderId=003i7&mapView=TileView
```

`order_id`/`job_name`/`data_center` come from the alert; `radius=3`,
`direction=1`, and `mapView=TileView` are fixed UI defaults confirmed
against five separate real links, not alert-derived. `odate` is always
left blank (a single space) - no real per-alert `odate` source was
available, and every real sample link used a blank one too, even for
jobs where an `orderDate` was known from the job-status response. The
path segment's trailing `%2520` is that same blank `odate` encoded
**twice** (once the way the query string would, `%20`, then again because
it's embedded as a literal substring of the path rather than its own path
component) - hardcoded as a literal for that reason, not computed via a
second `quote()` call that would read as a mistake out of context.

Returns `""` if `CONTROLM_URL` isn't configured or `order_id` is missing -
this is a nice-to-have link, not something worth failing a report over.

## mark_alert_read(): marking the Control-M alert itself as read

Once `build_job_report()` has actually captured the job's log
(`report.get("job_log") is not None` - i.e. the AAPI call succeeded, not
just attempted), `main()` calls `mark_alert_read(ctm_config, alert, path)`,
which makes two independent calls to `ctm_client.py`:

1. `update_alert(..., comment=f"Job log saved: {basename(path)}")` - sets
   the alert's own comment/text field in Control-M to the report's
   filename, so anyone looking at the alert in Control-M's console can see
   where the full detail landed.
2. `set_alert_status(..., "Reviewed")` - marks the alert as read.

Both are wrapped in their own `try`/`except`, logged, and best-effort - a
failure in either is a `WARN`, not a reason to fail the run (the report was
already saved successfully by this point). The gate on `job_log` being
present specifically (not just `CONTROLM_URL` being configured) means an
alert only gets marked read once there's actually something to show for
it: an AAPI outage that degrades the whole report leaves the Control-M
alert untouched too, so it doesn't silently disappear from whoever's
triage view without any detail having actually been captured.

**Both calls' full responses are persisted, not just logged**, because the
Control-M AAPI has been observed to return `HTTP 200` with a
"successfully modified" message **without the change actually taking
effect** - see `docs/ctm_client.md`. `mark_alert_read()` returns a dict
(`comment_set`/`comment_response`/`status_set`/`status_response`) that
`main()` attaches to the tracking-ledger record under `alert_marked_read`,
so `data/job_report_tracking.json` keeps a durable, timestamped record of
exactly what Control-M said back for each alert - the evidence needed to
show a developer "we called this and got X" when the AAPI's own bug means
the response can't be trusted at face value.

## save_job_report(): data/job_reports/\<alert_id\>.json

Keyed by `alert_id`, same convention as both tracking ledgers. A write
failure (disk full, permissions) is logged as `ERROR` and returns `""`
rather than raising - `main()` treats that as the run's overall failure
(exit code 1, so it's visible to Control-M EM), but it doesn't leave the
process in a half-crashed state.

## What's deliberately NOT here

No retry logic beyond what Control-M's own alert redelivery provides, no
archival, no custom logging framework - same scope decisions as
`ctm_to_snow_incident.py`. No direct ServiceNow integration - this script
never imports `requests` against ServiceNow, never touches `SERVICENOW_*`
config, and has no idea whether an incident was ever created for the alert
it's processing. Worklog enrichment happens entirely from the other side,
as a best-effort file read (see "Why this is a separate script" above and
`docs/ctm_to_snow_incident.md`).
