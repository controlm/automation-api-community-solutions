#!/usr/bin/env python3
# Filename: agent_config_baseline.py
"""
Agent configuration baseline (golden config) capture and comparison tool.

Companion to ctm_engineer.py (imports its CtmClient/build_client/logging
setup) but deliberately a separate script, not part of its --folder
preflight-check CLI: "does this agent's config match our approved baseline"
is a compliance/drift check against a stored reference, a different kind of
question from "can this preflight run succeed" (live connectivity/test
checks).

Golden configs are stored one per PLATFORM, not one universal template -
Windows and Linux agents return substantially different parameter sets (see
CTM_ENGINEER.md), so a single golden file with a big ignore-list would fight
that difference rather than model it. Each golden lives at
.engineer/config/golden/{platform}.json (or {platform}_{category}.json when
-t/--category is given, e.g. -t mfte -> linux_mfte.json) and holds the full
output of CtmClient.get_agent_params() for whichever agent was captured as
the approved reference, plus capture metadata. The category dimension is for
agent roles whose expected config differs from the platform's general
baseline - an MFTE-heavy Linux agent vs. a general-purpose one, a
SAP-integration agent, etc.

Some parameters are legitimately node-specific even within one platform
(e.g. AGENT_DIR - the install path can differ per host) and would show up
as "different" on every single agent forever if not excluded. Those are
listed in .engineer/config/golden/ignore_params.json (created with a small
built-in default the first time it's needed) - add to it as you discover
more node-specific parameters through real use; this isn't something that
can be fully enumerated up front without seeing more real agent data.

Usage: -n/--nodeid takes the agent name (Control-M's own term for it - see
the "nodeid" field in CtmClient.get_agents()'s results).

    python agent_config_baseline.py capture -n ctm-lin-agt.shytwr.net
        Detects the agent's platform (from its reported operatingSystem) and
        saves its live config as that platform's golden baseline. Refuses to
        overwrite an existing golden unless --force is passed.

    python agent_config_baseline.py capture -n ctm-lin-agt.shytwr.net --platform linux --force
    python agent_config_baseline.py capture -n ctm-mfte-agt.shytwr.net -t mfte
        Saves as linux_mfte.json (or windows_mfte.json) instead of the
        platform's general baseline.

    python agent_config_baseline.py compare -n ctm-lin-agt.shytwr.net
        Compares the agent's live config against its platform's golden
        baseline and reports missing/different/extra parameters (ignoring
        node-specific ones). Exit code 1 if anything is missing or
        different; extra parameters and ignored ones don't affect it.

    python agent_config_baseline.py compare -n ctm-lin-agt.shytwr.net --output json
        --output also takes "file" (prints only the report's path). Regardless
        of --output, a JSON report is always written to LOG_FOLDER (matching
        ctm_engineer.py --folder's behavior) - console output is a view onto
        it, not the only place the result goes.

    python agent_config_baseline.py compare -g ZZM_AGT_01
        Compares every agent in the ZZM_AGT_01 hostgroup against its own
        platform's golden baseline in one combined report (-n and -g are
        mutually exclusive). An agent that fails to fetch (unreachable,
        no operatingSystem reported, etc.) is reported inline as an ERROR
        row rather than aborting the whole group's report.
"""

import argparse
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import dotenv_values

import ctm_engineer as ce

GOLDEN_DIR = ce.SCRIPT_DIR / ".engineer" / "config" / "golden"
IGNORE_PARAMS_FILE = GOLDEN_DIR / "ignore_params.json"

# Known node-specific parameters, excluded from every comparison regardless
# of platform - starting point only, not exhaustive (see module docstring).
DEFAULT_IGNORE_PARAMS = ["AGENT_DIR"]

logger = logging.getLogger("agent-config-baseline")


def _detect_platform(operating_system):
    """Bucket an agent's reported operatingSystem string into a golden-file platform name.

    Returns None (rather than guessing) when operating_system is missing -
    callers should require an explicit --platform in that case, since
    silently defaulting could compare against the wrong platform's golden
    without anyone noticing.
    """
    if not operating_system:
        return None
    return "windows" if "windows" in operating_system.lower() else "linux"


def _detect_platform_for_agent(client, agent, server=None):
    server = server or client.server
    agents = client.get_agents(agent=agent, server=server)
    match = next((entry for entry in agents if entry.get("nodeid", "").lower() == agent.lower()), None)
    return _detect_platform((match or {}).get("operatingSystem"))


