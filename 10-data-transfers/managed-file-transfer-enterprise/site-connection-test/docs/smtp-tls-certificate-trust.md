# Trusting an SMTP server's certificate on RHEL

If `werkstatt.ldap.smtp.test.py` (or anything else on the hub) fails the SMTP test
with a certificate-trust error during STARTTLS (e.g. `unable to get local
issuer certificate`, `self-signed certificate`), the fix is the same as
for LDAPS — see [ldaps-certificate-trust.md](ldaps-certificate-trust.md)
for the background. This doc covers the SMTP-specific `openssl` syntax,
since SMTP negotiates TLS in-band via `STARTTLS` rather than starting
encrypted from the first byte the way LDAPS does.

## 1. Export the certificate

From the hub (or any host that can reach the SMTP server), run:

```bash
echo | openssl s_client -connect <smtp-host>:<port> -servername <smtp-host> -starttls smtp 2>/dev/null \
  | openssl x509 -outform PEM > <smtp-host>.pem
```

Replace `<smtp-host>` and `<port>` with `spring.mail.host` and
`spring.mail.port` from `hub_config.properties` (typically port `587`,
submission with STARTTLS). If the server instead uses implicit TLS on
port `465` (no `spring.mail.properties.mail.smtp.starttls.enable`), drop
`-starttls smtp` — port 465 is TLS from the first byte, like LDAPS:

```bash
echo | openssl s_client -connect <smtp-host>:465 -servername <smtp-host> 2>/dev/null \
  | openssl x509 -outform PEM > <smtp-host>.pem
```

Verify you got a real certificate:

```bash
openssl x509 -in <smtp-host>.pem -noout -subject -issuer -dates
```

You should see `subject=`, `issuer=`, and valid `notBefore`/`notAfter`
dates. If nothing prints, the STARTTLS negotiation didn't complete —
double-check the port (STARTTLS needs `-starttls smtp` on 587; implicit
TLS on 465 must NOT have that flag) and that the port is reachable
(`nc -zv <smtp-host> <port>`).

### Getting the full chain instead of just the leaf cert

Add `-showcerts` to capture the whole chain as presented by the server
(useful if the issuing CA — e.g. an internal/AD CA — isn't already
trusted on this host):

```bash
echo | openssl s_client -connect <smtp-host>:<port> -servername <smtp-host> -starttls smtp -showcerts 2>/dev/null
```

Pull out each `-----BEGIN CERTIFICATE-----...-----END CERTIFICATE-----`
block into its own `.pem`, same as the LDAPS case.

## 2. Trust it system-wide

```bash
sudo cp <smtp-host>.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract
```

No restart needed for `werkstatt.ldap.smtp.test.py` itself — it's a fresh
`python3` process each run, and Python's `ssl`/`smtplib` reads the system
trust store (`/etc/pki/tls/certs/ca-bundle.crt`) at process start, so a
new invocation picks up the update immediately. Re-run the SMTP test to
confirm the trust error is gone.

**The Control-M hub service itself is a different story.** It's a
long-running process that loads the trust store into memory once at
startup — `update-ca-trust extract` updates the on-disk bundle, but a
Control-M service that was already running keeps using whatever it
loaded before. Confirmed in practice: importing the SMTP cert alone
wasn't enough for real Control-M-sent mail (job onboarding/notification
emails) to start working — it took a restart of the relevant Control-M
hub service (a full reboot restarts it too, which is why that worked,
but the service restart is the actual fix, not the reboot itself) before
outbound mail used the newly-trusted cert. If you hit the same thing,
try restarting just the Control-M hub service first — no need to reboot
the whole VM unless that's the only practical way to bounce it.

To remove it later, delete the file from
`/etc/pki/ca-trust/source/anchors/` and re-run
`sudo update-ca-trust extract`.

If the LDAP and SMTP servers share the same CA (common when both sit
behind the same internal PKI), you only need to trust that CA cert once
— check `openssl x509 -in <file> -noout -issuer` against the LDAPS cert
before assuming you need two separate trust entries.

## Scripted version

[`bin/werkstatt.smtp.cert.import.sh`](../src/bin/werkstatt.smtp.cert.import.sh) wraps
both steps above into one command:

```bash
# Fetch only, saved to ./<host>.pem (STARTTLS on 587 by default):
src/bin/werkstatt.smtp.cert.import.sh -s <smtp-host>:587

# Implicit TLS on 465:
src/bin/werkstatt.smtp.cert.import.sh -s <smtp-host>:465 -I

# Fetch + trust system-wide, no prompts:
src/bin/werkstatt.smtp.cert.import.sh -s <smtp-host>:587 -i -y
```

With no `-s`, it auto-detects `spring.mail.host`/`spring.mail.port` from
`hub_config.properties` (or `.env`), and switches to implicit TLS
automatically if it finds
`spring.mail.properties.mail.smtp.starttls.enable=false`. Same
idempotency check as the LDAPS script — skips re-importing a certificate
already in the trust store. Run it with `-h` for the full flag list.
