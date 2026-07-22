# werkstatt.gpg.encrypt.file.sh

Encrypt a file to a recipient's public key, held by the `mftgpg` service account.

## Usage

```
werkstatt.gpg.encrypt.file.sh -f "<file>" -r "<recipient>" [options]
```

| Flag | Meaning |
|---|---|
| `-f` | **Required.** Path to the file to encrypt |
| `-r` | **Required.** Recipient identifier — email, uid substring, or fingerprint. Must resolve to exactly one key already in the keyring |
| `-o` | Output path, default `$MFTE_GPG_OUTPUT_DIR/<name>.asc` (or `.gpg` with `-b`) |
| `-b` | Write binary OpenPGP output instead of ASCII-armored |
| `-T` | Trust model (gpg `--trust-model` value), default `always` |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.encrypt.file.sh -f "$$FILE_ABS_PATH$$" -r "partner@example.com" -q
```

## Trust model

Encrypting to a key gpg doesn't yet trust fails unattended (`It is NOT certain that the key belongs to...`). This script defaults to `--trust-model always`, which is safe **only if** every public key ever imported into the keyring had its fingerprint verified out of band first (see [werkstatt.gpg.inspect.key.file.sh](werkstatt.gpg.inspect.key.file.sh.md)) — at that point every key in the ring was already deliberately trusted, so gpg's separate web-of-trust signing step is redundant, not skipped carelessly. Override with `-T` if a deployment wants gpg's normal trust checks instead.

## Origin

Hardened, production-like-demo version of a training script that also generated/took a passphrase and did an immediate list-packets round trip as a teaching aid. Public-key encryption never actually needs the recipient's passphrase — that's the point of asymmetric crypto — so this version doesn't touch private key material at all. Use [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md) separately to verify a round trip.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, recipient didn't resolve to exactly one key, or the gpg encrypt call failed |
| `2` | Usage error |

## Related

[mfte.gpg.sh](mfte.gpg.sh.md)'s `mfte_gpg_lookup_fingerprint` resolves `-r`. [werkstatt.gpg.import.public.key.sh](werkstatt.gpg.import.public.key.sh.md) / [werkstatt.gpg.import.keyserver.sh](werkstatt.gpg.import.keyserver.sh.md) get a recipient's key into the keyring in the first place.
