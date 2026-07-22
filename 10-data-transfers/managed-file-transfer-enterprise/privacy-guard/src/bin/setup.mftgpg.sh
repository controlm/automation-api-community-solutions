#!/bin/bash
# shellcheck enable=require-variable-braces
# file name: setup.mftgpg.sh
################################################################################
# License                                                                      #
################################################################################
function license() {
    printf '%s\n' ""
    printf '%s\n' " GPL-3.0-only or GPL-3.0-or-later"
    printf '%s\n' " Copyright (c) 2021 BMC Software, Inc."
    printf '%s\n' " Author: Volker Scheithauer"
    printf '%s\n' " E-Mail: orchestrator@bmc.com"
    printf '%s\n' ""
    printf '%s\n' " This program is free software: you can redistribute it and/or modify"
    printf '%s\n' " it under the terms of the GNU General Public License as published by"
    printf '%s\n' " the Free Software Foundation, either version 3 of the License, or"
    printf '%s\n' " (at your option) any later version."
    printf '%s\n' ""
    printf '%s\n' " This program is distributed in the hope that it will be useful,"
    printf '%s\n' " but WITHOUT ANY WARRANTY; without even the implied warranty of"
    printf '%s\n' " MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the"
    printf '%s\n' " GNU General Public License for more details."
    printf '%s\n' ""
    printf '%s\n' " You should have received a copy of the GNU General Public License"
    printf '%s\n' " along with this program.  If not, see <https://www.gnu.org/licenses/>."
}

# purpose : One-time / idempotent host setup for the mftgpg service account
#           ONLY -- deliberately scoped down from setup.user.sh, which loops
#           over every account in data.json's USERS.OS.
#
# origin  : Split out after review of setup.user.sh found it granting mftgpg
#           a real login password, an SSH keypair + authorized_keys entry,
#           and passwordless root sudo (inherited via the shared "controlm"
#           primary group's NOPASSWD ALL entry) -- all appropriate for the
#           interactive admin/service accounts that script also provisions,
#           none of it appropriate for mftgpg, which exists purely so
#           mfte.gpg.sh's `runuser -u mftgpg` calls have somewhere to drop
#           root privilege into. A compromised mftgpg should lose keyring
#           material, not hand back root.
#
# scope   : This script does NOT create the "controlm" group -- that's
#           shared, central infrastructure owned by setup.user.sh /
#           data.json's GROUPS.OS, not something a single service account's
#           setup script should be deciding a gid for. It fails loudly if
#           that group doesn't exist yet instead.
#
# run as  : root (or via sudo) -- useradd, chown under /home, and the
#           sudoers.d write all require it. Checked explicitly below rather
#           than failing midway through with a confusing permission error.

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MFTE_OPS_HOME="${MFTE_OPS_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
MFTE_LIB_DIR="${MFTE_LIB_DIR:-${MFTE_OPS_HOME}/lib}"

# shellcheck source=/dev/null
if ! source "${MFTE_LIB_DIR}/bash/mfte.sh"; then
  echo "ERROR: could not source ${MFTE_LIB_DIR}/bash/mfte.sh" >&2
  echo "If MFTE_OPS_HOME/MFTE_LIB_DIR were already exported in this shell (e.g. from an earlier" >&2
  echo "'source .env' in the same session), they override this script's own location-based" >&2
  echo "derivation -- a stale value from a different host/mount can point here at nothing." >&2
  echo "Try: unset MFTE_OPS_HOME MFTE_LIB_DIR" >&2
  exit 1
fi

# Config lives on the shared NFS mount, NOT next to this script -- every
# hub should read the exact same data.mftgpg.json. Resolved AFTER sourcing
# mfte.sh (above), rather than a hardcoded fallback computed before it, so
# there is exactly one place (.env's own MFTE_CONFIG_DIR=${MFTE_OPS_HOME}/config)
# that decides where this lives -- a second, independent hardcoded copy of
# that path here previously could silently drift from .env if MFTE_HOME
# ever moved without this script's own fallback being updated to match.
# The ":-" fallback below only matters if .env itself didn't set
# MFTE_CONFIG_DIR, and derives from the SAME MFTE_OPS_HOME this script
# already resolved above, not a separate absolute path.
MFTE_CONFIG_DIR="${MFTE_CONFIG_DIR:-${MFTE_OPS_HOME}/config}"
CONFIG_DIR="${MFTE_CONFIG_DIR}"
SCRIPT_DATA_FILE="${CONFIG_DIR}/data.mftgpg.json"

