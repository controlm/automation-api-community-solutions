# werkstatt.gpg.vault.export.all.passphrases.sh

Push every secret key's **already-filed local passphrase** into Vault in one pass — the batch counterpart to [werkstatt.gpg.vault.export.passphrase.sh](werkstatt.gpg.vault.export.passphrase.sh.md), for a multi-tenant keyring (N customer keys) where exporting one fingerprint at a time doesn't scale. Same relationship [werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) has to [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md).

## Scope

Enumerates every identity in the keyring that **has** a secret key (skips public-only/partner keys entirely — nothing to export for those). For each one:

- If no local passphrase file exists, or it fails the mode-600/`mftgpg`-ownership lockdown check, that fingerprint is **skipped** (not failed) — an expected, common state for a key that was just generated/imported and hasn't had its passphrase filed locally yet.
- Otherwise, the local passphrase file is pushed to Vault at this framework's standard path (`kv/onecm/gpg-passphrase/<fingerprint>`), same as the single-key script — unconditionally overwriting whatever (if anything) was already at that Vault path. Export is idempotent by design; there's no "already present in Vault, skip" bucket the way `werkstatt.gpg.import.all.private.sh` has one for "already present in keyring" — re-exporting the same local file to Vault is harmless and sometimes exactly the point (re-pushing after a local passphrase rotation).
- An actual Vault write failure (permission denied, Vault sealed/unreachable mid-run, etc.) is the only thing that counts as **failed**.

## Not done here, deliberately

- **Generating or rotating passphrases.** This only ever pushes whatever is already in each key's local passphrase file — see [werkstatt.gpg.generate.key.sh](werkstatt.gpg.generate.key.sh.md) for where that file comes from.
- **Vault policy/AppRole setup.** If every export in this run fails with "permission denied," that's a Vault ACL policy gap (`kv/data/onecm/gpg-passphrase/*` needs create+update, not just read) — not something this script can fix for you.

## Usage

```
werkstatt.gpg.vault.export.all.passphrases.sh [options]
```

| Flag | Meaning |
|---|---|
| `-k` | Only consider identities matching this search term (email, uid substring, or fingerprint) — passed through to gpg, same as [werkstatt.gpg.list.keys.sh](werkstatt.gpg.list.keys.sh.md) `-k`. Default: every secret key in the keyring. |
| `-q` | Quiet — suppresses the per-fingerprint + summary report (errors for real failures still go to stderr; the log always gets the full record) |
| `-V` | Print this script's own name and version, then exit |
| `-h` | Help |

```
werkstatt.gpg.vault.export.all.passphrases.sh -q
werkstatt.gpg.vault.export.all.passphrases.sh -k "partner@example.com" -q
```

## Env (required)

```
VAULT_ADDR
VAULT_TOKEN                 or:
VAULT_ROLE_ID / VAULT_SECRET_ID
```

Only fingerprints with a secret key present **and** an already-filed, properly locked-down local passphrase file are exported. Everything else is reported as `SKIP`, not `FAILED` — see "Scope" above.

## Identity enumeration

Uses the same primary-record parsing idiom [werkstatt.gpg.list.keys.sh](werkstatt.gpg.list.keys.sh.md) uses: one row per identity (fingerprint, uid), even for a multi-subkey key (sign + encrypt), by only capturing the `fpr`/`uid` immediately following a `pub`/`sec` record and stopping capture once a `sub`/`ssb` record starts. Listing is scoped to `--list-secret-keys` so only identities with a secret half present are ever considered.

## Report

Per-fingerprint lines (`EXPORTED` / `SKIP` / `FAILED`, with uid and Vault path) followed by a summary:

```
GPG batch Vault passphrase export complete
  secret keys scanned : N
  exported            : N
  skipped (no local)  : N
  failed              : N
```

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Every attempted export succeeded — including the case where nothing in the keyring had a local passphrase file to export at all (see the per-fingerprint report and the summary counts) |
| `1` | At least one export actually failed (a Vault write error on a fingerprint that **did** have a valid local passphrase file) |
| `2` | Usage error (bad/missing flags) |

## Related

[werkstatt.gpg.vault.export.passphrase.sh](werkstatt.gpg.vault.export.passphrase.sh.md) is the single-key version this batches over. [werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) is the equivalent batch pattern on the key-import side. [werkstatt.gpg.vault.status.sh](werkstatt.gpg.vault.status.sh.md) can confirm any individual fingerprint's export landed.
