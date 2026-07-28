# Vault unseal automation (lab only)

This lab Vault has no KMS/HSM/Transit auto-unseal configured (see [`docs/hashicorp.vault.md`](../docs/hashicorp.vault.md) §4 and its production auto-unseal discussion) — every restart requires 3 of 5 Shamir key shares fed to `vault operator unseal` by hand. `systemd/vault-unseal.service` + `systemd/vault-unseal.timer` automate that for this lab, at a cost that's worth stating plainly: the key shares have to live in a machine-readable file somewhere, which is exactly what Shamir splitting is meant to avoid. This is a deliberate lab/demo convenience, not a production pattern — see the "production" section below before considering this anywhere else.

## Prerequisites

`unseal.sh` calls `vault status`/`vault operator unseal` directly, and parses the former's JSON output with `jq` — neither is a safe assumption on the MFTE Hub database VM. Unlike an actual MFTE hub cluster node, this VM doesn't have the rest of the framework (`MFTE_OPS_HOME`, `mfte.gpg.vault.sh`, etc.) deployed on it, so nothing else on it already pulled these in as dependencies. Install both explicitly — see [`docs/hashicorp.vault.md` §3.5](../docs/hashicorp.vault.md#35-installing-the-vault-cli-on-rhel-nodes) for the full reasoning (yum repo vs. direct download, version alignment, why not to enable the RPM's `vault.service`); the short version:

```bash
sudo yum install -y yum-utils jq
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install vault
vault version   # confirm it reports 1.15.2, matching the server image in vault/docker-compose.yml
```

Also confirm this VM can actually reach Vault over the network before wiring up the systemd units (substitute this environment's actual `VAULT_ADDR` — `hashicorp.werkstatt.local` below is this repo's placeholder, not a real host):

```bash
curl -sk https://hashicorp.werkstatt.local/v1/sys/health
```

## Why the MFTE Hub database VM

The unseal automation runs on the MFTE Hub **database** VM, not the Docker/Portainer host that actually runs the `hashicorp-vault` container. That VM is not part of the MFTE processing cluster itself (it doesn't run `werkstatt.gpg.vault.*.sh` against live inbound files), but it's already part of this lab's broader GPG story and already has an `mftgpg` account provisioned on it. Running the unseal automation there instead of on the Vault host itself keeps a deliberate separation: compromising the Vault container/host doesn't also hand over the keys that unseal it, since they live on a different machine entirely. `unseal.sh` only ever talks to `VAULT_ADDR` over the network — it doesn't touch Docker, so there's no requirement that it run anywhere near the container.

## Why the `mftgpg` account

Reused rather than provisioning a new dedicated account, because it's already exactly what a secret-custodian account should look like on this VM: no password, no SSH keypair, no sudo, shell `/sbin/nologin` (see [`setup.mftgpg.sh`](../src/bin/setup.mftgpg.sh) / [`data.mftgpg.json`](../src/config/data.mftgpg.json)). `systemd`'s own `User=`/`Group=` directives run the service as `mftgpg` directly — no login shell is needed for that, same reason `runuser -u mftgpg` already works throughout this whole project despite the account being non-interactive.

**Worth being honest about the trade-off:** elsewhere in this project, `mftgpg` is deliberately single-purpose — GPG operations only, nothing else (see the README's "Why a dedicated service account" section). Giving it custody of Vault's own unseal keys blurs that boundary: this account now holds both "what can unseal Vault" and, on any host actually running the GPG scripts, "what Vault reveals once unsealed." On *this* VM specifically that's an acceptable lab simplification, since it isn't part of the live processing cluster and isn't handling real customer decrypt operations. It stops being acceptable the moment this account (or this VM) takes on real GPG-processing duties — at that point, use a separate custodian account instead, precisely to keep those two blast radii apart.

## Layout

Vault master-key material is kept in its own directory under `mftgpg`'s home, **separate from** the three GPG-specific ones (`.gnupg`, `mfte-gpg-meta`, `mfte-gpg-passphrases`) — Vault's unseal keys and GPG passphrases are different secret types and shouldn't be commingled under one name, even though the same account custodies both here:

```
/home/mftgpg/mfte-vault-unseal/   (700, mftgpg:controlm)
└── keys                          (600, mftgpg:controlm -- one Shamir share per line)
```

This directory is **not** managed by `setup.mftgpg.sh` (deliberately out of scope for that script — it provisions the GPG-specific paths only). Create it manually, once:

```bash
sudo mkdir -p /home/mftgpg/mfte-vault-unseal
sudo chown mftgpg:controlm /home/mftgpg/mfte-vault-unseal
sudo chmod 700 /home/mftgpg/mfte-vault-unseal

# one Shamir key share per line -- any 3 of the 5 from `vault operator init`
runuser -u mftgpg -- tee /home/mftgpg/mfte-vault-unseal/keys > /dev/null <<'EOF'
<key-1>
<key-2>
<key-3>
EOF
sudo chmod 600 /home/mftgpg/mfte-vault-unseal/keys
```

**Unseal key shares only — never the root token.** `vault operator unseal` doesn't accept or need it (unsealing isn't an authenticated operation, which is exactly why it works while Vault is still sealed); `unseal.sh` would just fail to use it if it were present. The root token is also far more sensitive than any single share — one share alone is useless to an attacker by design, while the root token is immediate, full, authenticated access to everything in Vault. Keep it out of this file entirely; per §4 of `docs/hashicorp.vault.md` it belongs in a password manager, not any file on disk.

## Deploying the automation

```bash
sudo mkdir -p /opt/werkstatt/vault-unseal
sudo cp scripts/unseal.sh /opt/werkstatt/vault-unseal/unseal.sh
sudo chmod +x /opt/werkstatt/vault-unseal/unseal.sh

sudo cp systemd/vault-unseal.service systemd/vault-unseal.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now vault-unseal.service   # runs once at boot
sudo systemctl enable --now vault-unseal.timer     # re-checks every 5 minutes thereafter
```

Verify:

```bash
systemctl list-timers vault-unseal.timer
journalctl -u vault-unseal.service -n 20
```

## Logging

Neither unit sets `StandardOutput=`/`StandardError=`, so systemd's default applies: both streams go to the journal, tagged under the unit's own name. `unseal.sh` never redirects its own `echo` output anywhere else, so every run's messages — `Already unsealed.`, `Unseal successful.`, and any `ERROR: ...` line — land there automatically, whether triggered by the boot-time service or a timer tick.

```bash
journalctl -u vault-unseal.service            # every run's output, oldest first
journalctl -u vault-unseal.service -f         # follow live
journalctl -u vault-unseal.service -n 20      # last 20 lines
journalctl -u vault-unseal.timer              # the timer's own activation/scheduling events, separate from the service's output
```

This only applies when systemd itself invokes `unseal.sh` (via the service or the timer). Running the script by hand from a shell just prints to that terminal — nothing in the script writes to the journal on its own.

`unseal.sh` is idempotent — it checks Vault's seal status first and exits immediately if already unsealed, so both the boot-time run and every 5-minute timer tick are safe to fire repeatedly; most runs just log "Already unsealed."

## What production does instead

None of the above — a production deployment shouldn't have a human-readable unseal-key file anywhere. See `docs/hashicorp.vault.md`'s production auto-unseal discussion: KMS-backed auto-unseal (AWS/Azure/GCP KMS), Vault's own Transit auto-unseal (a second, small Vault instance hosting just the `transit` engine), or an HSM-backed seal (Vault Enterprise). Any of those remove the need for this file, this account, and this systemd unit entirely.
