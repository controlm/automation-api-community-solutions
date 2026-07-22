# werkstatt.gpg.generate.key.sh

Generate a new GPG keypair, held by the `mftgpg` service account, for MFTE encrypt/decrypt/sign operations.

## Structure

Builds a **certify-only primary key** with separate **sign** and **encrypt** subkeys, rather than one single-purpose key — the generally recommended OpenPGP structure (the identity key is used as little as possible; day-to-day operations use subkeys that can be rotated/revoked independently). This is also a functional requirement on the tested gpg version (2.2.27): `--quick-generate-key` with usage `default` produces a sign+cert key with **no encryption capability at all**, which made `werkstatt.gpg.encrypt.file.sh` fail outright (`Unusable public key`) until generation was changed to explicitly add `sign` and `encr` subkeys via `--quick-add-key`. If you're on a different gpg version, re-verify a freshly generated key actually has an `e`-capable subkey (`gpg --list-keys --with-colons` — look for a `sub` line ending in `e`) before relying on encrypt against it.

## Usage

```
werkstatt.gpg.generate.key.sh -u "<uid>" [options]
```

| Flag | Meaning |
|---|---|
| `-u` | **Required.** Key identity, e.g. `"MFTE Ops <mfte-ops@example.com>"` |
| `-t` | Key type, default `rsa4096` |
| `-x` | Expiry, gpg syntax (e.g. `2y`), default `0` (never expires) |
| `-P` | Reuse an existing passphrase file instead of generating a new one (must already exist, mode 600, owned by `$MFTE_GPG_USER`) |
| `-N` | Do **not** update `default-key.json` with this key |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.generate.key.sh -u "MFTE Ops <mfte-ops@example.com>" -q
```

## Passphrase handling

A fresh passphrase is generated with `openssl rand -base64 24` and written straight into a mode-600 file owned by `$MFTE_GPG_USER` — never echoed to stdout, never written to a log line, never passed as a gpg CLI argument. On success, only the fingerprint and the passphrase file's **path** are printed, never the passphrase itself.

## Origin

Hardened, production-like-demo version of a training script that intentionally printed every intermediate value — including the generated passphrase — in cleartext, so a student could see the whole mechanism. That was the right design for its original purpose; this version keeps the same operation but locks the passphrase down immediately, since it now runs unattended against real key material rather than in front of a student watching the terminal.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Key/subkey generation failed (gpg error) |
| `2` | Usage error (missing `-u`, bad flag) |

## Related

[mfte.gpg.sh](mfte.gpg.sh.md) provides `mfte_gpg_run`, `mfte_gpg_write_passphrase_file`, `mfte_gpg_generate_passphrase`, `mfte_gpg_write_default_key_json`. See [onboarding-4gpg-server.sh](onboarding-4gpg-server.sh.md) for the same generation sequence used inline for per-customer key creation, and [werkstatt.gpg.set.default.key.sh](werkstatt.gpg.set.default.key.sh.md) for pointing `default-key.json` at a key that already exists (this script's `-N` skips that step; the other script fills the gap afterward).
