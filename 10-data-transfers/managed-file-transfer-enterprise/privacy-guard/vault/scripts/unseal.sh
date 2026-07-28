#!/usr/bin/env bash
# unseal.sh -- feeds locally-stored Shamir key shares to a remote lab Vault
# instance's `vault operator unseal` after a restart. Runs as the mftgpg
# service account on the MFTE Hub database VM, not on the Vault/Docker host
# itself. LAB/DEMO USE ONLY -- see ../UNSEAL.md for why this VM/account and
# why this approach at all.

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-https://hashicorp.werkstatt.local}"
KEY_FILE="${1:-/home/mftgpg/mfte-vault-unseal/keys}"

export VAULT_ADDR

if [[ ! -f "$KEY_FILE" ]]; then
  echo "ERROR: unseal key file not found: $KEY_FILE" >&2
  exit 1
fi

perms="$(stat -c %a "$KEY_FILE" 2>/dev/null || stat -f %Lp "$KEY_FILE")"
if [[ "$perms" != "600" ]]; then
  echo "ERROR: $KEY_FILE must be mode 600 (found $perms)." >&2
  exit 1
fi

# Vault runs on a different host (the Docker/Portainer host) with its own
# independent restart timing -- retry instead of assuming it's already
# reachable the moment this runs.
sealed=""
for _ in $(seq 1 30); do
  sealed="$(vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || true)"
  [[ -n "$sealed" ]] && break
  sleep 2
done
if [[ -z "$sealed" ]]; then
  echo "ERROR: Vault at $VAULT_ADDR unreachable after 60s." >&2
  exit 1
fi

if [[ "$sealed" == "false" ]]; then
  echo "Already unsealed."
  exit 0
fi

while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  vault operator unseal "$key" >/dev/null
done < "$KEY_FILE"

if [[ "$(vault status -format=json 2>/dev/null | jq -r '.sealed')" == "false" ]]; then
  echo "Unseal successful."
else
  echo "ERROR: still sealed after feeding all keys in $KEY_FILE." >&2
  exit 1
fi
