# Control-M Alerts -> ServiceNow Incidents

Turns Control-M alerts (job failures, agent up/down events) into ServiceNow
incidents, routed to the right assignment group and Configuration Item from
a simple, admin-editable mapping table - no ServiceNow expertise needed to
maintain the routing rules day to day. A second, independent pipeline
captures live Control-M job status/log/output into a local report file per
job alert and folds it into the incident's worklog.

Everything is triggered from a **single Control-M/EM alert action** calling
one shell script (`ctm_alerts.sh`), the same way the
[`4-ai-job-type-examples/service-now-incident`](../../4-ai-job-type-examples/service-now-incident)
example is triggered - both raise a ServiceNow incident from a failing job.
That example does it with an **Application Integrator job type** ordered as
a job; this one does it with a **script called by EM for every alert**. Same
ServiceNow Table API underneath.

> **Minimal reference implementation.** No retry framework, no archival, no
> logging framework. Built for a demo/lab environment - read **Known
> limitations and scope** at the bottom before using this anywhere near
> production. The scripts optimise for being readable end to end, not for
> robustness.

## What this actually does

Two independent pipelines that share only pure alert-parsing logic, both
driven from the one EM alert action - EM only supports one script per alert
action, so `ctm_alerts.sh` is that entry point and runs both itself:

1. **Job report pipeline** (runs first, time-boxed) - `ctm_alerts.sh` runs
   `ctm_job_report.sh` -> `ctm_job_report.py`, which for job alerts fetches
   the job's current status, execution log and output from the Control-M
   Automation API, writes them to `src/data/job_reports/<alert_id>.json`,
   computes a cross-launch link into Control-M's Monitoring view, and marks
   the Control-M alert itself as read (comment + status `Reviewed`) once the
   log has been captured.
2. **Incident pipeline** - `ctm_alerts.sh` then runs
   `ctm_to_snow_incident.py`, which reformats the raw alert arguments into
   JSON, classifies the alert (job failure / agent down / agent back / out
   of scope), resolves routing (assignment group + Configuration Item) from
   `config/mapping.json`, creates/updates/resolves the ServiceNow incident
   via REST, and - for job alerts - does a best-effort local read of the job
   report pipeline's JSON file to post the job's status/log/output/
   monitoring-link as separate worklog entries.

The two pipelines stay independently retryable even though one script
triggers both: a hung Control-M can only delay the job report step (it runs
under a wall-clock `timeout`), never the incident half; a ServiceNow outage
never blocks a job report. Each pipeline has its own dedup ledger, so a
redelivered alert retries just the half that failed. The worklog enrichment
is a **best-effort local file read**, not a live call into the Control-M
AAPI from the incident script - a missing or stale report file just means
that run's worklog has no job detail, never a failure.

`ctm_alerts.sh` also short-circuits before starting either pipeline for
anything that isn't a genuinely new alert (`call_type='I'` and
`status='Not_Noticed'`) - Control-M/EM re-invokes the same script for every
lifecycle transition of an alert, **including the ones this project's own
AAPI calls cause** (marking an alert read is itself an alert update that
echoes back through EM). See [`docs/ctm_alerts_sh.md`](docs/ctm_alerts_sh.md).

## Architecture

```text
Control-M EM
    |  (single alert action - EM only supports one script per action)
    v
src/ctm_alerts.sh
(wrapper: bails out here unless call_type=I and status=Not_Noticed -
 see "Why the early exit" in docs/ctm_alerts_sh.md)
    |
    |-- Step 1 (timeout-boxed, best-effort) --.
    |                                          v
    |                                    src/ctm_job_report.sh
    |                                    (wrapper: sudo -u oversight,
    |                                     logs to job_report.log)
    |                                          |
    |                                          v
    |                                    src/ctm_job_report.py
    |                                          |-- parse_ctm_args_to_json()      <-- shared, imported
    |                                          |-- describe_ctm_lifecycle()      <-- shared, imported
    |                                          |-- classify_alert()              <-- shared, imported
    |                                          |-- load_report_tracking()
    |                                          |     (data/job_report_tracking.json)
    |                                          |-- build_job_report()
    |                                          |     |-- ctm_client.get_job_status()   GET /run/job/{jobId}/status
    |                                          |     |-- ctm_client.get_job_output()   GET /run/job/{jobId}/output?runNo=<run_counter>
    |                                          |     |-- ctm_client.get_job_log()      GET /run/job/{jobId}/log
    |                                          |     '-- build_ctm_monitoring_url()    <-- shared, imported (no HTTP call)
    |                                          |-- save_job_report()
    |                                          |     '-> data/job_reports/<alert_id>.json
    |                                          '-- mark_alert_read() (once job_log was captured)
    |                                                |-- ctm_client.update_alert()      POST /run/alerts       (sets comment)
    |                                                '-- ctm_client.set_alert_status()  POST /run/alerts/status (status=Reviewed)
    |
    '-- Step 2 --.
                  v
            src/ctm_to_snow_incident.py
                  |-- parse_ctm_args_to_json() / describe_ctm_lifecycle() / classify_alert()
                  |-- load_alert_tracking() (data/alert_tracking.json)
                  |-- resolve_route()
                  |-- get_oauth_token()
                  |-- create_incident() / find_open_incident_by_correlation() / resolve_incident()
                  |-- add_worklog()
                  '-- load_job_report()  <-- best-effort READ of data/job_reports/<alert_id>.json,
                        |                    not a call into ctm_client.py or the Control-M AAPI
                        '-- add_job_report_worklogs()  (monitoring link + status + log + output,
                                                         each its own worklog entry)
                  |
                  v
            ServiceNow (Table API: incident, sys_user_group, cmdb_ci_service_business)
```