def _load_ignore_params():
    if IGNORE_PARAMS_FILE.is_file():
        return set(json.loads(IGNORE_PARAMS_FILE.read_text()))
    return set(DEFAULT_IGNORE_PARAMS)


def _golden_path(platform, category=None):
    """Build the golden file path - {platform}.json, or {platform}_{category}.json when a
    category is given (e.g. category="mfte" -> linux_mfte.json), for agent roles whose
    expected config differs from the platform's general baseline (an MFTE-heavy Linux
    agent vs. a general-purpose one, a SAP-integration agent, etc.)."""
    filename = f"{platform}_{category}.json" if category else f"{platform}.json"
    return GOLDEN_DIR / filename


def capture_golden(client, agent, platform, server=None, force=False, category=None):
    """Pull `agent`'s live config via get_agent_params and save it as the golden baseline for `platform`
    (optionally scoped to `category`, e.g. "mfte" -> linux_mfte.json - see _golden_path).

    :raises FileExistsError: if a golden already exists for this platform/category and force is False
    :return: the Path the golden was written to
    """
    server = server or client.server
    golden_path = _golden_path(platform, category)
    if golden_path.is_file() and not force:
        raise FileExistsError(f"{golden_path} already exists - pass --force to overwrite")

    agents = client.get_agents(agent=agent, server=server)
    match = next((entry for entry in agents if entry.get("nodeid", "").lower() == agent.lower()), None)
    operating_system = (match or {}).get("operatingSystem")

    params = client.get_agent_params(agent=agent, server=server, extended_data=True)

    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "platform": platform,
        "category": category,
        "source_agent": agent,
        "source_operating_system": operating_system,
        "server": server,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "params": params,
    }
    golden_path.write_text(json.dumps(payload, indent=2))
    return golden_path


def compare_to_golden(client, agent, server=None, platform=None, category=None, ignore_params=None):
    """Compare `agent`'s live config against the golden baseline for its platform/category.

    :return: dict with keys: agent, platform, category, golden_path, error (str or None),
        missing (list of {name, golden_value, category} - in golden, absent live -
            NOTE: this "category" is the BMC parameter's own category field, e.g.
            "Comm"/"Maintenance", unrelated to the golden-selection `category` argument),
        different (list of {name, golden_value, actual_value, category}),
        extra (list of {name, actual_value, category} - live only, informational),
        ignored (list of param names present but excluded as node-specific)
    """
    server = server or client.server
    ignore_params = ignore_params if ignore_params is not None else _load_ignore_params()

    if platform is None:
        platform = _detect_platform_for_agent(client, agent, server=server)
        if platform is None:
            return {
                "agent": agent, "platform": None, "category": category, "golden_path": None,
                "error": f"could not detect a platform for '{agent}' (no operatingSystem reported) - pass --platform explicitly",
                "missing": [], "different": [], "extra": [], "ignored": [],
            }

    golden_path = _golden_path(platform, category)
    if not golden_path.is_file():
        label = f"{platform}/{category}" if category else platform
        return {
            "agent": agent, "platform": platform, "category": category, "golden_path": str(golden_path),
            "error": f"no golden config found for '{label}' - run 'capture' first",
            "missing": [], "different": [], "extra": [], "ignored": [],
        }

    golden_data = json.loads(golden_path.read_text())
    golden_params = {p["name"]: p for p in golden_data["params"]}

    live_params_list = client.get_agent_params(agent=agent, server=server, extended_data=True)
    live_params = {p["name"]: p for p in live_params_list}

    missing, different, extra, ignored = [], [], [], []

    for name, golden_entry in golden_params.items():
        if name in ignore_params:
            if name in live_params:
                ignored.append(name)
            continue
        if name not in live_params:
            missing.append({"name": name, "golden_value": golden_entry.get("value"), "category": golden_entry.get("category")})
        elif str(live_params[name].get("value")) != str(golden_entry.get("value")):
            different.append({
                "name": name,
                "golden_value": golden_entry.get("value"),
                "actual_value": live_params[name].get("value"),
                "category": golden_entry.get("category"),
            })

    for name, live_entry in live_params.items():
        if name not in golden_params and name not in ignore_params:
            extra.append({"name": name, "actual_value": live_entry.get("value"), "category": live_entry.get("category")})

    return {
        "agent": agent, "platform": platform, "category": category, "golden_path": str(golden_path), "error": None,
        "missing": missing, "different": different, "extra": extra, "ignored": ignored,
    }


