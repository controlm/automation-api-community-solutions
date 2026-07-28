# mfte.sh

Shared library, sourced first by every script in `src/bin/`. Not a Run Command itself — provides execution-trace logging, Control-M-safe argument parsing, hand-rolled JSON field builders, and BMC Processing Rule Variable derivation, so no script redefines any of it independently.

## Loading

Every script does:

```bash
export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"
source "${MFTE_LIB_DIR}/bash/mfte.sh"
```

`mfte.sh` resolves its config file as `${MFTE_CONFIG_FILE:-${MFTE_OPS_HOME:-/mnt/mfte/ops}/config/.env}` and sources it with `set -a` / `source` / `set +a`. In practice `MFTE_OPS_HOME` is already set by the time this runs — every `bin/*.sh` script resolves it relative to its own location (`SCRIPT_DIR/..`, per the "Loading" snippet above) before sourcing this file — so the `.env` is found under wherever this framework's `src/` actually got deployed (`/mnt/mfte/ops` on a shared-NFS cluster, `/opt/werkstatt/ops` on a single standalone hub, or anywhere else), not a fixed path. `MFTE_CONFIG_FILE` is the explicit override, taking precedence over both; the `/mnt/mfte/ops` fallback only matters if this file is ever sourced directly outside that normal bin-script pattern (e.g. manual testing from a shell), where `MFTE_OPS_HOME` wouldn't already be set. If it's missing, every script sourcing `mfte.sh` fails loudly at startup rather than running with unset `MFTE_*` variables — the error message reports which `MFTE_OPS_HOME` value it actually resolved against, to make that fast to diagnose. Deploy `src/config/sample.env` to exactly the resolved path, filled in — a locally-named working copy (e.g. `vse.env`) must be placed there **as** `.env`, not under its working-copy name.

### Hard-required commands

Sourcing this file exits immediately if any of these aren't on `PATH`:

- `jq` — validates/compacts JSON (Tika metadata, `data.mftgpg.json`, etc.)
- `sha256sum` — checksum enrichment
- `file` — reserved for framework use, not currently called
- `hostname` — FQDN fallback if `MFTE_HOST_FQDN` isn't set
- `flock` — reserved for framework use (see Known limitations below — not currently used)

## What it provides

### Logging — `log_system LEVEL "message"`

Writes to `${MFTE_SYSTEM_LOG_DIR}/${SCRIPT_NAME}.log` — the script's own execution trace (start, argv dump, parse errors, completion), filtered by `MFTE_LOG_LEVEL` (`DEBUG` < `INFO` < `WARN`/`WARNING` < `ERROR`). This is never where business/event data goes (e.g. `cluster.jsonl`) — each calling script handles that separately. `SCRIPT_NAME` honors a value the caller already set, otherwise derives it from `$0`.

### Control-M-safe argument parsing

These exist because of real production incidents on `mfte.rule.vars.all.jsonl.sh` (2026-07-09), caused by how this environment's Control-M agent invokes Run Commands: it does **not** strip the quote characters used to bound a `$$VAR$$` substitution (they arrive as literal characters in the argv element), and it appends exactly one trailing empty argv element after every real flag, on every invocation.

| Function | Purpose |
|---|---|
| `mfte_unquote VALUE` | Strips one layer of surrounding double quotes from an `OPTARG`. Apply to every flag value. |
| `mfte_dump_argv "$@"` | Renders args as `{1:val} {2:val} ...` (brackets make an empty string visible) — log this when diagnosing a parsing mismatch; it's ground truth, unlike Control-M's own "Running command" display. |
| `mfte_check_no_leftover_args "$@"` | Call after your `getopts` loop + `shift $((OPTIND - 1))`. Tolerates exactly one trailing empty-string argument (a confirmed artifact of this Control-M agent) and fails on anything else — a leftover argument almost always means an unquoted `$$VAR$$` token broke word-splitting and every flag after it was silently never parsed. |

A getopts-based script that takes flags only (no legitimate positional argument — true of every script in this framework) should treat any other leftover as parsing having broken, not silently continue with partial data.

### JSON field builders

Hand-rolled rather than built with `jq`, because these are called many times per record (once per field); `jq` is used elsewhere in this framework for one-shot construction, not field-by-field assembly in a hot loop.

| Function | Purpose |
|---|---|
| `mfte_json_escape VALUE` | Escapes `\`, `"`, newline, CR, tab. |
| `mfte_json_kv_string KEY VALUE` | `"key":"value"` |
| `mfte_json_kv_bool KEY VALUE` | `"key":true` if `VALUE == "true"`, else `"key":false` |
| `mfte_json_kv_raw KEY VALUE` | `"key":<value>` — caller's responsibility that `VALUE` is already valid JSON |
| `mfte_json_kv_number_or_raw KEY VALUE` | Bare JSON number if all-digits, `null` if empty, or both `null` **and** a `<key>_raw` string field if it's something else — degrades instead of lying about the type or dropping the field |

### BMC variable helpers

| Function | Purpose |
|---|---|
| `mfte_derive_bmc_file_vars BEST_AVAILABLE_PATH` | Fills gaps in `FILE_NAME` / `FILE_ABS_DIR` / `FILE_EXT` / `FILE_EXT_NO_DOT` / `FILE_NAME_NO_EXT` / `FILE_SIZE` from whatever BMC variables are already set as globals — never overwrites a value MFT actually supplied. Shared by `mfte.rule.vars.all.jsonl.sh` and `werkstatt.gpg.receive.file.sh`, which differ in which path is authoritative to `stat()` — the caller passes whichever one it considers reliable. |
| `mfte_json_bmc_variables_block` | Emits the `"variables":{...}` JSON fragment for all 20 BMC Processing Rule Variables, reading them as globals. Byte-for-byte identical between the two scripts above before being pulled out here. |

The `getopts` parsing loop itself deliberately stays **per-script**, not shared here — a shared pass with a restricted optstring doesn't just ignore flags outside it, it silently treats the following argument as a stray positional and stops parsing everything after that point (confirmed by testing). Splitting parsing into "shared common flags + script-specific flags" isn't just less readable, it's unsafe.

## Origin

The argument-parsing helpers exist specifically because of the 2026-07-09 production incidents on `mfte.rule.vars.all.jsonl.sh` — see that script's own doc for the exact failure modes. The JSON helpers and BMC-variable derivation moved here once `werkstatt.gpg.receive.file.sh` needed the exact same logic that script already had.
