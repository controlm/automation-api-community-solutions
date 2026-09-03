# ctm_to_snow_incident.py

The incident pipeline's runtime script. Invoked once per Control-M alert
(via `ctm_alerts.sh`, as its second step - see `docs/ctm_alerts_sh.md`),
with the raw alert fields as command-line arguments. Talks only to
ServiceNow - it has no dependency on Control-M's Automation API and never
imports `ctm_client.py`. Job status/log/output capture (the actual AAPI
calls) lives entirely in the sibling `ctm_job_report.py` pipeline instead
(see `docs/ctm_job_report.md` for why these are kept separate); this script
only ever does a **best-effort local read** of what that pipeline already
wrote to disk (see **Worklog enrichment** below) - reading a file is not
the same dependency as importing `ctm_client.py` or calling the AAPI, and
that distinction is deliberate (an earlier version of this project did
call the AAPI directly from here and reverted it - see this script's own
version history).

## Usage

```bash
python3 ctm_to_snow_incident.py [-v|-q] call_type: I alert_id: 2256 application: "ZZM BMC" ...
```

- `-v` / `--verbose` - also logs full raw ServiceNow response bodies
  (except the OAuth token response, which is redacted even in verbose mode -
  it contains a live credential).
- `-q` / `--quiet` - suppresses `[INFO]` narrative lines. `[WARN]`/`[ERROR]`
  and the final `CTM_EM_INCIDENT_JSON` summary line always print regardless -
  that line is the one thing Control-M EM's log actually needs to see.
- With no CLI arguments: if `SNOW_CTM_DEMO_MODE=true` in `.env`, runs against
  a built-in sample alert instead of requiring live Control-M input.

Default verbosity when no `-v`/`-q` flag is given comes from `LOG_LEVEL` in
`.env` (`quiet` | `normal` | `verbose`).

Console output includes `--- Step N: ... ---` banners (Step 0: Alert
Received, Steps 4-7: SNOW OAuth/Create Incident/Add Worklog/Add Job Report
Worklog) that deliberately match `docs/ctm_alert_order.md`'s global
pipeline numbering - Steps 1-3 (Get Job Status/Output/Log) are logged the
same way in `ctm_job_report.py`. Cross-reference that doc directly against
a live log when debugging a specific alert end to end.

## Argument parsing: why it's not trivial

Control-M passes alert fields as alternating `'key:'`, `'value'` tokens, not
a JSON blob. Two real behaviors, both confirmed against actual production
Control-M output, make naive positional parsing (`$1 $2 $3...`) unsafe:

1. **Empty fields sometimes omit the value token entirely** - the very next
   token is immediately the next key. `parse_ctm_args_to_json()` looks ahead
   before consuming a value, rather than assuming a fixed position.
2. **Other times, Control-M sends a literal single space (`' '`) as the
   "empty" value**, and non-empty values frequently carry a trailing space
   (`'ZZM BMC '`, `'2256 '`). Both keys and values are stripped.

Both behaviors are covered by real captured samples in `sample/` and
exercised in the test suite - this isn't a hypothetical edge case.
`parse_ctm_args_to_json()`, `classify_alert()`, and `describe_ctm_lifecycle()`
are also imported directly by `ctm_job_report.py`, so any fix here
automatically applies to both pipelines rather than needing to be
duplicated and kept in sync.

## Alert lifecycle: only one state is ever actionable

Control-M's EM sends a **separate invocation for every lifecycle transition**
of the same underlying `alert_id`, not just once:

| call_type | status | Meaning |
|---|---|---|
| `I` | `Not_Noticed` | New alert - the only one that creates/resolves anything |
| `U` | `Noticed` | Someone acknowledged it in Control-M's own alert console |
| `U` | `Handled` | Closed in Control-M's own alert console |

`describe_ctm_lifecycle()` gates on this before classification even runs.
Since the ServiceNow incident number is never written back to Control-M,
a later `U` update has no way to be mapped to a specific incident - so
anything other than `I`+`Not_Noticed` is logged and skipped, not processed.

**This is a different problem from duplicate delivery.** A genuine
redelivery of the exact same `I`/`Not_Noticed` alert (e.g. an EM-level
retry) would look identical to a first delivery and slip past this gate -
that's what the tracking ledger (below) catches instead.

