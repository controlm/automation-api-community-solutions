# werkstatt.gpg.fingerprint.file.sh

Given an **encrypted file**, lists the key(s) it was encrypted to — i.e. which key(s) you may need to decrypt it — and whether each is present in this keyring with its secret half (meaning you can actually decrypt with it right now, vs. it being a recipient key you don't hold).

This inspects an **encrypted message**. If you have a **key file** instead and want its fingerprint before importing it, use [werkstatt.gpg.inspect.key.file.sh](werkstatt.gpg.inspect.key.file.sh.md) — a different operation on a different kind of input.

## Usage

```
werkstatt.gpg.fingerprint.file.sh -f "<file>" [options]
```

| Flag | Meaning |
|---|---|
| `-f` | **Required.** Path to the encrypted file to inspect |
| `-j` | Print a JSON array instead of a human-readable report |
| `-h` | Help |

```
werkstatt.gpg.fingerprint.file.sh -f "$$FILE_ABS_PATH$$"
```

For each recipient key the file was encrypted to, reports the key ID from the message itself, whether that key is present in this keyring (fingerprint + uid if so), and whether the secret half is present too. A file encrypted to a key you don't hold shows `in_keyring=false` — you'd need to obtain/import that key before [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md) can work.

## Origin

Used to inspect standalone key files instead. Real usage showed that's not what "fingerprint file" means to whoever's actually running these scripts — the natural reach was straight for an encrypted message, wanting to know what it takes to open it. That capability moved to `werkstatt.gpg.inspect.key.file.sh`, which does exactly what this script used to do.

`gpg --list-packets` reads OpenPGP packet headers only — it does not decrypt anything and needs no passphrase. It does, as a side effect, print "public key decryption failed" / "no secret key" noise to stderr when it can't complete a session-key decryption attempt — harmless, not surfaced as an error here.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | File not found/unreadable, or no `:pubkey enc packet:` entries found (not a public-key-encrypted message — e.g. symmetric/passphrase-only encryption, nothing to report) |

## Related

[werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md) fuses this same recipient discovery with an actual decrypt, for the automated inbound case.