# Reset Colors
Color_Off='\033[0m'
Cyan='\033[0;36m'
Green='\033[0;32m'
Yellow='\033[0;33m'
IYellow='\033[0;93m'
IRed='\033[0;91m'
Purple='\033[0;35m'

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Reads ${SCRIPT_DATA_FILE} and enforces (idempotently, safe to re-run):
  - the mftgpg OS account exists with the configured uid/home/shell,
    primary group unchanged from whatever it actually is on this host
  - NO password, NO SSH keypair, NO sudoers grant for mftgpg
  - the three mftgpg-private directories (MFTE_GPG_HOME/META_DIR/
    PASSPHRASE_DIR, all under mftgpg's own home) exist with correct
    mode/owner
  - the shared GPG directories (MFTE_GPG_OUTPUT_DIR, MFTE_GPG_EXCHANGE_DIR,
    MFTE_GPG_ONBOARDING_PRIVACY_DIR, MFTE_GPG_RECEIVE_STAGING_DIR --
    resolved from .env, wherever they actually point under MFTE_OPS_HOME)
    exist, group-owned by the shared controlm group with the setgid bit
    set, so both root (Control-M's own actions) and mftgpg (via runuser)
    can read/write them
  - (if GPG.agent_loopback_conf) gpg-agent.conf allowing loopback pinentry
  - (if SUDO.deny_all) an explicit sudoers override denying mftgpg all
    sudo, canceling out the NOPASSWD ALL it otherwise inherits from the
    shared "controlm" primary group on hosts where setup.user.sh has run

Optional:
  -q  quiet       suppress the human-readable report (errors still print)
  -h  help

Must be run as root.
USAGE
}

QUIET="false"
while getopts ':qh' opt; do
  case "$opt" in
    q) QUIET="true" ;;
    h) usage; exit 0 ;;
    :) echo "Missing value for -$OPTARG" >&2; usage; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done

retcode=0

################################################################################
# Preconditions                                                                #
################################################################################
if [[ "$(id -u)" -ne 0 ]]; then
  log_system ERROR "must run as root, current uid=$(id -u)"
  echo "ERROR: this script must run as root (useradd, chown under /home, and the" >&2
  echo "sudoers.d write all require it). Re-run as root, e.g.: sudo -i, then run this." >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_DATA_FILE" ]]; then
  log_system ERROR "data file not found: ${SCRIPT_DATA_FILE}"
  echo "ERROR: ${SCRIPT_DATA_FILE} not found." >&2
  exit 1
fi

SCRIPT_DATA="$(jq '.' "$SCRIPT_DATA_FILE")" || { echo "ERROR: ${SCRIPT_DATA_FILE} is not valid JSON." >&2; exit 1; }

GROUP_NAME="$(echo "$SCRIPT_DATA" | jq -r '.GROUP.name')"
GROUP_ID="$(echo "$SCRIPT_DATA" | jq -r '.GROUP.id')"

USER_NAME="$(echo "$SCRIPT_DATA" | jq -r '.USER.name')"
USER_BASE="$(echo "$SCRIPT_DATA" | jq -r '.USER.base')"
USER_SHELL="$(echo "$SCRIPT_DATA" | jq -r '.USER.shell')"
USER_ID="$(echo "$SCRIPT_DATA" | jq -r '.USER.id')"
USER_TITLE="$(echo "$SCRIPT_DATA" | jq -r '.USER.title')"
USER_HOME="${USER_BASE}/${USER_NAME}"

GPG_HOME_SUBDIR="$(echo "$SCRIPT_DATA" | jq -r '.GPG.home_dir')"
GPG_HOME_MODE="$(echo "$SCRIPT_DATA" | jq -r '.GPG.home_mode')"
GPG_AGENT_LOOPBACK="$(echo "$SCRIPT_DATA" | jq -r '.GPG.agent_loopback_conf')"
GPG_META_SUBDIR="$(echo "$SCRIPT_DATA" | jq -r '.GPG.meta_dir')"
GPG_META_MODE="$(echo "$SCRIPT_DATA" | jq -r '.GPG.meta_mode')"
GPG_PASS_SUBDIR="$(echo "$SCRIPT_DATA" | jq -r '.GPG.passphrase_dir')"
GPG_PASS_MODE="$(echo "$SCRIPT_DATA" | jq -r '.GPG.passphrase_mode')"

