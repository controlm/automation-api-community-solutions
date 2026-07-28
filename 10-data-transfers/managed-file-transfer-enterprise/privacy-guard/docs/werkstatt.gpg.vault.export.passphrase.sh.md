# werkstatt.gpg.vault.export.passphrase.sh

Push a key's already-filed local passphrase file into Vault, at the path [werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md) / [werkstatt.gpg.vault.import.passphrase.sh](werkstatt.gpg.vault.import.passphrase.sh.md) expect.

## Why a separate script

Vault-backed sibling of [werkstatt.gpg.export.passphrase.sh](werkstatt.gpg.export.passphrase.sh.md) — same "own script name for the passphrase move, not another flag on an existing script" reasoning as that file's own doc. The local passphrase file (created by [werkstatt.gpg.generate.key.sh](werkstatt.gpg.generate.key.sh.md)) is the source of truth here; this script copies it **to** Vault, it does not remove or alter the local file.

No gpg call happens here at all. The passphrase value itself is never read into a shell variable — Vault's own `key=@file` syntax reads the local file directly, so it never appears in this script's argv, stdout, or any log line it writes.

## Usage

```
werkstatt.gpg.vault.export.passphrase.sh [options]
```

| Flag | Meaning |
|---|---|
| `-k` | Fingerprint whose passphrase to push, default: fingerprint in `default-key.json` |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.vault.export.passphrase.sh -q
werkstatt.gpg.vault.export.passphrase.sh -k "<fingerprint>" -q
```

## Env (required)

```
VAULT_ADDR
VAULT_TOKEN                 or:
VAULT_ROLE_ID / VAULT_SECRET_ID
```

## Safety

Refuses to run if the local passphrase file isn't exactly mode 600, owned by `$MFTE_GPG_USER` — the same lockdown check every other script in this family uses. Refuses to run if Vault is unreachable or sealed. Export is idempotent: writing unconditionally overwrites whatever (if anything) was already at that Vault path, which is the point — re-exporting after a local passphrase rotation is a normal, expected use.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | No `-k` and no default key, gpg/Vault preflight failed, Vault auth failed, local passphrase file failed its lockdown check, or the Vault write itself failed |
| `2` | Usage error |

## Related

[werkstatt.gpg.vault.import.passphrase.sh](werkstatt.gpg.vault.import.passphrase.sh.md) — the corresponding "pull a Vault-stored passphrase back down" operation. [werkstatt.gpg.vault.export.all.passphrases.sh](werkstatt.gpg.vault.export.all.passphrases.sh.md) is the batch counterpart for a multi-tenant keyring. [werkstatt.gpg.vault.status.sh](werkstatt.gpg.vault.status.sh.md) can confirm the export landed. [werkstatt.gpg.export.passphrase.sh](werkstatt.gpg.export.passphrase.sh.md) is the plain (non-Vault) equivalent for staging a passphrase to a file instead.
