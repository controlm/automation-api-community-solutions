# werkstatt.gpg.receive.file.sh

Given an inbound encrypted file, figures out which of possibly many keys in this keyring it was encrypted to, decrypts it with that one, and records a full audit entry for the attempt. Invoked directly by a Control-M Processing Rule the same way [mfte.rule.vars.all.jsonl.sh](mfte.rule.vars.all.jsonl.sh.md) is — **not** chained after it.

## Why this exists

Built for the "one dedicated key per customer" pattern: N customers, N keypairs, all N secret halves held by `mftgpg`, each customer only ever seeing their own public key. A file arrives encrypted to exactly one of those N keys, and nothing upstream tells this script which one — that's the whole reason it exists, rather than always using [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md)'s `-k` or its single default-key fallback. It fuses [werkstatt.gpg.fingerprint.file.sh](werkstatt.gpg.fingerprint.file.sh.md)'s recipient discovery (`--list-packets`) with `werkstatt.gpg.decrypt.file.sh`'s actual decrypt logic.

gpg itself already auto-selects the matching secret key from a file's own packet headers when you run `--decrypt` — it does not need `--recipient`/`--local-user`. What it needs is the correct `--passphrase-file` for whichever secret key it ends up using, and with N distinct keys there is no single passphrase file that works for all of them. So the real job here is: identify the recipient key ID from the file, resolve it to a fingerprint this keyring holds the secret half of, locate that fingerprint's own passphrase file, and only then call `--decrypt`.

