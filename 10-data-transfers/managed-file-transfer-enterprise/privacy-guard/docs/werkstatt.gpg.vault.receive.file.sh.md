# werkstatt.gpg.vault.receive.file.sh

Given an inbound encrypted file, figures out which of possibly many keys in this keyring it was encrypted to, decrypts it with that one — sourcing the passphrase from Vault fresh on every run rather than a local file — and records a full audit entry for the attempt. Invoked directly by a Control-M Processing Rule the same way [mfte.rule.vars.all.jsonl.sh](mfte.rule.vars.all.jsonl.sh.md) and [werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md) are — **not** chained after either.

## Relationship to werkstatt.gpg.receive.file.sh

Vault-sourced sibling of [werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md) — same relationship [werkstatt.gpg.decrypt.file.sh](werkstatt.gpg.decrypt.file.sh.md) has to [werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md). Every part of this script is **identical** to the plain version — recipient discovery (`--list-packets`), resolving which key ID this keyring holds the secret half of, the full JSONL audit record, the `-R`/`-K` return-path relocation — **except** how the passphrase for the matched key is obtained. The plain version reads a local mode-600 file; this version fetches the passphrase from Vault fresh on every run and hands it to gpg via `--passphrase-fd` + process substitution, never writing it to disk. See [mfte.gpg.vault.sh](mfte.gpg.vault.sh.md)'s header for the fd-survival-through-`runuser` verification this depends on, and [werkstatt.gpg.vault.decrypt.file.sh](werkstatt.gpg.vault.decrypt.file.sh.md)'s doc for the same Vault-reachability trade-off (this script has no functioning fallback if Vault is unreachable/sealed at run time — that's the cost of never materializing the passphrase locally).

A given customer's key needs its passphrase actually **present in Vault** (via [werkstatt.gpg.vault.export.passphrase.sh](werkstatt.gpg.vault.export.passphrase.sh.md)) before a file encrypted to that key can be received through this script — if the recipient resolves to a key this keyring holds the secret half of, but Vault has no passphrase filed for it yet, this fails with `GPG_REASON=vault_passphrase_not_found`, exit code `1` — distinct from "not onboarded at all" (exit `3`, unchanged from the plain version), because the key **does** exist here; only its Vault-side passphrase is missing.

Everything below the passphrase-source difference — why this exists at all (the "one dedicated key per customer" pattern), why `-a`/`-p` work the way they do, the `$MFTE_GPG_RETURN_DIR` relocation rules, the NFS/`ftshome` staging requirement — is identical to `werkstatt.gpg.receive.file.sh`'s own doc; see that file for the full detail this doc doesn't repeat.

## Usage

```
werkstatt.gpg.vault.receive.file.sh -p "$$FILE_PATH$$" [options]
```

`-p` is the only required flag. Same BMC variable flag letters as [mfte.rule.vars.all.jsonl.sh](mfte.rule.vars.all.jsonl.sh.md) (`-a` through `-G`), all folded into this record's own `"variables":{...}` block — see that script's doc for the full flag table.

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
| `-V` | Print this script's own name and version, then exit |
| `-h` | Help |

There is deliberately **no** `-k` for "which key to decrypt with" — `-k` here means event name/type, matching `mfte.rule.vars.all.jsonl.sh`'s own `-k`, default `gpg_receive_file`. The whole point of this script is figuring out which key applies from the file itself.

### Vault env (required)

```
VAULT_ADDR
VAULT_TOKEN                 or:
VAULT_ROLE_ID / VAULT_SECRET_ID
```

### Recommended Run Command

```
werkstatt.gpg.vault.receive.file.sh -r "<rule_name>" -A "<action_name>" -p "$$FILE_PATH$$" -a "${MFTE_GPG_RECEIVE_STAGING_DIR}/$$FILE_NAME$$" -d "$$FILE_DIR$$" -D "$$FILE_ABS_DIR$$" -n "$$FILE_NAME$$" -N "$$FILE_NAME_NO_EXT$$" -e "$$FILE_EXT$$" -E "$$FILE_EXT_NO_DOT$$" -x "$$FILE_DATE$$" -X "$$FILE_DATE_LOCAL$$" -y "$$FILE_TIME$$" -Y "$$FILE_TIME_LOCAL$$" -z "$$FILE_SIZE$$" -u "$$USER$$" -c "$$COMPANY$$" -v "$$VIRTUAL_FOLDER$$" -m "$$EMAIL$$" -t "$$PHONE_NUMBER$$" -s "$$SUB_DIR_PATH$$" -g "$$STAGING_FILE_NAME$$" -G "$$STAGING_FILE_PATH$$" -q
```

Same `${MFTE_GPG_RECEIVE_STAGING_DIR}` shell/`.env` substitution note, the same "`-a` deliberately not `$$FILE_ABS_PATH$$`" reasoning, and the same "leave `-p`/`-d`/`-D` as the raw, sometimes-corrupted BMC token on purpose (MFTE-001)" reasoning as [werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md#recommended-run-command) — see that doc for the full explanation; nothing about the Vault sourcing changes any of it.

## NFS considerations

Identical to [werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md#nfs-considerations): `mftgpg` cannot reach `$MFTE_FTS_HOME`/`$MFTE_B2B_HOME` on any hub, so a Move File post-processing action into `$MFTE_GPG_RECEIVE_STAGING_DIR` is still mandatory before this script's action runs, and the final archival move into `$MFTE_GPG_RETURN_DIR` still runs as root (not `runuser -u mftgpg`) for the same `no_root_squash` reason. See that doc's full section for details and the `runuser -u mftgpg -- test -r <file>` verification command.

## Output schema

Carries the same `"variables":{...}` BMC-variable block `mfte.rule.vars.all.jsonl.sh` writes, plus this script's own blocks — schema `controlm_mfte_gpg_vault_receive_v1` (note the `_vault_` in the schema name, distinguishing it from the plain version's `controlm_mfte_gpg_receive_v1`):

```json
{
  "schema": "controlm_mfte_gpg_vault_receive_v1",
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
    "passphrase_source": "vault",
    "vault_path": "...",
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

The `"gpg"` block adds `passphrase_source` (always `"vault"` here) and `vault_path` compared to the plain version's record — otherwise identical shape.

Since a GPG-receive rule and a plain file-arrival rule are never the same Control-M rule, this record is always the sole record for its event — it does not rely on `mfte.rule.vars.all.jsonl.sh` having run at all.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Decrypted successfully (even if the audit write itself failed — the customer's file already exists on disk at that point; see `audit_write` in the stdout line) |
| `1` | Technical error: file resolves to **more than one** usable secret key (ambiguous — ruled out on purpose, not guessed), gpg preflight failure, Vault preflight/auth failure, the key is in the keyring but **no passphrase is filed in Vault yet** (`GPG_REASON=vault_passphrase_not_found`), or the gpg decrypt call itself failed |
| `2` | Usage error |
| `3` | File's recipient(s) resolved, but **none** are a key this keyring holds the secret half of — "customer not onboarded yet (or onboarded on a different hub)". Unchanged from the plain version — a Vault-side passphrase gap is a distinct case (exit `1`), not this one. |
| `4` | File is not a public-key-encrypted OpenPGP message at all — not an error, just outside this script's domain |

## Related

[werkstatt.gpg.receive.file.sh](werkstatt.gpg.receive.file.sh.md) is the plain (local-passphrase-file) version this mirrors — read that doc first for the full "why this exists," NFS, and Run Command reasoning shared by both. [werkstatt.gpg.vault.export.passphrase.sh](werkstatt.gpg.vault.export.passphrase.sh.md) / [werkstatt.gpg.vault.export.all.passphrases.sh](werkstatt.gpg.vault.export.all.passphrases.sh.md) are how a customer's passphrase gets into Vault before this script can decrypt for them. [werkstatt.gpg.vault.status.sh](werkstatt.gpg.vault.status.sh.md) diagnoses `vault_passphrase_not_found` and other Vault-side failures ahead of a real inbound event. [werkstatt.gpg.fingerprint.file.sh](werkstatt.gpg.fingerprint.file.sh.md) does the recipient-discovery half of this standalone (for manual inspection). [onboarding-4gpg-server.sh](onboarding-4gpg-server.sh.md) / [onboarding-4gpg-cluster.sh](onboarding-4gpg-cluster.sh.md) provision the keys this script looks for.
