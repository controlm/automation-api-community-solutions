# Trusting an LDAPS server's certificate on RHEL

If `werkstatt.ldap.smtp.test.py` (or anything else on the hub) fails an LDAPS bind
with a certificate-trust error (e.g. `unable to get local issuer
certificate`, `self-signed certificate`), the fix is to export the LDAP
server's certificate and add it to the hub's system trust store. No Java
truststore/`keytool` involved — RHEL trusts certificates system-wide via
`update-ca-trust`, and `openssl` (required by that tool anyway) is all you
need to fetch the cert.

## 1. Export the certificate

From the hub (or any host that can reach the LDAP server on its LDAPS
port), run:

```bash
echo | openssl s_client -connect <ldap-host>:636 -servername <ldap-host> 2>/dev/null \
  | openssl x509 -outform PEM > <ldap-host>.pem
```

Replace `<ldap-host>` with the hostname from `hub.ldap.ldap-url` in
`hub_config.properties` (strip the `ldaps://` prefix and port). If the
LDAPS port isn't 636, substitute the real port.

Verify you got a real certificate, not an empty file or an error page:

```bash
openssl x509 -in <ldap-host>.pem -noout -subject -issuer -dates
```

You should see a `subject=`, `issuer=`, and valid `notBefore`/`notAfter`
dates. If this prints nothing or errors, the connection didn't complete a
TLS handshake — check the hostname/port and that the LDAPS port is
actually reachable from this host (`nc -zv <ldap-host> 636`).

### Getting the full chain instead of just the leaf cert

The command above returns only the server's own (leaf) certificate. If
the issuing CA isn't already trusted on this host — e.g. an internal/AD
CA — add `-showcerts` to capture the whole chain as presented by the
server, then pull out each `-----BEGIN CERTIFICATE-----...-----END
CERTIFICATE-----` block into its own `.pem` (or trust each one
individually, next step handles either):

```bash
echo | openssl s_client -connect <ldap-host>:636 -servername <ldap-host> -showcerts 2>/dev/null
```

## 2. Trust it system-wide

```bash
sudo cp <ldap-host>.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract
```

That's it — no restart needed for `werkstatt.ldap.smtp.test.py` itself:
it's a fresh `python3` process each run, and the `ssl`/`ldap3` libraries
it uses read the system trust store at process start, so a new
invocation picks up the update immediately. Re-run the LDAPS test to
confirm the trust error is gone.

**The Control-M hub service itself is a different story** — see the
same caveat in
[smtp-tls-certificate-trust.md](smtp-tls-certificate-trust.md#2-trust-it-system-wide).
It's a long-running process that loads the trust store into memory once
at startup, so if the hub service itself does an LDAP bind (not just
this test script), a newly-trusted cert may not take effect until that
service is restarted, not just re-run.

To remove it later, delete the file from
`/etc/pki/ca-trust/source/anchors/` and re-run
`sudo update-ca-trust extract`.

## Scripted version

[`bin/werkstatt.ldaps.cert.import.sh`](../src/bin/werkstatt.ldaps.cert.import.sh) wraps both
steps above into one command, for repeatable/unattended use (e.g. a
Control-M Run Command):

```bash
# Fetch only (steps 1 above), saved to ./<host>.pem:
src/bin/werkstatt.ldaps.cert.import.sh -s ldaps://<ldap-host>:636

# Fetch + trust system-wide (steps 1 and 2), no prompts:
src/bin/werkstatt.ldaps.cert.import.sh -s ldaps://<ldap-host>:636 -i -y
```

With no `-s`, it auto-detects `hub.ldap.ldap-url` from
`hub_config.properties` (or `.env`), same as `werkstatt.ldap.smtp.test.py`. It
skips the `-i` import if a certificate with the same SHA-256 fingerprint
is already in `/etc/pki/ca-trust/source/anchors/`. Run it with `-h` for
the full flag list. It's still just `openssl` + `update-ca-trust` under
the hood — no Python, no dependency beyond what's already on any RHEL
host running `update-ca-trust` in the first place.
