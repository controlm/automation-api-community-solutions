#!/usr/bin/env python3
"""
werkstatt.ldap.smtp.test.py

Interactive console tool for MFTE hub environments.
Reads hub_config.properties for non-secret connection details,
prompts the operator for the actual passwords (never reads ENC()
values from the file), then runs an LDAP/LDAPS bind test and an
SMTP send test.

Runs preferentially on the hub (reads hub_config.properties), but also
works on a host that does NOT have that file, by falling back to a local
.env file for non-secret connection details and/or interactive prompts.

PASSWORDS ARE NEVER READ FROM ANY FILE. Even if a password-like key is
present in .env, it is ignored and the admin is always prompted directly.
"""

import os
import re
import sys
import getpass
import smtplib
import argparse
from pathlib import Path
from string import Template
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.utils import formataddr

# --- Vendored dependency bootstrap -----------------------------------------
# If a "vendor" folder sits next to this script (shipped in the deployment
# zip), prefer it over anything installed system-wide. This lets the script
# run with zero pip install / venv setup — just unzip and run with whatever
# system python3 is already on the hub.
_SCRIPT_DIR = Path(__file__).resolve().parent
_VENDOR_DIR = _SCRIPT_DIR / "vendor"
if _VENDOR_DIR.is_dir():
    sys.path.insert(0, str(_VENDOR_DIR))
# ----------------------------------------------------------------------------

try:
    import ldap3
    from ldap3.core.exceptions import LDAPException
except ImportError:
    print("Could not import ldap3.")
    print(f"Expected either a system install, or a 'vendor' folder next to this script at: {_VENDOR_DIR}")
    print("If you have the deployment zip, make sure you extracted it fully (script + vendor/ together).")
    sys.exit(1)

__version__ = "1.0.1"

_CONTROLM_ENV = os.environ.get("CONTROLM", "").strip()
if _CONTROLM_ENV:
    # Live hub path — hub_config.properties lives under $CONTROLM, not next
    # to this script.
    DEFAULT_PROPS_PATH = str(Path(_CONTROLM_ENV) / "cm" / "AFT" / "data" / "hub_config.properties")
else:
    # No CONTROLM env var on this host (likely not the hub) — fall back to
    # the old relative default so a copy placed next to the script still works.
    DEFAULT_PROPS_PATH = "hub_config.properties"
DEFAULT_ENV_PATH = str(_SCRIPT_DIR / "config" / ".env")

# Keys we will NEVER accept from a file, no matter what it's named.
FORBIDDEN_KEY_PATTERNS = ["password", "passwd", "secret", "pwd"]


def _is_forbidden_key(key):
    """True only if the key itself looks like it HOLDS a secret (ends with
    one of these terms) — not merely mentions one. This distinguishes an
    actual secret like 'hub.ldap.search-password' from a schema field name
    like 'hub.ldap.password-attribute-name', which just names which LDAP
    attribute stores passwords and isn't a secret itself."""
    k = key.lower()
    return any(k.endswith(suffix) for suffix in FORBIDDEN_KEY_PATTERNS)


def load_properties(path):
    """Parse a Java-style .properties file into a dict. Skips comments/blank lines.
    Returns {} if the file doesn't exist (caller decides whether that's fatal)."""
    props = {}
    p = Path(path)
    if not p.is_file():
        return props
    with p.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            if _is_forbidden_key(key):
                continue  # never load password-like fields, even ENC() ones
            props[key] = value.strip()
    return props


def load_env(path):
    """Parse a simple KEY=VALUE .env file. Any password-like key is dropped
    with a warning — passwords are always prompted interactively instead."""
    env = {}
    p = Path(path)
    if not p.is_file():
        return env
    with p.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if _is_forbidden_key(key):
                print(f"WARNING: ignoring '{key}' found in {path} — passwords are never read from a file.")
                continue
            env[key] = value
    return env


def merge_config(properties, env, prefix_map):
    """properties takes priority; env fills in anything still missing.
    prefix_map maps a short logical name -> properties key. The .env value
    can be given either under the logical name (e.g. LDAP_URL) or under the
    raw dotted properties-style key (e.g. hub.ldap.ldap-url) — so a whole
    hub_config.properties LDAP block can be pasted into .env verbatim."""
    merged = {}
    for logical_name, props_key in prefix_map.items():
        val = properties.get(props_key, "")
        if not val:
            val = env.get(logical_name, "")
        if not val and props_key:
            val = env.get(props_key, "")  # allow raw dotted key pasted directly into .env
        merged[logical_name] = val
    return merged