SUDO_DENY_ALL="$(echo "$SCRIPT_DATA" | jq -r '.SUDO.deny_all')"
SUDO_DENY_FILE="$(echo "$SCRIPT_DATA" | jq -r '.SUDO.file')"

echo " "
echo " mftgpg Service Account Setup"
echo " -----------------------------------------------"
echo -e " ${Cyan}User Name    : ${Yellow}${USER_NAME}${Color_Off}"
echo -e " ${Cyan}User Home    : ${Yellow}${USER_HOME}${Color_Off}"
echo -e " ${Cyan}User Shell   : ${Yellow}${USER_SHELL}${Color_Off}"
echo -e " ${Cyan}User ID      : ${Yellow}${USER_ID}${Color_Off}"
echo -e " ${Cyan}Primary Grp  : ${Yellow}${GROUP_NAME} (must pre-exist)${Color_Off}"
echo -e " ${Cyan}Data File    : ${Yellow}${SCRIPT_DATA_FILE}${Color_Off}"
echo " -----------------------------------------------"
log_system INFO "start user=${USER_NAME} home=${USER_HOME} data_file=${SCRIPT_DATA_FILE}"

################################################################################
# Group -- must already exist. This script never creates or resizes the      #
# shared "controlm" group -- that's whatever host-provisioning process       #
# owns it in this environment (setup.user.sh in some deployments, a          #
# pre-baked image or manual groupadd in others -- not every deployment of    #
# this framework has setup.user.sh in play).                                 #
################################################################################
function ensureGroupExists() {
    if [ ! "$(getent group "${GROUP_NAME}")" ]; then
        echo -e "${Color_Off} - ${Cyan}Group     :${Color_Off} '${GROUP_NAME}' ${IRed}does not exist -- create it first (e.g. groupadd -g ${GROUP_ID} ${GROUP_NAME}), however this host provisions shared groups${Color_Off}"
        log_system ERROR "primary group ${GROUP_NAME} does not exist"
        retcode=1
        return 1
    fi
    CURRENT_GID="$(getent group "${GROUP_NAME}" | cut -d: -f3)"
    if [ "${CURRENT_GID}" != "${GROUP_ID}" ]; then
        echo -e "${Color_Off} - ${Cyan}Group     :${Color_Off} '${GROUP_NAME}' ${IRed}gid drift: host has ${CURRENT_GID}, data.mftgpg.json expects ${GROUP_ID} (not changed, informational only)${Color_Off}"
        log_system WARN "gid drift group=${GROUP_NAME} host=${CURRENT_GID} expected=${GROUP_ID}"
    else
        echo -e "${Color_Off} = ${Cyan}Group     :${Color_Off} '${GROUP_NAME}' (gid ${CURRENT_GID}) ${Green}ok${Color_Off}"
    fi
    return 0
}

