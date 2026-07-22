# werkstatt.gpg.import.key.sh

Generic key import — dispatches to the same import logic as [werkstatt.gpg.import.public.key.sh](werkstatt.gpg.import.public.key.sh.md) / [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md) based on an explicit `-m` mode flag, for callers that want one script regardless of key type rather than choosing between the two single-purpose scripts.

## Usage

```
werkstatt.gpg.import.key.sh [-f "<file>"] -m public|private [options]
```

| Flag | Meaning |
|---|---|
| `-m` | **Required.** `public` or `private` |
| `-f` | Path to the key file. Default: the one file matching `*.<mode>.*` in `$MFTE_GPG_EXCHANGE_DIR`, if exactly one exists |
| `-P` | *(private mode only)* Passphrase file — must already exist, mode 600, owned by `$MFTE_GPG_USER`. If omitted, also tries `$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase` (same demo-convenience default as `import.private.key.sh` — see that doc) |
| `-D` | *(private mode only)* Set the imported key as default. Off by default |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.import.key.sh -f "$$FILE_ABS_PATH$$" -m public -q
```

If you always know which type you're importing, prefer the single-purpose scripts directly — this exists for callers that want one entry point either way. Same passphrase-file discipline as `import.private.key.sh` applies when `-m private` is used.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, invalid `-P`, or the gpg import failed / reported no change |
| `2` | Usage error (missing/invalid `-m`) |

## Related

[werkstatt.gpg.import.public.key.sh](werkstatt.gpg.import.public.key.sh.md), [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md).
