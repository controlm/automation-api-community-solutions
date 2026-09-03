# ctm_alerts.sh

**The single entry point Control-M's Enterprise Manager invokes** - EM only
supports one script per alert action, so this wrapper runs *both*
pipelines itself:

1. **Step 1** (time-boxed, best-effort) - runs the sibling wrapper
   `ctm_job_report.sh` -> `ctm_job_report.py`, so its output
   (`data/job_reports/<alert_id>.json`) exists in the common case by the
   time Step 2 needs it.
2. **Step 2** - runs `ctm_to_snow_incident.py` (via its dedicated venv) as
   the `oversight` user, logs both the raw invocation and the script's own
   output, and propagates **this step's** real exit code back to Control-M.

Before either step, it also bails out early on anything that isn't a
genuinely new alert - see **Why the early exit** below; that's not an
optional hardening pass, it's load-bearing (see the trailing-space bug
story in that section).

`ctm_job_report.sh` can still be run standalone or registered as its own
separate EM alert action if you want (see `docs/ctm_job_report_sh.md`) -
but don't do both, or the job report pipeline runs twice per alert.

## Configuration

Edit the paths near the top of the script to match your deployment:

```bash
CTM_ALERTS_DIR="/opt/bmc/alerting"
CTM_ALERTS_VENV="${CTM_ALERTS_DIR}/.venv"
CTM_ALERTS_PYTHON="${CTM_ALERTS_VENV}/bin/python3"
CTM_ALERTS_SCRIPT="${CTM_ALERTS_DIR}/ctm_to_snow_incident.py"
CTM_ALERTS_LOG="${CTM_ALERTS_DIR}/alerts.log"
CTM_ALERTS_USER="oversight"

CTM_JOB_REPORT_WRAPPER="${CTM_ALERTS_DIR}/ctm_job_report.sh"
CTM_JOB_REPORT_TIMEOUT="60s"
```

Fails loudly and specifically (not a generic error) if the venv Python or
`ctm_to_snow_incident.py` itself isn't found at the configured path -
includes the exact `venv`/`pip install` command needed to fix it. Step 1
is more forgiving: if `ctm_job_report.sh` isn't found or isn't executable,
that's logged as a warning and Step 2 still runs - a missing job report
wrapper degrades the run, it doesn't fail it.

## Why the early exit: call_type/status filtering before either step runs

Right after logging the raw invocation arguments, the script computes
`call_type` and `status` directly from `$@` and exits immediately (`exit
0`, no Python started at all) unless `call_type='I'` and
`status='Not_Noticed'` - the exact same condition
`describe_ctm_lifecycle()` in `ctm_to_snow_incident.py` uses to mean
`"initial"`.

**This exists because Control-M EM re-invokes this same script for its own
echoes.** `ctm_job_report.py`'s `mark_alert_read()` calls
`update_alert()`/`set_alert_status()` to mark a processed alert as read -
and each of those is itself an alert change, which EM sends back through
the same alert action as a new `call_type='U'` invocation. Both Python
scripts already gate on `describe_ctm_lifecycle()` internally and no-op
cleanly on a `'U'` alert, so nothing was ever *incorrect* - but every echo
still paid for a full `sudo` + venv Python startup for both scripts just to
reach that same "not a new alert, skip" conclusion. This check reaches the
same conclusion before any of that spins up.