def prompt_if_missing(value, label):
    """Interactively ask for a config value if it wasn't found in any file."""
    if value:
        return value
    return input(f"{label} (not found in config — enter manually): ").strip()


if _CONTROLM_ENV:
    DEFAULT_TEMPLATE_PATH = str(Path(_CONTROLM_ENV) / "cm" / "AFT" / "data" / "templates" / "user_onboarding_template.ftl")
    # Live hub path — show it in full, it's meaningful as-is.
    DISPLAY_TEMPLATE_PATH = DEFAULT_TEMPLATE_PATH
else:
    # No CONTROLM env var on this host (likely not the hub) — fall back to
    # the portable copy shipped alongside this script.
    DEFAULT_TEMPLATE_PATH = str(_SCRIPT_DIR / "data" / "user_onboarding_template.ftl")
    # Display only — the ACTUAL default above stays absolute so it still
    # resolves correctly no matter what directory the script is run from.
    # Showing "./data/..." here is cosmetic; Enter always uses the real
    # absolute path, not this string.
    DISPLAY_TEMPLATE_PATH = "./data/user_onboarding_template.ftl"

PLACEHOLDER_PATTERN = re.compile(r"\$\{(\w+)\}")


def load_template(path):
    """Read a .ftl template as raw text. Returns None if not found (caller decides)."""
    p = Path(path)
    if not p.is_file():
        return None
    return p.read_text(encoding="utf-8", errors="replace")


def find_placeholders(template_str):
    """Return the sorted set of ${...} placeholder names in the template."""
    return sorted(set(PLACEHOLDER_PATTERN.findall(template_str)))


def render_template(template_str, values):
    """Substitute ${name} placeholders. Uses safe_substitute so any name we
    didn't get a value for is left as literal text rather than raising —
    the caller is expected to check for leftovers before sending."""
    return Template(template_str).safe_substitute(values)


def find_unfilled_placeholders(rendered_str):
    """After rendering, detect any ${...} still present (i.e. we had no value for it)."""
    return sorted(set(PLACEHOLDER_PATTERN.findall(rendered_str)))


LDAP_PREFIX_MAP = {
    "LDAP_SEARCH_USER": "hub.ldap.search-user",
    "LDAP_URL": "hub.ldap.ldap-url",
    "LDAP_BASE_DN": "hub.ldap.base-dn",
    "LDAP_GROUP_SEARCH_BASE_DN": "hub.ldap.group-search-base-dn",
    "LDAP_USERNAME_ATTR": "hub.ldap.username-attribute-name",
    "LDAP_DN_ATTR": "hub.ldap.dn-attribute-name",
    "LDAP_TIMEOUT": "hub.ldap.timeout",
}

# Directory schema attribute-name mappings (not connection parameters) —
# used to validate that each configured attribute name is a real attribute
# type defined in the LDAP server's schema. Blank values in the properties
# file are skipped, not treated as errors.
#
# Each entry is (logical .env name, hub_config.properties key). The
# logical name is bash-safe (no dots/hyphens) so it can be sourced from
# the same shared config/.env that mfte.sh reads on the hub — see
# privacy-guard/src/config/sample.env. The dotted properties-style key is
# still checked as a fallback, so a whole LDAP block pasted verbatim from
# hub_config.properties keeps working unchanged.
LDAP_ATTR_MAP = {
    "password-attribute-name": ("LDAP_ATTR_PASSWORD", "hub.ldap.password-attribute-name"),
    "first-name-attribute-name": ("LDAP_ATTR_FIRST_NAME", "hub.ldap.first-name-attribute-name"),
    "last-name-attribute-name": ("LDAP_ATTR_LAST_NAME", "hub.ldap.last-name-attribute-name"),
    "company-name-attribute-name": ("LDAP_ATTR_COMPANY_NAME", "hub.ldap.company-name-attribute-name"),
    "email-attribute-name": ("LDAP_ATTR_EMAIL", "hub.ldap.email-attribute-name"),
    "phone-attribute-name": ("LDAP_ATTR_PHONE", "hub.ldap.phone-attribute-name"),
    "group-name-attribute-name": ("LDAP_ATTR_GROUP_NAME", "hub.ldap.group-name-attribute-name"),
    "member-attribute-name": ("LDAP_ATTR_MEMBER", "hub.ldap.member-attribute-name"),
    "member-of-attribute-name": ("LDAP_ATTR_MEMBER_OF", "hub.ldap.member-of-attribute-name"),
    "description-attribute-name": ("LDAP_ATTR_DESCRIPTION", "hub.ldap.description-attribute-name"),
    "ssh-public-key-attribute-name": ("LDAP_ATTR_SSH_PUBLIC_KEY", "hub.ldap.ssh-public-key-attribute-name"),
    "as2-id-attribute-name": ("LDAP_ATTR_AS2_ID", "hub.ldap.as2-id-attribute-name"),
    "as2-certificate-alias-attribute-name": ("LDAP_ATTR_AS2_CERT_ALIAS", "hub.ldap.as2-certificate-alias-attribute-name"),
    "as2-target-folder-attribute-name": ("LDAP_ATTR_AS2_TARGET_FOLDER", "hub.ldap.as2-target-folder-attribute-name"),
}

