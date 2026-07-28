#!/bin/bash

# file name: mfte.gpg.vault.sh
# purpose : Shared HashiCorp Vault helpers for the werkstatt.gpg.vault.*.sh
#           script family -- auth (token or AppRole), the mount/path
#           convention used for GPG passphrases, and get/put against Vault.
#           Source mfte.sh, then mfte.gpg.sh, then this file -- this
#           library calls mfte_gpg_* functions (mfte_gpg_passphrase_file,
#           mfte_gpg_copy_passphrase_as_user, mfte_gpg_write_passphrase_file,
#           mfte_gpg_run) and assumes they're already defined.
#
# scope   : Deliberately its OWN library file, not folded into mfte.gpg.sh.
#           Vault is optional -- most werkstatt.gpg.*.sh scripts have
#           nothing to do with it and shouldn't be forced to satisfy a
#           `vault` binary dependency check they don't need, same reasoning
#           mfte.gpg.sh's own header gives for being separate from mfte.sh.
#
# secrecy : Every function here follows the same rule as mfte_gpg_write_
#           passphrase_file: a passphrase value is only ever handed off as
#           a bash function argument (invisible in `ps`, not written to any
#           log line) or read/written by the `vault` CLI directly via
#           `key=@file` / `-field=`. It is never interpolated into a
#           command string, never printed, never passed to an external
#           command as a literal CLI argument.
#
# auth    : Either VAULT_TOKEN is already set (any valid token), or
#           VAULT_ROLE_ID + VAULT_SECRET_ID are set and this library logs
#           in via AppRole itself. Never accept a token or secret_id as a
#           script FLAG in any caller -- env vars only, same reasoning as
#           passphrases never being a CLI flag value.
#
# fd note : werkstatt.gpg.vault.decrypt.file.sh relies on a file descriptor
#           opened by process substitution surviving mfte_gpg_run's
#           internal `runuser -u ${MFTE_GPG_USER}` identity switch. Verified
#           empirically on ctm-mfte-hub-03 (2026-07-27): a no-shell service
#           account with a direct runuser exec (no -l/login) preserves an
#           inherited fd; only a path-based re-open (e.g. `cat /dev/fd/N`)
#           hits a permission wall, not the fd read gpg's --passphrase-fd
#           actually performs. Re-verify if MFTE_GPG_USER's account type or
#           the runuser/PAM build changes on a given host.

MFTE_GPG_VAULT_LIB_VERSION="1.0.0"

require_command vault

: "${MFTE_GPG_USER:?MFTE_GPG_USER is not set — check that mfte.sh sourced the .env}"

# Path convention (overridable via .env, same as any other MFTE_* setting):
#   <MFTE_VAULT_MOUNT>/<MFTE_VAULT_GPG_PREFIX>/<fingerprint>   key: passphrase
MFTE_VAULT_MOUNT="${MFTE_VAULT_MOUNT:-kv}"
MFTE_VAULT_GPG_PREFIX="${MFTE_VAULT_GPG_PREFIX:-onecm/gpg-passphrase}"

###############################################################################
# mfte_gpg_vault_preflight
###############################################################################
# Confirms VAULT_ADDR is set and the target Vault is reachable and unsealed.
# Does NOT require a token -- sys/health-backed `vault status` works
# unauthenticated, so this is a clean network/TLS/seal check independent of
# whatever auth method a caller will use next.
mfte_gpg_vault_preflight() {
    : "${VAULT_ADDR:?VAULT_ADDR must be set to use any werkstatt.gpg.vault.*.sh script}"
    export VAULT_ADDR

    local status_json sealed
    if ! status_json="$(vault status -format=json 2>&1)"; then
        echo "ERROR: could not reach Vault at ${VAULT_ADDR} -- check network path / VAULT_ADDR / TLS." >&2
        echo "vault status output: ${status_json}" >&2
        return 1
    fi
    sealed="$(printf '%s' "$status_json" | jq -r '.sealed')"
    if [[ "$sealed" != "false" ]]; then
        echo "ERROR: Vault at ${VAULT_ADDR} is sealed -- an admin needs to run 'vault operator unseal' (3 of 5 keys) before this can proceed." >&2
        return 1
    fi
    return 0
}

