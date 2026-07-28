# mfte.gpg.vault.sh

Shared HashiCorp Vault helpers for the `werkstatt.gpg.vault.*.sh` script family — auth (token or AppRole), the mount/path convention used for GPG passphrases, and get/put against Vault. Sourced after `mfte.sh` and `mfte.gpg.sh`; calls `mfte_gpg_*` functions from the latter and assumes they're already defined.

## Why a separate library

Deliberately its own file, not folded into [mfte.gpg.sh](mfte.gpg.sh.md) — Vault is optional. Most `werkstatt.gpg.*.sh` scripts have nothing to do with it and shouldn't be forced to satisfy a `vault` binary dependency check (`require_command vault`) they don't need. Same reasoning `mfte.gpg.sh`'s own header gives for being separate from `mfte.sh`.

## Path convention

```
<MFTE_VAULT_MOUNT>/<MFTE_VAULT_GPG_PREFIX>/<fingerprint>   key: passphrase
```

Both halves are overridable via the shared `.env`, same as any other `MFTE_*` setting. Defaults: `MFTE_VAULT_MOUNT=kv`, `MFTE_VAULT_GPG_PREFIX=onecm/gpg-passphrase`.

## Functions

### `mfte_gpg_vault_preflight`

Confirms `VAULT_ADDR` is set and the target Vault is reachable and unsealed, via `vault status -format=json`. Does **not** require a token — `sys/health` works unauthenticated, so this is a clean network/TLS/seal check independent of whichever auth method a caller uses next.

### `mfte_gpg_vault_login_if_needed`

Uses `VAULT_TOKEN` if already set. Otherwise logs in via AppRole using `VAULT_ROLE_ID`/`VAULT_SECRET_ID`, and exports the resulting scoped token as `VAULT_TOKEN` for the rest of the process. Unsets `VAULT_SECRET_ID` immediately after use — it has done its job and shouldn't linger in the environment any longer than the login call that consumed it.

**Why these are only ever env vars, never script flags:** MFTE Rules currently logs every Rule variable substitution in cleartext, so a token or `secret_id` could never be delivered as a Rule parameter without leaking into a system log. Reading them from the shared `.env` instead (via `mfte.sh`'s `set -a; source "${CONFIG_FILE}"; set +a`) sidesteps that leak vector entirely — these values come from a file via `source`, never through Control-M's Rule-variable substitution/logging path. Accepted as the interim approach given this host's `.env` is only reachable by cluster nodes and the local root user; revisit if that access boundary changes, or once MFTE Rules gains a secure-variable mechanism.

### `mfte_gpg_vault_passphrase_path <fingerprint>`

Prints the Vault path for a fingerprint's passphrase, per the convention above.

### `mfte_gpg_vault_get_passphrase <fingerprint>`

Prints the passphrase to stdout and nothing else (`vault kv get -field=passphrase ...`). Callers must only ever consume this via process substitution (`--passphrase-fd`) or capture it straight into a variable that is immediately handed to another `mfte_gpg_*` function and never echoed/logged — identical rule to every other passphrase-handling function in `mfte.gpg.sh`.

### `mfte_gpg_vault_put_passphrase_from_file <fingerprint> <local-passphrase-file>`

Writes an already-filed local passphrase file into Vault using vault's own `key=@file` syntax — vault reads the file directly, so the passphrase value never becomes this shell's variable and never appears in this process's argv. The caller is responsible for having already validated `<local-passphrase-file>` with `mfte_gpg_require_locked_down` before calling this.

### `mfte_gpg_vault_delete_passphrase <fingerprint> [--destroy]`

Default: soft delete of the current version (recoverable via `vault kv undelete`). `--destroy`: permanently removes all versions and metadata for this path — irreversible. Not currently wrapped by a standalone `werkstatt.gpg.vault.*.sh` script; called directly if a passphrase needs to be removed from Vault.

## Secrecy

Every function here follows the same rule as `mfte_gpg_write_passphrase_file` in `mfte.gpg.sh`: a passphrase value is only ever handed off as a bash function argument (invisible in `ps`, not written to any log line) or read/written by the `vault` CLI directly via `key=@file` / `-field=`. It is never interpolated into a command string, never printed, never passed to an external command as a literal CLI argument.

## The process-substitution / `runuser` dependency

[werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md) (and [werkstatt.gpg.vault.receive.file.sh](werkstatt.gpg.vault.receive.file.sh.md)) rely on a file descriptor opened by process substitution surviving `mfte_gpg_run`'s internal `runuser -u ${MFTE_GPG_USER}` identity switch. Verified empirically on `ctm-mfte-hub-03` (2026-07-27): a no-shell service account with a direct `runuser` exec (no `-l`/login) preserves an inherited fd; only a path-based re-open (e.g. `cat /dev/fd/N`) hits a permission wall, not the fd read gpg's `--passphrase-fd` actually performs. **Re-verify this if `MFTE_GPG_USER`'s account type or the `runuser`/PAM build changes on a given host** — this is host/build-specific behavior, not something guaranteed by POSIX semantics.

## Requirements

`vault` binary on `PATH` (`require_command vault`), `jq` on `PATH` (used by `mfte_gpg_vault_preflight` to parse `vault status -format=json`, not enforced via `require_command` but required all the same), and `MFTE_GPG_USER` already set (via `.env`, checked by `mfte.sh`). The `vault`/`jq` pair is a **client**-side requirement on every MFTE hub node running a `werkstatt.gpg.vault.*.sh` script — distinct from the Vault server itself — see [hashicorp.vault.md §3.5](hashicorp.vault.md#35-installing-the-vault-cli-on-rhel-nodes) for how both are installed on this cluster's RHEL nodes (the same section also covers the MFTE Hub database VM, which needs this pair too for the Vault unseal automation in `vault/UNSEAL.md`, despite not running this library at all).

## Related

Every script in the [werkstatt.gpg.vault.*.sh](werkstatt.gpg.vault.status.sh.md) family sources this after [mfte.sh](mfte.sh.md) and [mfte.gpg.sh](mfte.gpg.sh.md). [werkstatt.gpg.vault.status.sh](werkstatt.gpg.vault.status.sh.md) is the fastest way to check this library's preflight/auth/path logic is working end to end without touching gpg at all.
