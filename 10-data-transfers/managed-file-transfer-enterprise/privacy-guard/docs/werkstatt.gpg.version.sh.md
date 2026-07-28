# werkstatt.gpg.version.sh

Print the version of every `werkstatt.*.sh`/`mfte.*.sh` script and library actually deployed on **this** node, in one command.

## Why this exists

Built to answer "do we have the wrong/outdated script on this server" — node by node — without having to check each file's `SCRIPT_VERSION` by hand, or simply trust that a deploy actually reached every cluster member. The framework home is shared across hubs in principle (`/mnt/mfte/ops` on shared NFS in a clustered deployment — see the main [README](../README.md)'s Layout section), but nothing prevents one hub from lagging behind after a rollout; this gives a single command to confirm what's really on disk.

Pure static `grep` against file contents — runs no other script, executes no gpg or Vault call, has no dependency beyond what `mfte.sh` itself already requires.

## Usage

```
werkstatt.gpg.version.sh [options]
```

| Flag | Meaning |
|---|---|
| `-j` | Emit as JSON instead of a plain table |
| `-V` | Print this script's own name and version, then exit |
| `-h` | Help |

```
werkstatt.gpg.version.sh
werkstatt.gpg.version.sh -j
```

## What it reads

- This node's hostname (so output copy-pasted between nodes is unambiguous about which node it came from).
- Every `bin/*.sh` script's `SCRIPT_VERSION="..."` line (first match only; scripts without one report `<no version found>` rather than failing).
- The version constant out of every `lib/bash/*.sh` library (`MFTE_LIB_VERSION`, `MFTE_GPG_LIB_VERSION`, `MFTE_GPG_VAULT_LIB_VERSION`), matched generically via `^MFTE_[A-Z_]*_VERSION=` rather than one hardcoded name per file, so a new library only needs to follow that naming convention to show up here automatically.

## Output

Plain table by default (`Host:`, then `=== bin/ scripts ===` and `=== lib/bash/ libraries ===` sections); `-j` emits the same data as `{"host":"...","scripts":{...},"libraries":{...}}`.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Always — this is a report, not a pass/fail gate |
| `2` | Usage error (unknown flag, missing value, unexpected extra arguments) |

## Related

Every `werkstatt.gpg.vault.*.sh` script and `mfte.gpg.vault.sh` carry `SCRIPT_VERSION="1.0.0"` / `MFTE_GPG_VAULT_LIB_VERSION="1.0.0"` respectively, so they show up here the same as everything else — no special-casing needed for the Vault-backed family.
