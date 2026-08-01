# Function Reference — `werkstatt.ldap.smtp.test.py`

This document describes every function in `src/werkstatt.ldap.smtp.test.py`: what it
does, its parameters, its return value, and any side effects. It's aimed at
someone maintaining or extending the script — for usage instructions, see
the top-level `README.md` instead.

Functions are listed in the order they appear in the file.

---

## Bootstrap / module-level setup

Before any function runs, the module:

1. Computes `_SCRIPT_DIR` (the script's own directory via `Path(__file__).resolve().parent`) and `_VENDOR_DIR` (`_SCRIPT_DIR / "vendor"`).
2. If `vendor/` exists next to the script, prepends it to `sys.path` — so the bundled pure-Python `ldap3`/`pyasn1` are found before (or instead of) any system install.
3. Imports `ldap3`. If that fails, prints a diagnostic pointing at `_VENDOR_DIR` and exits with status 1.
4. Resolves `_CONTROLM_ENV` (`os.environ.get("CONTROLM", "").strip()`) and, based on whether it's set, computes `DEFAULT_PROPS_PATH`, `DEFAULT_TEMPLATE_PATH`, and `DISPLAY_TEMPLATE_PATH` (see `_build_template_message` below).

Key module-level constants:

| Name | Purpose |
|---|---|
| `DEFAULT_PROPS_PATH` | If `$CONTROLM` is set: `$CONTROLM/cm/AFT/data/hub_config.properties` (the live hub path). Otherwise: `"hub_config.properties"`, looked for in the current working directory (e.g. a copy placed next to the script on a non-hub host). |
| `DEFAULT_ENV_PATH` | `config/.env`, resolved **relative to the script**, not the caller's cwd |
| `FORBIDDEN_KEY_PATTERNS` | Suffixes (`password`, `passwd`, `secret`, `pwd`) that mark a config key as holding a secret |
| `LDAP_PREFIX_MAP` | Logical name → `hub.ldap.*` properties key, for connection parameters |
| `LDAP_ATTR_MAP` | Label → `hub.ldap.*-attribute-name` properties key, for schema validation |
| `SMTP_PREFIX_MAP` | Logical name → `spring.mail.*` / `b2b.*` properties key |
| `_KNOWN_OPERATIONAL_ATTRS` | `{"memberof"}` — attributes known to sometimes be absent from schema despite being real |
| `PLACEHOLDER_PATTERN` | Compiled regex `\$\{(\w+)\}`, matches `${name}`-style template placeholders |

---

## Config loading

### `_is_forbidden_key(key)`
**Params:** `key: str`
**Returns:** `bool`

True only if `key` (case-insensitive) **ends with** one of `FORBIDDEN_KEY_PATTERNS`. This is deliberately a suffix check, not a substring check — `hub.ldap.search-password` matches (ends in `password`), but `hub.ldap.password-attribute-name` does not (ends in `name`). The earlier substring-based version incorrectly flagged the latter; keep this suffix-only if you touch it again.

### `load_properties(path)`
**Params:** `path: str | Path`
**Returns:** `dict[str, str]`

Parses a Java-style `.properties` file (`key=value` per line, `#`-comments, blank lines skipped). Returns `{}` if the file doesn't exist — callers decide whether that's fatal, this function never raises or exits for a missing file. Any key matching `_is_forbidden_key` is silently dropped (no warning printed here, unlike `load_env`).

### `load_env(path)`
**Params:** `path: str | Path`
**Returns:** `dict[str, str]`

Same `KEY=VALUE` parsing as `load_properties`, plus:
- Strips surrounding `"` or `'` quotes from values.
- Prints a `WARNING:` line and drops the key if it matches `_is_forbidden_key` (unlike `load_properties`, this one is user-facing so it warns).
- Returns `{}` if the file doesn't exist.

No support for multi-line values, escaped `=` in keys, or `export KEY=value` syntax.

### `merge_config(properties, env, prefix_map)`
**Params:**
- `properties: dict` — from `load_properties`
- `env: dict` — from `load_env`
- `prefix_map: dict[str, str]` — logical name → properties dotted key

**Returns:** `dict[str, str]` keyed by the logical names in `prefix_map`

Resolution order per key, first non-empty wins:
1. `properties[props_key]`
2. `env[logical_name]` (e.g. `LDAP_URL`)
3. `env[props_key]` (e.g. `hub.ldap.ldap-url`) — this is what lets an admin paste `hub_config.properties` lines directly into `.env` without renaming anything

### `prompt_if_missing(value, label)`
**Params:** `value: str`, `label: str`
**Returns:** `str`

If `value` is truthy, returns it unchanged. Otherwise calls `input()` with a message built from `label` and returns the stripped response. Used for the handful of fields considered essential enough to demand interactively if config didn't supply them (LDAP search user, URL, base DN; SMTP host, username).

---

## Template handling

### `load_template(path)`
**Params:** `path: str | Path`
**Returns:** `str | None`

Reads the `.ftl` template file as UTF-8 text (`errors="replace"` for any bad bytes). Returns `None` if the file doesn't exist — caller must check for this.

### `find_placeholders(template_str)`
**Params:** `template_str: str`
**Returns:** `list[str]` (sorted, deduplicated)

Runs `PLACEHOLDER_PATTERN.findall()` to extract every `${name}` placeholder's inner name.

### `render_template(template_str, values)`
**Params:** `template_str: str`, `values: dict[str, str]`
**Returns:** `str`

Wraps `string.Template(template_str).safe_substitute(values)`. Uses `safe_substitute` (not `substitute`) deliberately — any placeholder not present in `values` is left as literal `${name}` text rather than raising `KeyError`. Callers are expected to check the result with `find_unfilled_placeholders` afterward.

### `find_unfilled_placeholders(rendered_str)`
**Params:** `rendered_str: str`
**Returns:** `list[str]` (sorted, deduplicated)

Same regex as `find_placeholders`, but run on the *rendered* output. A non-empty result means some placeholder had no value supplied — this is the safety net that stops a literal `${b2bCompanyName}` from silently reaching a sent email.

---

## Config assembly

### `get_ldap_config(properties, env)`
**Params:** `properties: dict`, `env: dict`
**Returns:** `dict` with keys: `search_user`, `url`, `base_dn`, `group_search_base_dn`, `username_attr`, `dn_attr`, `timeout`, `attr_map`

Calls `merge_config` with `LDAP_PREFIX_MAP` for the connection parameters (prompting via `prompt_if_missing` for `search_user`, `url`, `base_dn` if still empty). Separately builds `attr_map`: for each entry in `LDAP_ATTR_MAP`, checks `properties` first, then falls back to `env` **using the raw dotted key** (not a logical name — there isn't one defined for these fields). Blank/missing attribute values are omitted from `attr_map` entirely rather than stored as empty strings.

`username_attr` and `dn_attr` default to `"sAMAccountName"` / `"distinguishedName"` if not configured anywhere. `timeout` defaults to `"10"` — note this only applies if the key is *missing*; a key present but set to an empty string stays empty (see README "Known limitations").

### `get_smtp_config(properties, env)`
**Params:** `properties: dict`, `env: dict`
**Returns:** `dict` with keys: `host`, `port`, `username`, `starttls_enable`, `starttls_required`, `connection_timeout`, `sender`, `company_name`, `file_exchange_url`, `test_recipient`

Calls `merge_config` with `SMTP_PREFIX_MAP`. Builds `file_exchange_url` from the `SMTP_PROXY_DOMAIN` value (`b2b.hub.proxy.domain.name`): if the value already starts with `http://` or `https://` it's used as-is, otherwise `https://` is prepended. `test_recipient` comes from `SMTP_TEST_RECIPIENT`, which has an empty `props_key` in `SMTP_PREFIX_MAP` (it's script-only, not a real `hub_config.properties` field) — so it can only ever come from `.env`.

---

## Console helpers

### `print_section(title)`
**Params:** `title: str`
**Returns:** `None`

Prints a blank line, a 60-character `=` divider, the title, and another divider. Purely cosmetic, used to separate the LDAP test, SMTP test, and schema validation sections in the console output.

### `confirm(prompt, default_yes=True)`
**Params:** `prompt: str`, `default_yes: bool = True`
**Returns:** `bool`

Appends `" [Y/n]: "` or `" [y/N]: "` to `prompt` depending on `default_yes`, calls `input()`, and returns `default_yes` if the response is empty, otherwise `True` iff the response (lowercased) is `"y"` or `"yes"`.

---

## LDAP test

### `run_ldap_test(cfg)`
**Params:** `cfg: dict` — the return value of `get_ldap_config`
**Returns:** `None` (prints results; nothing structured is returned)

1. Prints the connection details (bind account, URL, base DN, group search base DN, username/DN attributes, timeout).
2. If `url` or `search_user` is empty, prints a message and returns early — no test attempted.
3. Prompts for the bind password via `getpass.getpass`. Empty input aborts the test.
4. Builds an `ldap3.Server`, using SSL if the URL starts with `ldaps://`, requesting full schema info (`get_info=ldap3.ALL` — this is what makes schema validation possible later). Timeout is taken from `cfg["timeout"]`, falling back to a plain `Server(...)` call without an explicit timeout if that value can't be parsed as a number.
5. Opens an `ldap3.Connection` with `auto_bind=True`, which performs a real LDAP simple bind (this **is** the authentication step — LDAP has no separate "check password" call).
6. Checks `conn.bound` explicitly (not just the absence of an exception) and prints an unambiguous `LOGIN: SUCCESS` or `LOGIN: FAILED` line, using `conn.result["description"]` for the server's own explanation.
7. If `base_dn` is set, runs a search (`(username_attr=*)`, `size_limit=5`) and prints how many entries matched plus their DNs.
8. Calls `_validate_attribute_schema(server, cfg)` (see below).
9. Unbinds and prints `LDAP test PASSED.`

Exceptions: `ldap3`'s `LDAPException` subclasses are caught and printed as `LDAP test FAILED: {e}`; anything else is caught separately as `LDAP test FAILED (unexpected error): {e}`. Both mean the function returns without raising — callers never need to wrap this in their own try/except.

### `_validate_attribute_schema(server, cfg)`
**Params:** `server: ldap3.Server` (post-bind, with schema populated), `cfg: dict`
**Returns:** `None` (prints results)

Checks every attribute name the hub is configured to use against the server's actual LDAP schema, since a successful bind only proves the *credentials* work — it says nothing about whether the *attribute-name mappings* point at real schema attributes.

1. If `server.schema` or `server.schema.attribute_types` is empty (some directories restrict subschema read access), prints a message and returns — this can't be worked around client-side.
2. Builds `to_check`: a copy of `cfg["attr_map"]` (the provisioning fields — password, first/last name, company, email, phone, group/member attributes, SSH key) plus `username_attr` and `dn_attr` from the connection config.
3. For each non-empty attribute name, checks membership in `server.schema.attribute_types` (an `ldap3` case-insensitive dict, so `sAMAccountName` and `samaccountname` match identically). Buckets the result as:
   - `valid` — found in the schema
   - `operational` — not found, but the name (lowercased) is in `_KNOWN_OPERATIONAL_ATTRS` (currently just `memberof`) — some directories omit constructed/computed attributes from the schema they return even though the attribute is real
   - `not_found` — not found and not a known operational exception
4. Prints each bucket, then a one-line summary.

If you add new operational attribute exceptions later, extend `_KNOWN_OPERATIONAL_ATTRS` rather than special-casing them inline.

---

## SMTP test

### `_smtp_connect_and_login(cfg, password)`
**Params:** `cfg: dict` — from `get_smtp_config`, `password: str`
**Returns:** `smtplib.SMTP` (already connected and authenticated)

Computes a timeout in seconds from `cfg["connection_timeout"]` (stored in milliseconds, per the source properties file), defaulting to 30s if that can't be parsed. Opens the SMTP connection, sends `EHLO`, calls `STARTTLS` + re-`EHLO` if `starttls_enable` is `"true"`, then logs in. Does **not** close the connection — callers are responsible for calling `.quit()` (or wrapping in a context manager) once done.

### `run_smtp_test(cfg)`
**Params:** `cfg: dict` — the return value of `get_smtp_config`
**Returns:** `None`

1. Prints host/port/username/STARTTLS settings.
2. If `host` or `username` is empty, prints a message and returns early.
3. Prompts for the SMTP password via `getpass.getpass`. Empty input aborts.
4. Resolves the recipient: if `cfg["test_recipient"]` is set, shows it as a default (Enter accepts); otherwise requires typing an address. Empty result aborts.
5. Resolves the from-address similarly, defaulting to `cfg["sender"]` or `cfg["username"]`.
6. Calls `_build_template_message(cfg, from_addr, to_addr)` to construct the actual email. If that returns `None` (template not found, or the admin declined to send with unresolved placeholders), returns without sending.
7. Connects via `_smtp_connect_and_login`, sends the message, always calls `.quit()` in a `finally` block, and prints `SMTP test PASSED` or a failure message.

### `_build_template_message(cfg, from_addr, to_addr)`
**Params:** `cfg: dict`, `from_addr: str`, `to_addr: str`
**Returns:** `email.mime.multipart.MIMEMultipart | None`

1. Prints which template source is in play (`CONTROLM` env var found → live hub path; not found → bundled `data/` copy) and prompts for the template path, defaulting to `DEFAULT_TEMPLATE_PATH` (the real absolute path — the shorter `DISPLAY_TEMPLATE_PATH` string like `./data/user_onboarding_template.ftl` is what's *shown*, but pressing Enter still resolves to the correct absolute path regardless of the caller's current directory).
2. Loads the template via `load_template`. Returns `None` if not found.
3. Finds placeholders via `find_placeholders`. If none, sends the template as-is.
4. Otherwise, assigns a value to each placeholder with **no per-field prompting**:
   - `FileExchangeURL`, `b2bCompanyMailAddress`, `b2bCompanyName` are filled from `cfg` (`file_exchange_url`, `sender`, `company_name` respectively) — even if blank, so a missing config value shows up as an empty field rather than a prompt.
   - `userName`, `password`, `temporaryPasswordPeriod` are hardcoded to `"TEST Only"` — this is deliberate: this send path is for connectivity testing, and these fields must never contain anything resembling a real credential.
   - Any other placeholder name is left unassigned. This is intentional: it surfaces as a literal `${name}` in the next step, which is the only way an unrecognized/future template field gets caught rather than silently sent blank.
5. Prints an "Auto-filled from config (no prompts)" summary of every field from step 4 above (including the ones that came out blank), so the admin can see what actually shipped without being asked.
6. Renders via `render_template`, checks for leftovers via `find_unfilled_placeholders`. If any remain, prints a warning and calls `confirm(..., default_yes=False)` — sending only proceeds if the admin explicitly opts in despite the unresolved fields.
7. Prompts for subject (default: `"File Exchange Access - Connection Test"`).
8. Builds a `MIMEMultipart("alternative")` with a plain-text fallback part (a one-line "requires HTML" notice) and the rendered HTML as the second part, and returns it.

---

## Entry point

### `main()`
**Params:** none
**Returns:** `None`

1. Parses CLI args: `-f/--file` (properties path, default `DEFAULT_PROPS_PATH`) and `-e/--env-file` (`.env` path, default `DEFAULT_ENV_PATH`, resolved relative to the script).
2. Loads both files via `load_properties` / `load_env`, printing which were found.
3. Prints a reminder that passwords are never read from either file.
4. If `confirm("Run LDAP/LDAPS bind + search test?")`, builds LDAP config via `get_ldap_config` and calls `run_ldap_test`.
5. If `confirm("Run SMTP send test?")`, builds SMTP config via `get_smtp_config` and calls `run_smtp_test`.
6. Prints `"Done."`

Guarded by `if __name__ == "__main__":` at the bottom of the file.

---

## Notes for future changes

- **Adding a new LDAP connection field**: add to `LDAP_PREFIX_MAP`, then read it out of the `merge_config` result in `get_ldap_config`.
- **Adding a new attribute-schema field to validate**: add to `LDAP_ATTR_MAP`; it'll automatically flow into `attr_map` and get checked by `_validate_attribute_schema` without further code changes.
- **Adding a new template placeholder that should auto-fill from config**: add it to the `KNOWN_CONFIG_FIELDS` dict inside `_build_template_message`. Anything not added here will correctly trigger the unresolved-placeholder warning instead of silently sending blank — that's the intended fallback behavior, not a bug to "fix" by adding a blanket default.
- **The forbidden-key filter is a suffix match, not substring** — if you add new secret-like field name conventions, append to `FORBIDDEN_KEY_PATTERNS` rather than changing the matching logic back to substring (that was tried once and incorrectly ate `password-attribute-name`).