# ctm_job_report.sh

The wrapper for the **job report** pipeline - structurally identical to
`ctm_alerts.sh` (see that doc for the full reasoning behind the `sudo -u
user --` invocation style, logging approach, and exit code propagation;
this doc only covers what's different). Runs `ctm_job_report.py` (via the
same shared venv as `ctm_alerts.sh`) as the `oversight` user, logs both the
raw invocation and the script's own output, and propagates the real exit
code back to Control-M.

**Normally invoked by `ctm_alerts.sh` itself, not registered separately
with EM.** Control-M EM only supports one script per alert action, so
`ctm_alerts.sh` is the single entry point EM actually calls; it runs this
script as its first step, time-boxed (`timeout`), before running
`ctm_to_snow_incident.py` - see `docs/ctm_alerts_sh.md`. This wrapper still
works completely standalone (manual runs, testing, or if you genuinely
want it as its own separate EM alert action instead) - it has no
dependency on `ctm_alerts.sh` or on being invoked by it - but **don't
register it separately with EM while `ctm_alerts.sh` is also configured**,
or the job report pipeline runs twice per alert.

## Configuration

```bash
CTM_ALERTS_DIR="/opt/bmc/alerting"
CTM_ALERTS_VENV="${CTM_ALERTS_DIR}/.venv"
CTM_ALERTS_PYTHON="${CTM_ALERTS_VENV}/bin/python3"
CTM_JOB_REPORT_SCRIPT="${CTM_ALERTS_DIR}/ctm_job_report.py"
CTM_JOB_REPORT_LOG="${CTM_ALERTS_DIR}/job_report.log"
CTM_ALERTS_USER="oversight"
```

Same `CTM_ALERTS_DIR`/venv/user as `ctm_alerts.sh` - both scripts are meant
to be deployed side by side and share `config/.env` - but a different
target script and a different log file.

## sudoers: this needs its own entries

Authorizing `ctm_alerts.sh` does **not** authorize this script - `sudo`
matches the exact command pattern, including the script path and log file
path. You need a second set of entries:

```text
# /etc/sudoers.d/ctm-job-report
ctm_em_user ALL=(oversight) NOPASSWD: /usr/bin/tee -a /opt/bmc/alerting/job_report.log
ctm_em_user ALL=(oversight) NOPASSWD: /opt/bmc/alerting/.venv/bin/python3 /opt/bmc/alerting/ctm_job_report.py *
```

Forgetting this is the most likely deployment mistake when adding this
wrapper to an existing `ctm_alerts.sh`-only deployment - the symptom is
`sudo: a password is required` (or a silent permission denial, depending on
your `sudo` logging config) only on this script's invocations, with
`ctm_alerts.sh` continuing to work fine.

## Logging

Always logs to its own `job_report.log` - same two-part structure as
`ctm_alerts.sh`: raw invocation arguments first, then the Python script's
own `[INFO]`/`[WARN]`/`[ERROR]` output via `tee`. This is independent of
who invoked it.

**When invoked via `ctm_alerts.sh`'s Step 1 (the normal path), this same
output also lands in `alerts.log`** - `ctm_alerts.sh` pipes Step 1's entire
combined output through its own `tee` as well, so `alerts.log` ends up as
the complete per-alert narrative across both pipelines. The two logs are
no longer fully independent the way they'd be if this wrapper were still
registered as its own separate EM alert action; `job_report.log` remains
useful as just this pipeline's own history in isolation. The two dedup
ledgers (`data/job_report_tracking.json` vs `data/alert_tracking.json`)
stay fully independent regardless - see `docs/ctm_alerts_sh.md`.

## Exit codes

`ctm_job_report.py` returns `0` for "processed successfully" *or*
"correctly skipped" (not a job alert, duplicate delivery, update alert), and
`1` for actual failures: no CLI arguments provided and demo mode isn't
enabled, both `-v` and `-q` given at once, or a job alert whose report
failed to write. This wrapper propagates that exit code via
`PIPESTATUS[0]`, same mechanism as `ctm_alerts.sh`.