SMTP_PREFIX_MAP = {
    "SMTP_HOST": "spring.mail.host",
    "SMTP_PORT": "spring.mail.port",
    "SMTP_USERNAME": "spring.mail.username",
    "SMTP_STARTTLS_ENABLE": "spring.mail.properties.mail.smtp.starttls.enable",
    "SMTP_STARTTLS_REQUIRED": "spring.mail.properties.mail.smtp.starttls.required",
    "SMTP_CONNECTION_TIMEOUT": "spring.mail.properties.mail.smtp.connectiontimeout",
    "SMTP_SENDER": "b2b.company.mail.address",
    "SMTP_COMPANY_NAME": "b2b.company.name",
    "SMTP_PROXY_DOMAIN": "b2b.hub.proxy.domain.name",
    # Not present in hub_config.properties — .env only. props_key of ""
    # means merge_config will never find it there and always falls through
    # to the .env value (or blank, if not set there either).
    "SMTP_TEST_RECIPIENT": "",
}


def get_ldap_config(properties, env):
    cfg = merge_config(properties, env, LDAP_PREFIX_MAP)

    # Attribute-name mappings. Check properties first, then the logical
    # bash-safe .env name (e.g. LDAP_ATTR_PASSWORD), then finally the raw
    # dotted key pasted directly into .env (e.g.
    # hub.ldap.password-attribute-name=userPassword) — so either the
    # shared config/.env or a block copied verbatim from
    # hub_config.properties works.
    attr_map = {}
    for label, (logical_name, props_key) in LDAP_ATTR_MAP.items():
        val = properties.get(props_key, "").strip()
        if not val:
            val = env.get(logical_name, "").strip()
        if not val:
            val = env.get(props_key, "").strip()
        if val:
            attr_map[label] = val

    return {
        "search_user": prompt_if_missing(cfg["LDAP_SEARCH_USER"], "LDAP search/bind user (e.g. CN=...,DC=...)"),
        "url": prompt_if_missing(cfg["LDAP_URL"], "LDAP server URL (e.g. ldaps://host:636)"),
        "base_dn": prompt_if_missing(cfg["LDAP_BASE_DN"], "LDAP base DN"),
        "group_search_base_dn": cfg["LDAP_GROUP_SEARCH_BASE_DN"],
        "username_attr": cfg["LDAP_USERNAME_ATTR"] or "sAMAccountName",
        "dn_attr": cfg["LDAP_DN_ATTR"] or "distinguishedName",
        "timeout": cfg["LDAP_TIMEOUT"] or "10",
        "attr_map": attr_map,
    }


