# HashiCorp Vault — Install, Setup & MFTE Integration

Lab/demo Vault instance backing the `werkstatt.gpg.vault.*.sh` script
family, prepared ahead of Control-M's own native HashiCorp Vault
integration becoming available. This document covers how the instance was
built, how it's configured, and how the MFTE scripts talk to it.

---

## 1. What this actually does

GPG private keys in this framework are decrypt-capable but
passphrase-protected. Historically the passphrase lived in a local,
mode-600 file owned by the `mftgpg` service account
(`$MFTE_GPG_PASSPHRASE_DIR/<fingerprint>.passphrase`). Vault gives this an
alternative: the passphrase is stored centrally, retrieved on demand via
an authenticated API call, and never has to sit as a static file on every
host that needs it.

Two ways the scripts use this:
- **Fetch fresh every run** (`werkstatt.gpg.vault.decrypt.file.sh`,
  `werkstatt.gpg.vault.receive.file.sh`) — the passphrase is pulled from
  Vault and handed to `gpg` via `--passphrase-fd` + process substitution.
  It never touches disk, never becomes a shell variable that's echoed or
  logged, and is gone the moment the `gpg` call completes.
- **Pull once, file locally** (`werkstatt.gpg.vault.import.passphrase.sh`)
  — for a host that would rather keep using the plain, file-based
  `werkstatt.gpg.decrypt.file.sh`/`werkstatt.gpg.receive.file.sh` day to
  day, with Vault only used to distribute the passphrase once.

**Important limitation, stated up front:** Control-M's own native
HashiCorp Vault integration (BMC's "Use External Vault" feature on
connection-profile fields) is **not what this document describes**. That
integration only ever retrieves a value into a *password-type* field
(e.g. an SFTP passphrase) — it has no path for supplying an SSH/GPG
*private key* itself, and this environment doesn't have access to test
that integration yet regardless. Everything here is a standalone,
script-driven Vault integration, built to be ready for when — or if — the
product-level integration becomes available and relevant.

---

## 2. Architecture

```
                 ┌──────────────────────────┐
                 │   Traefik (reverse proxy)│
                 │   TLS termination        │
                 └────────────┬─────────────┘
                              │ plain HTTP, internal Docker network
                              ▼
                 ┌─────────────────────────────────────┐
                 │  HashiCorp Vault 1.15.2             │
                 │  (Docker container)                 │
                 │  storage: file (persistent volume)  │
                 │  KV v2 @ kv/onecm/gpg-passphrase/*  │
                 │  AppRole auth @ auth/approle        │
                 └────────────┬────────────────────────┘
                              │ REST API (vault CLI)
                              ▼
        ┌─────────────────────────────────────────────┐
        │  MFTE cluster nodes (/mnt/mfte/ops shared)  │
        │  werkstatt.gpg.vault.*.sh scripts           │
        │  mfte.gpg.vault.sh (shared library)         │
        │  Auth: VAULT_ROLE_ID / VAULT_SECRET_ID      │
        │        from the shared .env                 │
        └──────────────────────────────────────────── ┘
```

Vault runs as a Docker container (Portainer-managed), fronted in this lab by Traefik
for TLS termination. Every MFTE cluster node reaches it over the network as
`VAULT_ADDR`, the same way any REST client would — there's no local Vault
process on the MFTE hosts themselves.

**Out of scope, deliberately:** setting up and configuring Traefik (or any other TLS-terminating reverse proxy) is not documented here. Any SSL/TLS-capable reverse proxy can be substituted, or Vault can be reached directly without one — this project only requires that `VAULT_ADDR` resolves to a reachable Vault API, however that's fronted. The same applies to the `logging:`/GELF block seen in §3.2's compose file — that's this lab's own log-shipping choice, not part of the Vault integration, and isn't documented or required here either.

---

## 3. Installation

### 3.1 Prerequisites

Docker Engine with the Compose v2 plugin (`docker compose ...`), or a standalone `docker-compose` v1.27+ — anything that understands Compose file format `3.9`. Not pinned to an exact tested version in this lab; if `docker compose up`/Portainer rejects the file outright, a too-old Compose implementation is the first thing to check.

The compose file below references two volumes and one network as `external: true` — Docker does **not** create an external volume/network for you; a missing one is a hard failure at deploy time (`external volume "hashicorp_data" not found`), not a warning. Create them first if they don't already exist:

