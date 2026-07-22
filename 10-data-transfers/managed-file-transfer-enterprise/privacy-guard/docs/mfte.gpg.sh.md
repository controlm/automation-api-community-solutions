# mfte.gpg.sh

Shared GPG library, sourced by every `werkstatt.gpg.*.sh` and `onboarding-4gpg-*.sh` script — always **after** `mfte.sh`. Provides privilege-dropping gpg invocation, passphrase-file handling, default-key metadata, and fingerprint lookup/import helpers, so no calling script re-rolls any of it independently.

Kept as a separate library rather than folded into `mfte.sh` so scripts that have nothing to do with GPG (e.g. `mfte.rule.vars.all.jsonl.sh`) aren't forced to satisfy `gpg`/`runuser`/`openssl` dependency checks they don't need.

## Requirements

Hard-requires `gpg`, `runuser`, `openssl` on `PATH`, and these already-sourced `.env` variables (fails loudly if any are unset): `MFTE_GPG_USER`, `MFTE_GPG_HOME`, `MFTE_GPG_META_DIR`, `MFTE_GPG_PASSPHRASE_DIR`, `MFTE_GPG_OUTPUT_DIR`, `MFTE_GPG_EXCHANGE_DIR`.

## Privilege model

All actual `gpg` calls run as a dedicated service account (`MFTE_GPG_USER`, typically `mftgpg`), never as the identity Control-M's agent uses to invoke the calling script (root, on this platform — there's no Control-M "RunAs" option). `mfte_gpg_run` is the one entry point:

```bash
mfte_gpg_run() {
    runuser -u "${MFTE_GPG_USER}" -- gpg --homedir "${MFTE_GPG_HOME}" "$@"
}
```

`--homedir` is passed explicitly on every call rather than relying on `GNUPGHOME` surviving the identity switch — `runuser` doesn't guarantee the caller's environment reaches the target user's shell the way a plain env var export would.

## Functions

### Preflight & permission checks

| Function | Purpose |
|---|---|
| `mfte_gpg_preflight` | Call once per script, after argument parsing, before any real gpg operation. Refuses to proceed unless `MFTE_GPG_HOME` is exactly mode 700, owned by `MFTE_GPG_USER` — fails loudly at the start of a run, not partway through an operation. |
| `mfte_gpg_require_locked_down PATH MODE` | Refuses to use a key/passphrase file or directory whose mode or owner doesn't match what's expected (e.g. `600`), rather than trusting it blindly. |

### Passphrase handling

One passphrase file per key, named by fingerprint, under `MFTE_GPG_PASSPHRASE_DIR` (mode 700), each file mode 600, both owned by `MFTE_GPG_USER`. The passphrase value itself never appears as a CLI argument, in stdout, or in any log line these functions write.

| Function | Purpose |
|---|---|
| `mfte_gpg_passphrase_file IDENT` | Prints the conventional path for a fingerprint's passphrase file. |
| `mfte_gpg_write_passphrase_file IDENT PASSPHRASE` | Writes/overwrites a passphrase file as `MFTE_GPG_USER`, mode 600. Callers must pass the value straight from generation into this function and let it go out of scope — never echo/printf/log it themselves. |
| `mfte_gpg_generate_passphrase` | `openssl rand -base64 24`. Result must go straight to `mfte_gpg_write_passphrase_file`, never to stdout or a log line. |
| `mfte_gpg_copy_passphrase_as_user SRC DST` | Copies a passphrase file to a new location **as** `MFTE_GPG_USER`, not as the calling script's own identity (typically root) — a plain `cp` would leave the copy root-owned, inconsistent with every other passphrase file in this framework. Creates the destination directory (also as `MFTE_GPG_USER`) if needed, locks the result to 600. |

### Default-key metadata

Replaces the old `dsse.gpg.info.json` concept. `default-key.json` (under `MFTE_GPG_META_DIR`) holds only `fingerprint`, `uid`, `created`, and a `passphrase_file` **path** — never the passphrase itself, so it can safely stay more widely readable (644) than the passphrase file (600) it points at.

