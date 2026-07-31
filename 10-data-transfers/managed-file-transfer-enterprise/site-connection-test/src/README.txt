MFTE Hub LDAP/SMTP Test Tool — Deployment Package
===================================================

CONTENTS
  ldap_smtp_test.py   - the script
  vendor/              - bundled pure-Python dependencies (ldap3, pyasn1)
  .env.example          - template for hosts without hub_config.properties

REQUIREMENTS
  Any Linux host with system python3 already on PATH (python3 --version to check).
  Nothing else. No pip install, no venv, no internet access needed.

DEPLOY
  1. Copy this whole folder (or the zip) to the target host.
  2. Unzip if needed: unzip mfte_ldap_smtp_test-vX.Y.Z.zip
  3. cd into the extracted folder — the vendor/ folder MUST stay next to the script.

RUN ON THE HUB (properties file auto-detected)
  cd /opt/ctmag/ctm/cm/AFT/data
  python3 /path/to/extracted/ldap_smtp_test.py -f hub_config.properties

RUN ON A NON-HUB HOST
  cp .env.example .env
  # edit .env with the non-secret connection details
  python3 ldap_smtp_test.py

NOTES
  - Passwords are NEVER read from hub_config.properties or .env, even if
    present there. You will always be prompted directly, and nothing is
    written back to disk.
  - vendor/ contains no compiled binaries — it is OS/architecture agnostic
    and safe to copy between RHEL, Ubuntu, etc., as long as python3 exists.