```bash
docker volume create hashicorp_data
docker volume create hashicorp_config
docker network ls | grep prod   # confirm it already exists in this environment
docker network create prod      # only if this network doesn't exist yet
```

`prod` here is just the Docker network this compose file expects to attach to — whatever reverse proxy (if any) fronts Vault needs to be reachable on it. Setting up that proxy itself is out of scope; see the note in §2.

Before first start, seed `vault.hcl` (§3.2 below) into the empty `hashicorp_config` volume — e.g.:

```bash
docker run --rm -v hashicorp_config:/vault/config -v "$(pwd)/vault":/seed \
  alpine cp /seed/vault.hcl /vault/config/vault.hcl
```

or copy it in via Portainer's own volume browser if deploying through the Portainer UI instead of the CLI.

The hostname and Traefik router rule/entrypoint are hardcoded directly into `vault/docker-compose.yml` (`hashicorp.werkstatt.local`, `https-external`) rather than templated via a `.env` file — this is a demo instance, so there's no second environment to parameterize for. Edit those values directly in the compose file for a different host/domain/entrypoint. These labels only matter at all if fronting Vault with Traefik specifically, as this lab does; swap or drop the `traefik.*` labels entirely for a different reverse proxy, or no proxy at all.

### 3.2 Docker Compose (via Portainer)

The compose file and Vault config below also live as real files alongside this doc, ready to use as-is: [`vault/docker-compose.yml`](../vault/docker-compose.yml) and [`vault/vault.hcl`](../vault/vault.hcl). The deployed version additionally carries a `logging:` block (`gelf` driver) and `traefik.*` labels reflecting this lab's own log-shipping and reverse-proxy choices — neither is configured or required by this doc (see §2's scope note); substitute, drop, or replace with whatever this environment actually uses.

```yaml
version: "3.9"

volumes:
  hashicorp_data:
    external: true
  hashicorp_config:
    external: true

networks:
  prod:
    external: true

services:
  vault:
    image: hashicorp/vault:1.15.2
    container_name: hashicorp-vault
    hostname: hashicorp.werkstatt.local
    restart: unless-stopped
    cap_add:
      - IPC_LOCK
    command: ["vault", "server", "-config=/vault/config/vault.hcl"]
    environment:
      VAULT_ADDR: "http://0.0.0.0:8200"
    volumes:
      - hashicorp_data:/vault/data
      - hashicorp_config:/vault/config
    networks:
      - prod
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.vault.rule=Host(`hashicorp.werkstatt.local`)"
      - "traefik.http.routers.vault.entrypoints=https-external"
      - "traefik.http.routers.vault.tls=true"
      - "traefik.http.services.vault.loadbalancer.server.port=8200"
      - "traefik.docker.network=prod"
```

`cap_add: IPC_LOCK` lets Vault lock secret-bearing memory pages (`mlock`)
without disabling that protection — the alternative, `disable_mlock =
true` in the config, is what you'd use only if the container runtime
can't grant that capability at all.

Vault config (`vault.hcl`, seeded into the `hashicorp_config` volume
before first start):

```hcl
storage "file" {
  path = "/vault/data"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"   # Traefik terminates TLS at the edge
}
ui = true
```

**Not dev mode.** `vault server -dev` was deliberately avoided — it
auto-unseals, uses in-memory storage, and skips every operational step
(init, unseal, persistent storage) that a real deployment requires.
Everything below (init, unseal, seal status surviving a restart) only
applies because this is a real server-mode deployment.

### 3.3 Deploy and verify

Either via the CLI:

```bash
docker compose -f vault/docker-compose.yml up -d
```

or via Portainer: **Stacks → Add stack**, paste `vault/docker-compose.yml`'s contents, set the environment variables from §3.1, then **Deploy**.

Confirm the container actually started and is healthy before moving on to initialization:

```bash
docker ps --filter name=hashicorp-vault
docker logs hashicorp-vault
```

A container that exits immediately, or logs a storage/config error, means something in §3.1 wasn't satisfied (a volume/network missing, or `vault.hcl` not actually seeded into `hashicorp_config` yet) — resolve that before running `vault operator init` in §4.

### 3.4 Why Docker, not a dedicated host

