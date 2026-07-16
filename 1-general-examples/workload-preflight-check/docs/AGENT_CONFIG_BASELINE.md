# agent_config_baseline.py

Compares an agent's live configuration parameters (`CtmClient.get_agent_params()`) against an approved "golden" baseline, and reports anything missing or different. A companion to [`ctm_engineer.py`](CTM_ENGINEER.md) (imports its `CtmClient`/`build_client`/logging setup) but deliberately a separate script — "does this agent's config match our approved baseline" is a compliance/drift check against a stored reference, a different kind of question from `--folder`'s live connectivity/test checks.

## Why per-platform goldens, not one universal template

Windows and Linux agents return substantially different parameter sets — confirmed directly: `ctm-win-agt.werkstatt.local`'s `AGENT_DIR` is `D:\Programs\BMC\Control-M Agent\Default\`, `ctm-lin-agt.werkstatt.local`'s is `/opt/ctmag/ctm`, and the two platforms simply don't share the same parameter catalog beyond a common core. A single golden with a big ignore-list would fight that difference rather than model it, so each platform gets its own golden file.

## Storage

```text
.engineer/config/golden/
  linux.json           # golden baseline for Linux agents in general
  linux_mfte.json       # golden baseline for Linux agents in an MFTE-heavy role (optional, via -t mfte)
  linux_sap.json         # golden baseline for Linux agents in a SAP-integration role (optional, via -t sap)
  windows.json          # golden baseline for Windows agents in general
  ignore_params.json    # parameter names excluded from every comparison (node-specific)
```

Each golden file holds the full output of `get_agent_params()` for whichever agent was captured as the approved reference, plus capture metadata (`platform`, `category`, `source_agent`, `source_operating_system`, `server`, `captured_at`).

Platform is auto-detected from the agent's reported `operatingSystem` (`"windows"` if that substring appears, else `"linux"`) — if an agent has no `operatingSystem` reported at all (e.g. Control-M hasn't identified it yet), the tool refuses to guess and asks for `--platform` explicitly instead of silently comparing against the wrong platform's golden.

`-t`/`--category` adds an optional second dimension beyond platform, for agent roles whose expected config differs from the platform's general baseline (an MFTE-heavy Linux agent vs. a general-purpose one, a SAP-integration agent, etc.) — `-t mfte` reads/writes `linux_mfte.json` instead of `linux.json`. Left out, both `capture` and `compare` use the plain `{platform}.json` file — this is fully backward compatible, existing goldens captured without `-t` are unaffected.

## Node-specific parameters

Some parameters legitimately differ per agent even on the same platform — right now just `AGENT_DIR` (the install path), in `ignore_params.json`. This is a **starting point, not an exhaustive list** — there was no way to enumerate every node-specific parameter without more real agent data across more nodes. Add to `ignore_params.json` as you discover more through actual use; it's a plain JSON list of parameter names, no code changes needed:

```json
["AGENT_DIR"]
```

## Usage

On `capture` and `compare`, `-n`/`--nodeid` takes the agent name — Control-M's own term for it (the `"nodeid"` field in `get_agents()`'s results). `-h`/`--help` behaves normally on every subcommand.

On `compare`, `-n`/`--nodeid` and `-g`/`--group` are mutually exclusive — pick one target per run.

Capture a golden baseline from a known-good agent:

```bash
python agent_config_baseline.py capture -n ctm-lin-agt.werkstatt.local
python agent_config_baseline.py capture -n ctm-lin-agt.werkstatt.local --platform linux --force  # overwrite an existing golden
python agent_config_baseline.py capture -n ctm-mfte-agt.werkstatt.local -t mfte                  # saves as linux_mfte.json
```

