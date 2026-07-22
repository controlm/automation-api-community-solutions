#!/bin/bash

# file name: mfte.gpg.sh
# purpose : Shared GPG helpers for MFTE GPG operation scripts -- privilege-
#           dropping gpg invocation (mfte_gpg_run), passphrase-file
#           handling, default-key metadata, fingerprint lookup/import, and
#           key-file inspection -- so no werkstatt.gpg.*.sh script re-rolls
#           any of this independently. Source mfte.sh FIRST, then this
#           file. Kept as a separate library rather than folded into
#           mfte.sh so scripts that have nothing to do with GPG (e.g.
#           mfte.rule.vars.all.jsonl.sh) aren't forced to satisfy
#           gpg/runuser/openssl dependency checks they don't need.
#
# origin  : These scripts originated as training material, written to show
#           a student every intermediate value -- including passphrases —
#           in plain view on purpose. That was the right call for its
#           original purpose. This library exists because these scripts
#           are moving into a production-like demo, where the same
#           transparency in stdout/logs would mean a passphrase or key
#           sitting in a Control-M job log forever. The functions below
#           exist to make that not happen by default, without pretending
#           the original design was a mistake.
#
# privilege: All actual `gpg` calls in this framework run as a dedicated
#           service account (MFTE_GPG_USER, e.g. "mftgpg"), never as the
#           identity Control-M's agent uses to invoke the calling script.
#           On this platform MFTE rule/action scripts always execute as
#           root — there is no Control-M "RunAs" job option here to switch
#           identity before the script starts — so every script that needs
#           to touch a GPG keyring drops privilege itself, per gpg call,
#           via runuser. This keeps private key material and passphrases
#           owned and readable only by mftgpg, never exposed to root's
#           broader reach than that one operation requires.

require_command gpg
require_command runuser
require_command openssl

: "${MFTE_GPG_USER:?MFTE_GPG_USER is not set — check that mfte.sh sourced the .env}"
: "${MFTE_GPG_HOME:?MFTE_GPG_HOME is not set — check that mfte.sh sourced the .env}"
: "${MFTE_GPG_META_DIR:?MFTE_GPG_META_DIR is not set — check that mfte.sh sourced the .env}"
: "${MFTE_GPG_PASSPHRASE_DIR:?MFTE_GPG_PASSPHRASE_DIR is not set — check that mfte.sh sourced the .env}"
: "${MFTE_GPG_OUTPUT_DIR:?MFTE_GPG_OUTPUT_DIR is not set — check that mfte.sh sourced the .env}"
: "${MFTE_GPG_EXCHANGE_DIR:?MFTE_GPG_EXCHANGE_DIR is not set — check that mfte.sh sourced the .env}"

MFTE_GPG_DEFAULT_KEY_FILE="${MFTE_GPG_META_DIR}/default-key.json"

###############################################################################
# mfte_gpg_run <gpg args...>
###############################################################################
# Runs gpg as MFTE_GPG_USER against MFTE_GPG_HOME. --homedir is passed
# explicitly on every call rather than relying on GNUPGHOME surviving the
# identity switch through runuser -- runuser does not guarantee the
# caller's environment reaches the target user's shell the way a plain env
# var export would, so don't depend on it here.
mfte_gpg_run() {
    runuser -u "${MFTE_GPG_USER}" -- gpg --homedir "${MFTE_GPG_HOME}" "$@"
}

###############################################################################
# mfte_gpg_require_locked_down <path> <expected_octal_mode>
###############################################################################
# Refuses to use a key/passphrase file or directory whose permissions or
# ownership don't match what's expected, rather than trusting it blindly.
# expected_octal_mode is a plain string like "600" or "700".
mfte_gpg_require_locked_down() {
    local path="$1" expected="$2" actual owner
    if [[ ! -e "$path" ]]; then
        echo "ERROR: expected file/dir not found: $path" >&2
        return 1
    fi
    actual="$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" 2>/dev/null)"
    owner="$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path" 2>/dev/null)"
    if [[ "$actual" != "$expected" ]]; then
        echo "ERROR: $path has mode $actual, expected $expected -- refusing to use it" >&2
        return 1
    fi
    if [[ "$owner" != "${MFTE_GPG_USER}" ]]; then
        echo "ERROR: $path is owned by $owner, expected ${MFTE_GPG_USER} -- refusing to use it" >&2
        return 1
    fi
    return 0
}

