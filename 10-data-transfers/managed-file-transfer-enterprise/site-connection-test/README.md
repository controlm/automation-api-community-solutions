# MFTE Hub LDAP/SMTP Connection Test Tool

## Purpose

This is a single interactive console script, `ldap_smtp_test.py`, that
answers one operational question for an MFT Enterprise hub: **are LDAP and
SMTP actually reachable and correctly configured, right now, with these
credentials?** It performs a real LDAP/LDAPS bind + search, validates every
configured directory attribute name against the server's own schema, and
sends a real SMTP message rendered from the live HTML onboarding template —
rather than asking an admin to infer connectivity from a failed onboarding
job days later.

It reads `hub_config.properties` when run on the hub itself, or a local
`.env` (same key names, so hub lines paste in unchanged) when run from any
other host. **Passwords are never read from either file** — see
[Password handling](#password-handling) below — you're always prompted
directly, and nothing is written back to disk.

No `pip install`, no venv, no internet access required at runtime. The
`vendor/` folder bundles pure-Python `ldap3`/`pyasn1`, so the deployed
package runs with whatever system `python3` is already on the hub.

## Tested on

Any Linux (or macOS) host with a system `python3` on `PATH` — check with
`python3 --version`. `vendor/` contains no compiled extensions, so it's
OS/architecture agnostic. The LDAP schema validation was verified against
Active Directory; other LDAP servers should work for bind/search but may
report directory-specific operational attributes as `NOT FOUND` (see
[Known limitations](#known-limitations)).

## Layout

```
site-connection-test/
├── README.md              this file
├── docs/
│   └── README.md          function-by-function reference for ldap_smtp_test.py
├── package/               build_package.py's output — not committed source, rebuild via src/build_package.py
│   └── mfte_ldap_smtp_test-vX.Y.Z.zip
└── src/
    ├── README.txt          short deploy notes bundled *inside* the zip itself
    ├── build_package.py    packages everything below into package/
    ├── ldap_smtp_test.py    the script
    ├── vendor/              bundled pure-Python deps (ldap3, pyasn1) — no compiled binaries
    ├── config/
    │   └── sample.env       template for non-hub hosts (copy to config/.env, fill in)
    └── data/
        └── user_onboarding_template.ftl   portable snapshot of the HTML email template
```

## Script index

| Script | Purpose |
| --- | --- |
| [ldap_smtp_test.py](docs/README.md) | The tool itself — LDAP/LDAPS bind + search + schema validation, and an SMTP send test using the real onboarding template. Function-by-function reference in [docs/README.md](docs/README.md). |
| [build_package.py](src/build_package.py) | Zips `ldap_smtp_test.py` + `vendor/` + `config/` + `data/` + `README.md` into `package/mfte_ldap_smtp_test-v<version>.zip`, ready to copy to a hub. Standard library only — no dependencies of its own. |

## Getting started

1. Build the deployment zip (run from `src/`):

   ```bash
   cd src
   python3 build_package.py
   ```

   This writes `package/mfte_ldap_smtp_test-v<version>.zip`, where
   `<version>` is read straight out of `ldap_smtp_test.py`'s own
   `__version__` — the two always stay in sync.
2. Copy that zip to the target host and unzip it:

   ```bash
   unzip mfte_ldap_smtp_test-vX.Y.Z.zip && cd deploy
   ```

   Keep `vendor/` and `data/` next to `ldap_smtp_test.py` — they're
   resolved relative to the script's own location, not your current
   directory, so it works no matter where you `cd` from.
3. Run it.
   - **On the hub** (auto-detects `hub_config.properties` in the current
     directory, and reads the live template from
     `$CONTROLM/cm/AFT/data/templates/user_onboarding_template.ftl`):

     ```bash
     cd /opt/ctmag/ctm/cm/AFT/data
     python3 /path/to/extracted/ldap_smtp_test.py
     ```

   - **From a non-hub machine:**

     ```bash
     cp config/sample.env config/.env
     # edit config/.env with real values
     python3 ldap_smtp_test.py
     ```

     `config/.env` uses the **same key names as `hub_config.properties`**
     (`hub.ldap.search-user`, `hub.ldap.ldap-url`, `spring.mail.host`,
     `b2b.company.name`, etc.), so you can paste the relevant lines
     straight off the hub with no renaming. One field is script-only, not
     from the hub file — `SMTP_TEST_RECIPIENT=your-test-inbox@example.com`
     pre-fills the recipient prompt so a one-off test only needs Enter.
4. Check the version of what you're running at any time with
   `python3 ldap_smtp_test.py --version`.

## What the script does

### 1. LDAP / LDAPS test

- Prints the bind account and connection details (search user, server URL,
  base DN, group search base DN, username/DN attributes, timeout).
- Prompts for the bind password (never read from any file — see
  [Password handling](#password-handling) below).
- Performs a real LDAP bind (`ldap3` `auto_bind=True`) and explicitly
  checks `conn.bound` / `conn.result` rather than just inferring success
  from the absence of an exception, so you get an unambiguous:
  ```
  LOGIN: SUCCESS — bound as CN=ldap_mfte,... (success)
  ```
  or
  ```
  LOGIN: FAILED — invalidCredentials
  ```
- If a base DN is configured, runs a search and lists up to 5 matching
  entries.
- **Attribute schema validation**: checks every configured attribute name
  (`hub.ldap.*-attribute-name` fields — password, first/last name, company,
  email, phone, group/member attributes, SSH key attribute, etc.) against
  the LDAP server's actual schema (`server.schema.attribute_types`,
  fetched during the bind). Reports each as:
  - `VALID` — matches a real schema attributeType
  - `OPERATIONAL` — a known constructed/computed attribute (e.g.
    `memberOf`) that may be valid even though some directories omit it
    from the returned schema
  - `NOT FOUND` — no matching attributeType; worth double-checking against
    your AD/LDAP schema

  This validates the *attribute mappings*, not just the bind — a
  successful login does not by itself prove the configured attribute
  names are real.

### 2. SMTP test

- Prompts for the SMTP password, recipient (pre-filled from
  `SMTP_TEST_RECIPIENT` if set), and from-address.
- Renders the real HTML onboarding template
  (`user_onboarding_template.ftl`), substituting `${...}` placeholders:
  - `FileExchangeURL`, `b2bCompanyMailAddress`, `b2bCompanyName` are
    auto-filled from config with **no prompts** — printed once as an
    "Auto-filled from config" summary so you can see what shipped.
  - `userName`, `password`, `temporaryPasswordPeriod` are hardcoded to
    `"TEST Only"` — never prompted, never populated with anything that
    could resemble a real credential.
  - Any placeholder the script doesn't recognize is left unfilled, which
    triggers a warning and a confirmation prompt before sending — so a
    template change never silently ships a literal `${newField}` in a
    real email.
- Sends as a proper `multipart/alternative` MIME message (HTML part +
  plain-text fallback) via `smtplib`, using STARTTLS per the configured
  security settings.
- Subject defaults to `File Exchange Access - Connection Test`.

## Password handling

Passwords are **never read from `hub_config.properties` or `.env`**, even
if a value is present there. Both loaders actively filter out any key
*ending* in `password`, `passwd`, `secret`, or `pwd` (this is a suffix
match, not substring — a field like `hub.ldap.password-attribute-name` is
correctly kept, since that names which LDAP attribute stores passwords and
isn't a secret itself). You are always prompted directly via `getpass`,
and nothing is written back to disk.

This matters because `hub_config.properties` stores its real secrets
Jasypt-encrypted (`ENC(...)`) — this script has no way to decrypt those
even if it tried, so prompting interactively is the only viable path
anyway.

## Template path resolution

| `$CONTROLM` env var | Default template used |
|---|---|
| Set | `$CONTROLM/cm/AFT/data/templates/user_onboarding_template.ftl` (live hub copy) |
| Not set | `data/user_onboarding_template.ftl` (bundled copy next to the script) |

The script prints which source it picked before prompting, and you can
always override the path manually at the prompt.

Note: the bundled copy in `data/` is a **snapshot**. If the real template
on the hub changes, re-sync this copy manually — it isn't kept in sync
automatically.

## Known limitations

- If the LDAP server restricts subschema access, `server.schema` comes
  back empty and attribute validation is skipped with a message saying
  so — this is a directory-side permission, not something the script can
  work around.
- `hub.ldap.timeout=` blank in a real hub file stays blank if pasted into
  `.env` verbatim — the script's own `"10"` default only applies when the
  key is missing entirely, not when it's present but empty.
- This script reads `spring.mail.*` for SMTP settings, not the separate
  `hub.smtp.*` keys that also exist in some `hub_config.properties` files —
  worth confirming these don't diverge in your environment.
