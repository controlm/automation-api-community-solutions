# Postman collection

[`src/postman/Workload PreFlight Check.postman_collection.json`](../src/postman/Workload%20PreFlight%20Check.postman_collection.json) — the same Automation API calls the scripted implementations ([`ctm-preflight.ps1`](CTM_PREFLIGHT_PS1.md), [`ctm_engineer.py`](CTM_ENGINEER.md)) automate, exposed one request at a time. Best for manual, ad hoc checks, or for exploring/demoing the underlying API calls without writing any code — the fastest way to see exactly what the API is doing before you commit to a scripted version.

## Setup

Import the collection into Postman, then set these collection or environment variables:

| Variable | Description |
|---|---|
| `baseUrl` | Control-M Automation API base URL, e.g. `https://your-ctm-em/automation-api` |
| `apiKey` | Automation API key, sent as the `x-api-key` header |
| `CTM_SERVER` | Control-M/Server name the folder is deployed to |
| `CTM_FOLDER` | Folder to check, e.g. `ZZM_UC_MULTIPATH_CLOUD` |
| `CTM_EM` | Enterprise Manager name (used by some requests' path variables) |
| `CTM_JOB` | A specific job name, for requests scoped to one job |
| `CTM_AGENT` | Agent nodeid, for the agent-test and connection-profile-test requests |
| `CTM_HOSTGROUP` | Host Group name, for the agents-in-hostgroup request |
| `CTM_CCP_TYPE` | Connection profile type, e.g. `FileTransfer` |
| `CTM_CCP_NAME` | Connection profile name |

## Requests, in the order to run them

The `resources` folder walks the same dependency chain the scripts automate — each step's output feeds the next request's path variables:

| # | Folder | Request | Call |
|---|---|---|---|
| 1 | `resources/jobs` | Get deployed jobs that match the search criteria | `GET /deploy/jobs?format=json&folder={{CTM_FOLDER}}&server={{CTM_SERVER}}&useArrayFormat=true` — find each job's `Host` (Host Group) and, for File Transfer jobs, its connection profile names |
| 2 | `resources/servers` | get all the Servers name and hostname in the system | `GET /config/servers` |
| 3 | `resources/agents` | get hostgroup agents | `GET /config/server/:server/hostgroup/:hostgroup/agents` — resolve a job's Host Group to its member agents |
| 4 | `resources/agents` | Test the Agent connectivity to the server | `POST /config/server/:server/agent/:agent/test` — Control-M's own "Test Availability" check |
| 5 | `resources/connectionprofile` | Test connection profile centralized on agent | `POST /deploy/connectionprofile/centralized/test/:type/:name/:server/:agent` — Control-M's own "Test Centralized Connection Profile" check |

A top-level `Stage 01` folder also has a standalone "Get deployed folder status" request (the same call as step 1) for a quick one-off folder lookup without walking the full chain.

## What you learn from this vs. the scripts

Running these by hand shows exactly which API call each piece of the automated checks maps to, and lets you inspect a single job/agent/connection-profile's raw response before deciding whether an automated check (PS1 or Python) needs adjusting for your environment — e.g. confirming a connection profile's exact `type` string, or what a failing agent test's response body actually looks like. It doesn't produce a report or an exit code; for that, use [`ctm-preflight.ps1`](CTM_PREFLIGHT_PS1.md) or [`ctm_engineer.py`](CTM_ENGINEER.md).
