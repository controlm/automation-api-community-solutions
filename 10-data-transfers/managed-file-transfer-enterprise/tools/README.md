# tools/

A single flat folder holding every interactively-run python/bash tool from
this repo's subprojects, merged together — matching how these actually get
used on a hub: an operator `cd`s into one `tools` directory and runs
whatever script is needed, rather than juggling separate per-project deploy
zips.

**This folder is generated.** Don't hand-edit anything in it — edit the
source under `../site-connection-test/src/` or `../privacy-guard/src/`
instead, then regenerate:

```bash
cd ..
./collect-tools.sh
```

Add `-n` for a dry run (prints what would change, writes nothing), `-T` to
collect without building the tarball, or `-h` for the full flag list.

Each run also builds `../package/mfte-tools-<version>.tar.gz` — a tarball of
this whole folder, versioned off `collect-tools.sh`'s own
`SCRIPT_VERSION` (bump that when the packaging changes, independent of
any individual tool's own version). Extracting it produces a `tools/`
folder identical to this one, minus the internal
`.collector-manifest.txt` bookkeeping file.

`../package/mfte-tools-latest.tar.gz` is a plain copy of that same
tarball under a stable filename, updated on every run — so a download
URL doesn't need to know the current version:

```bash
wget https://raw.githubusercontent.com/controlm/automation-api-community-solutions/master/10-data-transfers/managed-file-transfer-enterprise/package/mfte-tools-latest.tar.gz
```

It's a real copy, not a symlink — GitHub's raw-content endpoint serves a
symlink as the literal text of its target path, not the target file's
actual bytes, which would silently break `wget`/`curl` downloads of
`latest`.

## Layout

```
tools/
├── README.md                              this file
├── .collector-manifest.txt                internal bookkeeping — don't edit
├── ldap_smtp_test.py                       site-connection-test
├── bin/
│   ├── ldaps-import-cert.sh                site-connection-test
│   ├── smtp-tls-import-cert.sh             site-connection-test
│   └── werkstatt.*.sh (28 scripts)         privacy-guard
├── lib/bash/
│   ├── cert_trust_common.sh                site-connection-test
│   └── mfte*.sh (3 files)                  privacy-guard
├── config/
│   ├── site-connection-test.sample.env     site-connection-test's config/sample.env, renamed
│   ├── privacy-guard.sample.env            privacy-guard's config/sample.env, renamed
│   └── data.mftgpg.json                    privacy-guard
├── vendor/                                 site-connection-test — bundled ldap3/pyasn1
└── data/
    └── user_onboarding_template.ftl        site-connection-test
```

## Why two `sample.env` files, renamed

Both subprojects ship a `config/sample.env`, but they configure completely
unrelated things — `hub.ldap.*`/`spring.mail.*` keys for
`ldap_smtp_test.py` vs. `MFTE_HOME`/`MFTE_GPG_*` framework keys for the
`werkstatt.gpg.*.sh` scripts. `collect-tools.sh` detects this automatically
(by content, not a hardcoded filename list) and renames **both** files with
their project name rather than letting one silently overwrite the other.

## Known limitation: both tools want the same `config/.env`

Because everything is now flattened into one `config/` folder,
`ldap_smtp_test.py`'s default `.env` path and `mfte.sh`'s default `.env`
path (sourced by every `werkstatt.gpg.*.sh` script) both resolve to the
exact same file: `tools/config/.env`. That's fine if you only use one
toolset at a time, but you can't populate `config/.env` for both
simultaneously — one would silently be reading the other's file.

Both tools already support an override, so use differently-named real
files instead of the shared default:

```bash
# site-connection-test
cp config/site-connection-test.sample.env config/site-connection-test.env
# edit config/site-connection-test.env, then:
python3 ldap_smtp_test.py -e config/site-connection-test.env

# privacy-guard
cp config/privacy-guard.sample.env config/privacy-guard.env
# edit config/privacy-guard.env, then:
MFTE_CONFIG_FILE=config/privacy-guard.env bin/werkstatt.gpg.list.keys.sh
```

(`ldap_smtp_test.py` running directly on the hub doesn't need any of this —
it auto-detects the real `hub_config.properties` and never touches
`config/.env` at all in that case.)

## Requirements

| Tool | Needs |
|---|---|
| `ldap_smtp_test.py` | `python3` only — `vendor/` bundles `ldap3`/`pyasn1`, no `pip install` |
| `bin/ldaps-import-cert.sh`, `bin/smtp-tls-import-cert.sh` | `bash`, `openssl`; `sudo` + `update-ca-trust` for `-i` (RHEL) |
| `bin/werkstatt.gpg.*.sh` | `bash`, `jq`, `sha256sum`, `file`, `hostname`, `flock`, `gpg` — all standard on RHEL. Also needs `MFTE_OPS_HOME`-style config: see `config/privacy-guard.sample.env` and the override note above. |

## Full documentation

This folder is a packaging convenience, not a replacement for each
subproject's own docs:

- `ldap_smtp_test.py`: [../site-connection-test/README.md](../site-connection-test/README.md), function reference in [../site-connection-test/docs/README.md](../site-connection-test/docs/README.md)
- Cert-trust scripts: [../site-connection-test/docs/ldaps-certificate-trust.md](../site-connection-test/docs/ldaps-certificate-trust.md), [../site-connection-test/docs/smtp-tls-certificate-trust.md](../site-connection-test/docs/smtp-tls-certificate-trust.md)
- `werkstatt.gpg.*.sh`: [../privacy-guard/docs/](../privacy-guard/docs/)

## What's deliberately excluded

- `build_package.py` and its own `package/*.zip` output — dev-time
  packaging tooling for `site-connection-test`, not something an operator
  runs from `tools/`.
- `privacy-guard/vault/**` — a separate systemd-deployed subsystem for the
  Vault/DB host, unrelated to this ad-hoc `tools/` workflow.
- Any literal `.env` file — only `sample.env`-style templates are ever
  collected, never a real local config.
- `__pycache__/`, `*.pyc` — gitignored, locally-generated bytecode caches,
  never source.
