# werkstatt.gpg.import.all.private.sh

Import every **private** key file staged in `$MFTE_GPG_EXCHANGE_DIR` (or `-d`) into the `mftgpg` keyring in one pass — the batch counterpart to [werkstatt.gpg.import.private.key.sh](werkstatt.gpg.import.private.key.sh.md), for provisioning many customer decrypt-only keys (or migrating `mftgpg`'s own identities between hosts) at once.

## Usage

```
werkstatt.gpg.import.all.private.sh [options]
```

| Flag | Meaning |
|---|---|
| `-d` | Directory to scan, default `$MFTE_GPG_EXCHANGE_DIR` |
| `-q` | Quiet — suppresses the per-file + summary report (real failures still print) |
| `-h` | Help |

```
werkstatt.gpg.import.all.private.sh -q
```

## Scope

Same inspect-before-import checks as [werkstatt.gpg.import.all.public.sh](werkstatt.gpg.import.all.public.sh.md), mirrored for the private case: `*.passphrase` files skipped outright, unreadable files skipped as "not a key file," a file whose primary record is `pub` (public-only) skipped and pointed at that script instead, and a fingerprint whose **secret** key is already present skipped as "already present." Only a real `gpg --import` failure on a file that passed every check counts as a failure.

## Deliberately NOT done here

- **Passphrase filing.** Each imported key still needs its passphrase filed separately via [werkstatt.gpg.import.passphrase.sh](werkstatt.gpg.import.passphrase.sh.md) `-k <fingerprint> -f <passphrase-file>` — there's no way to know which passphrase file (if any) goes with which of N imported keys just from scanning a directory, and guessing would be worse than requiring the explicit follow-up. Every newly-imported fingerprint is listed in the summary specifically so that follow-up is easy to script against.
- **Setting a default key.** Importing N keys in one batch has no single obvious "default" candidate — set one explicitly afterward with [werkstatt.gpg.set.default.key.sh](werkstatt.gpg.set.default.key.sh.md) if needed.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Ran to completion with zero real import failures |
| `1` | At least one file that should have imported cleanly did not; others were still attempted |
| `2` | Usage error (directory doesn't exist) |

## Related

[onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md) is the onboarding-specific equivalent that **does** file passphrases automatically — it can do so safely only because it scans a directory with a guaranteed `<fingerprint>.passphrase` sibling naming convention that this general-purpose script can't assume.
