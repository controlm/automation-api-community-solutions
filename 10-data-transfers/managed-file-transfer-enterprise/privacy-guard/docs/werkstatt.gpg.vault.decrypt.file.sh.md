# werkstatt.gpg.vault.decrypt.file.sh

Decrypt a file using a private key held by the `mftgpg` service account, with the passphrase fetched from Vault fresh on every run — the Vault-aware sibling of [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md), kept as its own script rather than a flag on that one so the plain file-based path never has a Vault dependency forced onto it.

## Usage

```
werkstatt.gpg.vault.decrypt.file.sh -f "<file>" [options]
```

| Flag | Meaning |
|---|---|
| `-f` | **Required.** Path to the encrypted file |
| `-o` | Output path, default: derived from `-f` (extension stripped) under `$MFTE_GPG_OUTPUT_DIR`, with a numeric suffix if that name already exists |
| `-k` | Fingerprint of the private key to decrypt with, default: fingerprint in `default-key.json` |
| `-q` | Quiet |
| `-V` | Print this script's own name and version, then exit |
| `-h` | Help |

```
werkstatt.gpg.vault.decrypt.file.sh -f "$$FILE_ABS_PATH$$" -q
```

## Env (required)

```
VAULT_ADDR
VAULT_TOKEN                 or:
VAULT_ROLE_ID / VAULT_SECRET_ID
```

## Mechanism

The passphrase goes from Vault to gpg via `--passphrase-fd` and process substitution — it is never written to disk at any point, never a CLI argument to gpg or to this script, and never echoed or logged. Unlike [werkstatt.gpg.vault.import.passphrase.sh](werkstatt.gpg.vault.import.passphrase.sh.md), nothing is filed locally; this script re-fetches from Vault every single run.

**Trade-off, stated plainly:** this decrypt now depends on Vault being reachable and unsealed at the moment of the run — a local passphrase file has no such dependency. If that trade-off is wrong for a given host, use `werkstatt.gpg.vault.import.passphrase.sh` once to file the passphrase locally, then use the plain [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md) from then on.

## The process-substitution / `runuser` dependency

This depends on a file descriptor opened by process substitution surviving `mfte_gpg_run`'s internal `runuser -u ${MFTE_GPG_USER}` identity switch — verified empirically (2026-07-27, `ctm-mfte-hub-03`); see [mfte.gpg.vault.sh](mfte.gpg.vault.sh.md)'s header for the details. **Re-verify on any host where `MFTE_GPG_USER`'s account type or the `runuser`/PAM build differs.**

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, gpg preflight failed, Vault preflight failed, Vault auth failed, no `-k` and no default key recorded, or the decrypt itself failed (including no passphrase present yet at the Vault path) |
| `2` | Usage error |

## Related

[werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md) is the plain, non-Vault equivalent this mirrors. [werkstatt.gpg.vault.export.passphrase.sh](werkstatt.gpg.vault.export.passphrase.sh.md) is how a passphrase gets into Vault in the first place. [werkstatt.gpg.vault.status.sh](werkstatt.gpg.vault.status.sh.md) diagnoses Vault-side failures before they show up here. [werkstatt.gpg.vault.receive.file.sh](werkstatt.gpg.vault.receive.file.sh.md) is the automated inbound-handler version of this same Vault-sourced decrypt, for the "figure out which key" case. [werkstatt.gpg.fingerprint.file.sh](werkstatt.gpg.fingerprint.file.sh.md) can tell you which key(s) a file needs before you run this.
