# ServiceNow API calls

Every HTTP call the integration makes to ServiceNow, in the order the
incident pipeline makes them. All of it is plain REST against a standard
ServiceNow instance - OAuth token endpoint plus the Table API
(`/api/now/table/...`). No scripted REST resource, no Import Set, no
custom endpoint.

Source of truth: `src/ctm_to_snow_incident.py` (runtime) and
`src/setup_resolve_mapping.py` (one-time name -> sys_id resolution).

> **Runnable requests + related reference.** This project's `postman/`
> folder holds only the Control-M AAPI collection, not a ServiceNow one -
> the
> [`4-ai-job-type-examples/service-now-incident`](../../../4-ai-job-type-examples/service-now-incident)
> example drives the **same** Table API from an Application Integrator job
> type, and its
> [`postman/ServiceNow Incident Integration.postman_collection.json`](../../../4-ai-job-type-examples/service-now-incident/postman/ServiceNow%20Incident%20Integration.postman_collection.json)
> has the OAuth / create / update / worklog / resolve / choice-list
> requests as runnable calls. Two lookup-side differences for this project,
> both detailed below: the Business Service lookup is against
> `cmdb_ci_service_business` (call 2), not `cmdb_ci_service`, and the
> agent-back flow adds a `correlation_id` incident lookup (see *Related
> calls*). That README's *ServiceNow API calls* section also covers what
> this project doesn't exercise - the design-time load-button lookups, the
> `impact` / `urgency` / `state` / `close_code` choice-list values, the
> `close_code` + `close_notes` business rules on resolve, and full sample
> request/response bodies.

Conventions used below:

- `{instance}` - `SERVICENOW_INSTANCE` from `config/.env` (the bare
  instance name, e.g. `dev00000`).
- `{token}` - the `access_token` from call 1.
- Base host is always `https://{instance}.service-now.com`.

---

## 1. Login - OAuth token (client credentials)

`get_oauth_token()` - logged as **Step 4: SNOW Get OAuth Token**.

```
POST https://{instance}.service-now.com/oauth_token.do
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
client_id={SERVICENOW_CLIENT_ID}
client_secret={SERVICENOW_CLIENT_SECRET}
```

- No `Authorization` header on this call - the client id/secret in the
  form body *are* the credential.
- Grant type is **client_credentials**, not `password` - there is no
  ServiceNow user in this exchange. The account behind the OAuth
  application still needs the roles listed below; the incident's "caller"
  is a separate concept (`caller_id`, see call 3).

**Success - HTTP 200**

```json
{
  "access_token": "abcd1234....",
  "token_type": "Bearer",
  "expires_in": 1800,
  "scope": "useraccount"
}
```

Only `access_token` is used. It is passed as `Authorization: Bearer
{token}` on every subsequent call. The script never refreshes it - one
token per run, and a run makes only a handful of calls well inside the
30-minute default lifetime. The token is redacted in logs even at `-v`.

**Failure** - any non-200 aborts the run (`RuntimeError`), as does a 200
with no `access_token` in the body.

### Required roles on the OAuth account

| Role | Why |
|---|---|
| `itil` | create + update `incident` |
| `service_viewer` | read `cmdb_ci_service_business` during setup (call 2) |

`service_viewer` is a real requirement, not a guess - without it the
Business Service lookup in `setup_resolve_mapping.py` returns an empty
result set rather than a 403, which looks like a misspelled name.

---

## 2. Resolve names -> sys_ids (one-time, setup only)

`lookup_sys_id()`, called by `setup_resolve_mapping.py` - **not** on the
per-alert hot path. This is how the human-readable assignment group and
Business Service names in `config/mapping_source.json` become the sys_ids
that call 3 actually sends. Runtime reads the resolved sys_ids straight
out of `config/mapping.json`; it never does this lookup itself (that was
tried and reverted - see `docs/setup_resolve_mapping.md`).

```
GET https://{instance}.service-now.com/api/now/table/{table}
      ?sysparm_query=name={name}
      &sysparm_fields=sys_id,name
      &sysparm_limit=2
Authorization: Bearer {token}
Accept: application/json
```

| Mapping field | `{table}` | Incident field it feeds |
|---|---|---|
| `assignment_group_name` | `sys_user_group` | `assignment_group` |
| `cmdb_ci_name` | `cmdb_ci_service_business` | `cmdb_ci` |

- `sysparm_limit=2` is deliberate - the code only needs to know whether
  more than one record matches. Two hits -> it uses the first and logs a
  warning; zero hits -> empty sys_id and a warning to check spelling/case.

**Success - HTTP 200**

```json
{ "result": [ { "sys_id": "0c43a...e91", "name": "Secure Data Transfer" } ] }
```

A broader `GET .../sys_user_group` / `GET .../cmdb_ci_service_business`
(filtered only by `active=true`, returning `name,sys_id` for every row) is
handy for eyeballing the available names when a lookup keeps coming back
empty - the AI job's Postman collection has these as "List Assignment
Groups" / "List Business Services" (change its `cmdb_ci_service` to
`cmdb_ci_service_business`).

---

## 3. Create incident (with assignment group + business service)

`create_incident()` - logged as **Step 5: SNOW Create Incident**.

```
POST https://{instance}.service-now.com/api/now/table/incident
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json

{
  "short_description": "ZZM PreFlight Check: Ended not OK (Alert 2256)",
  "caller_id": "{SERVICENOW_CALLER_ID}",
  "urgency": "1",
  "impact": "1",
  "assignment_group": "0c43a...e91",
  "cmdb_ci": "b7e22...4af",
  "correlation_id": "ctm-lin-srv:ctm-lin-agt.werkstatt.local"
}
```