This script does **not** handle onboarding (matching an inbound sender to a customer record, provisioning a new customer's keypair). It only ever looks at what's already in the keyring against what the file itself needs — see [onboarding-4gpg-server.sh](onboarding-4gpg-server.sh.md) for provisioning.

## Usage

```
werkstatt.gpg.receive.file.sh -p "$$FILE_PATH$$" [options]
```

`-p` is the only required flag. Same BMC variable flag letters as `mfte.rule.vars.all.jsonl.sh` (`-a` through `-G`), all folded into this record's own `"variables":{...}` block — see that script's doc for the full flag table.

### GPG / audit options

| Flag | Meaning |
|---|---|
| `-w` | Decrypt output path, default: derived from the file under `$MFTE_GPG_OUTPUT_DIR` |
| `-R` | Final path for the **decrypted** file, applied only after a successful decrypt. Default: computed from `$MFTE_GPG_RETURN_DIR` |
| `-K` | Final path for the now-processed **encrypted original** — applied on **every** outcome (decrypted, no_key, skipped, or error), not just success. Default: computed from `$MFTE_GPG_RETURN_DIR` |
| `-o` | Report mode: `jsonl`\|`json-file`\|`both`, default `$MFTE_LOG_FORMAT` |
| `-l` | Custom log directory override |
| `-j` | Print the full JSON record to stdout instead of a short status line |
| `-q` | Quiet — nothing to stdout (wins over `-j` if both given) |
| `-h` | Help |

There is deliberately **no** `-k` for "which key to decrypt with" — `-k` here means event name/type, matching `mfte.rule.vars.all.jsonl.sh`'s own `-k`. The whole point of this script is figuring out which key applies from the file itself. If you already know the key, `werkstatt.gpg.decrypt.file.sh -k` is the more direct tool.

### File path used for the actual gpg operations

`-a FILE_ABS_PATH` is used for the real gpg calls when given, falling back to `-p FILE_PATH` otherwise. `-p` is the only *required* flag per spec, but pass both in production — a relative/virtual `FILE_PATH` handed straight to gpg can fail to open depending on this process's cwd.

### `$MFTE_GPG_RETURN_DIR`

A single `.env` path used for both `-R` and `-K`'s defaults, in either form:

```
MFTE_GPG_RETURN_DIR="/mnt/ftshome/b2bhome/secureTransport/{TYPE}"
MFTE_GPG_RETURN_DIR="/mnt/ftshome/b2bhome/secureTransport"
```

With the literal text `{TYPE}` (a plain string substitution this script does itself, not shell expansion), it's replaced with `encrypted`/`decrypted`; without it, `/encrypted` or `/decrypted` is appended automatically. Either way the two file types always land in separate subfolders, created on first use. Neither `-R`/`-K` nor this variable is required — unset means both files are left exactly where earlier flags/defaults already put them.

**The encrypted original moves on every outcome**, not just a successful decrypt — staging is only reachable by `mftgpg`/root, and leaving a file there after a `no_key`/`skipped`/error outcome would strand it somewhere the admin can never reach again. The **decrypted** output only moves when the decrypt actually succeeded (there's nothing to move otherwise). This final move runs as whatever this script is already running as (root), not via `runuser -u mftgpg` — deliberate, since this environment's NFS exports have `no_root_squash` set (root already has unrestricted access across every export), so the move works without requesting a new `mftgpg` permission grant on the return destination. Retention of files at the return destinations is **not** this script's job — once landed there, cleanup is on whoever owns that filesystem.

### Recommended Run Command

```
werkstatt.gpg.receive.file.sh -r "<rule_name>" -A "<action_name>" -p "$$FILE_PATH$$" -a "${MFTE_GPG_RECEIVE_STAGING_DIR}/$$FILE_NAME$$" -d "$$FILE_DIR$$" -D "$$FILE_ABS_DIR$$" -n "$$FILE_NAME$$" -N "$$FILE_NAME_NO_EXT$$" -e "$$FILE_EXT$$" -E "$$FILE_EXT_NO_DOT$$" -x "$$FILE_DATE$$" -X "$$FILE_DATE_LOCAL$$" -y "$$FILE_TIME$$" -Y "$$FILE_TIME_LOCAL$$" -z "$$FILE_SIZE$$" -u "$$USER$$" -c "$$COMPANY$$" -v "$$VIRTUAL_FOLDER$$" -m "$$EMAIL$$" -t "$$PHONE_NUMBER$$" -s "$$SUB_DIR_PATH$$" -g "$$STAGING_FILE_NAME$$" -G "$$STAGING_FILE_PATH$$" -q
```

`${MFTE_GPG_RECEIVE_STAGING_DIR}` above is a shell/`.env` variable reference, not a BMC `$$VAR$$` token — substitute its actual resolved value when building the real Run Command, since Control-M's agent does not expand plain shell variables itself.

**`-a` is deliberately not `$$FILE_ABS_PATH$$`.** If a prior action in the same rule moves the inbound file (a native "Move File" post-processing step relocating it out of a root-only landing directory into a staging directory `mftgpg` can actually read — see "NFS considerations" below), `$$FILE_ABS_PATH$$` is the one variable that actually gets read by this script (it prefers `-a` over `-p`), so it's worth hand-building from the known, fixed staging directory plus `$$FILE_NAME$$` (which the move doesn't change) rather than trusting Control-M's post-Move recomputation of it.

Every other flag — including `-p`, `-d`, `-D` — is left as the raw BMC token on purpose, even though `$$FILE_PATH$$`/`$$FILE_DIR$$` are known to come back corrupted after this kind of Move (a real BMC product issue — track as `MFTE-001` if you file one). These flags aren't read by this script for anything operational; they only feed the `"variables":{...}` audit block. Hand-building them to paper over the corruption would hide the real product bug's actual output from that record — exactly the evidence needed to diagnose it. `-a` is the sole exception because it's the one flag this script actually depends on to function.

## NFS considerations

**In a cluster, `$MFTE_FTS_HOME` (and everything under it, including `$MFTE_B2B_HOME`) lives on a shared NFS mount that `mftgpg` cannot access at all — not on this hub, not on any hub.** The MFT Client component that owns `ftshome`/`b2bhome` runs as root, manages that tree as root, and never grants `mftgpg` (a deliberately least-privileged account — see the main [README](../README.md#why-a-dedicated-service-account-mftgpg)) any standing access to it. This is true cluster-wide because the mount itself is shared, not a per-host quirk. Since Control-M rule/action scripts also run as root, a file landing anywhere under `ftshome` is directly readable by the rule itself but **not** by `mftgpg`, and this script's `gpg --list-packets` call fails with "can't open" — indistinguishable from "this file isn't GPG-encrypted at all." Both report as `NOTHING_TO_DO` / exit `4`. This is why the Move File step below is mandatory, not just a hardening nicety.

**Testing this must be done as `mftgpg`, never as root, or the test lies to you.** If this environment's NFS exports additionally have `no_root_squash` set, a root shell's `ls`/`cat`/`sha256sum` succeeds regardless of the real underlying permissions — the client's root maps to the server's root too, bypassing all permission checks — which can make it look like `mftgpg` has access when the `ftshome`/`b2bhome` restriction above means it doesn't. Always verify with:

```
runuser -u mftgpg -- test -r <file> && echo OK || echo DENIED
```

**The fix: relocate the file to somewhere on the NFS share outside `ftshome` that `mftgpg` can actually reach.** A Control-M rule's native "Move File" post-processing action relocates the inbound file from its `ftshome`-rooted landing directory into `$MFTE_GPG_RECEIVE_STAGING_DIR` — a directory `mftgpg` has standing access to, provisioned by [setup.mftgpg.sh](setup.mftgpg.sh.md) (`2775`, group `controlm`) — before this script's action runs. The same asymmetry applies in reverse on the way out: the final archival move into `$MFTE_GPG_RETURN_DIR` (itself under `b2bhome`) has to run as this script's own identity (root), not via `runuser -u mftgpg`, precisely because `mftgpg` can't write back into `ftshome` either — see "return" in the header comment above.

## Output schema

Carries the same `"variables":{...}` BMC-variable block `mfte.rule.vars.all.jsonl.sh` writes (via the shared `mfte_json_bmc_variables_block()` function), plus this script's own blocks:

```json
{
  "schema": "controlm_mfte_gpg_receive_v1",
  "...": "run_id, timestamp, host, run_user, source, event, rule_name, action_name",
  "variables": { "...": "same BMC-variable block as mfte.rule.vars.all.jsonl.sh" },
  "file": { "operate_path": "..." },
  "gpg": {
    "status": "decrypted | no_key | skipped | error",
    "decrypted": true,
    "reason": "",
    "recipient_keyid": "...",
    "fingerprint": "...",
    "uid": "...",
    "output": "...",
    "sha256": "..."
  },
  "return": {
    "decrypted_path": "...",
    "encrypted_path": "...",
    "moved": true,
    "move_ok": true
  }
}
```

Since a GPG-receive rule and a plain file-arrival rule are never the same Control-M rule, this record is always the sole record for its event — it does not rely on `mfte.rule.vars.all.jsonl.sh` having run at all.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Decrypted successfully (even if the audit write itself failed — the customer's file already exists on disk at that point; see `audit_write` in the stdout line) |
| `1` | Technical error: file resolves to **more than one** usable secret key (ambiguous — ruled out on purpose, not guessed), preflight failure, or the gpg decrypt call itself failed |
| `2` | Usage error |
| `3` | File's recipient(s) resolved, but **none** are a key this keyring holds the secret half of — "customer not onboarded yet (or onboarded on a different hub)" |
| `4` | File is not a public-key-encrypted OpenPGP message at all — not an error, just outside this script's domain |

## Origin

Not one of the original nine training scripts. Built for real usage once the one-key-per-customer pattern needed an automated inbound handler.

## Related

[werkstatt.gpg.fingerprint.file.sh](werkstatt.gpg.fingerprint.file.sh.md) does the recipient-discovery half of this standalone (for manual inspection). [onboarding-4gpg-server.sh](onboarding-4gpg-server.sh.md) / [onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md) provision the keys this script looks for. See the main [README](../README.md#multi-hub--nfs-considerations) for the broader NFS/no_root_squash context.
