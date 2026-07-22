# setup.mftgpg.sh

One-time / idempotent host setup for the `mftgpg` service account **only** — deliberately scoped down from a generic `setup.user.sh`-style provisioning script. Reads `src/config/data.mftgpg.json` and enforces the account, its directories, and an explicit sudo denial, safe to re-run on every hub.

## Origin

Split out after review found a generic account-provisioning script granting `mftgpg` a real login password, an SSH keypair + `authorized_keys` entry, and passwordless root sudo (inherited via a shared `controlm` primary group's `NOPASSWD ALL` entry) — all appropriate for interactive admin/service accounts, none of it appropriate for `mftgpg`, which exists purely so [mfte.gpg.sh](mfte.gpg.sh.md)'s `runuser -u mftgpg` calls have somewhere to drop root privilege into. A compromised `mftgpg` should lose keyring material, not hand back root.

This script does **not** create the shared `controlm` group — that's central infrastructure owned by whatever process provisions shared groups on a given host (a generic user-setup script, a pre-baked image, or a manual `groupadd`). It fails loudly if that group doesn't already exist.

## Usage

```
setup.mftgpg.sh [options]
```

| Flag | Meaning |
|---|---|
| `-q` | Quiet — suppress the human-readable report (errors still print) |
| `-h` | Help |

Must run as **root** — `useradd`, `chown` under `/home`, and the `sudoers.d` write all require it. Checked explicitly at the start rather than failing midway through with a confusing permission error.

```bash
./setup.mftgpg.sh          # human-readable report
./setup.mftgpg.sh -q       # quiet, errors only
```

Run once per hub — `/home/mftgpg` is per-host, not shared (see the main [README](../README.md#multi-hub--nfs-considerations)).

## What it enforces, idempotently

Reads `${MFTE_CONFIG_DIR:-${MFTE_OPS_HOME}/config}/data.mftgpg.json`:

1. **Group precondition** — confirms `GROUP.name` exists; reports (does not fix) gid drift. Aborts if the group is missing entirely.
2. **Account** — creates `USER.name` if missing (`useradd -m`, explicit `-u`, no `-r` since this environment's service-account uids sit in the 6000s, well above the default `SYS_UID_MAX`). On every run: enforces the configured shell, reports (never auto-fixes) uid drift, fixes primary-group drift (safe to auto-fix — doesn't strand file ownership), and confirms no `authorized_keys` file is present. Deliberately **no** password, SSH keypair, or sudoers grant — `mftgpg` is reached only via root's `runuser -u mftgpg`, never direct login.
3. **Private GPG directories** — `MFTE_GPG_HOME`/`META_DIR`/`PASSPHRASE_DIR` (all under `mftgpg`'s own home), created at the modes from `data.mftgpg.json`'s `GPG` block. Optionally writes `gpg-agent.conf` with `allow-loopback-pinentry` if `GPG.agent_loopback_conf` is `true`.
4. **Shared GPG directories** — `MFTE_GPG_OUTPUT_DIR`, `MFTE_GPG_EXCHANGE_DIR`, `MFTE_GPG_ONBOARDING_PRIVACY_DIR`, `MFTE_GPG_RECEIVE_STAGING_DIR`, resolved directly from the already-sourced `.env` (not from `data.mftgpg.json` — these aren't a fixed subdir name under the user's home the way the three private ones are). Created `2775`, group-owned by the shared `controlm` group, so both `mftgpg` (via `runuser`) and root (Control-M's own actions) can read/write them.
5. **Sudo deny** — if `SUDO.deny_all` is `true`, installs an explicit `mftgpg ALL=(ALL) !ALL` override at `SUDO.file`, validated with `visudo -cf` before installing. `mftgpg`'s primary group (`controlm`) may already carry `NOPASSWD ALL` via a shared sudoers file on hosts where generic user setup has run; omitting a grant here doesn't cancel that — `sudoers.d` is processed in ASCII order and is last-match-wins, so the deny file's name must sort **after** whatever grants the group access (see the `SUDO.note` field in `data.mftgpg.json` before renaming it).

## Configuration source: `data.mftgpg.json`

| Key | Meaning |
|---|---|
| `GROUP.name` / `GROUP.id` | The shared primary group `mftgpg` belongs to — must already exist |
| `USER.name` / `.base` / `.shell` / `.id` / `.title` | Account identity — `USER.base/USER.name` is the home directory |
| `GPG.home_dir` / `.home_mode` | `.gnupg` subdir under the user's home, and its mode (700) |
| `GPG.agent_loopback_conf` | Whether to write `gpg-agent.conf` with `allow-loopback-pinentry` |
| `GPG.meta_dir` / `.meta_mode` | `default-key.json`'s directory (644-readable — no secrets in it) |
| `GPG.passphrase_dir` / `.passphrase_mode` | Passphrase files' directory (700) |
| `SUDO.deny_all` / `.file` | Whether/where to write the explicit sudo denial |

## Report

```
mftgpg setup complete
  user               : mftgpg (uid 6101)
  home               : /home/mftgpg
  shell              : /sbin/nologin
  MFTE_GPG_HOME      : /home/mftgpg/.gnupg
  MFTE_GPG_META_DIR  : /home/mftgpg/mfte-gpg-meta
  MFTE_GPG_PASSPHRASE_DIR : /home/mftgpg/mfte-gpg-passphrases
  MFTE_GPG_OUTPUT_DIR: ...
  MFTE_GPG_EXCHANGE_DIR   : ...
  MFTE_GPG_ONBOARDING_PRIVACY_DIR : ...
  MFTE_GPG_RECEIVE_STAGING_DIR    : ...
  sudo               : explicitly denied (...) | not managed by this script
```

## Exit codes

Exits non-zero (the accumulated `retcode`) if any step fails — group missing, `useradd` failure, uid drift detected, or a rejected sudoers fragment. Individual failures are reported inline and the script continues through the remaining steps rather than aborting on the first one, except a missing group precondition, which aborts immediately.

## Related

See the main [README](../README.md#why-a-dedicated-service-account-mftgpg) for why `mftgpg` exists as a separate account at all, and [mfte.gpg.sh](mfte.gpg.sh.md) for how scripts actually drop into it per gpg call.
