# mfte.rule.vars.all.jsonl.sh

Captures **every** BMC Control-M MFT Enterprise Processing Rule Action variable as one structured JSON record per file-transfer event, with optional sha256 checksum and Apache Tika (mime/version/metadata) enrichment. Intended as a small, direct Control-M Run Command — short flags, one JSON object per run.

## Requirements

Sources [mfte.sh](mfte.sh.md) — inherits its hard command requirements (`jq`, `sha256sum`, `file`, `hostname`, `flock`) and its `.env` loading. Fails loudly if `MFTE_LOG_DIR`, `MFTE_JSONL_FILE`, or `MFTE_JSON_DIR` aren't set by the `.env`.

Also requires `curl` on its own — not part of `mfte.sh`'s shared requirements, since it's only needed by this script's optional Graylog forwarding (see below). Other scripts that source `mfte.sh` don't pick up `curl` as a dependency just because this one needs it.

Optional, only needed for Tika enrichment: `java` + a Tika CLI jar (`tika-app-*.jar`, tested against 3.3.1).

## Usage

```
mfte.rule.vars.all.jsonl.sh [short options]
```

| Flag | BMC variable | | Flag | BMC variable |
|---|---|---|---|---|
| `-p` | `$$FILE_PATH$$` | | `-c` | `$$COMPANY$$` |
| `-a` | `$$FILE_ABS_PATH$$` | | `-v` | `$$VIRTUAL_FOLDER$$` |
| `-d` | `$$FILE_DIR$$` | | `-m` | `$$EMAIL$$` |
| `-D` | `$$FILE_ABS_DIR$$` | | `-t` | `$$PHONE_NUMBER$$` |
| `-n` | `$$FILE_NAME$$` | | `-s` | `$$SUB_DIR_PATH$$` |
| `-N` | `$$FILE_NAME_NO_EXT$$` | | `-g` | `$$STAGING_FILE_NAME$$` |
| `-e` | `$$FILE_EXT$$` | | `-G` | `$$STAGING_FILE_PATH$$` |
| `-E` | `$$FILE_EXT_NO_DOT$$` | | | |
| `-x` | `$$FILE_DATE$$` (UTC) | | | |
| `-X` | `$$FILE_DATE_LOCAL$$` | | | |
| `-y` | `$$FILE_TIME$$` (UTC) | | | |
| `-Y` | `$$FILE_TIME_LOCAL$$` | | | |
| `-z` | `$$FILE_SIZE$$` | | | |
| `-u` | `$$USER$$` | | | |

Metadata flags (not BMC variables): `-r` rule name, `-A` action name, `-k` event type (default `file_rule_action`), `-o` output mode override (`jsonl`\|`json-file`\|`both`, default `$MFTE_LOG_FORMAT`), `-l` custom log directory override, `-T` skip all enrichment for this run, `-q` quiet (suppress stdout JSON + report), `-h` help.

### Recommended Run Command

```
mfte.rule.vars.all.jsonl.sh -r "<rule_name>" -A "<action_name>" -p "$$FILE_PATH$$" -a "$$FILE_ABS_PATH$$" -d "$$FILE_DIR$$" -D "$$FILE_ABS_DIR$$" -n "$$FILE_NAME$$" -N "$$FILE_NAME_NO_EXT$$" -e "$$FILE_EXT$$" -E "$$FILE_EXT_NO_DOT$$" -x "$$FILE_DATE$$" -X "$$FILE_DATE_LOCAL$$" -y "$$FILE_TIME$$" -Y "$$FILE_TIME_LOCAL$$" -z "$$FILE_SIZE$$" -u "$$USER$$" -c "$$COMPANY$$" -v "$$VIRTUAL_FOLDER$$" -m "$$EMAIL$$" -t "$$PHONE_NUMBER$$" -s "$$SUB_DIR_PATH$$" -g "$$STAGING_FILE_NAME$$" -G "$$STAGING_FILE_PATH$$" -q
```

**Every `$$VAR$$` token must be double-quoted, with no exceptions.** Two separate, confirmed production incidents (2026-07-09) explain why:

1. **Unquoted filenames with spaces silently truncate the entire record.** bash's `getopts` stops parsing options the instant it hits a bareword that doesn't start with `-`. An unquoted filename like `Generative AI for VSE.PPTX` splits into multiple shell words; `getopts` hits `AI` and stops — every flag after that point is never parsed. This shipped a near-empty JSON record with **exit code 0**, reported as a success, before this defense existed.
2. **This Control-M agent doesn't strip quote characters** — it only uses them to find argument boundaries, then passes them through as literal text. `-r "Data Upload"` arrives as the 12-character string `"Data Upload"` (quotes included). `mfte_unquote()` (from [mfte.sh](mfte.sh.md)) strips exactly one layer of surrounding quotes from every `OPTARG` to compensate.

