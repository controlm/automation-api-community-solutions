MFTE Hub LDAP/SMTP Test Tool — Deployment Package
===================================================

CONTENTS
  werkstatt.ldap.smtp.test.py - the script
  vendor/ - bundled pure-Python dependencies (ldap3, pyasn1)
  config/sample.env - template for hosts without hub_config.properties
  data/ - portable snapshot of the HTML onboarding template
  bin/werkstatt.ldaps.cert.import.sh - fetch + trust an LDAPS server's TLS cert (RHEL)
  bin/werkstatt.smtp.cert.import.sh - same, for the SMTP/STARTTLS server
  lib/bash/werkstatt.cert.trust.common.sh - helpers shared by the two bin/*.sh scripts

REQUIREMENTS
  Any Linux host with system python3 already on PATH (python3 --version to check).
  Nothing else. No pip install, no venv, no internet access needed.
  bin/*.sh additionally need bash, openssl, and (for -i imports) sudo +
  update-ca-trust — all standard on RHEL.

DEPLOY
  1. Copy this whole folder (or the zip) to the target host.
  2. Unzip if needed: unzip werkstatt.ldap.smtp.test-vX.Y.Z.zip
  3. cd into the extracted folder — vendor/, data/, and lib/ MUST stay next
     to the scripts that use them (all paths resolve relative to the
     script's own location, not your current directory).

RUN ON THE HUB (properties file auto-detected)
  cd /opt/ctmag/ctm/cm/AFT/data
  python3 /path/to/extracted/werkstatt.ldap.smtp.test.py -f hub_config.properties

RUN ON A NON-HUB HOST
  cp config/sample.env config/.env
  # edit config/.env with the non-secret connection details
  python3 werkstatt.ldap.smtp.test.py

IF LDAP/SMTP FAILS ON A CERTIFICATE-TRUST ERROR
  bin/werkstatt.ldaps.cert.import.sh -s ldaps://<ldap-host>:636 -i -y
  bin/werkstatt.smtp.cert.import.sh -s <smtp-host>:587 -i -y
  Both auto-detect the target host from hub_config.properties/.env if -s
  is omitted, and skip re-importing a cert already trusted. Run either
  with -h for the full flag list.

NOTES
  - Passwords are NEVER read from hub_config.properties or .env, even if
    present there. You will always be prompted directly, and nothing is
    written back to disk.
  - vendor/ contains no compiled binaries — it is OS/architecture agnostic
    and safe to copy between RHEL, Ubuntu, etc., as long as python3 exists.
