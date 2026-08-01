# Managed File Transfer Enterprise

## Purpose

This folder collects example tooling for operating a Control-M Managed
File Transfer Enterprise (MFTE) hub — two independent subprojects, plus a
repo-level layer that packages both together for deployment.

| Subproject | Answers | Docs |
|---|---|---|
| [privacy-guard](privacy-guard/README.md) | GPG encryption/decryption in flight (dedicated service account, per-customer keys, automatic inbound key resolution) and structured JSON auditing of every Control-M Processing Rule Action variable. Runs as Control-M Run Commands on the hub. | [privacy-guard/README.md](privacy-guard/README.md), one doc per script under [privacy-guard/docs/](privacy-guard/docs/) |
| [site-connection-test](site-connection-test/README.md) | "Are LDAP and SMTP actually reachable and correctly configured, right now?" — a real LDAP/LDAPS bind+search+schema-validation and SMTP send test, plus scripts to fetch and trust a server's TLS certificate when either test fails on a certificate error. | [site-connection-test/README.md](site-connection-test/README.md), function reference in [site-connection-test/docs/README.md](site-connection-test/docs/README.md) |

Both are independent — neither depends on the other's code — but they're
packaged together (see below) because an MFTE hub operator typically wants
both toolsets available in the same place.

## Layout

```
managed-file-transfer-enterprise/
├── README.md              this file
├── collect-tools.sh        merges every subproject's tools into tools/ + package/tools-v<version>.tar.gz
├── privacy-guard/           GPG encryption + rule-variable auditing (see table above)
│   └── src/                 bin/, lib/bash/, config/ — no packaging script of its own
├── site-connection-test/    LDAP/SMTP connectivity test + cert-trust scripts (see table above)
│   └── src/
│       ├── build_package.py     per-project packaging -> site-connection-test/package/*.zip
│       └── bin/, lib/bash/, config/, vendor/, data/
├── tools/                   generated -- merged output of collect-tools.sh, see tools/README.md
└── package/                 generated -- collect-tools.sh's tarball output
```

## Packaging: two layers

**Per-project** — `site-connection-test/src/build_package.py` zips just
that one tool (`ldap_smtp_test.py` + its `vendor/`/`config/`/`data/`/
`bin/`/`lib/`) into `site-connection-test/package/mfte_ldap_smtp_test-v<version>.zip`.
Use this when you only need the connectivity-test tool standalone.
`privacy-guard` has no equivalent of its own — its only packaging path is
the repo-level layer below.

**Repo-level** — `./collect-tools.sh`, run from this directory, merges
**every** subproject's `src/{bin,lib/bash,config,vendor,data}` (plus any
top-level entry script) into one flat `tools/` folder and a versioned
`package/tools-v<version>.tar.gz`. This is what actually gets copied onto
a hub in practice — an operator `cd`s into one `tools` directory and runs
whatever script is needed, rather than juggling separate per-project
deploy zips. New subprojects are picked up automatically as long as they
follow the same `<project>/src/` layout — see the header comment in
[collect-tools.sh](collect-tools.sh) and [tools/README.md](tools/README.md)
for the collision-handling and exclusion rules.

```bash
./collect-tools.sh          # collect + build package/tools-v<version>.tar.gz
./collect-tools.sh -n       # dry run -- show what would change, write nothing
./collect-tools.sh -T       # collect into tools/, skip the tarball
./collect-tools.sh -h       # full flag list
```

## Adding a new subproject

More subprojects will land here over time. `collect-tools.sh` picks up a
new one automatically — no script changes needed — as long as it follows
the same layout as the two above:

```
<new-project>/
└── src/
    ├── <entry-script>.py|.sh   optional -- a top-level tool, if it has one
    ├── bin/*.sh                 optional
    ├── lib/bash/*.sh             optional
    ├── config/*                  optional -- never commit a real .env, only sample.env-style templates
    ├── vendor/**                  optional
    └── data/*                    optional
```

Only the subproject table and layout diagram near the top of this file
are hand-maintained — update those when you add one, so the overview
here doesn't silently fall behind what `collect-tools.sh` is actually
packaging.
