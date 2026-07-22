# werkstatt.gpg.list.keys.sh

List every identity in the `mftgpg` keyring — fingerprint, primary uid, created/expires, whether a secret key is present (i.e. an identity you can decrypt/sign with, vs. an imported partner's public-only key), and whether it's the current default key.

## Usage

```
werkstatt.gpg.list.keys.sh [options]
```

| Flag | Meaning |
|---|---|
| `-k` | Filter to identities matching this search term (email, uid substring, or fingerprint) |
| `-j` | Print a JSON array instead of a human-readable report |
| `-h` | Help |

```
werkstatt.gpg.list.keys.sh -q
werkstatt.gpg.list.keys.sh -k "partner@example.com"
```

## Parsing note

gpg's `--with-colons` output repeats `fpr` and `uid` lines for every subkey, not just the primary key — the same trap [mfte.gpg.sh](mfte.gpg.sh.md)'s `mfte_gpg_lookup_fingerprint()` had to be fixed for. This script only captures the `fpr`/`uid` immediately following a `pub`/`sec` record and stops capturing once a `sub`/`ssb` record starts, so a multi-subkey identity (see [werkstatt.gpg.generate.key.sh](werkstatt.gpg.generate.key.sh.md)) shows up as **one** row, not three.

Capability letters shown (`c`=certify, `s`=sign, `e`=encrypt, `a`=auth) are gpg's own, taken from the primary key record.

## Origin

Not one of the original nine training scripts — added once real usage surfaced the gap: no way to see what's actually in the keyring without hand-rolling `gpg --with-colons` parsing each time.

## Exit codes

`0` always (even with zero matches — an empty keyring or filter miss is reported, not an error).

## Related

[werkstatt.gpg.set.default.key.sh](werkstatt.gpg.set.default.key.sh.md) to change which key is flagged as default. [werkstatt.gpg.delete.key.sh](werkstatt.gpg.delete.key.sh.md) to remove one.
