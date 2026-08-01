#!/usr/bin/env python3
"""
werkstatt.build.package.py

Packages everything needed to deploy werkstatt.ldap.smtp.test.py onto a
hub or any other host into a single zip file under ../package/, relative
to this script's location (i.e. run from src/, writes to
site-connection-test/package/).

Usage:
    python3 werkstatt.build.package.py

No third-party dependencies — uses only the standard library, so this can
run on a machine that doesn't have ldap3/pyasn1 installed either.
"""

import sys
import zipfile
from pathlib import Path
from datetime import datetime

__version__ = "1.1.0"

# This script lives in src/. The package output goes to ../package/,
# i.e. a sibling of src/ under site-connection-test/.
SRC_DIR = Path(__file__).resolve().parent
PACKAGE_DIR = SRC_DIR.parent / "package"


def _get_script_version():
    """Read werkstatt.ldap.smtp.test.py's __version__ as plain text (avoids
    importing it, since that module needs vendor/ldap3 on the path to succeed)."""
    source = (SRC_DIR / "werkstatt.ldap.smtp.test.py").read_text(encoding="utf-8")
    for line in source.splitlines():
        if line.startswith("__version__"):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    return "unknown"


SCRIPT_VERSION = _get_script_version()
ZIP_NAME = f"werkstatt.ldap.smtp.test-v{__version__}.zip"

# Top-level items in src/ to include in the package. Directories are
# included recursively. Anything not listed here (e.g. README.txt, this
# build script itself, __pycache__) is intentionally left out.
INCLUDE_ITEMS = [
    "werkstatt.ldap.smtp.test.py",
    "vendor",
    "config",
    "data",
    "bin",
    "lib",
    "README.md",
]

# Files/patterns to skip even inside an included directory.
EXCLUDE_SUFFIXES = (".pyc",)
EXCLUDE_NAMES = {"__pycache__", ".DS_Store"}


def should_skip(path: Path) -> bool:
    if path.name in EXCLUDE_NAMES:
        return True
    if path.suffix in EXCLUDE_SUFFIXES:
        return True
    if "__pycache__" in path.parts:
        return True
    return False


def collect_files():
    """Return a list of (absolute_path, arcname) tuples to add to the zip.
    arcname is prefixed with 'deploy/' so extracting the zip produces a
    clean deploy/ folder, matching how this has been packaged previously."""
    files = []
    missing = []

    for item_name in INCLUDE_ITEMS:
        item_path = SRC_DIR / item_name
        if not item_path.exists():
            missing.append(item_name)
            continue

        if item_path.is_file():
            if not should_skip(item_path):
                files.append((item_path, f"deploy/{item_name}"))
        else:
            for sub_path in item_path.rglob("*"):
                if sub_path.is_file() and not should_skip(sub_path):
                    rel = sub_path.relative_to(SRC_DIR)
                    files.append((sub_path, f"deploy/{rel.as_posix()}"))

    return files, missing


def build_zip():
    files, missing = collect_files()

    if missing:
        print("WARNING: the following expected items were not found and will be skipped:")
        for name in missing:
            print(f"  - {name}")
        print()

    if not files:
        print("ERROR: nothing to package — no expected files found. Aborting.")
        sys.exit(1)

    PACKAGE_DIR.mkdir(parents=True, exist_ok=True)
    zip_path = PACKAGE_DIR / ZIP_NAME

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for abs_path, arcname in files:
            zf.write(abs_path, arcname)

    size_kb = zip_path.stat().st_size / 1024
    print(f"Built: {zip_path}")
    print(f"werkstatt.build.package.py version: {__version__}")
    print(f"werkstatt.ldap.smtp.test.py version: {SCRIPT_VERSION}")
    print(f"Size: {size_kb:.1f} KB")
    print(f"Files packaged: {len(files)}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == "__main__":
    build_zip()