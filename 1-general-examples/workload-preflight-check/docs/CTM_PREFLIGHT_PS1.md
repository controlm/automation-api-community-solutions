# ctm-preflight.ps1

PowerShell 7 implementation of the workload preflight check — see the [project README](../README.md) for the "why". Best suited to scheduling before a run, wiring into CI/CD or an orchestrator, or any scripted/automated use: it produces a JSON report and a script-friendly exit code.

## Prerequisites

- PowerShell 7+ (`pwsh`)
- Network access to the Control-M Automation API Gateway, plus outbound ICMP/TCP if you want SFTP endpoints network-tested
- An Automation API key with read access to Deploy and Configuration services

## Configuration

Create `.engineer/config/.env` next to the script (a `.env.sample` is provided), or pass `-EnvFile` to point elsewhere:

| Key | Required | Description |
|---|---|---|
| `baseUrl` | Yes | Control-M Automation API base URL, e.g. `https://your-ctm-em/automation-api` |
| `apiKey` | Yes | Automation API key, sent as the `x-api-key` header |
| `CTM_SERVER` | Yes | Control-M/Server name the folder is deployed to |
| `SFTP_PORT` | No (default `22`) | Used only when an SFTP connection profile has no explicit `Port` |
| `FTP_PORT` | No (default `21`) | Reserved for future use |
| `MFT_PORT` | No (default `1222`) | Reserved for future use |
| `LOG_FOLDER` | No (default `.engineer/logs`) | Where the JSON report is written, relative to the script's location |

## Usage

```bash
./ctm-preflight.ps1 -Folder ZZM_UC_MULTIPATH_CLOUD
```

```bash
./ctm-preflight.ps1 -Folder ZZM_UC_MULTIPATH_CLOUD -EnvFile /path/to/other.env
```

## Output modes

The `-Output` parameter controls what's printed to the console. The JSON report file is **always** written to `LOG_FOLDER`, in every mode.

| Mode | Behavior |
|---|---|
| `verbose` (default) | Full human-readable report: per-job progress, summary, color-coded table, unique-resources-tested breakdown, then the JSON report path |
| `json` | Prints only the JSON report content to stdout — nothing else. Useful for piping into `jq` or another tool |
| `file` | Prints only the path to the JSON report file — nothing else |

```bash
./ctm-preflight.ps1 -Folder ZZM_UC_MULTIPATH_CLOUD -Output json | jq '.CcpFailures'
./ctm-preflight.ps1 -Folder ZZM_UC_MULTIPATH_CLOUD -Output file
```

## JSON report schema

Written to `{LOG_FOLDER}/ctm_preflight_{Folder}_{yyyyMMdd_HHmmss}.json`:

| Field | Description |
|---|---|
| `Folder`, `Server`, `RunTimestamp` | Run identification |
| `TotalJobs` | Jobs found in the folder (all types) |
| `AgentTestableJobs` | Jobs that had a `Host` and were actually agent-tested (excludes `SKIPPED`) |
| `AgentFailures` | Count of jobs whose agent test failed |
| `CcpFailures` | Count of `Job:FileTransfer` jobs with a failing source and/or destination connection profile |
| `NetEndpointsTested` / `NetEndpointFailures` | SFTP network (ping/port) test counts |
| `NetTestDisclaimer` | Restates the network-test limitation from the project README |
| `Jobs[]` | One entry per job: `Job`, `Type`, `Hostgroup`, `Agent`, `AgentStatus`/`AgentMessage`, `CcpSrcName`/`CcpSrcStatus`/`CcpSrcMessage`, `CcpDestName`/`CcpDestStatus`/`CcpDestMessage`, `NetSrcHost`/`NetSrcPingStatus`/`NetSrcPortStatus`/`NetSrcNote`, `NetDestHost`/`NetDestPingStatus`/`NetDestPortStatus`/`NetDestNote`, `TestedAt` |

Status values are one of `OK`, `ERROR`, or `SKIPPED`.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | No agent or connection-profile failures |
| `1` | At least one agent or connection-profile failure, or the initial job retrieval from Control-M failed |

SFTP network-test failures do **not** affect the exit code, since that check is informational only — check `NetEndpointFailures` in the JSON report if you need to gate on it separately.
