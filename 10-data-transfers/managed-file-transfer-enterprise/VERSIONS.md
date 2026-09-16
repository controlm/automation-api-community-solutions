# mfte-tools release history

One row per `collect-tools.sh` release build. INSTALL-TYPE is this
repo's own convention for the X.Y.Z `SCRIPT_VERSION`: NEW is the first
ever release, PATCH is a Z-only bump, UPGRADE is an X or Y bump.

`tools/version.txt` (shipped inside the tarball itself, so `cat
tools/version.txt` on a host answers "what did I extract" without this
file) was introduced at 1.2.8 -- 1.2.4/1.2.6/1.2.7 below predate it and
don't contain one.

| VERSION | PLATFORM | PACKAGE-DATE | INSTALL-TYPE | COMMENTS |
|---|---|---|---|---|
| 1.2.4 | Linux-noarch | Jul-31-2026 | NEW | Initial mfte-tools package (site-connection-test + privacy-guard tool collection) |
| 1.2.6 | Linux-noarch | Aug-14-2026 | PATCH | Script/package update |
| 1.2.7 | Linux-noarch | Sep-16-2026 | PATCH | Fix SCHILY.fflags PAX header warning on GNU tar extraction (RHEL/Ubuntu) |
| 1.2.8 | Linux-noarch | Sep-16-2026 | PATCH | Add version.txt + VERSIONS.md release ledger; exclude .DS_Store from tarball |
| 1.2.9 | Linux-noarch | Sep-16-2026 | PATCH | Fix -h Recommended Run Command: substitute the real MFTE_GPG_RECEIVE_STAGING_DIR value live instead of printing an unexpanded shell-variable placeholder (werkstatt.gpg.receive.file.sh, werkstatt.gpg.vault.receive.file.sh) |
| 1.2.10 | Linux-noarch | Sep-16-2026 | PATCH | Add {VFOLDER} placeholder to MFTE_GPG_RETURN_DIR so returned files land in the customer's own MFTE-managed virtual folder instead of a shared, non-onboarded folder like secureTransport (werkstatt.gpg.receive.file.sh, werkstatt.gpg.vault.receive.file.sh); update sample.env default accordingly |
| 1.2.11 | Linux-noarch | Sep-16-2026 | PATCH | Add required -v vfolder flag + {VFOLDER} placeholder to MFTE_GPG_ONBOARDING_B2B_DIR so onboarding delivers the customer's public key into their own MFTE-managed Virtual Folder instead of a shared, non-onboarded folder (onboarding-4gpg-server.sh); fixes a real bash gotcha where an unescaped brace inside a ${var:-default} silently corrupted the path |
| 1.2.12 | Linux-noarch | Sep-16-2026 | PATCH | Add --skip-verify to gpg --decrypt (a signed-but-unverifiable attachment no longer causes a false decrypt_failed) and surface gpg's actual stderr in both the log (ERROR, not DEBUG) and the Control-M action output on a real decrypt failure (werkstatt.gpg.receive.file.sh, werkstatt.gpg.vault.receive.file.sh) |