The script also tolerates exactly one trailing empty argument after all real flags — a confirmed, consistent artifact of this Control-M agent's command construction. Any other leftover argument (multiple, or non-empty) is treated as a parsing failure and exits `2`. The raw argv the process actually received is always logged (`argv[...]` in the system log; echoed to stderr on the failure path) — ground truth independent of what Control-M's "Running command:" display shows.

## Configuration (`.env`)

### Required

| Key | Example | Notes |
|---|---|---|
| `MFTE_LOG_DIR` | `${MFTE_OPS_HOME}/logs` | Base log directory |
| `MFTE_JSONL_FILE` | `${MFTE_LOG_DIR}/processing/cluster.jsonl` | The shared, multi-writer event log — every rule/action across every hub node appends here |
| `MFTE_JSON_DIR` | `${MFTE_LOG_DIR}/processing/cluster.d` | Per-run individual JSON files, only used in `json-file`/`both` output mode |
| `MFTE_SYSTEM_LOG_DIR` | `${MFTE_LOG_DIR}/system` | Script execution trace — separate from the event log above |

### Optional

| Key | Default if unset | Notes |
|---|---|---|
| `MFTE_LOG_FORMAT` | `jsonl` | Output mode: `jsonl`, `json-file`, or `both`. `-o` overrides per-run. |
| `MFTE_LOG_LEVEL` | `INFO` | Filters the system log |
| `MFTE_HASH_ALGORITHM` | `sha256` | Only `sha256` has a matching command wired up; anything else silently skips hashing |
| `MFTE_TIKA_JAR` | *(unset — Tika skipped)* | Path to `tika-app-*.jar` |
| `MFTE_TIKA_ENABLED` | `true` | Persistent Tika on/off. Does **not** affect sha256 — that's controlled only by `-T` |
| `MFTE_HOST_FQDN` | `hostname -f` at runtime | Recorded as `host` in every JSON record |
| `MFTE_GRAYLOG_ENABLED` | `false` | Turns on GELF-over-HTTP forwarding to Graylog — see [Graylog forwarding](#graylog-forwarding-optional) below. Independent of `MFTE_LOG_FORMAT`: runs in addition to whichever local sink(s) that selects, not instead of them |
| `MFTE_GRAYLOG_URL` | *(unset)* | GELF HTTP input endpoint, e.g. `http://graylog.example.net:12201/gelf`. Required if `MFTE_GRAYLOG_ENABLED=true`; the script logs an error and fails the Graylog step (not the whole run, unless `MFTE_GRAYLOG_FAIL_MODE=hard`) if it's unset |
| `MFTE_GRAYLOG_TIMEOUT` | `5` | Seconds before the `curl` POST to Graylog gives up (`--max-time`) |
| `MFTE_GRAYLOG_FAIL_MODE` | `soft` | `soft`: log the failure and let the run still succeed if the local sink(s) wrote. `hard`: treat a failed Graylog post the same as a failed local write — the whole run exits `1` |

Template: [`graylog-sample.env`](../src/config/graylog-sample.env) — a standalone file, not merged into `sample.env`, since none of these variables are used by anything else in privacy-guard. Copy its contents into the deployed `MFTE_OPS_HOME/config/.env` alongside the rest of this script's config to turn Graylog forwarding on.

## Output schema

One JSON object per line (schema `controlm_mfte_processing_rule_variables_v1`):

```json
{
  "schema": "controlm_mfte_processing_rule_variables_v1",
  "run_id": "20260709T234745Z-838030",
  "timestamp": "2026-07-09T23:47:45Z",
  "host": "ctm-mfte-hub-02.example.net",
  "run_user": "root",
  "source": "controlm_mfte_processing_rule",
  "event": "file_rule_action",
  "rule_name": "Data Upload",
  "action_name": "Run Command",
  "variables": { "...": "every raw BMC variable, as received" },
  "file": { "...": "derived/normalized file fields" },
  "actor": { "...": "user, company, email, phone" },
  "mfte": { "virtual_folder": "...", "sub_dir_path": "..." },
  "staging": { "file_name": "...", "file_path": "..." },
  "enrichment": { "file": true, "sha256": true, "tika": true, "tika_metadata": true },
  "checksum": { "algorithm": "sha256", "value": "..." },
  "tika": { "version": "Apache Tika 3.3.1", "mime": "...", "metadata": { "...": "varies by file type" } }
}
```

`FILE_SIZE`/`size_bytes` is emitted as a JSON number when numeric; if BMC ever substitutes something non-numeric (seen when a Run Command wasn't quoted and substitution broke), the field becomes `null` with a sibling `FILE_SIZE_raw` string preserving what was actually received, rather than silently coercing or failing.

`tika.metadata` has **no fixed shape** — Tika's metadata keys differ by file type. Don't build downstream tooling that assumes specific keys will always be present.

## Enrichment

Runs only when the file is actually reachable on this host and `-T` wasn't passed:

- **sha256**: `sha256sum` (falls back to `shasum -a 256`). Controlled only by `-T`/file reachability — `MFTE_TIKA_ENABLED` does not affect it.
- **Tika mime + version**: `java -jar $MFTE_TIKA_JAR --detect` / `--version`.
- **Tika metadata**: `java -jar $MFTE_TIKA_JAR -j`, compacted/validated with `jq`. Falls back to `null` (`enrichment.tika_metadata: false`) if Tika's output isn't valid JSON.

`-T` always wins over `MFTE_TIKA_ENABLED=false` if both are in play. Each Tika invocation is a JVM cold start (~1-3s+); this script makes up to three per file when Tika is enabled.

Tika execution is traced in the system log: `tika start`/`tika complete` (the latter with `mime`, `version`, `metadata`, and `elapsed_s`) bracket a successful run. `tika unavailable` (`WARN`) fires instead if `MFTE_TIKA_ENABLED=true` but `java` or the jar isn't actually usable — previously this failed completely silently. `tika detect returned no mime` / `tika metadata not valid JSON` / `tika metadata call returned nothing` (all `WARN`) flag a Tika call that ran but didn't produce a usable result.

## Logging

Two separate logs: the **event log** (`MFTE_JSONL_FILE`) is business data, shared across every rule/action/hub node; the **system log** (`MFTE_SYSTEM_LOG_DIR/mfte.rule.vars.all.jsonl.sh.log`) is this script's own execution trace. Never mix the two.

A write failure to either the event log or the per-run JSON file is fatal (`exit 1`) — this script never reports "capture complete" with exit `0` if the write didn't actually succeed, since Control-M only sees the exit code.

## Graylog forwarding (optional)

Set `MFTE_GRAYLOG_ENABLED=true` (see [Configuration](#configuration-env) above) to also POST a GELF-formatted copy of every record to a Graylog GELF HTTP input, via `curl`. This is an independent toggle layered on top of whichever local sink(s) `MFTE_LOG_FORMAT`/`-o` already write — it is not a fourth `-o` mode, and disabling it (the default) leaves the script's behavior completely unchanged.

Only a small, deliberately curated subset of fields is promoted to individually queryable GELF custom fields — chosen for a specific set of Graylog dashboard widgets (files per node/rule/direction/company, file size, files by type, transfers over time), not an exhaustive mirror of the local record:

| GELF field (as stored/queried in Graylog) | Source in the local JSON record |
|---|---|
| `host` | `.host` (GELF standard field — Graylog also exposes this as `source`) |
| `timestamp` | `.timestamp` (the event's own `RUN_TS_ISO`, not the wall-clock moment the Graylog POST happens — enrichment can take a few seconds) |
| `run_id` | `.run_id` — correlates a Graylog message back to its full local audit record (`cluster.jsonl`/per-run JSON) |
| `rule_name` | `.rule_name` |
| `action_name` | `.action_name` |
| `company` | `.actor.company` |
| `event_source` | `.source` (a hardcoded constant, `controlm_mfte_processing_rule`, always — not per-node or per-rule) |
| `file_name` | `.file.name` |
| `file_abs_path` | `.file.abs_path` |
| `file_size_bytes` | `.file.size_bytes` |
| `tika_mime` | `.tika.mime` — assumes Tika stays enabled; if `-T`/`MFTE_TIKA_ENABLED=false` is ever used routinely, this arrives empty and any "files by type" widget needs a null-handling bucket |
| `mfte_raw_payload` | the entire local JSON record, stringified — see below |

Everything else in the local record — `schema`, `checksum.*`, `tika.version`/`tika.metadata`, every raw BMC `variables.*`, etc. — is **not** promoted to its own field. It's still fully present inside `mfte_raw_payload` (full-text searchable, e.g. by a known checksum value), just not as a clean structured/aggregatable field.

**`mfte_raw_payload` is kept in Graylog deliberately, with a PII tradeoff attached.** Tika's metadata (`tika.metadata`, folded into this payload when enrichment runs) can carry real people's names from a file's own embedded document properties (e.g. `meta:last-author`, `dc:creator` from an Office file) — confirmed from a live event. Keeping the raw payload in Graylog means that PII now lives in Graylog too, not only in the local audit files. If Graylog's Enterprise features support field- or stream-level access control in this deployment, use them to restrict who can see this field, rather than treating Graylog as a wider-access copy of data that used to be local-only.

GELF fields are sent with a leading underscore (`_rule_name`, `_company`, etc.) — Graylog strips that underscore on ingest, so they're queried without it (`rule_name`, `company`). This is standard GELF behavior, not specific to this script.

Failure handling is controlled by `MFTE_GRAYLOG_FAIL_MODE`:

- **`soft` (default)**: a failed post (non-`202` response, timeout, or missing `MFTE_GRAYLOG_URL`) is logged via `log_system ERROR` and otherwise ignored — the run still succeeds if the local sink(s) wrote successfully.
- **`hard`**: a failed post is treated exactly like a failed local write — the whole run exits `1`, same as the [Exit codes](#exit-codes) table below describes for write failures.

## Permissions

`cluster.jsonl` is a shared, multi-writer file — different rules, actions, and hub nodes append to it, sometimes as root, sometimes as a service account. The script sets `umask 002` so everything it creates is group-writable (664/775). Directories should additionally have the setgid bit (`chmod 2775`) so files inherit the directory's group regardless of the creating user's primary group. Substitute `$MFTE_OPS_HOME` for wherever this deployment's `src/` actually lives (`/mnt/mfte/ops` on a shared-NFS cluster, `/opt/werkstatt/ops` on a single standalone hub — see the main [README](../README.md)'s Layout section) — don't run these against a hardcoded guess:

```bash
chgrp -R controlm "${MFTE_OPS_HOME}/logs/processing" "${MFTE_OPS_HOME}/logs/system"
find "${MFTE_OPS_HOME}/logs/processing" "${MFTE_OPS_HOME}/logs/system" -type d -exec chmod 2775 {} \;
find "${MFTE_OPS_HOME}/logs/processing" "${MFTE_OPS_HOME}/logs/system" -type f -exec chmod 664 {} \;
```

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Write failure (permissions, disk, etc.) — record was **not** captured despite parsing successfully |
| `2` | Argument parsing failure — missing/unknown flag, invalid `-o` mode, or unexpected leftover positional arguments (almost always an unquoted `$$VAR$$` token upstream) |

## Using this as a template

`mfte_unquote()`, `mfte_dump_argv()`, and `mfte_check_no_leftover_args()` live in [mfte.sh](mfte.sh.md) specifically so other rule/action scripts can reuse them. If copying this script for a new rule:

- Keep the quoting requirement in the Run Command and the `mfte_unquote()` calls on every `OPTARG`.
- Keep the leftover-argument check after your own `getopts` loop.
- Re-verify the trailing-empty-argument tolerance if the new script is invoked by anything other than this specific Control-M agent — it's an artifact of this caller, not a general `getopts` guarantee.

## Known limitations

- **`flock` is a hard dependency of `mfte.sh` but is never actually called** by this script. Given `cluster.jsonl` is an explicitly shared, multi-writer file, this suggests the framework's original design intended lock-protected appends that never got wired in. A single JSON line write is normally atomic on Linux under `PIPE_BUF` (4096 bytes), which most records here fit — but that's an implicit assumption, not an enforced guarantee.
- **Historical bad records**: any `cluster.jsonl` entries written before the quoting/unquoting fixes went in may have quote-polluted fields or be near-empty. Not automatically detectable after the fact except heuristically (e.g. `FILE_NAME` empty but `FILE_PATH` present).
- **Graylog forwarding makes one attempt, no retry.** A transient network blip or a momentarily-unreachable Graylog input is treated the same as any other failure — logged (and fatal, under `MFTE_GRAYLOG_FAIL_MODE=hard`) rather than retried. The local sink(s) (`cluster.jsonl`/per-run JSON) remain the durable record regardless of Graylog's reachability; Graylog is a forwarded copy, not the source of truth.