def _format_missing_line(entry, color, prefix="  - "):
    """Render a missing-parameter line - only the parameter name (red) and the golden value
    (purple) are colored; surrounding text/punctuation/category stays plain."""
    name = ce._colorize(entry["name"], "red", color)
    golden_part = ce._colorize(repr(entry["golden_value"]), "purple", color)
    return f"{prefix}{name} (golden: {golden_part}) [{entry['category']}]"


def _format_different_line(entry, color, prefix="  - "):
    """Render a different-parameter line - only the parameter name (yellow), golden value
    (purple), and actual value (light blue) are colored; surrounding text stays plain."""
    name = ce._colorize(entry["name"], "yellow", color)
    golden_part = ce._colorize(repr(entry["golden_value"]), "purple", color)
    actual_part = ce._colorize(repr(entry["actual_value"]), "light_blue", color)
    return f"{prefix}{name}: golden={golden_part} actual={actual_part} [{entry['category']}]"


def _print_compare_report(result):
    """Human-readable, color-coded console report - reuses ctm_engineer's color helpers for consistency."""
    color = ce._color_enabled()
    label = f"{result['platform']}/{result['category']}" if result.get("category") else result["platform"]
    print(f"=== Agent Config Baseline: '{result['agent']}' vs '{label}' golden ===")
    print(f"Golden: {result['golden_path']}\n")

    def _count_line(label, count, bad_color="red", ok_color="green"):
        return f"{label}: {ce._colorize(str(count), bad_color if count else ok_color, color)}"

    print(_count_line("Missing parameters", len(result["missing"])))
    print(_count_line("Different parameters", len(result["different"]), bad_color="yellow"))
    print(f"Extra parameters: {ce._colorize(str(len(result['extra'])), 'yellow' if result['extra'] else 'green', color)}")
    if result["ignored"]:
        print(f"Ignored (node-specific): {len(result['ignored'])}")

    if result["missing"]:
        print("\nMissing (in golden, not on this agent):")
        for entry in result["missing"]:
            print(_format_missing_line(entry, color))

    if result["different"]:
        print("\nDifferent:")
        for entry in result["different"]:
            print(_format_different_line(entry, color))

    if result["extra"]:
        print("\nExtra (on this agent, not in golden):")
        for entry in result["extra"]:
            name = ce._colorize(entry["name"], "yellow", color)
            actual_part = ce._colorize(repr(entry["actual_value"]), "light_blue", color)
            print(f"  - {name} = {actual_part} [{entry['category']}]")


def compare_group_to_golden(client, group, server=None, platform=None, category=None, ignore_params=None):
    """Compare every agent in a hostgroup against its platform's golden baseline, in one pass.

    Streamlines checking a whole fleet at once rather than one compare_to_golden
    call per node. Reuses CtmClient.resolve_host for the group -> agent(s)
    resolution, so this also transparently works if `group` turns out to be a
    bare agent name or an Agentless Host rather than a real Host Group - same
    ambiguity resolve_host already handles for --folder's preflight checks.

    platform/category, if given, are applied uniformly to every agent in the
    group (comparing all of them against the same golden); left as None,
    each agent auto-detects its own platform independently - the common case,
    since a hostgroup is usually all one platform, but not assumed here.

    :return: dict with keys: group, resolved (resolve_host's result),
        error (str or None - only set if the group/host itself couldn't be
        resolved to any agents), results (list of compare_to_golden's
        per-agent dicts, one per resolved agent)
    """
    server = server or client.server
    resolved = client.resolve_host(group, server=server)
    if resolved["error"] or not resolved["agents"]:
        return {
            "group": group, "resolved": resolved,
            "error": resolved["error"] or f"'{group}' resolved to no agents",
            "results": [],
        }

    ignore_params = ignore_params if ignore_params is not None else _load_ignore_params()
    results = []
    for agent in resolved["agents"]:
        try:
            results.append(
                compare_to_golden(client, agent, server=server, platform=platform, category=category, ignore_params=ignore_params)
            )
        except ce.CtmApiError as exp:
            # A single unreachable/misbehaving agent shouldn't sink the whole
            # group report - record it as an error entry and keep going, same
            # as the "no golden found"/"no platform detected" error dicts
            # compare_to_golden itself returns.
            results.append({
                "agent": agent, "platform": platform, "category": category, "golden_path": None,
                "error": f"failed to fetch live config: {exp.message}",
                "missing": [], "different": [], "extra": [], "ignored": [],
            })
    return {"group": group, "resolved": resolved, "error": None, "results": results}


