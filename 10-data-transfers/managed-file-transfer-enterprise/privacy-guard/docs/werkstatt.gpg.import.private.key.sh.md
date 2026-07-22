# werkstatt.gpg.import.private.key.sh

Import a **private** key (e.g. migrating `mftgpg`'s own identity from another host, or provisioning a partner-supplied decrypt-only key) into the keyring.

## Usage

```
werkstatt.gpg.import.private.key.sh [-f "<file>"] [options]
```

| Flag | Meaning |
|---|---|
| `-f` | Path to the private key file (armored or binary). Default: the one file matching `*.private.*` in `$MFTE_GPG_EXCHANGE_DIR`, if exactly one exists |
| `-P` | Passphrase file for the imported key — must already exist, mode 600, owned by `$MFTE_GPG_USER`. Copied into this framework's standard fingerprint-keyed location after import |
| `-D` | Set the imported key as the default (used by `werkstatt.gpg.decrypt.file.sh` / `werkstatt.gpg.export.key.sh` when no `-k`/`-r` given). Off by default |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.import.private.key.sh -f "$$FILE_ABS_PATH$$" -P "/secure/staged.passphrase" -D -q
```

## Passphrase handling

The imported key's protection passphrase isn't something this script generates — it already exists, set on whatever system the key came from — so it must be staged in a locked-down file via `-P` *before* running, the same way a human would hand over a physical key rather than saying the combination out loud.

**Demo-convenience default, not the production posture:** if `-P` is omitted, this script also looks for `$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase` (the name [werkstatt.gpg.export.passphrase.sh](werkstatt.gpg.export.passphrase.sh.md)'s own default writes) once the fingerprint is known, and uses it automatically if it passes the same mode-600 lockdown check. That closes the loop end-to-end without typing a path, but it also means accepting the default puts the private key and the passphrase that unlocks it in the same shared, group-writable directory — undoing the separate-channel design this whole passphrase scheme otherwise follows. Fine for a lab; a real deployment should keep passphrases on a genuinely separate channel and always pass `-P` explicitly.

If neither `-P` nor that default file is usable, the key is imported but nothing is filed for it — decrypt fails against it until a passphrase file is provided some other way (see [werkstatt.gpg.import.passphrase.sh](werkstatt.gpg.import.passphrase.sh.md)).

The passphrase itself is never a flag on this script and is never echoed or logged — only its file path is.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, `-P` failed lockdown, or the gpg import failed / reported no change |

## Related

[werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) for many keys at once (does not file passphrases — see that doc). [werkstatt.gpg.set.default.key.sh](werkstatt.gpg.set.default.key.sh.md) for setting a default on an already-present key, which this script's `-D` can't do (gpg reports "no change" for an unchanged import, which this script treats as a hard failure before reaching `-D`).