Vault is a single static binary with no heavy runtime dependencies — it
runs fine as a container. No dedicated server is required for a lab
deployment; the only trade-off is that if Vault and its clients are
colocated, you don't naturally exercise the network/TLS/proxy path a
genuinely remote Vault would require. Running it through Traefik on the
existing Docker host, reachable the same way other services are, gets
the realistic network path without needing separate hardware.

### 3.5 Installing the `vault` CLI on RHEL nodes

Everything above (§3.1–3.4) installs the Vault **server** — one Docker container, on the Docker/Portainer host. Separately, any RHEL host that talks to it as a client needs the `vault` **CLI binary** on `PATH` — these nodes are pure API clients against the remote server over `VAULT_ADDR`, never a server themselves. That's two distinct groups in this lab:

- **Every MFTE hub cluster node running any `werkstatt.gpg.vault.*.sh` script** — `mfte.gpg.vault.sh` (`require_command vault`) shells out to it directly for every operation (`vault status`, `vault kv get/put`, `vault write auth/approle/login`, etc.).
- **The MFTE Hub database VM**, for the Vault unseal automation in [`vault/UNSEAL.md`](../vault/UNSEAL.md) — `unseal.sh` calls `vault status`/`vault operator unseal` directly. That VM isn't part of the processing cluster and doesn't have the rest of this framework (`MFTE_OPS_HOME`, etc.) deployed on it, so neither `vault` nor `jq` can be assumed already present there the way they can on an actual hub node — install both explicitly.

`jq` is also required on any of these hosts (`mfte.gpg.vault.sh`'s `mfte_gpg_vault_preflight` parses `vault status -format=json` with it; `unseal.sh` does the same) — install alongside `vault` if it isn't already present:

```bash
sudo yum install -y jq
```

Two ways to get the `vault` binary onto a RHEL node:

**Option 1 — direct release download:**

```bash
curl -o vault.zip https://releases.hashicorp.com/vault/1.15.2/vault_1.15.2_linux_amd64.zip
unzip vault.zip
sudo mv vault /usr/local/bin/
vault version
```

Simplest for a single node or an air-gapped environment with no repo access, but every upgrade is a fully manual re-download-and-replace, and there's no package-manager record of what's installed.

**Option 2 — HashiCorp's yum repo (chosen for this cluster):**

```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install vault
```

Chosen over the direct download for every MFTE hub node in this cluster, and for the MFTE Hub database VM — repo metadata is GPG-signed (verified automatically by yum, unlike a bare `curl`+`unzip`), and future updates are a normal `yum update vault` rather than repeating the manual download on every node.

**Version alignment:** confirm the installed CLI version matches (or is at least protocol-compatible with) the server's — `vault version` on the node should report `1.15.2` to match §3.2's `hashicorp/vault:1.15.2` image. A newer CLI talking to an older server (or vice versa) can behave inconsistently around newer API fields.

**Do not enable the RPM's `vault.service`.** The yum package ships a systemd unit for running a *local* Vault server (expecting its own config at `/etc/vault.d/vault.hcl`), which is not what these nodes are for — they only ever use the `vault` binary as a CLI client against the remote server from §3.2. Leave `vault.service` uninstalled/disabled; installing the package does not start or enable it by itself, but don't `systemctl enable --now vault` on these hosts.

#### Alternative not taken: talking to Vault over its REST API directly

`mfte.gpg.vault.sh` could instead call Vault's HTTP API with `curl` and skip installing the `vault` binary on cluster nodes entirely — every operation it uses today has a direct REST equivalent (`vault status` → `GET $VAULT_ADDR/v1/sys/health`, `vault write auth/approle/login` → `POST .../v1/auth/approle/login`, `vault kv get/put` → `GET`/`POST` against `.../v1/kv/data/...`). The library already requires `jq` (to parse `vault status -format=json`'s seal state), so the only genuinely new dependency would be `curl` — already present on essentially any RHEL node — meaning this path could actually *drop* a package (`vault`) rather than add one.

**Not pursued here, deliberately.** The `vault` binary keeps the integration simple to reason about and, importantly, lets anyone troubleshoot it interactively from any hub cluster node's own shell — `vault status`, `vault kv get ...`, `vault login` — without hand-rolling and maintaining raw HTTP request/response/error-handling code in `mfte.gpg.vault.sh` first. Since this whole Vault integration is for demo and educational purposes only (see §1), that hands-on testability was weighed as more valuable than trimming one package dependency. Revisit this if the integration ever needs to run somewhere the `vault` binary genuinely can't be installed.