###############################################################################
# Passphrase file helpers
###############################################################################
# Convention: one passphrase file per key, named by fingerprint, under
# MFTE_GPG_PASSPHRASE_DIR (mode 700), each file mode 600, both owned by
# MFTE_GPG_USER. gpg reads it directly via --passphrase-file -- the
# passphrase value itself never appears as a CLI argument, in stdout, or in
# any log line written by these scripts.

mfte_gpg_passphrase_file() {
    local ident="$1"
    printf '%s/%s.passphrase' "${MFTE_GPG_PASSPHRASE_DIR}" "$ident"
}

# mfte_gpg_write_passphrase_file <fingerprint-or-label> <passphrase>
# Writes/overwrites a passphrase file as MFTE_GPG_USER, mode 600. Callers
# must not echo, printf, or log the passphrase value themselves -- pass it
# straight from generation into this function and let it go out of scope.
mfte_gpg_write_passphrase_file() {
    local ident="$1" passphrase="$2" target
    target="$(mfte_gpg_passphrase_file "$ident")"
    runuser -u "${MFTE_GPG_USER}" -- mkdir -p "${MFTE_GPG_PASSPHRASE_DIR}"
    runuser -u "${MFTE_GPG_USER}" -- chmod 700 "${MFTE_GPG_PASSPHRASE_DIR}"
    printf '%s' "$passphrase" | runuser -u "${MFTE_GPG_USER}" -- tee "$target" >/dev/null
    runuser -u "${MFTE_GPG_USER}" -- chmod 600 "$target"
}

# mfte_gpg_generate_passphrase
# 24 bytes of randomness, base64-encoded. Only used when a script needs to
# mint a brand-new passphrase (key generation). The result must go straight
# to mfte_gpg_write_passphrase_file, never to stdout or a log line.
mfte_gpg_generate_passphrase() {
    openssl rand -base64 24
}

# mfte_gpg_copy_passphrase_as_user <src> <dst>
# Copies an already-written passphrase file to a new location AS
# MFTE_GPG_USER, not as the caller (typically root) -- a plain `cp` run
# by the calling script would produce a file owned by whatever identity
# invoked the script, not mftgpg, inconsistent with every other
# passphrase file in this framework and unusable by mftgpg itself
# wherever ownership actually matters downstream. Creates the destination
# directory (as MFTE_GPG_USER too) if it doesn't exist, and locks the
# result to 600.
mfte_gpg_copy_passphrase_as_user() {
    local src="$1" dst="$2" dst_dir
    dst_dir="$(dirname "$dst")"
    runuser -u "${MFTE_GPG_USER}" -- mkdir -p "$dst_dir" || return 1
    runuser -u "${MFTE_GPG_USER}" -- cp "$src" "$dst" || return 1
    runuser -u "${MFTE_GPG_USER}" -- chmod 600 "$dst" || return 1
    return 0
}

###############################################################################
# Default-key metadata (replaces the old dsse.gpg.info.json concept)
###############################################################################
# Deliberately holds identifying info only -- fingerprint, uid, created
# date, and a pointer to where the passphrase file lives -- never the
# passphrase itself. That split means this file can stay more widely
# readable (644) than the passphrase file (600, mftgpg-only) it points at,
# without that convenience ever leaking a secret.

mfte_gpg_write_default_key_json() {
    local fingerprint="$1" uid="$2" created="$3" tmp
    mkdir -p "${MFTE_GPG_META_DIR}"
    tmp="$(mktemp)"
    jq -n \
        --arg fingerprint "$fingerprint" \
        --arg uid "$uid" \
        --arg created "$created" \
        --arg passphrase_file "$(mfte_gpg_passphrase_file "$fingerprint")" \
        '{fingerprint: $fingerprint, uid: $uid, created: $created, passphrase_file: $passphrase_file}' \
        > "$tmp"
    mv "$tmp" "${MFTE_GPG_DEFAULT_KEY_FILE}"
    chmod 644 "${MFTE_GPG_DEFAULT_KEY_FILE}"
}

# mfte_gpg_default_fingerprint
# Prints the fingerprint of the default key, or nothing if default-key.json
# doesn't exist / isn't valid JSON. Callers check for an empty result.
mfte_gpg_default_fingerprint() {
    [[ -r "${MFTE_GPG_DEFAULT_KEY_FILE}" ]] || return 0
    jq -r '.fingerprint // empty' "${MFTE_GPG_DEFAULT_KEY_FILE}" 2>/dev/null
}