## Duplicate-delivery guard: data/alert_tracking.json

A single JSON file, keyed by `alert_id`, recording what action was taken:
`created_incident`, `resolved_incident`, `no_matching_incident`, or
`skipped_out_of_scope`, each with a timestamp and (where applicable) the
resulting incident number/sys_id. Before processing an `I`/`Not_Noticed`
alert, the script checks whether that `alert_id` already has a recorded
action and skips if so, rather than creating a second incident.

Created automatically on first write. A missing or corrupted tracking file
is treated as empty history (logged as a warning) rather than a fatal error.

This ledger is entirely separate from `ctm_job_report.py`'s own
`data/job_report_tracking.json` - the two pipelines' dedup/retry state is
deliberately not shared, so a redelivered alert can retry just the piece
that previously failed (incident creation, job report, or both).

## Alert classification

`classify_alert()` mirrors the original `alerts.py`'s exact job-check and
hardcoded message patterns:

- `order_id` present, not `'00000'`, and `job_name` present -> `'job'`
- Message contains `'STATUS OF AGENT PLATFORM'` + `'CHANGED TO UNAVAILABLE'` -> `'agent_unavailable'`
- Message contains `'STATUS OF AGENT PLATFORM'` + `'CHANGED TO AVAILABLE'` -> `'agent_available'`
- Everything else (server disconnection, Control-M "x-alerts", unrecognized
  `order_id='00000'` messages) -> `'other'` - logged and skipped, explicitly
  out of scope for this project, not a gap to fill in later without a
  separate scoping decision.

Only `'job'` is meaningful to `ctm_job_report.py` too - `agent_unavailable`,
`agent_available`, and `other` are a clean no-op there, since job
status/log/output only make sense for an alert that actually has an
`order_id`.

## Agent correlation: why it's not just `host_id`

`build_agent_correlation_id()` builds `data_center:host_id`, not `host_id`
alone - in newer Control-M releases, one `host_id` can sit under more than
one CTM Server, so `host_id` alone isn't guaranteed unique.

**`host_id` is frequently empty in practice.** Confirmed against real
production alerts: for `STATUS OF AGENT PLATFORM` alerts specifically,
Control-M leaves the structured `host_id` field blank and puts the actual
agent hostname only in the free-text `message`. Without a fallback, every
agent alert from the same data center would collapse onto the identical
correlation ID, unable to distinguish between different agents.
`extract_agent_hostname_from_message()` parses the hostname out of the
message text when `host_id` is empty; an explicitly populated `host_id`
still takes priority when present.

### The resolve flow

1. `agent_unavailable` -> `create_incident()` with `correlation_id` set to
   the value above.
2. `agent_available` -> `find_open_incident_by_correlation()` queries
   ServiceNow for an active incident with a matching `correlation_id`.
   - **Found**: `resolve_incident()` sets `state: "6"`, `close_code: "Solution
     provided"`, and `close_notes` referencing the Control-M alert ID. These
     exact values were confirmed against a real ServiceNow instance via a
     live Postman PATCH test, not assumed from ServiceNow's generic
     documentation - a prior mismatch in this same project (Business
     Service Phase/Status) is exactly why this was verified rather than
     guessed.
   - **Not found**: logged, no incident created. This is the expected,
     normal outcome when the corresponding `agent_unavailable` alert was
     never processed (e.g. it arrived before this script was correctly
     deployed) or was already closed some other way.

## Routing (job alerts and agent alerts share this)

`resolve_route()` matches the alert's `application` field (case-insensitive
prefix, e.g. `ZZM*`) against `config/mapping.json`, first match wins. Agent
alerts have no `application` field at all, so they always fall through
to whatever the catch-all (`pattern: "*"`) rule resolves to.

`config/mapping.json` is generated by `setup_resolve_mapping.py` - see that
script's own doc. It carries a `_do_not_edit` sentinel object as its first
array entry; `load_mapping()` filters this out by checking for that specific
key, **not** by checking for a missing/empty `pattern` field - a marker with
no `pattern` would default to `pattern=""`, which would incorrectly match
before the real catch-all rule for every agent alert (which calls
`resolve_route("", rules)`). This was caught and fixed during development,
not a hypothetical risk.