---

## 4. Initialize & Unseal

First start only:

```bash
export VAULT_ADDR='https://<vault-host>'
vault operator init
```

This prints **5 unseal keys and 1 root token, exactly once.** There is no
"view again." Save all 6 values immediately in a password manager —
**not** a plaintext file, and not the browser's "Download keys" button
(writes a plaintext file straight to the Downloads folder).

5 shares / 3 threshold (Vault's default) was kept even for a
single-operator lab — not because the trust-splitting property matters
solo, but because "collect 3 of 5 keys to unseal after every restart" is
the actual operational muscle memory worth building before doing it under
real pressure later.

Unseal (required after **every** restart — this Vault has no
auto-unseal configured):

```bash
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>
vault login <root-token>
```

`vault status` confirms seal state without needing a token at all (hits
`sys/health`, unauthenticated) — useful as a clean reachability/seal check
independent of anything else:

```bash
vault status
```

---

## 5. Secrets Engine (KV v2)

```bash
vault secrets enable -path=kv kv-v2
```

Path convention used throughout the script family:

```
kv/onecm/gpg-passphrase/<fingerprint>      key: passphrase
```

(`kv` = mount name, `onecm/gpg-passphrase` = prefix — both overridable via
`MFTE_VAULT_MOUNT` / `MFTE_VAULT_GPG_PREFIX`, see §7.)

---

## 6. Authentication (AppRole)

```bash
vault auth enable approle
```

Policy — read access scoped to the GPG-passphrase subpath, plus a
narrower write exception so the export scripts can push new/updated
passphrases without granting broad write over the rest of `onecm/*`:

```bash
vault policy write mft-policy - <<'EOF'
path "kv/data/onecm/*" {
  capabilities = ["read"]
}
path "kv/data/onecm/gpg-passphrase/*" {
  capabilities = ["create", "update", "read"]
}
EOF
```

Role:

```bash
vault write auth/approle/role/mft-role \
  token_policies="mft-policy" \
  token_ttl=1h \
  token_max_ttl=4h
```

`role_id` is static, retrievable any time:

```bash
vault read auth/approle/role/mft-role/role-id
```

`secret_id` is shown **once** at generation, same rule as the unseal
keys — there is no "look it up later":

```bash
vault write -f auth/approle/role/mft-role/secret-id
```

### 6.1 secret_id TTL — a real gotcha

`secret_id_ttl`/`token_ttl`/`token_max_ttl` are read from the role's
config **at the moment a `secret_id` is generated** — changing the role
afterward does **not** retroactively apply to an already-issued
`secret_id`. Set the desired TTLs on the role *first*, then generate.

Also: `secret_id_ttl` can never exceed the `approle` auth mount's own
`max_lease_ttl` — Vault silently **clamps** it with no error if you ask
for more than the mount allows. Check/raise the ceiling first if you want
a specific value to actually take effect:

```bash
vault read sys/auth/approle/tune          # check current max_lease_ttl
vault auth tune -max-lease-ttl=2160h approle   # raise it (e.g. to 90 days)
```

Then generate the `secret_id` and confirm the `secret_id_ttl` in the
output actually matches what you asked for before trusting it.

Rotating a `secret_id` (old one no longer used, e.g. after any exposure —
including having been pasted into a chat/ticket):

```bash
vault list auth/approle/role/mft-role/secret-id   # lists accessors, not values
vault write auth/approle/role/mft-role/secret-id-accessor/destroy \
  secret_id_accessor=<accessor-to-revoke>
```

---

## 7. MFTE Integration (`.env`)

Added to the existing shared `.env`
(`${MFTE_OPS_HOME}/config/.env`, read by every script via
`mfte.sh`'s `set -a; source; set +a`):

```bash
###############################################################################
# Privacy Guard - Vault
###############################################################################
VAULT_ADDR=https://<vault-host>
VAULT_ROLE_ID=<role_id>
VAULT_SECRET_ID=<secret_id>
MFTE_VAULT_MOUNT=kv
MFTE_VAULT_GPG_PREFIX=onecm/gpg-passphrase
```

### 7.1 Why `.env`, not a Control-M Rule variable

MFTE Rules currently logs every Rule-variable substitution in cleartext
(`mfte_dump_argv` / `log_system`, in `mfte.sh`) — there is no
secure/masked-variable mechanism in MFTE yet. That means
`VAULT_SECRET_ID` can **never** be delivered as a Rule variable without
it leaking into a system log the moment Control-M substitutes it — no
amount of care in the script itself fixes this, because the exposure
happens one layer up, before the script even runs.

Putting these values in the shared `.env` instead sidesteps that leak
vector entirely: they're read via a plain `source`, never through
Control-M's Rule-variable substitution/logging path. This was accepted
as the pragmatic interim approach given this host's `.env` is only
reachable by cluster nodes and the local root user — revisit if that
access boundary ever changes, or once MFTE Rules gains an actual
secure-variable mechanism (at which point the long-term intent is R&D
exporting these as real shell environment variables set *outside* the
Rule's own command substitution — nothing in `mfte.gpg.vault.sh` would
need to change for that; it already only ever checks whether these are
already set in the environment).

### 7.2 `VAULT_TOKEN` vs `VAULT_ROLE_ID`/`VAULT_SECRET_ID`

`mfte_gpg_vault_login_if_needed()` (in `mfte.gpg.vault.sh`) uses
`VAULT_TOKEN` if already set; otherwise it logs in via AppRole using
`VAULT_ROLE_ID`/`VAULT_SECRET_ID` and mints a fresh token for that run.
Don't store a long-lived `VAULT_TOKEN` anywhere — it's meant to be
short-lived and re-minted every run, which is exactly why the `.env`
carries the AppRole credential pair, not a static token.

---

## 8. Script family reference

All scripts live in `bin/`, all share the same version/flag conventions
(`SCRIPT_VERSION`, `-V`, `-q`, `-h`) as the rest of the framework.

| Script | Purpose |
|---|---|
| `mfte.gpg.vault.sh` *(lib)* | Shared Vault helpers: reachability/seal check, AppRole login, path convention, get/put/delete against Vault. No `gpg` calls at all — pure Vault transport. |
| `werkstatt.gpg.vault.status.sh` | Diagnostic: reachability, seal status, auth, and whether a passphrase is present for a given key — never prints the value itself. |
| `werkstatt.gpg.vault.export.passphrase.sh` | Push one key's already-filed **local** passphrase file into Vault. |
| `werkstatt.gpg.vault.export.all.passphrases.sh` | Same, in bulk, for every secret key in the keyring in one pass. Continue-on-error with a per-key report (EXPORTED / SKIPPED / FAILED). |
| `werkstatt.gpg.vault.import.passphrase.sh` | Pull a passphrase **from** Vault, validate it actually unlocks the key (encrypt/decrypt round trip against a throwaway string), then file it locally. |
| `werkstatt.gpg.vault.decrypt.file.sh` | Decrypt a file with the passphrase fetched from Vault fresh every run, via `--passphrase-fd` — nothing filed locally, ever. Vault-aware sibling of `werkstatt.gpg.decrypt.file.sh`. |
| `werkstatt.gpg.vault.receive.file.sh` | Same Vault-fetch mechanism, but for the multi-tenant "figure out which of N keys this inbound file was encrypted to" flow, plus the full JSONL audit record. Vault-aware sibling of `werkstatt.gpg.receive.file.sh`. |

None of the plain (non-Vault) scripts were modified to support any of
this — every Vault capability is additive, in its own file.

---

## 9. Operational notes

### 9.1 The `--passphrase-fd` / `runuser` dependency

`werkstatt.gpg.vault.decrypt.file.sh` and
`werkstatt.gpg.vault.receive.file.sh` both depend on a file descriptor
(opened via process substitution) surviving `mfte_gpg_run`'s internal
`runuser -u ${MFTE_GPG_USER}` identity switch. This was verified
empirically (2026-07-27, `ctm-mfte-hub-03`, `mftgpg` = no-shell service
account, direct `runuser` exec with no `-l`/login flag):

```bash
# WRONG test -- this re-opens the fd by path, hits a real permission
# check against the pipe's ownership, and fails regardless of whether
# gpg's --passphrase-fd (which reads the inherited fd directly, no
# re-open) would actually work:
runuser -u mftgpg -- cat -- /dev/fd/3 3< <(printf 'canary')
# -> cat: /dev/fd/3: Permission denied

# CORRECT test -- reads the already-inherited descriptor directly, same
# mechanism gpg's --passphrase-fd actually uses:
runuser -u mftgpg -- /bin/bash -c 'read -u 3 value; printf "%s\n" "$value"' 3< <(printf 'canary')
# -> canary   (confirms the fd survives the identity switch)
```

Re-run this canary test on any host where `MFTE_GPG_USER`'s account type
or the `runuser`/PAM build might differ before trusting the Vault-fetch
scripts there.

### 9.2 KV v2 path gotcha

BMC's own Control-M Vault documentation and the raw HTTP API both use
`kv/data/<path>` (the `data/` segment is KV v2's own convention). The
`vault` CLI's `kv` subcommands (`vault kv get kv/<path>`, `vault kv put
kv/<path>`) add that `data/` segment for you automatically — don't
double it up if you're ever comparing a CLI command against a raw
`curl`/API call to the same path.

### 9.3 This Vault has no expiry notifications

Nothing currently warns before a `secret_id` expires — if `secret_id_ttl`
is set to anything other than unlimited (`0`), track that expiry date
somewhere outside Vault itself (calendar reminder, or extend
`werkstatt.gpg.vault.status.sh` to report remaining TTL via `vault write
auth/approle/role/mft-role/secret-id-accessor/lookup`).

---

## 10. Troubleshooting

**`ERROR: <path> not found or not readable` from `mfte.sh` at startup**
— `mfte.sh`'s `CONFIG_FILE` resolves via `MFTE_CONFIG_FILE` override →
`MFTE_OPS_HOME` (already resolved relative to whichever script invoked
it, via that script's own `SCRIPT_DIR/..`) → `/mnt/mfte/ops` as a
last-resort fallback. If this fires, either `MFTE_OPS_HOME` didn't
resolve the way you expected (check the calling script actually sits
under a `bin/` sibling of `config/`), or the `.env` genuinely isn't at
the expected location on this node.

**`403 permission denied` on `werkstatt.gpg.vault.export.passphrase.sh`**
— the AppRole policy only grants `read` by default; export needs
`create`/`update` on the `gpg-passphrase` subpath specifically (see §6's
policy block). A 403 on *read* (e.g. from `werkstatt.gpg.vault.status.sh`
or the decrypt scripts) instead points at a different problem — the
token/policy not covering `kv/data/onecm/gpg-passphrase/*` for reads at
all, or an expired/wrong `secret_id`.

**`secret_id_ttl` in the output doesn't match what you set on the role**
— see §6.1; the auth mount's `max_lease_ttl` silently caps it.

**Decrypt fails with a generic gpg error rather than a clear "no
passphrase" message** — confirmed present as a real gap in the plain
`werkstatt.gpg.vault.decrypt.file.sh` (it does not pre-check Vault
passphrase presence before attempting decrypt, unlike
`werkstatt.gpg.vault.receive.file.sh`, which does). Run
`werkstatt.gpg.vault.status.sh -k <fingerprint>` first to rule this out
before assuming something else is wrong.

---

## 11. Test commands

Every command below was actually run and confirmed working against this
deployment (not theoretical) — kept here as a repeatable verification
sequence for a fresh install, a suspected regression, or a new node.

### 11.1 Vault core: reachability, seal, KV v2 round trip

```bash
# Reachability + seal status -- no token required (hits sys/health)
vault status

# KV v2 write/read round trip
vault kv put kv/onecm/mft-test passphrase="TestPassphrase123!"
vault kv get kv/onecm/mft-test
```

### 11.2 AppRole: login, and both permission directions

```bash
# role_id is static -- retrievable any time
vault read auth/approle/role/mft-role/role-id

# AppRole login -- exchanges role_id + secret_id for a scoped token
vault write auth/approle/login \
  role_id="<role_id>" \
  secret_id="<secret_id>"
```

**Positive test** — the scoped token can read what the policy allows:

```bash
VAULT_TOKEN=<scoped-token> vault kv get kv/onecm/mft-test
```

**Negative test** — and, just as important, confirm it's *refused*
outside that scope. A read against a non-existent path under the same
prefix returns "no value found," which is a successful-but-empty read,
**not** a permission failure — it doesn't prove policy scoping by itself:

```bash
# NOT a real negative test -- still matches the kv/data/onecm/* wildcard:
VAULT_TOKEN=<scoped-token> vault kv get kv/onecm/other-secret
# -> "No value found at kv/data/onecm/other-secret" (path allowed, just empty)
```

The decisive negative test is attempting an operation the policy actually
denies — e.g. a **write**, when the policy only grants `read`:

```bash
VAULT_TOKEN=<scoped-token> vault kv put kv/onecm/mft-test passphrase=hacked
# -> Code: 403. Errors: * 1 error occurred: * permission denied
```

A `403 permission denied` here is success — it confirms the policy is
enforcing the boundary, not just that the mechanism runs end to end.

### 11.3 `--passphrase-fd` / `runuser` fd-survival canary

Confirms a file descriptor opened via process substitution actually
survives `mfte_gpg_run`'s internal `runuser -u ${MFTE_GPG_USER}` identity
switch, before trusting any Vault-fetch script that depends on it
(`werkstatt.gpg.vault.decrypt.file.sh`,
`werkstatt.gpg.vault.receive.file.sh`).

```bash
# WRONG test -- re-opens the fd BY PATH, which triggers a real permission
# check against the pipe's ownership and fails regardless of whether
# --passphrase-fd (which reads the inherited fd directly, no re-open)
# would actually work:
runuser -u mftgpg -- cat -- /dev/fd/3 3< <(printf 'canary-value-12345')
# -> cat: /dev/fd/3: Permission denied   (expected -- not the real test)

# CORRECT test -- reads the already-inherited descriptor directly, same
# mechanism gpg's --passphrase-fd actually uses:
runuser -u mftgpg -- /bin/bash -c 'read -u 3 value; printf "%s\n" "$value"' 3< <(printf 'canary-value-12345')
# -> canary-value-12345   (confirms the fd survives the identity switch)
```

### 11.4 Script-level status check

Reachability + auth + passphrase-presence, without touching gpg at all:

```bash
./werkstatt.gpg.vault.status.sh -k <fingerprint>
```

Expected clean output:

```
=== Vault reachability / seal status ===
  OK -- reachable at https://<vault-host>, unsealed
=== Vault auth ===
  OK -- authenticated (token policies not shown here; use 'vault token lookup' if needed)
=== Passphrase presence ===
  OK -- a passphrase is present at kv/onecm/gpg-passphrase/<fingerprint> for fingerprint <fingerprint> (value not shown)
```

### 11.5 Full end-to-end round trip (encrypt → Vault-sourced decrypt → verify)

The test that actually proves the whole chain, not just each piece in
isolation — encrypt needs no Vault at all (public key only); decrypt is
where Vault comes in:

```bash
# 1. Push this key's local passphrase into Vault first, if not done already
./werkstatt.gpg.vault.export.passphrase.sh -k <fingerprint>

# 2. Throwaway test file
echo "vault decrypt test payload $(date -u)" > /tmp/vault-test.txt

# 3. Encrypt -- no Vault, no passphrase, just the public key
./werkstatt.gpg.encrypt.file.sh -f /tmp/vault-test.txt -r <fingerprint> -o /tmp/vault-test.txt.asc

# 4. Decrypt -- THIS is the step that pulls the passphrase from Vault
./werkstatt.gpg.vault.decrypt.file.sh -f /tmp/vault-test.txt.asc -k <fingerprint>
# -> reports the actual output path, e.g. .../mfte-gpg-out/vault-test.txt.1

# 5. Byte-for-byte integrity check against the ORIGINAL plaintext
#    (not against the .asc file -- that's ciphertext, comparing its hash
#    to the decrypted output's hash is comparing two different things)
diff /tmp/vault-test.txt <output path from step 4>
# no output = clean match
```

---

## 12. Known limitations / future work

- **Control-M's native Vault integration is untested against this
  design** — this environment doesn't have access to that product
  feature yet. Everything here is a standalone bridge, built to be
  replaced or supplemented once that access exists.
- **No secure-variable delivery from MFTE Rules yet** — see §7.1. The
  `.env`-based credential delivery is the interim state, not the intended
  end state.
- **No automated `secret_id` rotation** — currently a manual
  generate/update-`.env`/destroy-old-accessor sequence (§6.1).
- **No bulk delete/rotate script** — `mfte_gpg_vault_delete_passphrase()`
  exists in `mfte.gpg.vault.sh`, but no `werkstatt.gpg.vault.delete.
  passphrase.sh` calls it yet; deletion is currently a manual `vault kv
  delete`/`vault kv metadata delete` operation.