def get_smtp_config(properties, env):
    cfg = merge_config(properties, env, SMTP_PREFIX_MAP)
    proxy_domain = cfg["SMTP_PROXY_DOMAIN"]
    file_exchange_url = ""
    if proxy_domain:
        file_exchange_url = proxy_domain if proxy_domain.startswith(("http://", "https://")) else f"https://{proxy_domain}"
    return {
        "host": prompt_if_missing(cfg["SMTP_HOST"], "SMTP host"),
        "port": cfg["SMTP_PORT"] or "587",
        "username": prompt_if_missing(cfg["SMTP_USERNAME"], "SMTP username"),
        "starttls_enable": cfg["SMTP_STARTTLS_ENABLE"] or "true",
        "starttls_required": cfg["SMTP_STARTTLS_REQUIRED"] or "true",
        "connection_timeout": cfg["SMTP_CONNECTION_TIMEOUT"] or "30000",
        "sender": cfg["SMTP_SENDER"],
        "company_name": cfg["SMTP_COMPANY_NAME"],
        "file_exchange_url": file_exchange_url,
        "test_recipient": cfg["SMTP_TEST_RECIPIENT"],
    }


def print_section(title):
    print("\n" + "=" * 60)
    print(title)
    print("=" * 60)


def confirm(prompt, default_yes=True):
    suffix = " [Y/n]: " if default_yes else " [y/N]: "
    ans = input(prompt + suffix).strip().lower()
    if not ans:
        return default_yes
    return ans in ("y", "yes")


def run_ldap_test(cfg):
    print_section("LDAP / LDAPS Test")
    print(f"Search user (bind account) : {cfg['search_user']}")
    print(f"Server URL                 : {cfg['url']}")
    print(f"Base DN                    : {cfg['base_dn']}")
    print(f"Group search base DN       : {cfg['group_search_base_dn'] or '(not set)'}")
    print(f"Username attribute         : {cfg['username_attr']}")
    print(f"DN attribute               : {cfg['dn_attr']}")
    print(f"Timeout                    : {cfg['timeout']}s")

    if not cfg["url"] or not cfg["search_user"]:
        print("Incomplete LDAP config (missing url or search-user) — skipping test.")
        return

    password = getpass.getpass(f"Enter LDAP bind password for {cfg['search_user']}: ")
    if not password:
        print("No password entered — skipping LDAP test.")
        return

    use_ssl = cfg["url"].strip().lower().startswith("ldaps://")
    try:
        server = ldap3.Server(cfg["url"], use_ssl=use_ssl, get_info=ldap3.ALL, connect_timeout=int(float(cfg["timeout"]) or 10))
    except Exception:
        server = ldap3.Server(cfg["url"], use_ssl=use_ssl, get_info=ldap3.ALL)

    try:
        conn = ldap3.Connection(
            server,
            user=cfg["search_user"],
            password=password,
            auto_bind=True,
        )
        # Don't just infer success from "no exception raised" — check the
        # actual bind result the server returned.
        if conn.bound:
            result_desc = conn.result.get("description", "success") if conn.result else "success"
            print(f"LOGIN: SUCCESS — bound as {cfg['search_user']} ({result_desc})")
        else:
            result_desc = conn.result.get("description", "unknown reason") if conn.result else "unknown reason"
            print(f"LOGIN: FAILED — {result_desc}")
            return

        if cfg["base_dn"]:
            search_filter = f"({cfg['username_attr']}=*)"
            conn.search(
                search_base=cfg["base_dn"],
                search_filter=search_filter,
                search_scope=ldap3.SUBTREE,
                attributes=[cfg["username_attr"]],
                size_limit=5,
            )
            print(f"SEARCH OK: {len(conn.entries)} entries returned under {cfg['base_dn']} (limited to 5)")
            for entry in conn.entries:
                print(f"  - {entry.entry_dn}")

        _validate_attribute_schema(server, cfg)

        conn.unbind()
        print("LDAP test PASSED.")
    except LDAPException as e:
        print(f"LDAP test FAILED: {e}")
    except Exception as e:
        print(f"LDAP test FAILED (unexpected error): {e}")


# Attribute names that are commonly "operational"/constructed in Active
# Directory (e.g. memberOf is computed, not a stored forward attribute) —
# some directory servers omit these from the schema returned over LDAP even
# though the attribute is perfectly real and usable. Flag these differently
# rather than reporting a flat FAIL.
_KNOWN_OPERATIONAL_ATTRS = {"memberof"}


