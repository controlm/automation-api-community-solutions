# werkstatt.gpg.import.passphrase.sh

File a staged passphrase file into this framework's standard fingerprint-keyed location (`$MFTE_GPG_PASSPHRASE_DIR/<fingerprint>.passphrase`), independent of importing a private key.

## Why this exists

[werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md)'s `-P` flag already files a passphrase as part of importing the key itself — for the ordinary "migrate `mftgpg`'s identity to a new hub" case, that's the only script you need. This one exists for cases outside that: re-staging a passphrase file that was lost or corrupted after the key was already imported, rotating a passphrase for a key already present, or filing one for a key that was imported earlier without `-P`. Companion to [werkstatt.gpg.export.passphrase.sh](werkstatt.gpg.export.passphrase.sh.md), which has the same "not folded into the key-export/import scripts, on purpose" reasoning.

## Usage

```
werkstatt.gpg.import.passphrase.sh -k "<fingerprint>" [-f "<file>"] [options]
```

| Flag | Meaning |
|---|---|
| `-k` | **Required.** Fingerprint (or uid/email substring resolving to exactly one **secret** key already in this keyring) this passphrase belongs to — no default-key fallback, deliberately: filing a passphrase is a write against sensitive material, worth naming the key explicitly every time |
| `-f` | Path to the staged passphrase file — must exist, mode 600, owned by `$MFTE_GPG_USER`. Default: `$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase` |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.import.passphrase.sh -k "<fingerprint>" -f "/secure/staging/key.passphrase" -q
```

## Safety

Refuses to file a passphrase for a fingerprint whose secret key isn't already present in this keyring — filing one for a key you don't hold is almost always the wrong fingerprint or the wrong hub, not a legitimate use case. Before filing anything, this also **proves the passphrase actually unlocks the key**: it encrypts a throwaway string to the key's own public half, then decrypts it back using the staged passphrase file. A mistyped or stale passphrase file fails loudly here instead of being discovered later when a real decrypt fails against real data. Nothing is written to `$MFTE_GPG_PASSPHRASE_DIR` unless that round trip succeeds.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (validated and filed) |
| `1` | No secret key resolved for `-k`, passphrase file failed lockdown, the round-trip validation failed, or the file copy failed |
| `2` | Usage error (missing `-k`) |

## Related

[werkstatt.gpg.export.passphrase.sh](werkstatt.gpg.export.passphrase.sh.md) for the export side. [werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) points every newly-imported fingerprint at this script as a required follow-up.