################################################################################
# Account -- create if missing, enforce shell + home + primary group on      #
# every run. Deliberately does NOT set a password, generate an SSH keypair,  #
# add an authorized_keys entry, or touch sudoers -- mftgpg is reached only   #
# via root's `runuser -u mftgpg`, never by direct login.                     #
################################################################################
function ensureAccount() {
    if id "${USER_NAME}" >/dev/null 2>&1; then
        echo -e "${Color_Off} = ${Cyan}Status    :${Color_Off} '${USER_NAME}' ${Green}user exists${Color_Off}"
    else
        echo -e "${Color_Off} + ${Cyan}${USER_NAME}${Color_Off}: ${Yellow}creating${Color_Off}"
        # Deliberately NOT -r: this environment's service accounts (ctmag,
        # ctmfte, mftuser, mftgpg, ...) use uids in the 6000s, well above the
        # default SYS_UID_MAX (999) that -r's "system account" range implies
        # -- useradd will still honor -u's explicit value either way, but -r
        # fights it and produces a spurious "uid is greater than SYS_UID_MAX"
        # warning on every fresh host. No -p / chpasswd anywhere in this
        # script: an account nothing should ever log into interactively
        # doesn't need a password, valid or not.
        if ! useradd -m -d "${USER_HOME}" -g "${GROUP_NAME}" -u "${USER_ID}" -c "${USER_TITLE}" -s "${USER_SHELL}" "${USER_NAME}"; then
            echo -e "${Color_Off} - ${Cyan}Status    :${Color_Off} ${IRed}useradd FAILED for '${USER_NAME}'${Color_Off}"
            log_system ERROR "useradd failed user=${USER_NAME}"
            retcode=1
            return 1
        fi
        log_system INFO "account created user=${USER_NAME} uid=${USER_ID} home=${USER_HOME}"
    fi

    # enforce shell every run
    CURRENT_SHELL="$(getent passwd "${USER_NAME}" | cut -d: -f7)"
    if [ "${CURRENT_SHELL}" == "${USER_SHELL}" ]; then
        echo -e "${Color_Off} = ${Cyan}Shell     :${Color_Off} '${USER_SHELL}' ${Green}ok${Color_Off}"
    else
        echo -e "${Color_Off} + ${Cyan}Shell     :${Color_Off} '${CURRENT_SHELL}' -> '${USER_SHELL}' ${IYellow}fixing${Color_Off}"
        usermod -s "${USER_SHELL}" "${USER_NAME}"
        log_system INFO "shell fixed user=${USER_NAME} -> ${USER_SHELL}"
    fi

    # report (never auto-fix) uid drift, same posture as setup.user.sh --
    # usermod -u leaves stale file ownership scattered across the filesystem
    CURRENT_UID="$(id -u "${USER_NAME}")"
    if [ "${CURRENT_UID}" == "${USER_ID}" ]; then
        echo -e "${Color_Off} = ${Cyan}UID       :${Color_Off} '${USER_ID}' ${Green}ok${Color_Off}"
    else
        echo -e "${Color_Off} - ${Cyan}UID       :${Color_Off} ${IRed}drift: current '${CURRENT_UID}', data.mftgpg.json '${USER_ID}' (NOT changed, fix manually)${Color_Off}"
        log_system WARN "uid drift user=${USER_NAME} current=${CURRENT_UID} expected=${USER_ID}"
        retcode=1
    fi

    # primary group -- report drift, fix it (this IS safe to auto-fix,
    # unlike uid: it doesn't strand file ownership, chgrp already covers it
    # for every MFTE_GPG_* path below)
    CURRENT_PRIMARY="$(id -gn "${USER_NAME}" 2>/dev/null)"
    if [ "${CURRENT_PRIMARY}" == "${GROUP_NAME}" ]; then
        echo -e "${Color_Off} = ${Cyan}Primary   :${Color_Off} '${GROUP_NAME}' ${Green}ok${Color_Off}"
    else
        echo -e "${Color_Off} + ${Cyan}Primary   :${Color_Off} '${CURRENT_PRIMARY}' -> '${GROUP_NAME}' ${IYellow}fixing${Color_Off}"
        usermod -g "${GROUP_NAME}" "${USER_NAME}"
        log_system INFO "primary group fixed user=${USER_NAME} -> ${GROUP_NAME}"
    fi

    # explicit, positive confirmation this account carries none of the
    # interactive-access artifacts setup.user.sh would otherwise attach
    if [[ -f "${USER_HOME}/.ssh/authorized_keys" ]]; then
        echo -e "${Color_Off} - ${Cyan}SSH       :${Color_Off} ${IRed}authorized_keys present at ${USER_HOME}/.ssh/authorized_keys -- unexpected for mftgpg, review manually${Color_Off}"
        log_system WARN "unexpected authorized_keys present for ${USER_NAME}"
    else
        echo -e "${Color_Off} = ${Cyan}SSH       :${Color_Off} no authorized_keys ${Green}ok${Color_Off}"
    fi
    return 0
}

