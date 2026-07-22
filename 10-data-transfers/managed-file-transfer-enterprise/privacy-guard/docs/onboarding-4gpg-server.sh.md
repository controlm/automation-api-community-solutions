# onboarding-4gpg-server.sh

Demo/convenience wrapper for onboarding one new customer onto the "one dedicated key per customer" GPG pattern in a single step: generate a fresh keypair for them, then export both halves to where the rest of the workflow expects to find them.

- **Private key + passphrase** → `$MFTE_GPG_ONBOARDING_PRIVACY_DIR` (shared NFS, defaults under `$MFTE_GPG_EXCHANGE_DIR/onboarding`) for [onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md) to pick up on every hub.
- **Public key only** → `$MFTE_GPG_ONBOARDING_B2B_DIR/<email>/` (defaults under `/mnt/ftshome/b2bhome/secureTransport/onboarding`) for the customer to collect.

Not a replacement for [werkstatt.gpg.generate.key.sh](werkstatt.gpg.generate.key.sh.md) / [werkstatt.gpg.export.key.sh](werkstatt.gpg.export.key.sh.md) — this script duplicates their core gpg sequences inline rather than invoking them as subprocesses, but every actual gpg call still goes through the same [mfte.gpg.sh](mfte.gpg.sh.md) helpers, so the result is a normal key the framework's other scripts can use without knowing it came from here.

**Never sets this key as the default** — there's no flag to skip that step because skipping it is the only behavior. The whole point of the one-key-per-customer pattern is that there is no single default identity; every onboarded customer's key exists purely to be found by its own recipient match at decrypt time (see [werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md)).

## Usage

```
onboarding-4gpg-server.sh -n "<name>" -m "<email>" [options]
```

| Flag | Meaning |
|---|---|
| `-n` | **Required.** Customer/user display name, e.g. `"ACME Finance"` |
| `-m` | **Required.** Customer email — also used as a directory segment under the B2B export path, so validated as a plain email (no `/`, no whitespace) |
| `-t` | Key type, default `rsa4096` |
| `-x` | Expiry, gpg syntax, default `0` (never expires) |
| `-F` | Force — generate an **additional** key even if this email is already fully onboarded (normally refused, exit `3`). You'll likely need to disambiguate fingerprints manually afterward (`export.key.sh -k`). Not needed to resume an incomplete prior onboarding — that happens automatically, see "Resume" below |
| `-P` | Override `$MFTE_GPG_ONBOARDING_PRIVACY_DIR` |
| `-B` | Override `$MFTE_GPG_ONBOARDING_B2B_DIR` |
| `-q` | Quiet |
| `-h` | Help |

```
onboarding-4gpg-server.sh -n "ACME Finance" -m "finance@acme.example.com" -q
```

On success, prints the new fingerprint and both export locations — never the passphrase itself.

## Resume behavior

If a secret key already resolves for the given email, this script does **not** always refuse outright — it checks whether **both** exports (private+passphrase in the privacy dir, public key at the B2B destination) are actually present. If either is missing, it treats this as an interrupted prior run (a real observed failure mode: the export step failing after key generation already succeeded) and resumes from the export step using the existing key, rather than generating a new one. Only a fully already-staged customer is refused outright (exit `3`).

## Accepted risk (deliberate, not an oversight)

`$MFTE_GPG_ONBOARDING_PRIVACY_DIR` ends up holding a private key **and** its passphrase together, unencrypted-at-rest beyond filesystem permissions, on shared NFS storage — specifically so [onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md) can pick both up on every hub without a human relaying the passphrase out of band. That is a real weakening of the two-channel transfer design every other script in this framework goes out of its way to preserve (see [werkstatt.gpg.export.key.sh](werkstatt.gpg.export.key.sh.md)'s `-W` warning) — accepted here deliberately, for demo convenience. Clean up `$MFTE_GPG_ONBOARDING_PRIVACY_DIR` once every hub has imported; this script does not do that for you.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Onboarded successfully (key generated or reused, both exports placed) |
| `1` | Technical error (key generation, export, or relocation failed) |
| `2` | Usage error (bad/missing flags, invalid email) |
| `3` | A secret key already resolves for this email **and** both exports are already fully staged — refused without `-F`. A *partially* staged customer does not hit this code — see "Resume" above |

## Related

[onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md) — run this on every hub after this script generates a key on one. Next step is always that script.
