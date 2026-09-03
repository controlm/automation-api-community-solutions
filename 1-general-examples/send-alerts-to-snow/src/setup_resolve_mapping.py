#!/usr/bin/env python3
# Filename: setup_resolve_mapping.py
"""
ONE-TIME SETUP HELPER - run this after editing config/mapping_source.json

You do NOT need to know ServiceNow to use this. Just:
  1. Open config/mapping_source.json and enter your ServiceNow group and
     Business Service names in plain English (copy the .example file first
     if you haven't already).
  2. Make sure config/.env has your ServiceNow connection details filled in
     (copy from .env.example if you haven't already).
  3. Run:  python3 setup_resolve_mapping.py
  4. Read the output below. Fix anything marked [NOT FOUND] and re-run.
  5. Once everything shows [OK], config/mapping.json is ready and the
     main script (ctm_to_snow_incident.py) will use it automatically.

You should re-run this script any time you edit mapping_source.json.
"""

import os
import sys
import json
from datetime import datetime

from ctm_to_snow_incident import (
    SCRIPT_DIR,
    SCRIPT_VERSION as RUNTIME_SCRIPT_VERSION,
    load_config,
    get_oauth_token,
    lookup_sys_id,
)

SCRIPT_VERSION = "1.0.0"

MAPPING_SOURCE_FILE = os.path.join(SCRIPT_DIR, "config", "mapping_source.json")
MAPPING_OUTPUT_FILE = os.path.join(SCRIPT_DIR, "config", "mapping.json")


def banner(text: str) -> None:
    print()
    print("=" * 70)
    print(text)
    print("=" * 70)


def main() -> int:
    if "--version" in sys.argv[1:]:
        print(f"setup_resolve_mapping.py version {SCRIPT_VERSION} "
              f"(uses ctm_to_snow_incident.py v{RUNTIME_SCRIPT_VERSION})")
        return 0

    banner(f"ServiceNow Mapping Setup (v{SCRIPT_VERSION}, runtime script v{RUNTIME_SCRIPT_VERSION})")
    print("This will read config/mapping_source.json, look each name up in")
    print("ServiceNow, and write the result to config/mapping.json.")

    if not os.path.exists(MAPPING_SOURCE_FILE):
        print()
        print(f"[NOT FOUND] {MAPPING_SOURCE_FILE} does not exist.")
        print("Copy config/mapping_source.json.example to config/mapping_source.json,")
        print("fill in your ServiceNow group and Business Service names, and re-run this script.")
        return 1

    config = load_config()
    if not config.get("SERVICENOW_INSTANCE") or not config.get("SERVICENOW_CLIENT_ID"):
        print()
        print("[NOT FOUND] Your config/.env is missing ServiceNow connection details.")
        print("Copy config/.env.example to config/.env and fill in the SERVICENOW_* values first.")
        return 1

    with open(MAPPING_SOURCE_FILE, "r") as f:
        source_rules = json.load(f)

    print()
    print(f"Found {len(source_rules)} rule(s) in mapping_source.json. Connecting to ServiceNow...")

    try:
        access_token = get_oauth_token(config)
    except RuntimeError as e:
        print()
        print(f"[FAILED] Could not connect to ServiceNow: {e}")
        print("Double-check SERVICENOW_INSTANCE, SERVICENOW_CLIENT_ID and")
        print("SERVICENOW_CLIENT_SECRET in config/.env, then re-run this script.")
        return 1

    print("Connected successfully. Looking up each name...")

    resolved_rules = []
    any_problems = False

    for idx, rule in enumerate(source_rules, start=1):
        pattern = rule.get("pattern", "")
        group_name = rule.get("assignment_group_name", "")
        ci_name = rule.get("cmdb_ci_name", "")
        service_name = rule.get("service_name", "")

        print()
        print(f"Rule {idx}: pattern='{pattern}'")

        group_sys_id = ""
        if group_name:
            group_sys_id = lookup_sys_id(config, access_token, "sys_user_group", group_name)
            if group_sys_id:
                print(f"  [OK] Assignment group '{group_name}' found.")
            else:
                print(f"  [NOT FOUND] Assignment group '{group_name}' does not exist in ServiceNow.")
                print(f"              Check the spelling against ServiceNow's Groups list and try again.")
                any_problems = True
        else:
            print("  (no assignment group specified for this rule)")

        ci_sys_id = ""
        if ci_name:
            ci_sys_id = lookup_sys_id(config, access_token, "cmdb_ci_service_business", ci_name)
            if ci_sys_id:
                print(f"  [OK] Business Service '{ci_name}' found.")
            else:
                print(f"  [NOT FOUND] Business Service '{ci_name}' does not exist in ServiceNow.")
                print(f"              Check the spelling against ServiceNow's Business Services list and try again.")
                any_problems = True
        else:
            print("  (no Business Service specified for this rule)")

        resolved_rules.append({
            "service_name": service_name,
            "pattern": pattern,
            "assignment_group_name": group_name,
            "assignment_group_sys_id": group_sys_id,
            "cmdb_ci_name": ci_name,
            "cmdb_ci_sys_id": ci_sys_id,
        })

    marker = {
        "_do_not_edit": True,
        "_note": "This file is auto-generated by setup_resolve_mapping.py from mapping_source.json. "
                 "Edit mapping_source.json instead and re-run that script - changes made directly "
                 "here will be overwritten the next time it runs.",
        "_generated_by_version": SCRIPT_VERSION,
        "_generated_at": datetime.now().isoformat(),
    }
    output = [marker] + resolved_rules

    with open(MAPPING_OUTPUT_FILE, "w") as f:
        json.dump(output, f, indent=2)

    banner("Done")
    print(f"Wrote {len(resolved_rules)} rule(s) to {MAPPING_OUTPUT_FILE}")

    if any_problems:
        print()
        print("Some names above were marked [NOT FOUND]. Those rules were still")
        print("written out, but with a blank ID - they will not route correctly")
        print("until you fix the name in mapping_source.json and run this script again.")
        return 1

    print()
    print("Everything looks good. ctm_to_snow_incident.py is ready to use.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