`config/mapping.json` itself is generated, not hand-written:

```text
config/mapping_source.json   (you edit this: plain ServiceNow names)
         |
         v
setup_resolve_mapping.py     (one-time: looks each name up in ServiceNow)
         |
         v
config/mapping.json          (generated: names + resolved sys_ids, gitignored)
```

## Files in this example

| Path | What it is |
| ---- | ---------- |
| [`src/ctm_alerts.sh`](src/ctm_alerts.sh) | The single wrapper Control-M/EM calls - early-exit filter, then Step 1 (job report, time-boxed) and Step 2 (incident). See [`docs/ctm_alerts_sh.md`](docs/ctm_alerts_sh.md). |
| [`src/ctm_job_report.sh`](src/ctm_job_report.sh) | Wrapper for the job report pipeline - own log file, own dedup ledger. Invoked by `ctm_alerts.sh`; also runs standalone. See [`docs/ctm_job_report_sh.md`](docs/ctm_job_report_sh.md). |
| [`src/ctm_to_snow_incident.py`](src/ctm_to_snow_incident.py) | Incident pipeline: alert -> classify -> route -> create/update/resolve incident + worklog. See [`docs/ctm_to_snow_incident.md`](docs/ctm_to_snow_incident.md). |
| [`src/ctm_job_report.py`](src/ctm_job_report.py) | Job report pipeline: job alert -> Control-M job status/log/output -> local JSON report. See [`docs/ctm_job_report.md`](docs/ctm_job_report.md). |
| [`src/ctm_client.py`](src/ctm_client.py) | Minimal Control-M Automation API client (plain `requests`, no SDK) used only by the job report pipeline. See [`docs/ctm_client.md`](docs/ctm_client.md). |
| [`src/setup_resolve_mapping.py`](src/setup_resolve_mapping.py) | One-time helper: resolves the plain names in `mapping_source.json` to sys_ids and writes `mapping.json`. See [`docs/setup_resolve_mapping.md`](docs/setup_resolve_mapping.md). |
| [`src/test_ctm_to_snow_incident.py`](src/test_ctm_to_snow_incident.py) / [`src/test_ctm_job_report.py`](src/test_ctm_job_report.py) | stdlib `unittest` suites - no live ServiceNow or Control-M needed. |
| [`src/config/.env.example`](src/config/.env.example) | Copy to `src/config/.env` - ServiceNow + Control-M AAPI connection details. |
| [`src/config/mapping_source.json`](src/config/mapping_source.json) | The routing rules you edit (plain ServiceNow names). Ships with a `ZZM* -> Secure Data Transfer` demo rule plus a `*` catch-all. |
| [`src/sample/`](src/sample/) | Real captured Control-M alert samples, used by both test suites. |
| [`docs/`](docs/) | Per-script deep-dive documentation - the design decisions behind each script, cross-referenced from the code. |
| [`postman/Control-M Automation API.postman_collection.json`](postman/Control-M%20Automation%20API.postman_collection.json) | The five Control-M AAPI calls `ctm_client.py` makes (job status/output/log, update alert, set alert status), as runnable requests. |
| `src/data/` | Created at runtime: the two dedup ledgers and `job_reports/<alert_id>.json`. Gitignored. |

`postman/` covers only the **Control-M** side. The **ServiceNow** calls are
the standard Table API, already shipped as runnable requests with the
[AI ServiceNOW example](../../4-ai-job-type-examples/service-now-incident/postman) -
see **ServiceNow Table API reference** below.

## Setup (in order)

1. **Python environment**
   ```bash
   cd src
   python3 -m venv .venv
   .venv/bin/pip install -r ../requirements.txt
   ```

