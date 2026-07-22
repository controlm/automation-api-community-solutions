# werkstatt.gpg.export.passphrase.sh

Copy a key's passphrase file out to a chosen location — e.g. staging it for [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md) `-P` on another host.

## Why a separate script

[werkstatt.gpg.export.key.sh](werkstatt.gpg.export.key.sh.md) `-s -W` *can* bundle a passphrase alongside a key export, but that's an explicit opt-in specifically because bundling undoes the point of keeping the passphrase on a separate channel. Giving the passphrase its own script name (rather than another flag combination) keeps "move just the passphrase, deliberately, by itself" the easy, ordinary path, and "bundle it with the key" the harder, explicit exception — not the other way around.

No gpg call happens here at all — this only validates the source passphrase file is properly locked down (mode 600, owned by `mftgpg`) and copies it. The passphrase value itself is never read into a shell variable, echoed, or logged; only file paths appear in any log line.

## Usage

```
werkstatt.gpg.export.passphrase.sh [options]
```

| Flag | Meaning |
|---|---|
| `-k` | Fingerprint whose passphrase to export, default: fingerprint in `default-key.json` |
| `-o` | Output path, default `$MFTE_GPG_EXCHANGE_DIR/<fingerprint>.passphrase` |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.export.passphrase.sh -q
werkstatt.gpg.export.passphrase.sh -k "<fingerprint>" -o "/secure/staging/key.passphrase" -q
```

Refuses to run if the source passphrase file isn't exactly mode 600, owned by `$MFTE_GPG_USER`. The output copy is written at mode 600 too, but that's this script's own doing — if you move it again afterward, set permissions explicitly at the destination.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | No `-k` and no default key, source passphrase file failed its lockdown check, or the copy itself failed |

## Related

[werkstatt.gpg.import.passphrase.sh](werkstatt.gpg.import.passphrase.sh.md) — the corresponding "file a staged passphrase in" operation on the receiving end.
