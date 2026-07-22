# werkstatt.gpg.set.default.key.sh

Point `default-key.json` at a key that's **already present** in this node's own keyring, without re-generating or re-importing anything.

## Why this exists

Fills a real gap: [werkstatt.gpg.generate.key.sh](werkstatt.gpg.generate.key.sh.md) sets a default as a side effect of creating a key, and [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md) `-D` sets one as a side effect of importing a key — neither works when the key is already fully present and unchanged, since gpg's own `--import` reports "no change" for that case (no `IMPORT_OK` line), which `import.private.key.sh` treats as a hard failure before it ever reaches its `-D` handling. This script has no import step to trip over that — it only reads the keyring and writes `default-key.json`.

Surfaced by a real 3-hub cluster where `mftgpg`'s own identity ended up the default on one hub (set during that hub's original `generate.key.sh` run) but not the other two (which received it via export/import during hub-to-hub setup, without `-D`) — there was no clean way to fix the other two without this script.

## Usage

```
werkstatt.gpg.set.default.key.sh -k "<fingerprint>" [options]
```

| Flag | Meaning |
|---|---|
| `-k` | **Required.** Full 40-hex fingerprint of a key already present in this node's keyring, with its secret half here |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.set.default.key.sh -k "A2314D02AE03DB3B2562ABAAAD3F85A14853BDCF" -q
```

## Scope

Local to **this node only** — `default-key.json` lives under `MFTE_GPG_META_DIR`, which is not shared across hubs (same as the keyring itself). Run once per hub you want the same default on, same as [onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md).

## Exit codes

| Code | Meaning |
|---|---|
| `0` | `default-key.json` now points at the given fingerprint |
| `1` | Technical error (write failed) |
| `2` | Usage error |
| `3` | The given fingerprint has no secret key in this node's keyring — a public-only key isn't something this node can decrypt/sign with, which is the whole point of "default" |

## Related

[werkstatt.gpg.list.keys.sh](werkstatt.gpg.list.keys.sh.md) shows the current default and every candidate fingerprint.