################################################################################
# GPG directory bootstrap -- the actual "One-time host setup" block from     #
# README.md, made idempotent and re-runnable instead of a one-off manual     #
# command sequence.                                                          #
################################################################################
function ensureDir() {
    local label="$1" path="$2" mode="$3"
    mkdir -p "$path"
    chown "${USER_NAME}:${GROUP_NAME}" "$path"
    chmod "$mode" "$path"
    echo -e "${Color_Off} = ${Cyan}${label}${Color_Off} : ${Yellow}${path}${Color_Off} (${mode}, ${USER_NAME}:${GROUP_NAME}) ${Green}ok${Color_Off}"
    log_system INFO "dir ensured label=${label} path=${path} mode=${mode} owner=${USER_NAME}:${GROUP_NAME}"
}

function ensureGpgDirs() {
    ensureDir "MFTE_GPG_HOME     " "${USER_HOME}/${GPG_HOME_SUBDIR}" "${GPG_HOME_MODE}"
    ensureDir "MFTE_GPG_META_DIR " "${USER_HOME}/${GPG_META_SUBDIR}" "${GPG_META_MODE}"
    ensureDir "MFTE_GPG_PASS_DIR " "${USER_HOME}/${GPG_PASS_SUBDIR}" "${GPG_PASS_MODE}"

    if [[ "$GPG_AGENT_LOOPBACK" == "true" ]]; then
        local agent_conf="${USER_HOME}/${GPG_HOME_SUBDIR}/gpg-agent.conf"
        if [[ ! -f "$agent_conf" ]] || ! grep -qx 'allow-loopback-pinentry' "$agent_conf"; then
            printf 'allow-loopback-pinentry\n' > "$agent_conf"
            chown "${USER_NAME}:${GROUP_NAME}" "$agent_conf"
            chmod 600 "$agent_conf"
            echo -e "${Color_Off} + ${Cyan}gpg-agent.conf${Color_Off}: ${IYellow}written (allow-loopback-pinentry)${Color_Off}"
            log_system INFO "gpg-agent.conf written path=${agent_conf}"
        else
            echo -e "${Color_Off} = ${Cyan}gpg-agent.conf${Color_Off}: ${Green}ok${Color_Off}"
        fi
    fi
}

################################################################################
# Shared GPG directories -- output, exchange, onboarding, and the            #
# receive-staging landing spot. These are NOT under mftgpg's own home like   #
# the three above; env.sh resolves them under MFTE_OPS_HOME (a subdirectory  #
# of MFTE_TMP_DIR / MFTE_OPS_HOME/privacy) instead, because they have to be  #
# reachable by BOTH mftgpg (gpg's actual writes, via runuser) and root       #
# (Control-M's own encrypt/decrypt/export scripts, and the native "Move      #
# File" action that stages inbound files for werkstatt.gpg.receive.file.sh)  #
# -- same group-writable + setgid pattern README.md documents for            #
# cluster.jsonl, not owner-only like MFTE_GPG_HOME/META/PASSPHRASE above.    #
# Read directly from the already-sourced .env rather than from              #
# data.mftgpg.json -- these paths aren't a fixed subdir name under USER_HOME #
# the way the three private ones are, they're whatever the environment      #
# actually resolves them to.                                                #
################################################################################
function ensureSharedDir() {
    local label="$1" path="$2"
    if [[ -z "$path" ]]; then
        echo -e "${Color_Off} - ${Cyan}${label}${Color_Off} : ${IRed}env var not set -- skipping${Color_Off}"
        log_system WARN "shared dir skipped label=${label} reason=env_var_unset"
        return 0
    fi
    mkdir -p "$path"
    chgrp "${GROUP_NAME}" "$path"
    chmod 2775 "$path"
    echo -e "${Color_Off} = ${Cyan}${label}${Color_Off} : ${Yellow}${path}${Color_Off} (2775, root:${GROUP_NAME}) ${Green}ok${Color_Off}"
    log_system INFO "shared dir ensured label=${label} path=${path} mode=2775 group=${GROUP_NAME}"
}

function ensureSharedGpgDirs() {
    ensureSharedDir "MFTE_GPG_OUTPUT_DIR   " "${MFTE_GPG_OUTPUT_DIR:-}"
    ensureSharedDir "MFTE_GPG_EXCHANGE_DIR " "${MFTE_GPG_EXCHANGE_DIR:-}"
    ensureSharedDir "GPG_ONBOARDING_DIR    " "${MFTE_GPG_ONBOARDING_PRIVACY_DIR:-}"
    ensureSharedDir "GPG_RECEIVE_STAGING   " "${MFTE_GPG_RECEIVE_STAGING_DIR:-}"
}