###############################################################################
# mfte_gpg_vault_login_if_needed
###############################################################################
# Uses VAULT_TOKEN if already set. Otherwise logs in via AppRole using
# VAULT_ROLE_ID/VAULT_SECRET_ID -- which reach this function's environment
# via mfte.sh's `set -a; source "${CONFIG_FILE}"; set +a` when they're
# defined in the shared .env, same as every other MFTE_* setting -- and
# exports the resulting scoped token as VAULT_TOKEN for the rest of this
# process. Unsets VAULT_SECRET_ID immediately after use -- it has done its
# job and shouldn't linger in the environment any longer than the login
# call that consumed it.
#
# NOTE ON WHY THIS IS SIMPLE: MFTE Rules currently logs every Rule variable
# substitution in cleartext, so VAULT_SECRET_ID could never be delivered as
# a Rule parameter without leaking into a system log. Putting it in the
# shared .env instead sidesteps that specific leak vector entirely --
# these values are read from a file via `source`, never passed through
# Control-M's Rule-variable substitution/logging path at all. Accepted as
# the interim approach given this host's .env is only reachable by cluster
# nodes and the local root user; revisit if that access boundary changes,
# or once MFTE Rules gains a secure-variable mechanism.
mfte_gpg_vault_login_if_needed() {
    if [[ -n "${VAULT_TOKEN:-}" ]]; then
        return 0
    fi
    if [[ -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
        echo "ERROR: no VAULT_TOKEN set, and VAULT_ROLE_ID/VAULT_SECRET_ID are not both set -- check that they're defined in the shared .env." >&2
        return 1
    fi
    local login_token
    login_token="$(vault write -field=token auth/approle/login \
        role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID" 2>/dev/null)" || {
        echo "ERROR: AppRole login failed -- check VAULT_ROLE_ID/VAULT_SECRET_ID and Vault reachability." >&2
        return 1
    }
    if [[ -z "$login_token" ]]; then
        echo "ERROR: AppRole login returned no token." >&2
        return 1
    fi
    export VAULT_TOKEN="$login_token"
    unset VAULT_SECRET_ID
    return 0
}

###############################################################################
# mfte_gpg_vault_passphrase_path <fingerprint>
###############################################################################
mfte_gpg_vault_passphrase_path() {
    local fp="$1"
    printf '%s/%s/%s' "${MFTE_VAULT_MOUNT}" "${MFTE_VAULT_GPG_PREFIX}" "$fp"
}

###############################################################################
# mfte_gpg_vault_get_passphrase <fingerprint>
###############################################################################
# Prints the passphrase to stdout and NOTHING else. Callers must only ever
# consume this via process substitution (--passphrase-fd) or capture it
# straight into a variable that is immediately handed to another
# mfte_gpg_* function and never echoed/logged -- identical rule to every
# other passphrase-handling function in mfte.gpg.sh.
mfte_gpg_vault_get_passphrase() {
    local fp="$1"
    vault kv get -field=passphrase "$(mfte_gpg_vault_passphrase_path "$fp")" 2>/dev/null
}

###############################################################################
# mfte_gpg_vault_put_passphrase_from_file <fingerprint> <local-passphrase-file>
###############################################################################
# Writes an already-filed local passphrase file into Vault using vault's own
# key=@file syntax -- vault reads the file directly; the passphrase value
# never becomes this shell's variable, never appears in this process's argv.
# Caller is responsible for having already validated <local-passphrase-file>
# with mfte_gpg_require_locked_down before calling this.
mfte_gpg_vault_put_passphrase_from_file() {
    local fp="$1" file="$2"
    vault kv put "$(mfte_gpg_vault_passphrase_path "$fp")" "passphrase=@${file}" >/dev/null
}

###############################################################################
# mfte_gpg_vault_delete_passphrase <fingerprint> [--destroy]
###############################################################################
# Default: soft delete of the current version (recoverable via
# 'vault kv undelete'). --destroy: permanently removes all versions and
# metadata for this path -- irreversible.
mfte_gpg_vault_delete_passphrase() {
    local fp="$1" mode="${2:-}"
    if [[ "$mode" == "--destroy" ]]; then
        vault kv metadata delete "$(mfte_gpg_vault_passphrase_path "$fp")"
    else
        vault kv delete "$(mfte_gpg_vault_passphrase_path "$fp")"
    fi
}