Payload construction:

| Field | Value |
|---|---|
| `short_description` | `"{job_name}: {message} (Alert {alert_id})"`, or `"{message} (Alert {alert_id})"` when there is no job name (agent alerts) |
| `caller_id` | `SERVICENOW_CALLER_ID` sys_id from `.env`, verbatim |
| `urgency` / `impact` | `"1"` when the Control-M `severity` is `V`, else `"3"` |
| `assignment_group` | routed sys_id - **omitted from the payload entirely** if the matched rule has no `assignment_group_sys_id` |
| `cmdb_ci` | routed Business Service sys_id - **omitted** if the matched rule has no `cmdb_ci_sys_id` |
| `correlation_id` | only for agent alerts (`data_center:host_id`), used later to find the incident to resolve; absent for job alerts |

**Routing** (`resolve_route()`): the Control-M `application` field is
matched case-insensitively against the ordered rule list in
`config/mapping.json`, first match wins, `pattern: "*"` is the catch-all.
Agent alerts have no `application` and always hit the catch-all. A rule
match yields both the `assignment_group` and `cmdb_ci` sys_ids together
(or blanks, which drop the corresponding key).

**Success - HTTP 201**

```json
{
  "result": {
    "sys_id": "9a8b7c6d5e4f...",
    "number": "INC0012345",
    "assignment_group": { "link": "https://.../sys_user_group/0c43a...e91", "value": "0c43a...e91" },
    "cmdb_ci":          { "link": "https://.../cmdb_ci/b7e22...4af",        "value": "b7e22...4af" },
    ...50+ more fields...
  }
}
```

`result.sys_id` and `result.number` are kept; the rest is logged only at
`-v`. **Anything other than 201 aborts the run.** A one-line
`CTM_EM_INCIDENT_JSON: {...}` summary (number, sys_id, the two routed
sys_ids, urgency/impact, caller) is always printed for Control-M EM's log.

> Reference fields (`assignment_group`, `cmdb_ci`, `caller_id`) accept a
> bare sys_id string on write. ServiceNow returns them as
> `{link, value}` objects on read - that is why the code reads
> `result.get("sys_id")` and not the reference objects.

---

## 4. Add worklog entries

Worklog entries are added by **PATCH-ing the incident** and setting
`work_notes` (a journal field - each PATCH *appends* one entry, it does
not overwrite). There is no separate `sys_journal_field` call.

### 4a. Base worklog - `add_worklog()`, **Step 6: SNOW Add Worklog Entry**

```
PATCH https://{instance}.service-now.com/api/now/table/incident/{incident_sys_id}
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json

{
  "work_notes": "Control-M alert 2256 on job ZZM PreFlight Check\nApplication: ZZM BMC / Sub-application: ...\nHost: ctm-lin-agt.werkstatt.local | Data center: ctm-lin-srv\nMessage: Ended not OK"
}
```

**Success - HTTP 200.** A non-200 aborts the run. The code checks that
`result.sys_mod_count` incremented as confirmation the append landed.

### 4b. Job-report worklogs - `add_job_report_worklogs()`, **Step 7**

Job alerts only, and only when `data/job_reports/{alert_id}.json` exists
(written by the separate `ctm_job_report.py` pipeline). Up to **four more
PATCHes to the same URL**, one `work_notes` entry each, in this order:

1. Control-M monitoring deep link
2. Control-M job status (rendered as readable text, every field the AAPI returned)
3. Control-M job log (truncated to 4000 chars)
4. Control-M job output (truncated to 4000 chars)

Each is **best-effort**: wrapped in its own try/except, a failed or
non-200 PATCH is logged as `WARN` and does not stop the others or fail
the run - the incident already exists by this point. Sections missing
from the report file are simply skipped. The count of entries that
posted is recorded in `data/alert_tracking.json` as
`job_report_worklogs_posted`.

---

## Related calls (agent up/down flow)

Not worklog-related, but same auth and same Table API:

### Find the incident to resolve - `find_open_incident_by_correlation()`

```
GET https://{instance}.service-now.com/api/now/table/incident
      ?sysparm_query=correlation_id={id}^active=true^state!=6
      &sysparm_fields=sys_id,number
      &sysparm_limit=1
Authorization: Bearer {token}
Accept: application/json
```

`^state!=6` (exclude Resolved) is load-bearing: ServiceNow leaves
`active=true` on a Resolved incident, so `active=true` alone would keep
re-matching an already-resolved incident. No match is a normal outcome,
not an error.

### Resolve it - `resolve_incident()`

```
PATCH https://{instance}.service-now.com/api/now/table/incident/{incident_sys_id}
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json

{
  "state": "6",
  "close_code": "Solution provided",
  "close_notes": "Agent is up and running again. (Control-M Alert ID: 2258)"
}
```

**Success - HTTP 200.** These exact values (`state` 6, that `close_code`
label) were confirmed against a live instance via Postman, not assumed.

---

## Call sequence per alert type

| Alert type | Calls |
|---|---|
| Job failure | 1 -> 3 -> 4a -> 4b (x0-4) |
| Agent unavailable | 1 -> 3 (with `correlation_id`) -> 4a |
| Agent available | 1 -> find-by-correlation -> resolve (if found) |
| Out of scope / lifecycle update | none (skipped before any HTTP call) |

Setup, run once and whenever `mapping_source.json` changes: 1 -> 2 (per
name, per rule).