def _print_group_compare_report(result):
    """Human-readable, color-coded console report for a group compare - one row per agent,
    then consolidated missing/different detail across all of them. Only the rightmost
    "Status" column is colorized (see ctm_engineer._print_preflight_report's own note) -
    ANSI escape codes would otherwise break fixed-width alignment on the numeric columns.
    """
    color = ce._color_enabled()
    host_type = result["resolved"]["host_type"]
    print(f"=== Agent Config Baseline: '{result['group']}' ({host_type}, {len(result['results'])} agent(s)) ===\n")

    row = "{:<32} {:<10} {:<9} {:<11} {:<7} {}"
    print(row.format("Agent", "Platform", "Missing", "Different", "Extra", "Status"))
    for r in result["results"]:
        if r["error"]:
            status_color = ce._colorize("ERROR", "red", color)
            print(row.format(r["agent"][:32], r["platform"] or "-", "-", "-", "-", status_color))
            continue
        missing_n, different_n, extra_n = len(r["missing"]), len(r["different"]), len(r["extra"])
        status = "OK" if not (missing_n or different_n) else "ERROR"
        status_color = ce._colorize(status, "green" if status == "OK" else "red", color)
        print(row.format(r["agent"][:32], r["platform"] or "-", missing_n, different_n, extra_n, status_color))

    total_missing = sum(len(r["missing"]) for r in result["results"])
    total_different = sum(len(r["different"]) for r in result["results"])
    total_errors = sum(1 for r in result["results"] if r["error"])

    print(f"\nTotal missing: {ce._colorize(str(total_missing), 'red' if total_missing else 'green', color)}")
    print(f"Total different: {ce._colorize(str(total_different), 'yellow' if total_different else 'green', color)}")
    if total_errors:
        print(f"Total errors: {ce._colorize(str(total_errors), 'red', color)}")

    for r in result["results"]:
        if r["error"]:
            print(f"\n{r['agent']}:")
            print(ce._colorize(f"  - {r['error']}", "red", color))
            continue
        if not (r["missing"] or r["different"]):
            continue
        print(f"\n{r['agent']} ({r['platform']}):")
        for entry in r["missing"]:
            print(_format_missing_line(entry, color, prefix="  - MISSING "))
        for entry in r["different"]:
            print(_format_different_line(entry, color, prefix="  - DIFFERENT "))


def _write_report(log_folder, target, result):
    """Write `result` (a compare_to_golden or compare_group_to_golden dict) as a timestamped
    JSON report under log_folder, mirroring ctm_engineer.py's _run_preflight_cli - the report
    file is always written regardless of --output, so `-n`/`-g` results are just as durable
    and pipeable as a --folder preflight report.

    :return: the Path the report was written to
    """
    log_folder.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = log_folder / f"ctm_agent_baseline_{target}_{timestamp}.json"
    report_path.write_text(json.dumps(result, indent=2, default=str))
    return report_path


