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
