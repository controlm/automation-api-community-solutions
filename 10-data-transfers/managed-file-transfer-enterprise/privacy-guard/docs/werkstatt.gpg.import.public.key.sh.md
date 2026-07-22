# werkstatt.gpg.import.public.key.sh

Import a partner/recipient's public key into the `mftgpg` keyring, so files can later be encrypted to them.

## Usage

```
werkstatt.gpg.import.public.key.sh [-f "<file>"] [options]
```

| Flag | Meaning |
|---|---|
| `-f` | Path to the public key file to import (armored or binary). Default: the one file matching `*.public.*` in `$MFTE_GPG_EXCHANGE_DIR`, if exactly one exists — error if zero or more than one, since guessing which key to import isn't a safe default |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.import.public.key.sh -f "$$FILE_ABS_PATH$$" -q
```

## Trust note

Importing a key does **not** mean this framework trusts it for encryption yet — [werkstatt.gpg.encrypt.file.sh](werkstatt.gpg.encrypt.file.sh.md)'s `--trust-model always` only matters because the only keys ever imported here are ones whose fingerprint was verified out of band first. Verify the fingerprint (see [werkstatt.gpg.inspect.key.file.sh](werkstatt.gpg.inspect.key.file.sh.md)) against what the partner actually published *before* running this.

No passphrase is involved in a public key import — nothing to protect beyond normal file permissions on the keyring itself, checked by `mfte_gpg_preflight`.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, or the gpg import failed / reported no change |

## Related

For many keys at once, use [werkstatt.gpg.import.all.public.sh](werkstatt.gpg.import.all.public.sh.md). For a keyserver-sourced key, use [werkstatt.gpg.import.keyserver.sh](werkstatt.gpg.import.keyserver.sh.md).
