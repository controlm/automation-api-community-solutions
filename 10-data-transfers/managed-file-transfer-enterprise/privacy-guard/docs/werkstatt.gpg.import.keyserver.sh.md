# werkstatt.gpg.import.keyserver.sh

Fetch a **public** key from a keyserver by its full fingerprint and import it into the `mftgpg` keyring — the keyserver-sourced equivalent of [werkstatt.gpg.import.public.key.sh](werkstatt.gpg.import.public.key.sh.md), for partners who publish rather than email/portal a key file.

This is the **only script in this family that touches the network.**

## Usage

```
werkstatt.gpg.import.keyserver.sh -k "<40-hex-fingerprint>" [options]
```

| Flag | Meaning |
|---|---|
| `-k` | **Required.** Full 40-character fingerprint to fetch — **not** an email address or short key ID, deliberately (see below). Non-hex characters (spaces, a leading `0x`, etc.) are stripped automatically, so pasting straight out of GPG Keychain, `gpg --list-keys`, or a keyserver's web UI works as-is |
| `-s` | Keyserver, default `${MFTE_GPG_KEYSERVER:-hkps://keys.openpgp.org}` |
| `-t` | Timeout in seconds before giving up, default `20` |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.import.keyserver.sh -k "<fingerprint>" -q
```

## Trust

Fetching from a keyserver changes the **transport**, not the trust model. `keys.openpgp.org` verifies email ownership before binding a uid, but that does not prove the fingerprint you asked for is genuinely the partner's — you still need the correct fingerprint from a channel independent of the keyserver (their site, a signed message, a phone call) before running this. That's why `-k` only accepts a full 40-hex fingerprint — short IDs are trivially collision-attackable against public keyservers, a well-documented historical PGP weakness; accepting one here would undo the whole point.

## Network

gpg's `dirmngr` component performs the actual fetch, not this script directly — if it hangs or fails, check whether this host has outbound HTTPS (443) to the keyserver at all before assuming anything is wrong with the fingerprint. A proxy, if needed, belongs in `mftgpg`'s own `~/.gnupg/dirmngr.conf`, not a flag on this script. Wrapped in `timeout` so a blocked/filtered network fails within a bounded time instead of hanging the calling job indefinitely.

After fetching, this script confirms the imported key's fingerprint exactly matches what was requested — defense in depth beyond trusting `--recv-keys`'s exit code alone.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Network timeout, fetch failure, nothing importable returned, or fingerprint mismatch |
| `2` | Usage error (missing/invalid `-k`) |

## Related

[werkstatt.gpg.inspect.key.file.sh](werkstatt.gpg.inspect.key.file.sh.md) for verifying a file-based key's fingerprint the same way this script requires for a keyserver fetch.