2. **ServiceNow connection** - copy `src/config/.env.example` to
   `src/config/.env` and fill in `SERVICENOW_INSTANCE`,
   `SERVICENOW_CLIENT_ID`, `SERVICENOW_CLIENT_SECRET`,
   `SERVICENOW_CALLER_ID`. Requires a ServiceNow OAuth Client Credentials
   application and a service account with the `itil` role (incident
   create/write) and `service_viewer` role (read access to
   `cmdb_ci_service_business` - a role check, not a guess; see
   [`docs/snow_api_calls.md`](docs/snow_api_calls.md)).

3. **Control-M AAPI connection** (only needed for the job report pipeline) -
   in the same `src/config/.env`, fill in `CONTROLM_URL` (including the
   `/automation-api` path) and `CONTROLM_API_KEY`. If left unset, the job
   report pipeline still runs but writes reports containing only the raw
   alert - see [`docs/ctm_job_report.md`](docs/ctm_job_report.md). Optionally
   set `CONTROLM_DEBUG=true` to have `ctm_client.py` log every AAPI
   request/response verbatim (see [`docs/ctm_client.md`](docs/ctm_client.md)).

4. **Routing rules** - edit `src/config/mapping_source.json` with your real
   ServiceNow group and Business Service names (plain English, no IDs), then:
   ```bash
   cd src && .venv/bin/python setup_resolve_mapping.py
   ```
   This generates `src/config/mapping.json` with the resolved sys_ids.
   Re-run any time `mapping_source.json` changes.

5. **Deploy both wrappers** - place `ctm_alerts.sh` and `ctm_job_report.sh`
   side by side where Control-M/EM expects them, update the paths at the top
   of each script to match your deployment, and add the required `sudoers`
   entries for **both** (see [`docs/ctm_alerts_sh.md`](docs/ctm_alerts_sh.md)
   and [`docs/ctm_job_report_sh.md`](docs/ctm_job_report_sh.md) - they need
   separate entries). Configure Control-M/EM's alert action
   (`XAlertsSend2Script` / `SendAlarmToScript` / `SendRequestToScript` etc.)
   to point at `ctm_alerts.sh` **only** - it runs `ctm_job_report.sh` itself
   as its first step. Do not also register `ctm_job_report.sh` directly with
   EM, or the job report pipeline runs twice per alert.

6. **Test without live Control-M** - run either test suite (no network), or
   set `SNOW_CTM_DEMO_MODE=true` / `CTM_JOB_REPORT_DEMO_MODE=true` in
   `.env` and run the corresponding script with no arguments to fire the
   built-in sample alert end to end against your real instances.

## Testing

```bash
cd src
.venv/bin/python test_ctm_to_snow_incident.py
.venv/bin/python test_ctm_job_report.py
```

Pure logic tests against the real captured Control-M alert samples in
`src/sample/` - no network calls, no live ServiceNow or Control-M instance
required. Between the two suites: argument parsing (including real
whitespace/omitted-token quirks confirmed against production data), routing
resolution, alert classification, correlation ID construction, payload
construction, and the job report pipeline's fetch-degradation and
alert-type-gating behavior.

Neither suite tests the live HTTP calls themselves - use the Postman
collections to exercise those against your own instances first: the
Control-M AAPI calls (job status/output/log, alert update/status) are in
[`postman/Control-M Automation API.postman_collection.json`](postman/Control-M%20Automation%20API.postman_collection.json),
and the ServiceNow calls are in the AI ServiceNOW example's collection (see
**ServiceNow Table API reference** below).

## Deep-dive docs

| Doc | Covers |
| --- | ------ |
| [`docs/ctm_alerts_sh.md`](docs/ctm_alerts_sh.md) | The EM entry point: early-exit filtering, `sudo -u` vs `su -c`, exit-code propagation, logging. |
| [`docs/ctm_job_report_sh.md`](docs/ctm_job_report_sh.md) | The job report wrapper and its separate `sudoers` entries. |
| [`docs/ctm_to_snow_incident.md`](docs/ctm_to_snow_incident.md) | Argument parsing, alert lifecycle gating, classification, routing, worklog enrichment. |
| [`docs/ctm_job_report.md`](docs/ctm_job_report.md) | Why it's a separate script, fetch degradation, `mark_alert_read()`, the cross-launch monitoring link. |
| [`docs/ctm_client.md`](docs/ctm_client.md) | Why plain `requests` and not the `controlm_py` SDK; the five AAPI calls; `CONTROLM_DEBUG`. |
| [`docs/setup_resolve_mapping.md`](docs/setup_resolve_mapping.md) | The one-time name -> sys_id resolution and the `_do_not_edit` marker. |
| [`docs/snow_api_calls.md`](docs/snow_api_calls.md) | Every ServiceNow HTTP call **this project** makes, in order, with payloads and the required OAuth roles. |
| [`docs/ctm_alert_order.md`](docs/ctm_alert_order.md) | The global Step 0-7 pipeline numbering with real captured request/response samples. |