def main():
    parser = argparse.ArgumentParser(description="Agent configuration baseline capture/comparison")
    parser.add_argument("--env-file", default=str(ce.DEFAULT_ENV_FILE), help="Path to .env file (default: %(default)s)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable debug-level logging")
    subparsers = parser.add_subparsers(dest="command", required=True)

    category_help = (
        "Optional category/role for the golden filename, e.g. -t mfte -> linux_mfte.json, "
        "-t sap -> linux_sap.json. Left empty, the filename is just {platform}.json."
    )

    nodeid_help = "Agent nodeid (Control-M's term for its hostname), e.g. -n ctm-lin-agt.shytwr.net"

    capture_parser = subparsers.add_parser("capture", help="Pull an agent's live config and save it as the golden baseline for its platform")
    capture_parser.add_argument("-n", "--nodeid", dest="agent", required=True, metavar="NODEID", help=nodeid_help)
    capture_parser.add_argument("--platform", choices=("linux", "windows"), default=None, help="Override auto-detected platform")
    capture_parser.add_argument("-t", "--category", default=None, help=category_help)
    capture_parser.add_argument("--force", action="store_true", help="Overwrite an existing golden file")

    compare_parser = subparsers.add_parser("compare", help="Compare an agent's (or a whole hostgroup's) live config against its platform's golden baseline")
    compare_target = compare_parser.add_mutually_exclusive_group(required=True)
    compare_target.add_argument("-n", "--nodeid", dest="agent", metavar="NODEID", help=nodeid_help)
    compare_target.add_argument(
        "-g", "--group", metavar="HOSTGROUP",
        help="Compare every agent in this hostgroup at once (streamlines checking a whole fleet "
             "instead of one -n call per node) - resolved via the same logic as --folder's Host "
             "resolution, so a bare agent name or Agentless Host works here too.",
    )
    compare_parser.add_argument("--platform", choices=("linux", "windows"), default=None, help="Override auto-detected platform")
    compare_parser.add_argument("-t", "--category", default=None, help=category_help)
    compare_parser.add_argument(
        "--output", choices=("verbose", "json", "file"), default="verbose",
        help="verbose (default): human-readable console report. json: print only the JSON "
             "report content. file: print only the JSON report's path. The JSON report file "
             "is always written to LOG_FOLDER regardless of this setting.",
    )

    args = parser.parse_args()

    # Peek LOG_FOLDER from the .env before full config validation, so a custom
    # log location is honored even if the rest of the .env turns out to be
    # invalid - same reasoning as ctm_engineer.py's own main().
    log_folder = ce.DEFAULT_LOG_FOLDER
    env_values = dotenv_values(args.env_file)
    log_folder_value = env_values.get("LOG_FOLDER")
    if log_folder_value:
        candidate = Path(log_folder_value)
        log_folder = candidate if candidate.is_absolute() else ce.SCRIPT_DIR / candidate

    ce.configure_logging(verbose=args.verbose, log_folder=log_folder)

    try:
        client = ce.build_client(args.env_file)
    except (FileNotFoundError, ValueError) as exp:
        logger.error(str(exp))
        return 1

    if args.command == "capture":
        try:
            platform = args.platform or _detect_platform_for_agent(client, args.agent)
            if platform is None:
                logger.error("Could not detect a platform for '%s' (no operatingSystem reported) - pass --platform explicitly", args.agent)
                return 1
            path = capture_golden(client, args.agent, platform, force=args.force, category=args.category)
        except FileExistsError as exp:
            logger.error(str(exp))
            return 1
        except ce.CtmApiError as exp:
            logger.error("Failed to capture config: %s", exp.message)
            return 1
        print(f"Golden config saved: {path}")
        return 0

    # compare
    if args.group:
        try:
            result = compare_group_to_golden(client, args.group, platform=args.platform, category=args.category)
        except ce.CtmApiError as exp:
            logger.error("Failed to fetch live config: %s", exp.message)
            return 1

        if result["error"]:
            logger.error(result["error"])
            return 1

        report_path = _write_report(log_folder, args.group, result)
        if args.output == "json":
            print(json.dumps(result, indent=2))
        elif args.output == "file":
            print(report_path)
        else:
            _print_group_compare_report(result)
            print(f"\nReport: {report_path}")

        total_missing = sum(len(r["missing"]) for r in result["results"])
        total_different = sum(len(r["different"]) for r in result["results"])
        total_errors = sum(1 for r in result["results"] if r["error"])
        return 1 if (total_missing or total_different or total_errors) else 0

    try:
        result = compare_to_golden(client, args.agent, platform=args.platform, category=args.category)
    except ce.CtmApiError as exp:
        logger.error("Failed to fetch live config: %s", exp.message)
        return 1

    if result["error"]:
        logger.error(result["error"])
        return 1

    report_path = _write_report(log_folder, args.agent, result)
    if args.output == "json":
        print(json.dumps(result, indent=2))
    elif args.output == "file":
        print(report_path)
    else:
        _print_compare_report(result)
        print(f"\nReport: {report_path}")

    return 1 if (result["missing"] or result["different"]) else 0


if __name__ == "__main__":
    sys.exit(main())