**A real bug shipped in the first version of this check, caught from a live
alert getting silently dropped**: the initial `_ctm_arg_value()` helper
didn't trim whitespace from extracted values, but Control-M pads some
values with a trailing space (e.g. a `status` token that's literally
`"Not_Noticed "`, not `"Not_Noticed"` - the same quirk
`parse_ctm_args_to_json()`'s own docstring documents and handles via
Python's `.strip()`). A genuine new alert whose `status` happened to carry
that trailing space failed the strict `!= "Not_Noticed"` comparison and
got skipped entirely - no incident, no job report, no log line beyond the
one skip message. Fixed by trimming every token (via a small `_ctm_trim()`
helper) before comparing or using it. **If you ever touch
`_ctm_arg_value()`/`_ctm_trim()`, re-test against a raw argument list that
includes a trailing-space value** - this exact bug is easy to reintroduce
by "simplifying" the trim step back out.

## Why `sudo -u user --`, not `su - user -c "string"`

The original version of this wrapper (and a much earlier draft of this one)
rebuilt the arguments into a single shell string, which a second shell
(`su -c "..."`) then re-parsed. That's an extra string-reassembly step -
exactly the kind of thing that can silently corrupt an alert field
containing a quote, backslash, or space, which matters a great deal given
how much of this project exists specifically because Control-M's argument
handover is fragile (see `ctm_to_snow_incident.py`'s parsing notes).

`sudo -u "${CTM_ALERTS_USER}" -- "$@"` passes the original argument array
straight through - no manual escaping, no re-parsing, no risk of a value
like `Ended not OK` or a message containing embedded quotes breaking the
invocation.

**This requires actual `sudoers` authorization**, not just a working `sudo`
binary. `sudo` checks the exact command pattern against `/etc/sudoers` -
whatever authorized the *old* `su -c` pattern will not automatically cover
this new invocation shape. You will likely need entries along these lines
(adjust user/paths to match your real sudoers policy):

```text
# /etc/sudoers.d/ctm-alerts
ctm_em_user ALL=(oversight) NOPASSWD: /usr/bin/tee -a /opt/bmc/alerting/alerts.log
ctm_em_user ALL=(oversight) NOPASSWD: /opt/bmc/alerting/.venv/bin/python3 /opt/bmc/alerting/ctm_to_snow_incident.py *
```

These entries are specific to this script's log file and target script -
`ctm_job_report.sh` needs its **own** `sudoers` entries pointing at
`job_report.log` and `ctm_job_report.py`; authorizing this script does not
authorize that one. `ctm_alerts.sh` itself does **not** need a `sudoers`
entry to invoke `ctm_job_report.sh` in Step 1 - it runs that wrapper
directly (under `timeout`, no `sudo -u`), and `ctm_job_report.sh` does its
own internal `sudo -u` calls, which is exactly what its own `sudoers`
entries (see `docs/ctm_job_report_sh.md`) already need to authorize
regardless of whether it's invoked by EM directly or by this script.

If your environment specifically requires `oversight`'s full login shell
(profile/environment sourcing), use `sudo -u "${CTM_ALERTS_USER}" -i --`
instead - but confirm this is actually necessary before adding it; the
non-login form is simpler and was sufficient for this project's testing.

**Not `runuser`**: that command doesn't do its own authorization checking -
it only verifies the *caller* is already root, with no `sudoers` policy, no
password/PAM check for the target user. Since this wrapper is invoked by a
non-root Control-M EM user, `runuser` would simply fail outright. `sudo` is
the correct tool for "let a non-root, authorized user run something as
another user, per policy" - which is exactly what's needed here.

## Logging

Several things get logged to `alerts.log`:

1. **The raw invocation arguments**, verbatim, timestamped - a simple,
   greppable record of exactly what Control-M sent, independent of
   anything either script does with it.
2. **Step 1's combined output** - both the `=== Running ctm_job_report.sh
   ===` banner and everything `ctm_job_report.sh`/`ctm_job_report.py`
   themselves print, piped through the same `tee`. This means
   `ctm_job_report.sh`'s output now lands in **both** `job_report.log`
   (via its own internal `tee`, unchanged) **and** `alerts.log` (via this
   wrapper's outer `tee` around the whole Step 1 invocation) - the two
   logs are no longer fully independent the way they were before
   `ctm_alerts.sh` started invoking `ctm_job_report.sh` itself.
   `alerts.log` ends up as the complete per-invocation narrative; consult
   `job_report.log` when you specifically want just the job report
   pipeline's own history across every alert.
3. **Step 2's structured output** (`ctm_to_snow_incident.py`'s own
   `[INFO]`/`[WARN]`/`[ERROR]`/`[RESULT]` lines), captured via `tee` the
   same way.

All of it also flows through to the wrapper's own real stdout - **this is
not optional cosmetic behavior**. An earlier version of this wrapper
redirected `tee`'s passthrough to `/dev/null`, which silently prevented
Control-M EM from ever seeing any of this script's output in its own log,
since EM captures the wrapper's stdout directly. If you don't see anything
in Control-M EM's log despite `alerts.log` looking correct, check that no
`tee` invocation in this script has been redirected to `/dev/null`.

## Exit code propagation

The original version of this wrapper never captured or propagated the
underlying script's exit code - its own exit status only ever reflected
whether the final `tee` logging command succeeded, meaning Control-M would
see "success" even when the actual alert processing failed outright. This
version captures **Step 2's** exit code via `PIPESTATUS[0]` (the exit code
of the `{ ... }` block around Step 2 - which resolves to the last command
executed *inside* that block, i.e. `ctm_to_snow_incident.py` - not
`PIPESTATUS[1]`, which would be `tee`'s own exit code). Getting this
backwards was a real mistake caught during development, not a hypothetical
footgun - double-check this if you modify the pipeline structure.

**Step 1's exit code never affects this script's own exit code.** A
timeout (`124`) or any other nonzero exit from `ctm_job_report.sh` is
logged as a warning and Step 2 still runs and still determines the overall
result - by design, per the "must never block incident creation" invariant
described at the top of this doc and in the top-level README.
