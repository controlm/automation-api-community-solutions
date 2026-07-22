# onboarding-4gpg-cluster.sh

Companion to [onboarding-4gpg-server.sh](onboarding-4gpg-server.sh.md) — run on **each** hub in the cluster (including the one `onboarding-4gpg-server.sh` already ran on — harmless there, see below) to pick up every customer key staged in `$MFTE_GPG_ONBOARDING_PRIVACY_DIR` and import **both** the private key **and** its passphrase into this node's own keyring in one pass.

## Why this isn't just `werkstatt.gpg.import.all.private.sh`

[werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) deliberately never files passphrases — scanning an arbitrary directory of key files gives it no reliable way to know which passphrase file (if any) belongs to which of N keys. This script doesn't have that problem: it only ever looks at `$MFTE_GPG_ONBOARDING_PRIVACY_DIR`, where `onboarding-4gpg-server.sh` guarantees every `<fingerprint>.private.asc` has a matching `<fingerprint>.passphrase` sibling. That guarantee is exactly what makes it safe for this script to file passphrases automatically where the general-purpose batch importer can't.

## Usage

```
onboarding-4gpg-cluster.sh [options]
```

| Flag | Meaning |
|---|---|
| `-d` | Directory to scan, default `$MFTE_GPG_ONBOARDING_PRIVACY_DIR` |
| `-q` | Quiet — suppresses the per-file + summary report (real failures still print) |
| `-h` | Help |

```
onboarding-4gpg-cluster.sh -q
```

Run this on every hub in the cluster after `onboarding-4gpg-server.sh` generates a new customer key on one of them — including that same hub is harmless, the key it just generated locally is already present and simply skipped as "already present." If you override `onboarding-4gpg-server.sh -P` to a different directory, override this script's `-d` to match.

## Behavior

Idempotent: a fingerprint whose secret half is already present on this node is skipped, not re-imported or re-filed — safe to run repeatedly, including after onboarding several new customers in a row and wanting to sync all of them to every hub in one pass. Each file is inspected (never imported blind) the same way [werkstatt.gpg.import.all.public.sh](werkstatt.gpg.import.all.public.sh.md) / [werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) do — filenames are a convention here, not trusted on their own.

Checks `mftgpg`'s own read access to the directory explicitly, up front, as `mftgpg` — not as whatever identity is running this script (root) — so a permission problem surfaces as one clear error instead of N confusing per-file failures. See the main [README](../README.md#multi-hub--nfs-considerations) for why testing as root can be misleading on an NFS export with `no_root_squash`.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Ran to completion with zero real failures (individual files may still have been skipped for benign reasons) |
| `1` | At least one file that should have imported cleanly did not (import failure, missing passphrase sibling, or a passphrase file that failed its lockdown check) |
| `2` | Usage error (directory doesn't exist, or `$MFTE_GPG_USER` cannot read it at all) |

## Related

[onboarding-4gpg-server.sh](onboarding-4gpg-server.sh.md) is the companion script that stages what this one imports.