## ServiceNow Table API reference

This project and the
[`4-ai-job-type-examples/service-now-incident`](../../4-ai-job-type-examples/service-now-incident)
example hit the **same standard ServiceNow Table API** - OAuth client-
credentials token, then `POST` / `PATCH` / `GET` on `/api/now/table/incident`
and the lookup tables. They are two front ends over one API, so there is
**no ServiceNow Postman collection in this folder** (only the Control-M AAPI
one) - use the ServiceNow collection from the AI ServiceNOW example:

| | This project | AI ServiceNOW job type |
| --- | --- | --- |
| Trigger | script called by Control-M/EM for every alert | Application Integrator job ordered in a folder |
| ServiceNow calls it makes | [`docs/snow_api_calls.md`](docs/snow_api_calls.md) | [README -> *ServiceNow API calls*](../../4-ai-job-type-examples/service-now-incident/README.md#servicenow-api-calls) |
| Runnable ServiceNow Postman requests | *(none here)* -> use the AI job's collection | [`postman/ServiceNow Incident Integration.postman_collection.json`](../../4-ai-job-type-examples/service-now-incident/postman/ServiceNow%20Incident%20Integration.postman_collection.json) |

That collection's requests (OAuth, create / update / worklog / resolve,
choice-list lookups) are exactly the calls this project makes. Two
differences on the lookup side, both covered in
[`docs/snow_api_calls.md`](docs/snow_api_calls.md):

- **`setup_resolve_mapping.py` resolves Business Service names against
  `cmdb_ci_service_business`**, not the `cmdb_ci_service` table the AI job's
  load button queries - swap the table name in the "List Business Services"
  request.
- **The agent-back resolve does a `correlation_id` lookup**
  (`GET incident?sysparm_query=correlation_id=<id>^active=true^state!=6`) with
  no equivalent in the AI job's collection - build it from the "Find Incident
  by Number" request by changing the query.

`docs/snow_api_calls.md` here is scoped to exactly what the scripts do
(create with routed `assignment_group` + `cmdb_ci`, appending `work_notes`
worklogs, correlation-ID lookup, agent-back resolve). For ServiceNow-side
detail this project doesn't exercise - the design-time load-button lookups,
the `impact`/`urgency`/`state`/`close_code` choice-list values, the
`close_code` + `close_notes` business rules on resolve, and full sample
request/response bodies - see the **ServiceNow API calls** section of the
[AI ServiceNOW README](../../4-ai-job-type-examples/service-now-incident/README.md#servicenow-api-calls).

## Known limitations and scope

This is a demo/reference implementation. Deliberately out of scope:

- **No retry logic, no archival, no logging framework** - if ServiceNow or
  Control-M is briefly unreachable, the alert (or job report) is simply not
  processed; nothing queues or retries it beyond Control-M's own alert
  redelivery.
- **Only three alert types are handled by the incident pipeline**: job
  failures, agent unavailable, agent available. Server disconnection alerts,
  Control-M "x-alerts", and any other alert shape are recognised as out of
  scope, logged, and skipped.
- **The job report pipeline only acts on job alerts.** Agent and other alert
  types are a clean no-op there.
- **No bi-directional sync.** The ServiceNow incident number is never
  written back to Control-M, so there is no way to update or annotate an
  incident from a later Control-M-side action beyond the specific
  agent-available -> resolve-incident flow this project builds via
  `correlation_id` matching.
- **The worklog integration is a one-way, best-effort file read, not real
  coupling.** `ctm_to_snow_incident.py` reads whatever
  `data/job_reports/<alert_id>.json` happens to contain when it runs - if
  `ctm_job_report.sh` timed out, failed, or hasn't run yet for this
  `alert_id`, the incident is still created, just without the extra worklog
  entries.
- **Control-M/EM re-invokes `ctm_alerts.sh` for its own echoes.** Marking an
  alert read is itself an alert change that EM sends back as a
  `call_type='U'` update. `ctm_alerts.sh` filters these out before starting
  either pipeline, but you may still see extra (harmless, no-op) invocations
  in your logs per real alert.
- **Routing is Application-prefix only.** Agent alerts have no `application`
  field and always fall through to the catch-all (`"*"`) rule.
- **Single ServiceNow instance, single Control-M source.** No multi-tenancy,
  no per-data-center instance selection.