################################################################################
# sudoers -- explicit deny, not just absence of a grant. mftgpg's primary    #
# group (controlm) already carries NOPASSWD ALL via /etc/sudoers.d/controlm  #
# on any host where setup.user.sh has run; omitting a grant here doesn't     #
# cancel that. sudoers is last-match-wins across the combined file set, so   #
# an explicit "mftgpg ALL=(ALL) !ALL" -- placed in a file that sorts after   #
# "controlm" -- overrides the group grant for mftgpg only.                   #
################################################################################
function ensureSudoDeny() {
    if [[ "$SUDO_DENY_ALL" != "true" ]]; then
        echo -e "${Color_Off} = ${Cyan}Sudo Deny :${Color_Off} skipped (SUDO.deny_all is false in data.mftgpg.json)"
        return 0
    fi

    local desired="${USER_NAME} ALL=(ALL) !ALL"
    if [[ -f "$SUDO_DENY_FILE" ]] && grep -qxF "$desired" "$SUDO_DENY_FILE"; then
        echo -e "${Color_Off} = ${Cyan}Sudo Deny :${Color_Off} '${SUDO_DENY_FILE}' ${Green}ok${Color_Off}"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    printf '%s\n' "$desired" > "$tmp"
    # never install a sudoers fragment without validating it first -- a
    # malformed file under sudoers.d can break sudo for every account on
    # the host, not just mftgpg
    if ! visudo -cf "$tmp" >/dev/null 2>&1; then
        echo -e "${Color_Off} - ${Cyan}Sudo Deny :${Color_Off} ${IRed}visudo -cf rejected the generated rule -- NOT installed${Color_Off}"
        log_system ERROR "visudo validation failed for generated ${SUDO_DENY_FILE}"
        rm -f "$tmp"
        retcode=1
        return 1
    fi
    install -m 0440 -o root -g root "$tmp" "$SUDO_DENY_FILE"
    rm -f "$tmp"
    echo -e "${Color_Off} + ${Cyan}Sudo Deny :${Color_Off} '${SUDO_DENY_FILE}' ${IYellow}installed: ${desired}${Color_Off}"
    log_system INFO "sudo deny installed file=${SUDO_DENY_FILE} rule=\"${desired}\""
}

ensureGroupExists || { log_system ERROR "aborting: group precondition failed"; exit 1; }
ensureAccount
ensureGpgDirs
ensureSharedGpgDirs
ensureSudoDeny

echo " -----------------------------------------------"
if [[ "$retcode" -eq 0 ]]; then
  echo -e " ${Cyan}Result       : ${Green}ok${Color_Off}"
else
  echo -e " ${Cyan}Result       : ${IRed}completed with warnings/errors -- see above and ${SYSTEM_LOG_FILE}${Color_Off}"
fi
log_system INFO "complete user=${USER_NAME} retcode=${retcode}"

if [[ "$QUIET" != "true" ]]; then
  cat <<REPORT

mftgpg setup complete
  user               : ${USER_NAME} (uid ${USER_ID})
  home               : ${USER_HOME}
  shell              : ${USER_SHELL}
  MFTE_GPG_HOME      : ${USER_HOME}/${GPG_HOME_SUBDIR}
  MFTE_GPG_META_DIR  : ${USER_HOME}/${GPG_META_SUBDIR}
  MFTE_GPG_PASSPHRASE_DIR : ${USER_HOME}/${GPG_PASS_SUBDIR}
  MFTE_GPG_OUTPUT_DIR: ${MFTE_GPG_OUTPUT_DIR:-<unset>}
  MFTE_GPG_EXCHANGE_DIR   : ${MFTE_GPG_EXCHANGE_DIR:-<unset>}
  MFTE_GPG_ONBOARDING_PRIVACY_DIR : ${MFTE_GPG_ONBOARDING_PRIVACY_DIR:-<unset>}
  MFTE_GPG_RECEIVE_STAGING_DIR    : ${MFTE_GPG_RECEIVE_STAGING_DIR:-<unset>}
  sudo               : $([ "$SUDO_DENY_ALL" == "true" ] && echo "explicitly denied (${SUDO_DENY_FILE})" || echo "not managed by this script")
REPORT
fi

exit "${retcode}"