| Function | Purpose |
|---|---|
| `mfte_gpg_write_default_key_json FINGERPRINT UID CREATED` | Writes `default-key.json` atomically (via a temp file + `mv`). |
| `mfte_gpg_default_fingerprint` | Prints the default fingerprint, or nothing if the file doesn't exist / isn't valid JSON. |

### Fingerprint / key lookup

| Function | Purpose |
|---|---|
| `mfte_gpg_sanitize_key_id RAW` | Strips whitespace from a pasted fingerprint (gpg's own display groups it in 4-hex-char chunks) — but only when what's left is purely hex, so a uid/email search term containing a real space (`"Jane Doe <jane@example.com>"`) passes through untouched. Safe to call unconditionally on any `-k` value. |
| `mfte_gpg_lookup_fingerprint TERM [public\|secret]` | Resolves a search term to a full 40-char **primary**-key fingerprint via `gpg --with-colons`. Only counts the `fpr` line immediately following a `pub`/`sec` record — see "Known bug" below. Prints nothing and returns 1 on no match or more than one distinct identity match; an ambiguous recipient/signer fails loudly rather than guessing. |
| `mfte_gpg_uid_for_fingerprint FP [public\|secret]` | Prints the primary uid string for a fingerprint. |
| `mfte_gpg_find_single_file DIR PATTERN` | Non-recursive glob match. Prints the one matching file if exactly one exists; prints nothing and returns 1 on zero or multiple matches — used to default a script's `-f` to "the one file already staged," never to guess among several candidates. |

**Known bug, already fixed here:** with the cert+sign+encrypt subkey structure this framework uses (see `werkstatt.gpg.generate.key.sh`), a naive `gpg --with-colons --list-keys <term> | grep fpr` returns three fingerprint lines per identity (primary + two subkeys), which made every lookup look "ambiguous" even for a single actual match. This was caught by actually running the code, not by review. Fixed by only counting the fingerprint immediately following a `pub`/`sec` record, and resetting the capture flag on `sub`/`ssb`. Worth remembering if you extend this library — `sub`/`ssb` records carry their own `fpr` lines too, and it's easy to double-count them.

### Import

| Function | Purpose |
|---|---|
| `mfte_gpg_import_key PATH public\|private` | Shared import call for every import script. `--status-fd 1` output is included so the caller can grep an `IMPORT_OK` line for the imported fingerprint instead of re-listing the whole keyring. The mode argument is used by callers for validation/logging, not to change the underlying gpg invocation (gpg imports both public and secret material from the same command). |
| `mfte_gpg_import_fingerprint IMPORT_OUTPUT` | Extracts the fingerprint from an `IMPORT_OK` status line. Prints nothing if none found (import failed, or key already present with no change). |
| `mfte_gpg_file_show_only PATH` | `gpg --import-options show-only` against a key **file** — reads packet headers without touching the keyring or unlocking anything. Returns non-zero if gpg couldn't read any key material at all. |
| `mfte_gpg_file_fingerprint SHOW_ONLY_OUTPUT` | Extracts the primary key's fingerprint from `mfte_gpg_file_show_only`'s output, same primary-record-only rule as `mfte_gpg_lookup_fingerprint`. |
| `mfte_gpg_file_has_secret SHOW_ONLY_OUTPUT` | Prints `"true"` if the file's primary record is `sec` (carries secret key material), `"false"` if `pub`. Checked against the first `pub`/`sec` record specifically. |

### Misc

| Function | Purpose |
|---|---|
| `mfte_increment_filename PATH` | Returns `PATH` unchanged if nothing exists there yet, otherwise `PATH.1`, `PATH.2`, ... — the first that doesn't exist. Shared by `werkstatt.gpg.decrypt.file.sh` and `werkstatt.gpg.receive.file.sh`. |

## Origin

These scripts originated as training material, written to show a student every intermediate value — including passphrases — in plain view, deliberately. That was the right call for its original purpose. This library exists because the scripts are moving into a production-like demo, where the same transparency in stdout/logs would mean a passphrase or key sitting in a Control-M job log forever. The functions above exist to make that not happen by default, without treating the original training design as a mistake.