def _validate_attribute_schema(server, cfg):
    """Check every configured attribute name against the server's actual
    schema (fetched during the bind via get_info=ALL). This validates that
    hub_config.properties' attribute-name mappings point at real attribute
    types — a successful bind alone does NOT verify this."""
    print_section("LDAP Attribute Schema Validation")

    schema = getattr(server, "schema", None)
    if schema is None or not getattr(schema, "attribute_types", None):
        print("Server did not return schema information (subschema may be restricted) — cannot validate attribute names.")
        return

    known_types = schema.attribute_types  # case-insensitive dict-like

    # Include the connection-level attribute names too, not just the
    # provisioning schema map — they're attribute names either way.
    to_check = dict(cfg.get("attr_map", {}))
    to_check["username-attribute-name"] = cfg["username_attr"]
    to_check["dn-attribute-name"] = cfg["dn_attr"]

    results = {"valid": [], "not_found": [], "operational": []}
    for label, attr_name in sorted(to_check.items()):
        if not attr_name:
            continue
        if attr_name in known_types:
            results["valid"].append((label, attr_name))
        elif attr_name.lower() in _KNOWN_OPERATIONAL_ATTRS:
            results["operational"].append((label, attr_name))
        else:
            results["not_found"].append((label, attr_name))

    for label, attr_name in results["valid"]:
        print(f"  VALID       {label:38s} = {attr_name}")
    for label, attr_name in results["operational"]:
        print(f"  OPERATIONAL {label:38s} = {attr_name}  (constructed attribute — may be real even though absent from schema)")
    for label, attr_name in results["not_found"]:
        print(f"  NOT FOUND   {label:38s} = {attr_name}  (no matching attributeType in server schema)")

    if results["not_found"]:
        print(f"\n{len(results['not_found'])} attribute name(s) did not match any schema attributeType — double-check these against your AD/LDAP schema.")
    else:
        print("\nAll configured attribute names matched a real schema attributeType.")