## Worklog enrichment: load_job_report() and add_job_report_worklogs()

For `'job'` alerts only, after the incident is created and its initial
worklog entry is added, `main()` calls:

```python
job_report = load_job_report(alert_id)
if job_report:
    add_job_report_worklogs(config, access_token, incident_sys_id, job_report)
```

`load_job_report()` is a best-effort read of
`data/job_reports/<alert_id>.json` - the exact file `ctm_job_report.py`'s
`save_job_report()` writes, using an own-copy `JOB_REPORT_DIR` constant
(same value, not an import) matching the pattern already established for
`ctm_client.py`/`ctm_job_report.py`'s own "own copy, no runtime coupling"
sharing rules. Missing file, unreadable file, or corrupt JSON all just
return `{}` - logged as a `WARN` for the latter two, silent for a simply
missing file (the common case when the job report step hasn't run yet, was
skipped, or timed out in `ctm_alerts.sh`).

`add_job_report_worklogs()` then posts up to **four separate worklog
entries** via `build_job_report_work_notes()` - a cross-launch monitoring
link, job status, job log, and job output, each its own `PATCH` (per user
request: separate entries, not one combined note, mirroring how a human
would add them). A section is only included when actually present in the
report - `ctm_job_report.py` sets a failed fetch's key to `None` and
`ctm_monitoring_url` to `""` when it can't be built, so a partial report
just yields fewer entries, never an error note. Log and output text are
each capped at `JOB_REPORT_WORK_NOTES_LIMIT` (4000 chars) with a
`...[truncated, N chars total]` marker - the full text is always still in
the local JSON report regardless of what's truncated here.

The job status entry is rendered as **human-readable text**
(`_format_job_status()`), not the raw `get_job_status()` JSON -
**every field the AAPI response actually has**, per user request, not a
curated subset. Field names go through generic camelCase-splitting
(`startTime` -> `Start Time`), with a small override map for the ones
that would otherwise come out garbled (`jobId` -> `Job ID`, `ctm` ->
`Control-M Server`, `outputURI` -> `Output URI`, etc.). Every date/time-
shaped string value is reformatted via `_format_ctm_timestamp()` -
handles both the 14-digit `startTime`/`endTime` shape and `orderDate`'s
6-digit `YYMMDD` shape, applied uniformly including inside list-valued
fields like `estimatedStartTime`. Booleans render as `Yes`/`No`; an empty
`endTime` specifically renders as `(still running)` since that's more
informative than `(empty)` for that one field; every other empty/`None`
value renders as `(empty)` rather than being silently dropped - the whole
point is showing everything the AAPI returned. Falls back to a raw JSON
dump only when the response is empty entirely.

Each `PATCH` is wrapped in its own `try`/`except` and is genuinely
best-effort: a failure posting one entry is logged as a `WARN` and does
**not** stop the others or fail the run - the incident already exists by
this point, so this is enrichment on top of it, not the incident pipeline's
actual job. `add_job_report_worklogs()` returns how many entries were
posted successfully, which `main()` records in
`data/alert_tracking.json` under `job_report_worklogs_posted`.

### Cross-launch link: build_ctm_monitoring_url()

A pure, shared function (imported by `ctm_job_report.py` too - see that
script's doc) that builds a deep link into Control-M's own Monitoring >
Neighborhood view for a job, so an agent working the ServiceNow incident
can click straight into Control-M. No HTTP call involved - just URL
construction from the alert plus `CONTROLM_URL`, reverse-engineered from
five real captured links. See `docs/ctm_job_report.md`'s "Cross-launch
link" section for the exact URL shape and what's alert-derived vs. a fixed
default.

## What's deliberately NOT here

No retry logic, no archival to processed/failed folders, no custom logging
framework, and no Control-M Automation API access at all - this script
never imports `ctm_client.py` or calls the AAPI directly (see "Worklog
enrichment" above for how it gets job detail without that dependency). See
the top-level README's "Known limitations and scope" for the full list.
This script optimizes for being readable end to end, not for production
robustness.