Compare another agent's live config against its platform's (and, if given, category's) golden:

```bash
python agent_config_baseline.py compare -n ctm-lin-agt.werkstatt.local
python agent_config_baseline.py compare -n ctm-lin-agt.werkstatt.local --output json
python agent_config_baseline.py compare -n ctm-mfte-agt.werkstatt.local -t mfte                  # compares against linux_mfte.json
```

Sample output:

```text
=== Agent Config Baseline: 'ctm-lin-agt.werkstatt.local' vs 'linux' golden ===
Golden: .engineer/config/golden/linux.json

Missing parameters: 0
Different parameters: 2
Extra parameters: 1
Ignored (node-specific): 1

Different:
  - ATCMNDATA: golden='9999' actual='7005' [Comm [ctm-lin-srv.werkstatt.local]]
  - SSL_CONTEXT_VALIDATION_DAYS: golden='999' actual='7' [Maintenance]

Extra (on this agent, not in golden):
  - RU_COMM_PORT = '8000' [Comm]
```

Reuses `ctm_engineer.py`'s color-coding (`_color_enabled`/`_colorize`) for consistency with the `--folder` preflight report. Color is applied narrowly — only to the parameter name and its golden/actual value, never to surrounding text, punctuation, or the BMC category label — so a missing/different/extra line reads as plain text with just those two tokens picked out: **the parameter name** is red (missing), yellow (different/extra); **the golden value** is always purple; **the actual/live value** is always light blue. Count lines (`Missing parameters: N`, etc.) color just the number — green when zero, red/yellow otherwise. In the `-g`/`--group` table, only the rightmost **Status** column is colored (`OK` green, `ERROR` red) — the numeric Missing/Different/Extra columns stay plain so fixed-width alignment isn't broken by ANSI codes.

## Comparing a whole hostgroup at once (`-g`/`--group`)

Rather than one `-n` call per node, `-g`/`--group` compares every agent in a hostgroup against its golden baseline in a single run:

```bash
python agent_config_baseline.py compare -g ZZM_AGT_01
python agent_config_baseline.py compare -g ZZM_AGT_01 --output json
```

`-g` is resolved via `CtmClient.resolve_host` — the same hostgroup/agent/Agentless-Host resolution logic `--folder`'s preflight check uses — so it also works transparently if you pass a bare agent name or an Agentless Host instead of a literal Host Group. `--platform`/`-t`, if given, apply uniformly to every agent in the group (comparing all of them against the same golden); left out, each agent auto-detects its own platform independently.

Sample output:

```text
=== Agent Config Baseline: 'XYSTEM_LIN' (hostgroup, 7 agent(s)) ===

Agent                            Platform   Missing   Different   Extra   Status
lmbrjck-strix-lin.werkstatt.loca -          -         -           -       ERROR
ctm-lin-agt.werkstatt.local      linux      0         0           0       OK
ctm-lin-em.werkstatt.local       linux      0         2           0       ERROR

Total missing: 2
Total different: 7
Total errors: 1

lmbrjck-strix-lin.werkstatt.local:
  - failed to fetch live config: Failed to propagate a request to CONTROL-M/Agent lmbrjck-strix-lin.werkstatt.local code:16
NodeID is not available

ctm-lin-em.werkstatt.local (linux):
  - DIFFERENT CTMPERMHOSTS: golden='ctm-lin-srv|ctm-lin-srv.werkstatt.local' actual='ctm-lin-srv.werkstatt.local|ctm-lin-srv' [Comm [ctm-lin-srv.werkstatt.local]]
  - DIFFERENT TRACKER_EVENT_PORT: golden='31516' actual='7292' [Tracking]
```

A single unreachable or misconfigured agent (down, no `operatingSystem` reported yet, etc.) does **not** abort the whole group's report — it shows as an `ERROR` row with its failure reason printed in the detail section below the table, while every other agent in the group still gets compared and reported normally. `Total errors` (only printed when non-zero) counts these separately from `Total missing`/`Total different`, and any of the three being non-zero fails the exit code — a group with nothing but one unreachable agent still exits 1, since an agent that couldn't be checked at all isn't a clean pass.

`compare --output json` for a group returns `{group, resolved, error, results: [...]}`, where each entry in `results` is a `compare_to_golden`-shaped dict (an agent that failed to fetch has its `error` field set and empty `missing`/`different`/`extra`/`ignored` lists).

## Exit codes and what counts as a real problem

| Category | Meaning | Affects exit code? |
| --- | --- | --- |
| Missing | In the golden, absent from this agent | Yes (exit 1) |
| Different | Present in both, values don't match | Yes (exit 1) |
| Extra | On this agent, not in the golden | No — informational only. A newer agent version could plausibly add parameters the golden's source agent didn't have; more config isn't automatically a violation the way missing/different config is. |
| Ignored | Node-specific, excluded from comparison entirely | No — not reported as a finding at all, just a count |
| Error (`-g`/`--group` only) | An agent in the group couldn't be fetched/compared at all (unreachable, no platform detected, etc.) | Yes (exit 1) — an agent that couldn't be checked isn't a clean pass |

`compare --output json` returns the same categorization as a structured dict — `{agent, platform, category, golden_path, error, missing, different, extra, ignored}` — for piping into other tooling.

## Report output

`compare` behaves the same as `ctm_engineer.py --folder`: a JSON report is **always** written to `LOG_FOLDER` (`.engineer/logs/` by default, or the `.env`'s `LOG_FOLDER` if set), regardless of `--output` — console output is just a view onto it, not the only place the result goes.

| `--output` | Console shows | Report file |
| --- | --- | --- |
| `verbose` (default) | Full human-readable report, plus the report path on the last line | Always written |
| `json` | Only the JSON report content | Always written |
| `file` | Only the report file's path | Always written |

Report filenames: `ctm_agent_baseline_{agent-or-group}_{yyyyMMdd_HHmmss}.json` — for a single agent it's the full compare dict, for `-g`/`--group` it's the group dict (`{group, resolved, error, results}`).
