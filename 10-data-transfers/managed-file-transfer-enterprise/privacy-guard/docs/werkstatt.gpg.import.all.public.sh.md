# werkstatt.gpg.import.all.public.sh

Import every **public** key file staged in `$MFTE_GPG_EXCHANGE_DIR` (or `-d`) into the `mftgpg` keyring in one pass — the batch counterpart to [werkstatt.gpg.import.public.key.sh](werkstatt.gpg.import.public.key.sh.md), for the "onboard 10 customers' public keys at once" case.

## Usage

```
werkstatt.gpg.import.all.public.sh [options]
```

| Flag | Meaning |
|---|---|
| `-d` | Directory to scan, default `$MFTE_GPG_EXCHANGE_DIR` |
| `-q` | Quiet — suppresses the per-file + summary report (real failures still print; skips never print to stderr regardless) |
| `-h` | Help |

```
werkstatt.gpg.import.all.public.sh -q
```

## Scope

Each file is inspected — never imported blind — before anything happens to it, top-level only, hidden files (dotfiles) excluded:

- Files named `*.passphrase` are skipped outright — never even handed to gpg.
- Anything gpg can't read any key material from is **skipped** (not failed) as "not a key file" — a stray README or `.DS_Store` doesn't flip the exit code.
- A file whose primary record is `sec` (secret key material) is skipped and pointed at [werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) instead — this script only ever imports the public half of anything.
- A fingerprint already present in the keyring (checked **before** calling `--import`) is skipped as "already present" — this is what makes the whole directory safe to re-run repeatedly, including on a pass where most keys are already there.

Only an actual `gpg --import` failure on a file that passed every check above counts as a real failure.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Ran to completion with zero real import failures (individual files may still have been skipped — see the per-file report and summary counts) |
| `1` | At least one file that should have imported cleanly did not; other files in the run were still attempted |
| `2` | Usage error (directory doesn't exist) |

## Related

[werkstatt.gpg.import.all.private.sh](werkstatt.gpg.import.all.private.sh.md) for the secret-key counterpart. [onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md) is a related but distinct batch scanner, purpose-built for the onboarding directory with different filename assumptions.
