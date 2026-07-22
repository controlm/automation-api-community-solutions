# werkstatt.gpg.inspect.key.file.sh

Show the fingerprint(s) and uid(s) of a key **file** without importing it — the out-of-band verification step meant to happen before [werkstatt.gpg.import.public.key.sh](werkstatt.gpg.import.public.key.sh.md) / [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md), and before trusting [werkstatt.gpg.encrypt.file.sh](werkstatt.gpg.encrypt.file.sh.md)'s `--trust-model always` for a given recipient.

This inspects a **key file** (something you'd hand to an import script). If you have an **encrypted message** instead and want to know which key(s) can decrypt it, use [werkstatt.gpg.fingerprint.file.sh](werkstatt.gpg.fingerprint.file.sh.md) — a different operation on a different kind of input.

## Usage

```
werkstatt.gpg.inspect.key.file.sh -f "<file>" [options]
```

| Flag | Meaning |
|---|---|
| `-f` | **Required.** Path to the key file to inspect (armored or binary, public or private — never imported, never unlocked) |
| `-q` | Quiet — suppress the human-readable report (errors still print) |
| `-h` | Help |

```
werkstatt.gpg.inspect.key.file.sh -f "$$FILE_ABS_PATH$$" -q
```

No passphrase involved — this only ever reads a key file's public packet headers (`--import-options show-only` never touches the keyring or requires unlocking anything, whether the file is a public or private key).

## Origin

This used to be `werkstatt.gpg.fingerprint.file.sh`. Renamed because real usage showed "fingerprint file" naturally reads as "which key(s) do I need to decrypt this file" (an encrypted message) to whoever's actually running these scripts, not "inspect this key file before importing it" — two genuinely different operations that happened to share a name. `werkstatt.gpg.fingerprint.file.sh` now does the decrypt-key-listing job; this script keeps the original key-file-inspection behavior under a name that doesn't collide.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, or gpg couldn't read any key material from it |

## Related

[werkstatt.gpg.import.public.key.sh](werkstatt.gpg.import.public.key.sh.md), [werkstatt.gpg.import.keyserver.sh](werkstatt.gpg.import.keyserver.sh.md) — this script is the verification step both expect to happen first.