###############################################################################
# mfte_increment_filename <path>
###############################################################################
# Returns <path> unchanged if nothing exists there yet, otherwise
# <path>.1, <path>.2, ... -- the first that doesn't already exist. Shared
# by werkstatt.gpg.decrypt.file.sh and werkstatt.gpg.receive.file.sh (was
# duplicated inline in decrypt.file.sh until receive.file.sh needed the
# same logic too).
mfte_increment_filename() {
    local base="$1" candidate="$1" n=1
    while [[ -e "$candidate" ]]; do
        candidate="${base}.${n}"
        n=$((n + 1))
    done
    printf '%s' "$candidate"
}

###############################################################################
# mfte_gpg_preflight
###############################################################################
# Called once near the top of every werkstatt.gpg.*.sh script, after argument
# parsing, before any real gpg operation. Confirms the keyring homedir
# itself is locked down (mode 700, owned by MFTE_GPG_USER) rather than
# discovering a loose GNUPGHOME the hard way, mid-operation. gpg homedirs
# are conventionally 700; anything looser here means something outside
# these scripts touched it.
mfte_gpg_preflight() {
    if ! mfte_gpg_require_locked_down "${MFTE_GPG_HOME}" 700; then
        echo "ERROR: MFTE_GPG_HOME (${MFTE_GPG_HOME}) failed its permission check -- refusing to proceed." >&2
        return 1
    fi
    return 0
}

###############################################################################
# Key lookup / import
###############################################################################

# mfte_gpg_sanitize_key_id <raw>
# gpg's own --fingerprint/--list-keys display formats a fingerprint with a
# space every 4 hex characters (plus a double space at the midpoint) --
# exactly what a user copies when they paste a fingerprint straight out of
# gpg's own output, and exactly what makes a literal `gpg --list-keys
# "<pasted fingerprint>"` fail to match anything. Strips ALL whitespace
# from <raw>, but ONLY when what's left is purely hex -- a uid/email
# search term that happens to contain a real space (e.g. "Jane Doe
# <jane@example.com>") is returned untouched, since gpg needs that space
# to match the display name. Safe to call unconditionally on any -k value
# before using it: a pasted fingerprint gets normalized, everything else
# passes through as-is.
mfte_gpg_sanitize_key_id() {
    local raw="$1" stripped
    stripped="${raw//[[:space:]]/}"
    if [[ -n "$stripped" && "$stripped" =~ ^[0-9A-Fa-f]+$ ]]; then
        printf '%s' "$stripped"
    else
        printf '%s' "$raw"
    fi
}

# mfte_gpg_lookup_fingerprint <search-term> [public|secret]
# Resolves a user id, email, or short id to a full 40-char PRIMARY-key
# fingerprint via gpg --with-colons. Only the fpr line immediately
# following a pub/sec record is taken -- a key built with separate sign
# and encrypt subkeys (see werkstatt.gpg.generate.key.sh) has three fpr lines
# per identity (primary + each subkey), and counting all of them made
# every lookup look "ambiguous" even for a single matching identity.
# Prints nothing and returns 1 on no match OR more than one distinct
# identity match -- an ambiguous recipient/signer should fail loudly, not
# guess.
mfte_gpg_lookup_fingerprint() {
    local term="$1" mode="${2:-public}" list_flag="--list-keys"
    [[ "$mode" == "secret" ]] && list_flag="--list-secret-keys"
    local fprs count
    fprs="$(mfte_gpg_run --batch --with-colons ${list_flag} "$term" 2>/dev/null | awk -F: '
        $1=="pub"||$1=="sec"{grab=1; next}
        $1=="sub"||$1=="ssb"{grab=0; next}
        $1=="fpr" && grab{print $10; grab=0}
    ' | sort -u)"
    count="$(printf '%s\n' "$fprs" | grep -c . || true)"
    if [[ "$count" -eq 1 ]]; then
        printf '%s' "$fprs"
        return 0
    fi
    return 1
}

# mfte_gpg_find_single_file <directory> <glob-pattern>
# Non-recursive glob match within <directory> (e.g. "*.public.*" against
# export.key.sh's own <fingerprint>.public.asc naming convention). Prints
# the one matching file if exactly one exists; prints nothing and returns
# 1 on zero or multiple matches. Used to default a script's -f to "the one
# file already staged in $MFTE_GPG_EXCHANGE_DIR" for demo convenience --
# ambiguous or empty stays a hard requirement for an explicit -f, never a
# guess among several candidates.
mfte_gpg_find_single_file() {
    local dir="$1" pattern="$2"
    local -a matches=()
    local f
    shopt -s nullglob
    for f in "$dir"/$pattern; do
        [[ -f "$f" ]] && matches+=("$f")
    done
    shopt -u nullglob
    if [[ "${#matches[@]}" -eq 1 ]]; then
        printf '%s' "${matches[0]}"
        return 0
    fi
    return 1
}

