# werkstatt.gpg.delete.key.sh

Remove a key (public, secret, or both) from the `mftgpg` keyring.

## Safety

This is the one operation in this script family that is **not** safely re-runnable — deleting a key you don't have a backup of is permanent. `-k` is required with no default-key fallback (never guess what to delete), and the script defaults to a **dry run** that reports what it would do without touching anything; pass `-y` to actually perform the deletion. This matters specifically because these scripts are invoked from Control-M Run Commands, where an argument-parsing mistake upstream (see [mfte.sh](mfte.sh.md)'s argv-quoting discussion) could otherwise turn "check a fingerprint" into "delete a key" with no human in the loop.

## Usage

```
werkstatt.gpg.delete.key.sh -k "<fingerprint>" [options]
```

| Flag | Meaning |
|---|---|
| `-k` | **Required.** Full fingerprint to delete — no default-key fallback |
| `-m` | Mode: `public` (default — fails if a secret key is still present, delete that first), `secret` (keeps the public half, e.g. to still verify old signatures), or `both` |
| `-y` | Actually perform the deletion. Without it, only reports what *would* be deleted (exit `3`) and changes nothing |
| `-q` | Quiet |
| `-h` | Help |

```
werkstatt.gpg.delete.key.sh -k "<fingerprint>" -m both -q       # dry run
werkstatt.gpg.delete.key.sh -k "<fingerprint>" -m both -y -q    # confirm
```

Deleting a secret key also removes its passphrase file under `$MFTE_GPG_PASSPHRASE_DIR`, and clears `default-key.json` if it pointed at the deleted key.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Deletion completed |
| `1` | Key not found, or requested mode needs a secret key that isn't present |
| `2` | Usage error (missing `-k`, invalid `-m`) |
| `3` | Dry run completed — nothing deleted, re-run with `-y` to confirm |

## Related

[werkstatt.gpg.list.keys.sh](werkstatt.gpg.list.keys.sh.md) to see what's actually in the keyring before deleting.
