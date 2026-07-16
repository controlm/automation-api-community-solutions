# Documentation index

For the "why" behind this tool, see the [project README](../README.md). This folder covers the "how" — one doc per script, notebook set, or collection, each self-contained.

## The preflight check, four ways

| Doc | Artifact | Best for |
|---|---|---|
| [`CTM_PREFLIGHT_PS1.md`](CTM_PREFLIGHT_PS1.md) | `src/ctm-preflight.ps1` (PowerShell 7) | Scheduling before a run, CI/CD, scripted/automated use |
| [`CTM_ENGINEER.md`](CTM_ENGINEER.md) | `src/ctm_engineer.py` (Python) | Same check as the PS1 script, plus a reusable `CtmClient` module for other Python tooling |
| [`AGENT_CONFIG_BASELINE.md`](AGENT_CONFIG_BASELINE.md) | `src/agent_config_baseline.py` (Python) | Comparing an agent's (or a whole hostgroup's) live config against an approved "golden" baseline — a compliance/drift check, not a live connectivity check |
| [`POSTMAN_COLLECTION.md`](POSTMAN_COLLECTION.md) | `src/postman/Workload PreFlight Check.postman_collection.json` | Manual, ad hoc checks; exploring/demoing the underlying API calls one at a time without writing any code |
| [`JUPYTER_NOTEBOOKS.md`](JUPYTER_NOTEBOOKS.md) | `src/jupyter/*.ipynb` | Interactive, whole-environment inventory and spot-checks (broader scope than a single folder's preflight check — see that doc's scope note) |

## Reference

| Doc | Covers |
|---|---|
| [`CCP_TYPES_REFERENCE.md`](CCP_TYPES_REFERENCE.md) | Catalog of every centralized connection profile type BMC documents, with the field(s) that carry an endpoint — for extending `resolve_connection_profile_endpoint` |

All four scripted/interactive implementations call the same underlying Control-M Automation API endpoints — see each doc's own "API calls used" section (or the [project README](../README.md#control-m-automation-api-calls-used) for the shared list) for specifics.
