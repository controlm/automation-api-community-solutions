# werkstatt.gpg.export.key.sh

Export a public key (to hand to a partner) or, with `-s`, a private key (e.g. to migrate `mftgpg`'s identity to another host) from the keyring.

## Usage

```
werkstatt.gpg.export.key.sh [options]
```

| Flag | Meaning |
|---|---|
| `-k` | Fingerprint to export, default: fingerprint in `default-key.json` |
| `-s` | Export the **private** key instead of the public key |
| `-o` | Output path, default `$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.<public\|private>.asc` |
| `-b` | Write binary OpenPGP output instead of ASCII-armored |
| `-W` | Secret export only (`-s`): also write the key's passphrase file alongside it, as `<output-dir>/<fingerprint>.passphrase`. **Weakens the two-channel transfer design** — see below. Ignored (with a warning) if `-s` wasn't given |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.export.key.sh -q
werkstatt.gpg.export.key.sh -k "<fingerprint>" -s -o "/secure/staging/key.private.asc" -q
```

## Passphrase requirement for secret export

Public key export needs no passphrase (verified against this gpg version). Secret key export **does** — gpg's agent won't hand over secret key material for export without one (`error receiving key from agent` reproduced without `--passphrase-file`). So `-s` follows the same `--pinentry-mode loopback --passphrase-file` pattern as [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md), not a plain `--export-secret-keys`.

## The `-W` tradeoff

By default, `-s` exports **only** the private key — its passphrase stays where it is, transferred separately and out of band (see [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md) `-P`). That split is deliberate: bundling a private key export with its own passphrase undoes the reason the passphrase is a separate file at all — anyone who gets the export folder gets both the lock and the key to it. `-W` is an explicit opt-in to bundle them anyway, for cases where the whole bundle is already handled as one sensitive unit (e.g. a controlled hub-to-hub migration). Not the default, so this tradeoff is a decision each time, not something that happens silently.

gpg itself writes secret-key export output at mode 600 regardless of process umask — that's gpg's own safety default, not something this script enforces. Don't rely on it surviving a copy/move elsewhere; set permissions explicitly at the destination too.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | No `-k` and no default key recorded, passphrase file failed lockdown (secret export), or the gpg export call failed / produced an empty file |

## Related

[werkstatt.gpg.export.passphrase.sh](werkstatt.gpg.export.passphrase.sh.md) for moving just the passphrase, deliberately, on its own — the ordinary path this script's `-W` is the explicit exception to.
