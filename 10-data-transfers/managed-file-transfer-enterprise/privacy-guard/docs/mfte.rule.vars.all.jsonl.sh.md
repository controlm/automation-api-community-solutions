# mfte.rule.vars.all.jsonl.sh

Captures **every** BMC Control-M MFT Enterprise Processing Rule Action variable as one structured JSON record per file-transfer event, with optional sha256 checksum and Apache Tika (mime/version/metadata) enrichment. Intended as a small, direct Control-M Run Command — short flags, one JSON object per run.

## Requirements

Sources [mfte.sh](mfte.sh.md) — inherits its hard command requirements (`jq`, `sha256sum`, `file`, `hostname`, `flock`) and its `.env` loading. Fails loudly if `MFTE_LOG_DIR`, `MFTE_JSONL_FILE`, or `MFTE_JSON_DIR` aren't set by the `.env`.

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

## Logging

Two separate logs: the **event log** (`MFTE_JSONL_FILE`) is business data, shared across every rule/action/hub node; the **system log** (`MFTE_SYSTEM_LOG_DIR/mfte.rule.vars.all.jsonl.sh.log`) is this script's own execution trace. Never mix the two.

A write failure to either the event log or the per-run JSON file is fatal (`exit 1`) — this script never reports "capture complete" with exit `0` if the write didn't actually succeed, since Control-M only sees the exit code.

## Permissions

`cluster.jsonl` is a shared, multi-writer file — different rules, actions, and hub nodes append to it, sometimes as root, sometimes as a service account. The script sets `umask 002` so everything it creates is group-writable (664/775). Directories should additionally have the setgid bit (`chmod 2775`) so files inherit the directory's group regardless of the creating user's primary group:

```
chgrp -R controlm /opt/werkstatt/ops/logs/processing /opt/werkstatt/ops/logs/system
find /opt/werkstatt/ops/logs/processing /opt/werkstatt/ops/logs/system -type d -exec chmod 2775 {} \;
find /opt/werkstatt/ops/logs/processing /opt/werkstatt/ops/logs/system -type f -exec chmod 664 {} \;
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