def _smtp_connect_and_login(cfg, password):
    """Open and authenticate an SMTP connection per the loaded config. Caller
    is responsible for calling .quit() or using it as a context manager."""
    try:
        timeout_s = max(1, int(float(cfg["connection_timeout"])) // 1000)
    except Exception:
        timeout_s = 30
    port = int(cfg["port"] or 587)
    smtp = smtplib.SMTP(cfg["host"], port, timeout=timeout_s)
    smtp.ehlo()
    if str(cfg["starttls_enable"]).lower() == "true":
        smtp.starttls()
        smtp.ehlo()
    smtp.login(cfg["username"], password)
    return smtp


def run_smtp_test(cfg):
    print_section("SMTP Test")
    print(f"Host        : {cfg['host']}")
    print(f"Port        : {cfg['port']}")
    print(f"Username    : {cfg['username']}")
    print(f"STARTTLS    : enable={cfg['starttls_enable']} required={cfg['starttls_required']}")

    if not cfg["host"] or not cfg["username"]:
        print("Incomplete SMTP config (missing host or username) — skipping test.")
        return

    password = getpass.getpass(f"Enter SMTP password for {cfg['username']}: ")
    if not password:
        print("No password entered — skipping SMTP test.")
        return

    default_from = cfg["sender"] or cfg["username"]
    default_recipient = cfg.get("test_recipient", "")
    if default_recipient:
        to_addr = input(f"Send test message to [{default_recipient}]: ").strip() or default_recipient
    else:
        to_addr = input("Send test message to (recipient email): ").strip()
    if not to_addr:
        print("No recipient entered — skipping SMTP test.")
        return
    from_addr = input(f"From address [{default_from}]: ").strip() or default_from

    msg = _build_template_message(cfg, from_addr, to_addr)
    if msg is None:
        return  # user aborted, or an unrecognized placeholder was left unresolved

    try:
        smtp = _smtp_connect_and_login(cfg, password)
        try:
            smtp.sendmail(from_addr, [to_addr], msg.as_string())
        finally:
            smtp.quit()
        print(f"SMTP test PASSED: message sent to {to_addr}.")
    except smtplib.SMTPException as e:
        print(f"SMTP test FAILED: {e}")
    except Exception as e:
        print(f"SMTP test FAILED (unexpected error): {e}")


def _build_template_message(cfg, from_addr, to_addr):
    if _CONTROLM_ENV:
        print(f"CONTROLM env var found ({_CONTROLM_ENV}) — defaulting to the live hub template.")
    else:
        print("CONTROLM env var not set on this host — defaulting to the bundled portable copy in data/.")
    template_path = input(f"Template path [{DISPLAY_TEMPLATE_PATH}]: ").strip() or DEFAULT_TEMPLATE_PATH
    template_str = load_template(template_path)
    if template_str is None:
        print(f"Template not found at: {template_path}")
        return None

    placeholders = find_placeholders(template_str)
    if not placeholders:
        print("No ${...} placeholders found in this template — sending as-is.")
        values = {}
    else:
        print(f"\nTemplate placeholders found: {', '.join(placeholders)}")

        # Fields sourced from hub_config.properties / .env — auto-filled,
        # never prompted for individually.
        KNOWN_CONFIG_FIELDS = {
            "FileExchangeURL": cfg.get("file_exchange_url", ""),
            "b2bCompanyMailAddress": cfg.get("sender", ""),
            "b2bCompanyName": cfg.get("company_name", ""),
        }
        # Fields that would otherwise look like real onboarding data — fixed
        # to a test marker, never prompted, since this path is connectivity
        # testing only and must never resemble a real credential email.
        TEST_ONLY_FIELDS = {"userName", "password", "temporaryPasswordPeriod"}

        values = {}
        for name in placeholders:
            if name in TEST_ONLY_FIELDS:
                values[name] = "TEST Only"
            elif name in KNOWN_CONFIG_FIELDS:
                values[name] = KNOWN_CONFIG_FIELDS[name]
            # else: leave unassigned — surfaces as a literal ${name} below,
            # which triggers the unresolved-placeholder warning/confirm.
            # This only fires for placeholders neither this script nor your
            # config knows about (e.g. the template gains a new field).

        auto_filled = {k: v for k, v in values.items() if k in KNOWN_CONFIG_FIELDS or k in TEST_ONLY_FIELDS}
        print("Auto-filled from config (no prompts):")
        for name, val in auto_filled.items():
            shown = val if val else "(blank — not set in hub_config.properties or .env)"
            print(f"  {name}: {shown}")

    rendered = render_template(template_str, values)
    leftover = find_unfilled_placeholders(rendered)
    if leftover:
        print(f"\nWARNING: these placeholders were left blank and remain literally in the email: {', '.join(leftover)}")
        if not confirm("Send anyway with unresolved placeholders visible in the email?", default_yes=False):
            print("Aborted — not sending.")
            return None

    subject = input("Subject [File Exchange Access - Connection Test]: ").strip() or "File Exchange Access - Connection Test"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = to_addr
    # Plain-text fallback for clients that can't render HTML
    text_fallback = "This email requires an HTML-capable mail client to view correctly."
    msg.attach(MIMEText(text_fallback, "plain", "utf-8"))
    msg.attach(MIMEText(rendered, "html", "utf-8"))
    return msg


def main():
    parser = argparse.ArgumentParser(description="Interactive LDAP/LDAPS and SMTP test tool for MFTE hub/non-hub hosts.")
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    parser.add_argument(
        "-f", "--file",
        default=DEFAULT_PROPS_PATH,
        help=f"Path to hub_config.properties, if present (default: {DEFAULT_PROPS_PATH})",
    )
    parser.add_argument(
        "-e", "--env-file",
        default=DEFAULT_ENV_PATH,
        help=f"Path to .env file with non-secret overrides/fallbacks (default: config/.env, relative to this script's location)",
    )
    args = parser.parse_args()

    properties = load_properties(args.file)
    env = load_env(args.env_file)

    print_section(f"MFTE LDAP/SMTP Connection Test Tool v{__version__}")
    print_section("Configuration Sources")
    if properties:
        print(f"hub_config.properties: found at {args.file}")
    else:
        print(f"hub_config.properties: not found at {args.file} (fine — running off .env / prompts)")
    if env:
        print(f".env: found at {args.env_file}")
    else:
        print(f".env: not found at {args.env_file} (fine — will prompt for anything missing)")
    print("\nPasswords are NEVER read from either file, even if present — you will always be")
    print("prompted directly for LDAP bind and SMTP passwords, and they are not written anywhere.")

    if confirm("\nRun LDAP/LDAPS bind + search test?"):
        ldap_cfg = get_ldap_config(properties, env)
        run_ldap_test(ldap_cfg)

    if confirm("\nRun SMTP send test?"):
        smtp_cfg = get_smtp_config(properties, env)
        run_smtp_test(smtp_cfg)

    print("\nDone.")


if __name__ == "__main__":
    main()