# mfte_gpg_import_key <path> <public|private>
# Shared import logic for all three import scripts. gpg's own import
# handles both public and secret key material from the same command; the
# mode argument here is used by the caller for validation/logging (e.g.
# confirming a "private key" import actually produced a secret key), not
# to change the underlying gpg invocation. --status-fd 1 output is
# included in stdout so the caller can grep an IMPORT_OK line for the
# imported fingerprint rather than re-listing the whole keyring to find it.
mfte_gpg_import_key() {
    local path="$1" mode="$2"
    case "$mode" in
        public|private) ;;
        *) echo "ERROR: mfte_gpg_import_key mode must be 'public' or 'private', got: $mode" >&2; return 2 ;;
    esac
    mfte_gpg_run --batch --yes --status-fd 1 --import "$path"
}

# mfte_gpg_import_fingerprint <import-output>
# Extracts the fingerprint from a gpg --status-fd 1 --import IMPORT_OK
# line. Prints nothing if none found (e.g. import failed or key already
# present with no change -- callers should check for an empty result).
mfte_gpg_import_fingerprint() {
    printf '%s\n' "$1" | awk '/\[GNUPG:\] IMPORT_OK/{print $NF}' | head -1
}

# mfte_gpg_uid_for_fingerprint <fingerprint> [public|secret]
# Looks up the primary uid string for a given fingerprint. Prints nothing
# if not found.
mfte_gpg_uid_for_fingerprint() {
    local fp="$1" mode="${2:-public}" list_flag="--list-keys"
    [[ "$mode" == "secret" ]] && list_flag="--list-secret-keys"
    mfte_gpg_run --batch --with-colons ${list_flag} "$fp" 2>/dev/null | awk -F: '$1=="uid"{print $10; exit}'
}

# mfte_gpg_file_show_only <path>
# Runs gpg --import-options show-only against a key FILE -- reads its
# packet headers without ever touching the keyring or requiring anything
# to be unlocked, same operation werkstatt.gpg.inspect.key.file.sh already
# does inline. Prints the raw --with-colons output; returns non-zero if
# gpg couldn't read any key material from the file at all. Pulled out here
# (rather than left inline like inspect.key.file.sh's own copy) because
# the two batch-import scripts (werkstatt.gpg.import.all.public.sh /
# .private.sh) both need it for the same reason inspect.key.file.sh does:
# find out what's in a file before doing anything with it.
mfte_gpg_file_show_only() {
    local path="$1"
    mfte_gpg_run --batch --with-colons --import-options show-only --import "$path"
}

# mfte_gpg_file_fingerprint <show-only-output>
# Extracts the PRIMARY key's fingerprint from mfte_gpg_file_show_only's
# output -- same "only the fpr line immediately following a pub/sec
# record" rule as mfte_gpg_lookup_fingerprint, for the same reason (a
# cert+sign+encrypt key structure has separate fpr lines for each subkey
# too; grabbing all of them would pick up the wrong one here since we only
# want the primary). Prints nothing if the file had no readable key data.
mfte_gpg_file_fingerprint() {
    printf '%s\n' "$1" | awk -F: '
        $1=="pub"||$1=="sec"{grab=1; next}
        $1=="sub"||$1=="ssb"{grab=0; next}
        $1=="fpr" && grab{print $10; grab=0}
    ' | head -1
}

# mfte_gpg_file_has_secret <show-only-output>
# Prints "true" if the file's primary record is "sec" (this file carries
# secret/private key material), "false" if it's "pub" (public key only),
# nothing if neither was found. Checked against the FIRST pub/sec record
# specifically, not just "does 'sec' appear anywhere in the output" --
# an armored export can't mix a public primary with a secret subkey in
# practice, but checking the primary record explicitly costs nothing and
# doesn't rely on that assumption holding.
mfte_gpg_file_has_secret() {
    printf '%s\n' "$1" | awk -F: '$1=="pub"{print "false"; exit} $1=="sec"{print "true"; exit}'
}
