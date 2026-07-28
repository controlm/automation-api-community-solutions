# werkstatt.gpg.vault.import.passphrase.sh

Pull a key's passphrase from Vault, prove it actually unlocks that key, and file it locally at this framework's standard fingerprint-keyed location — the Vault-sourced counterpart to [werkstatt.gpg.import.passphrase.sh](werkstatt.gpg.import.passphrase.sh.md) (which pulls from a staged file instead).

## Why this exists

Same "own script name, not another flag" reasoning as every other passphrase-move script in this family. Use this when you want a Vault-stored passphrase materialized locally — e.g. for a host that will keep using the plain [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md) rather than the Vault-aware variant, or as a one-time migration step. If you'd rather never materialize the passphrase locally at all, use [werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md) instead, which fetches just-in-time per decrypt and never files anything.

## Usage

```
werkstatt.gpg.vault.import.passphrase.sh -k "<fingerprint>" [options]
```

| Flag | Meaning |
|---|---|
| `-k` | **Required.** Fingerprint (or uid/email substring resolving to exactly one **secret** key already in this keyring) whose passphrase to pull from Vault — no default-key.json fallback, deliberately, same reasoning as [werkstatt.gpg.import.passphrase.sh](werkstatt.gpg.import.passphrase.sh.md)'s `-k` |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.vault.import.passphrase.sh -k "<fingerprint>" -q
```

## Env (required)

```
VAULT_ADDR
VAULT_TOKEN                 or:
VAULT_ROLE_ID / VAULT_SECRET_ID
```

## Safety

Refuses to proceed if the secret key for `-k` isn't already in this keyring, if Vault is unreachable/sealed, or if no passphrase is found at the expected Vault path.

Before filing anything permanently, this proves the passphrase actually unlocks the key — same non-destructive encrypt/decrypt round trip `werkstatt.gpg.import.passphrase.sh` uses, except the candidate is written to a **temporary**, fingerprint-namespaced-with-a-pending-token location first (`pending-vault-$$-<UTC timestamp>`), validated there, and only moved into its permanent fingerprint-keyed name if validation succeeds. A `trap ... EXIT` cleans up the temporary file on any exit path. Nothing permanent is written to `$MFTE_GPG_PASSPHRASE_DIR` unless the round trip succeeds — a stale or wrong Vault value fails loudly here instead of surfacing later when a real decrypt fails against real customer data.

The candidate passphrase goes straight from `mfte_gpg_vault_get_passphrase`'s stdout into `mfte_gpg_write_passphrase_file`'s function argument — it is never assigned to a variable this script itself echoes or logs.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (fetched, validated, and filed) |
| `1` | No secret key resolved for `-k`, gpg/Vault preflight failed, Vault auth failed, no passphrase found at the Vault path, the validation encrypt step failed (key not encrypt-capable), the round-trip validation failed, or moving the validated file into place failed |
| `2` | Usage error (missing `-k`) |

## Related

[werkstatt.gpg.vault.export.passphrase.sh](werkstatt.gpg.vault.export.passphrase.sh.md) is the export side. [werkstatt.gpg.import.passphrase.sh](werkstatt.gpg.import.passphrase.sh.md) is the plain (non-Vault) equivalent, sourcing from a staged file instead. [werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md) is the alternative for never materializing the passphrase locally at all.
