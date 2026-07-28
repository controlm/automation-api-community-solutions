# werkstatt.gpg.vault.status.sh

Diagnostic-only check of the Vault integration: reachability, seal status, auth, and whether a passphrase actually exists at the expected path for a given key — without ever printing the passphrase value itself, and without performing any gpg operation.

## When to use this

Run this before [werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md) in a new environment, or whenever a Vault-backed decrypt fails and it's unclear whether the problem is Vault-side or gpg-side. It never touches the keyring beyond resolving a default fingerprint, so it's safe to run as a first troubleshooting step without risk of side effects.

## Usage

```
werkstatt.gpg.vault.status.sh [options]
```

| Flag | Meaning |
|---|---|
| `-k` | Fingerprint to check for a Vault-stored passphrase, default: fingerprint in `default-key.json`. If no fingerprint resolves at all, the script still reports reachability/seal/auth status and skips the secret-presence check. |
| `-h` | Help |

```
werkstatt.gpg.vault.status.sh
werkstatt.gpg.vault.status.sh -k "<fingerprint>"
```

## What it checks, in order

1. **Vault reachability / seal status** — `mfte_gpg_vault_preflight` (`vault status`, unauthenticated). Reported OK/FAILED.
2. **Vault auth** — skipped if step 1 failed. Skipped (not failed) if neither `VAULT_TOKEN` nor both `VAULT_ROLE_ID`/`VAULT_SECRET_ID` are set — that's treated as "auth not configured for this check," not an error. Otherwise attempts `mfte_gpg_vault_login_if_needed`.
3. **Passphrase presence** — skipped if no `-k` given and no default key recorded, or if step 2 wasn't authenticated. Otherwise reports whether a passphrase exists at `mfte_gpg_vault_passphrase_path <fingerprint>` — never the value, only presence.

Each section prints its own OK / FAILED / SKIPPED / NOT FOUND line, so a failure at any stage is immediately attributable to the specific layer (network/TLS, seal state, credentials, or the passphrase path itself) rather than surfacing as one opaque error.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Always — this is a report, not a pass/fail gate. Read the printed sections to determine actual health. |
| `2` | Usage error (unknown flag, missing value, unexpected extra arguments) |

## Related

[werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md) and [werkstatt.gpg.vault.receive.file.sh](werkstatt.gpg.vault.receive.file.sh.md) are the scripts this is meant to troubleshoot ahead of. [werkstatt.gpg.vault.export.passphrase.sh](werkstatt.gpg.vault.export.passphrase.sh.md) is how a missing passphrase reported here gets filed into Vault in the first place. See [mfte.gpg.vault.sh](mfte.gpg.vault.sh.md) for the underlying preflight/auth/path functions this script calls directly.
