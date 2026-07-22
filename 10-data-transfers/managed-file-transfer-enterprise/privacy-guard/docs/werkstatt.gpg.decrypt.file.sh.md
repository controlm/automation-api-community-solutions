# werkstatt.gpg.decrypt.file.sh

Decrypt a file using a private key held by the `mftgpg` service account.

Use this when you already know which key to decrypt with (or there's a single default key). If a file could have been encrypted to any one of several keys and you need to figure out which, use [werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md) instead.

## Usage

```
werkstatt.gpg.decrypt.file.sh -f "<file>" [options]
```

| Flag | Meaning |
|---|---|
| `-f` | **Required.** Path to the encrypted file |
| `-o` | Output path, default: derived from `-f` (extension stripped) under `$MFTE_GPG_OUTPUT_DIR`, with a numeric suffix if that name already exists |
| `-k` | Fingerprint of the private key to decrypt with, default: fingerprint in `default-key.json` |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.decrypt.file.sh -f "$$FILE_ABS_PATH$$" -q
```

## Passphrase handling

The passphrase is never a flag on this script. It's read directly from a 600-permission file owned by `$MFTE_GPG_USER` (`$MFTE_GPG_PASSPHRASE_DIR/<fingerprint>.passphrase`) via gpg's own `--passphrase-file`, and is never echoed to stdout or written to a log line.

## Origin

Hardened, production-like-demo version of a training script that took a passphrase as a CLI argument and printed it in cleartext, deliberately, so a student could see exactly what value was driving the decrypt. That was reasonable for its original purpose; not reasonable for an unattended Control-M Run Command, where the "terminal" a passphrase would print to is a job log that persists indefinitely.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, no `-k` and no default key recorded, passphrase file failed its lockdown check, or decryption itself failed |
| `2` | Usage error |

## Related

[werkstatt.gpg.generate.key.sh](werkstatt.gpg.generate.key.sh.md) / [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md) create the `default-key.json` fallback this uses when `-k` is omitted. [werkstatt.gpg.fingerprint.file.sh](werkstatt.gpg.fingerprint.file.sh.md) can tell you which key(s) a file needs before you run this.
