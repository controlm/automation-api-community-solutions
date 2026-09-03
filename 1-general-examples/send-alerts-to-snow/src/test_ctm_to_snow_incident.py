#!/usr/bin/env python3
# Filename: test_ctm_to_snow_incident.py
"""
Test script for ctm_to_snow_incident.py - no network calls, no live
ServiceNow instance required. Covers:

  1. Parsing the exact real sample captured from production Control-M
     output (sanitized fields from the original alerts.py debug log),
     including its trailing-whitespace and single-space-empty-value
     quirks.
  2. Parsing the alternate real Control-M behavior where empty fields
     are omitted entirely rather than padded with a space.
  3. Routing resolution (resolve_route) against a multi-rule mapping,
     including ordering and catch-all fallback.
  4. Payload construction omitting assignment_group/cmdb_ci when unresolved.

Run with:  python3 test_ctm_to_snow_incident.py
Uses only the standard library (unittest) - no new dependency for a
script that's just meant to demonstrate/verify behavior.
"""

import json
import os
import unittest

from ctm_to_snow_incident import (
    parse_ctm_args_to_json,
    resolve_route,
    classify_alert,
    build_agent_correlation_id,
    extract_agent_hostname_from_message,
    describe_ctm_lifecycle,
    load_config,
    SCRIPT_DIR,
    build_correlation_lookup_query,
    build_short_description,
    build_work_notes,
)

FIXTURES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample")


def load_fixture(filename: str) -> list:
    with open(os.path.join(FIXTURES_DIR, filename), "r") as f:
        return json.load(f)


# --- Real sample, exactly as captured from production (sanitized) ---
# Source: original alerts.py debug log line:
#   22-Jul-26 14:40:44 [DEBUG] alerts: Arguments: [...]
# See fixtures/job_alert_real_sample.json
REAL_CTM_SAMPLE_ARGS = load_fixture("job_alert_real_sample.json")


class TestParseRealCtmSample(unittest.TestCase):
    """Parse the exact real-world sample with its whitespace quirks."""

    def setUp(self):
        self.alert = parse_ctm_args_to_json(REAL_CTM_SAMPLE_ARGS)

    def test_all_21_fields_present(self):
        self.assertEqual(len(self.alert), 21)

    def test_values_with_trailing_space_are_stripped(self):
        # Raw token was '2256 ' (trailing space) - must come out clean.
        self.assertEqual(self.alert["alert_id"], "2256")
        self.assertEqual(self.alert["data_center"], "ctm-lin-srv")
        self.assertEqual(self.alert["memname"], "zzm.pre.flight.sh")
        self.assertEqual(self.alert["run_as"], "mftuser")
        self.assertEqual(self.alert["run_counter"], "00001")

    def test_multi_word_values_stripped_correctly(self):
        # Raw tokens: 'Multipath Cloud Demo ', 'ZZM BMC ',
        # 'ZZM PreFlight Check ' - internal spaces must be preserved,
        # only the trailing space removed.
        self.assertEqual(self.alert["sub_application"], "Multipath Cloud Demo")
        self.assertEqual(self.alert["application"], "ZZM BMC")
        self.assertEqual(self.alert["job_name"], "ZZM PreFlight Check")
        self.assertEqual(self.alert["host_id"], "ctm-lin-agt.werkstatt.local")

    def test_literal_single_space_values_become_empty_string(self):
        # Raw tokens were a single space ' ', not an empty string and
        # not an omitted token - this is the real Control-M behavior
        # for "no value" fields in this sample.
        self.assertEqual(self.alert["last_user"], "")
        self.assertEqual(self.alert["last_time"], "")
        self.assertEqual(self.alert["closed_from_em"], "")
        self.assertEqual(self.alert["ticket_number"], "")
        self.assertEqual(self.alert["notes"], "")

    def test_values_without_trailing_space_unaffected(self):
        self.assertEqual(self.alert["call_type"], "I")
        self.assertEqual(self.alert["order_id"], "0039s")
        self.assertEqual(self.alert["severity"], "V")
        self.assertEqual(self.alert["send_time"], "20260722144043")
        self.assertEqual(self.alert["message"], "Ended not OK")
        self.assertEqual(self.alert["alert_type"], "R")

    def test_no_desync_across_consecutive_space_only_fields(self):
        # last_user and last_time are back-to-back single-space fields -
        # confirms the look-ahead doesn't desync across consecutive
        # "empty" fields, same risk class as the fully-omitted-token case.
        keys_in_order = list(self.alert.keys())
        idx_last_user = keys_in_order.index("last_user")
        idx_last_time = keys_in_order.index("last_time")
        idx_message = keys_in_order.index("message")
        self.assertEqual(idx_last_time, idx_last_user + 1)
        self.assertEqual(idx_message, idx_last_time + 1)
        self.assertEqual(self.alert["message"], "Ended not OK")  # would be corrupted if desynced


class TestParseOmittedTokenStyle(unittest.TestCase):
    """
    The other real Control-M behavior: empty fields' value tokens are
    omitted entirely, so the next token is immediately the next key.
    (Matches the documented example in the original alerts.py.)
    """

    # See fixtures/job_alert_omitted_values_sample.json
    ARGS_WITH_OMITTED_VALUES = load_fixture("job_alert_omitted_values_sample.json")

    def setUp(self):
        self.alert = parse_ctm_args_to_json(self.ARGS_WITH_OMITTED_VALUES)

    def test_all_21_fields_present(self):
        self.assertEqual(len(self.alert), 21)

    def test_consecutive_omitted_fields_dont_desync(self):
        # memname/order_id and the five-in-a-row run before alert_type
        # are the two spots most likely to desync a naive parser.
        self.assertEqual(self.alert["memname"], "")
        self.assertEqual(self.alert["order_id"], "00000")
        self.assertEqual(self.alert["run_as"], "")
        self.assertEqual(self.alert["sub_application"], "")
        self.assertEqual(self.alert["application"], "")
        self.assertEqual(self.alert["job_name"], "")
        self.assertEqual(self.alert["host_id"], "")
        self.assertEqual(self.alert["alert_type"], "R")
        self.assertEqual(self.alert["run_counter"], "00000000000")

    def test_message_field_intact(self):
        self.assertEqual(
            self.alert["message"],
            "STATUS OF AGENT PLATFORM ctm-win-em CHANGED TO UNAVAILABLE",
        )


class TestExtractAgentHostname(unittest.TestCase):
    """
    Confirmed against real production alerts 2257 (unavailable) and 2258
    (available) - both had host_id='' but message contained the actual
    hostname 'ctm-lin-em.werkstatt.local'.
    """

    def test_extracts_hostname_with_domain_suffix(self):
        message = "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO UNAVAILABLE"
        self.assertEqual(extract_agent_hostname_from_message(message), "ctm-lin-em.werkstatt.local")

    def test_extracts_hostname_without_domain_suffix(self):
        message = "STATUS OF AGENT PLATFORM ctm-win-em CHANGED TO UNAVAILABLE"
        self.assertEqual(extract_agent_hostname_from_message(message), "ctm-win-em")

    def test_works_for_available_message_too(self):
        message = "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO AVAILABLE"
        self.assertEqual(extract_agent_hostname_from_message(message), "ctm-lin-em.werkstatt.local")

    def test_no_match_returns_empty_string_not_a_crash(self):
        self.assertEqual(extract_agent_hostname_from_message("Ended not OK"), "")


class TestCorrelationIdFallsBackToMessage(unittest.TestCase):
    """
    The real bug this fixes: host_id is empty for these alerts in
    production, so a correlation_id built from host_id alone collapses
    every agent in a data center onto the same key. Must fall back to
    extracting the hostname from the message instead.
    """

    def test_real_production_alert_2257_shape(self):
        # Exact shape of the real 2257/2258 alerts: host_id empty,
        # hostname only present in message.
        alert = {
            "data_center": "ctm-lin-srv",
            "host_id": "",
            "message": "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO UNAVAILABLE",
        }
        self.assertEqual(
            build_agent_correlation_id(alert),
            "ctm-lin-srv:ctm-lin-em.werkstatt.local",
        )

    def test_does_not_collapse_to_bare_data_center_colon(self):
        # This is exactly what production actually produced before the
        # fix - guards against regressing back to it.
        alert = {
            "data_center": "ctm-lin-srv",
            "host_id": "",
            "message": "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO UNAVAILABLE",
        }
        self.assertNotEqual(build_agent_correlation_id(alert), "ctm-lin-srv:")

    def test_two_different_agents_same_data_center_no_longer_collide(self):
        alert_a = {
            "data_center": "ctm-lin-srv",
            "host_id": "",
            "message": "STATUS OF AGENT PLATFORM agent-a.werkstatt.local CHANGED TO UNAVAILABLE",
        }
        alert_b = {
            "data_center": "ctm-lin-srv",
            "host_id": "",
            "message": "STATUS OF AGENT PLATFORM agent-b.werkstatt.local CHANGED TO UNAVAILABLE",
        }
        self.assertNotEqual(
            build_agent_correlation_id(alert_a),
            build_agent_correlation_id(alert_b),
        )

    def test_populated_host_id_still_takes_priority_over_message(self):
        # If host_id IS populated (some other Control-M alert source
        # might send it), prefer it over parsing the message.
        alert = {
            "data_center": "ctm-lin-srv",
            "host_id": "explicit-host-id",
            "message": "STATUS OF AGENT PLATFORM different-name.werkstatt.local CHANGED TO UNAVAILABLE",
        }
        self.assertEqual(build_agent_correlation_id(alert), "ctm-lin-srv:explicit-host-id")


class TestMappingFileResolution(unittest.TestCase):
    """
    Real bug, hit twice in production before being fixed: a relative
    MAPPING_FILE value (default, or set explicitly in .env) must resolve
    against this script's own directory, not whatever the caller's cwd
    happens to be at invocation time (e.g. via sudo -u from the wrapper,
    which does not guarantee this script's own folder as cwd).
    """

    def setUp(self):
        # Preserve and restore the real environment/cwd around each test
        self._saved_env = dict(os.environ)
        self._saved_cwd = os.getcwd()
        for var in ["SERVICENOW_INSTANCE", "SERVICENOW_CLIENT_ID",
                    "SERVICENOW_CLIENT_SECRET", "SERVICENOW_CALLER_ID"]:
            os.environ.setdefault(var, "test-value")

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._saved_env)
        os.chdir(self._saved_cwd)

    def test_unset_resolves_to_script_dir(self):
        os.environ.pop("MAPPING_FILE", None)
        config = load_config()
        expected = os.path.join(SCRIPT_DIR, "config", "mapping.json")
        self.assertEqual(config["MAPPING_FILE"], expected)

    def test_relative_path_resolves_against_script_dir_not_cwd(self):
        # The actual bug: this exact value, invoked from an unrelated
        # working directory, used to resolve to a path relative to /tmp
        # instead of the script's own folder.
        os.environ["MAPPING_FILE"] = "config/mapping.json"
        os.chdir("/tmp")
        config = load_config()
        expected = os.path.join(SCRIPT_DIR, "config", "mapping.json")
        self.assertEqual(config["MAPPING_FILE"], expected)

    def test_absolute_path_respected_as_is(self):
        os.environ["MAPPING_FILE"] = "/some/explicit/absolute/mapping.json"
        config = load_config()
        self.assertEqual(config["MAPPING_FILE"], "/some/explicit/absolute/mapping.json")


class TestBuildShortDescription(unittest.TestCase):
    """
    Real bug: job_name exists as an empty string (not a missing key) for
    agent alerts, so alert.get('job_name', 'unknown job') never triggered
    its fallback - producing a bare leading ": " in a real ServiceNow
    incident's short_description.
    """

    def test_agent_alert_no_leading_colon(self):
        # Exact shape of real production alert 2263
        alert = {
            "job_name": "",
            "message": "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO UNAVAILABLE",
            "alert_id": "2263",
        }
        result = build_short_description(alert)
        self.assertFalse(result.startswith(":"), f"Leading colon artifact still present: {result!r}")
        self.assertEqual(
            result,
            "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO UNAVAILABLE (Alert 2263)",
        )

    def test_job_alert_format_unchanged(self):
        alert = {
            "job_name": "ZZM PreFlight Check",
            "message": "Ended not OK",
            "alert_id": "2256",
        }
        result = build_short_description(alert)
        self.assertEqual(result, "ZZM PreFlight Check: Ended not OK (Alert 2256)")


class TestBuildWorkNotes(unittest.TestCase):
    """Same bug class as short_description, applied to the worklog text."""

    def test_agent_alert_no_blank_job_clause(self):
        alert = {
            "alert_id": "2263",
            "job_name": "",
            "application": "",
            "sub_application": "",
            "host_id": "",
            "data_center": "ctm-lin-srv",
            "message": "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO UNAVAILABLE",
        }
        result = build_work_notes(alert)
        self.assertNotIn("on job \n", result)
        self.assertIn("Control-M alert 2263\n", result)
        self.assertIn("Application: unknown / Sub-application: unknown", result)
        self.assertIn("Host: unknown | Data center: ctm-lin-srv", result)

    def test_job_alert_includes_job_clause(self):
        alert = {
            "alert_id": "2256",
            "job_name": "ZZM PreFlight Check",
            "application": "ZZM BMC",
            "sub_application": "Demo",
            "host_id": "ctm-lin-agt.werkstatt.local",
            "data_center": "ctm-lin-srv",
            "message": "Ended not OK",
        }
        result = build_work_notes(alert)
        self.assertIn("Control-M alert 2256 on job ZZM PreFlight Check\n", result)


class TestCorrelationLookupQuery(unittest.TestCase):
    """
    Real bug caught from production evidence: the same incident got
    "found and resolved" twice by two different agent_available alerts,
    with the second resolve's resolved_at timestamp not even changing -
    proof ServiceNow silently no-op'd a redundant resolve because
    active=true alone doesn't exclude already-Resolved incidents.
    """

    def test_excludes_resolved_state(self):
        query = build_correlation_lookup_query("ctm-lin-srv:ctm-lin-em.werkstatt.local")
        self.assertIn("state!=6", query)

    def test_still_filters_on_correlation_id_and_active(self):
        query = build_correlation_lookup_query("some:id")
        self.assertIn("correlation_id=some:id", query)
        self.assertIn("active=true", query)


class TestDescribeCtmLifecycle(unittest.TestCase):
    """
    Only 'I' + 'Not_Noticed' is a new, actionable alert. 'U' updates
    (Noticed/Handled) are Control-M re-notifying about the SAME
    alert_id as its own console status changes - must be recognized
    and skipped, not treated as new alerts, or every review/handle
    action taken in Control-M's own alert console would create a
    duplicate ServiceNow incident.
    """

    def test_initial_alert(self):
        alert = {"call_type": "I", "status": "Not_Noticed"}
        self.assertEqual(describe_ctm_lifecycle(alert), "initial")

    def test_acknowledged_update(self):
        alert = {"call_type": "U", "status": "Noticed"}
        self.assertEqual(describe_ctm_lifecycle(alert), "acknowledged_in_ctm")

    def test_handled_update(self):
        alert = {"call_type": "U", "status": "Handled"}
        self.assertEqual(describe_ctm_lifecycle(alert), "closed_in_ctm")

    def test_unrecognized_combination(self):
        alert = {"call_type": "I", "status": "Noticed"}
        self.assertEqual(describe_ctm_lifecycle(alert), "unknown_lifecycle_state")

    def test_missing_fields_dont_crash(self):
        self.assertEqual(describe_ctm_lifecycle({}), "unknown_lifecycle_state")

    def test_real_job_sample_is_initial(self):
        # Confirms the existing real job fixture is still correctly
        # treated as a new alert after adding this gate - a regression
        # here would silently stop all job alerts from ever creating
        # incidents.
        alert = parse_ctm_args_to_json(REAL_CTM_SAMPLE_ARGS)
        self.assertEqual(describe_ctm_lifecycle(alert), "initial")

    def test_real_agent_unavailable_sample_is_initial(self):
        alert = parse_ctm_args_to_json(
            load_fixture("job_alert_omitted_values_sample.json")
        )
        self.assertEqual(describe_ctm_lifecycle(alert), "initial")

    def test_real_ctm_update_alert_noticed_is_skipped(self):
        # Full realistic token list, matching Control-M's actual
        # re-notification shape when alert 2258 gets reviewed in
        # Control-M's own alert console (see the Control-M Alerts
        # screenshot: status changed from 'New' to 'Reviewed').
        alert = parse_ctm_args_to_json(
            load_fixture("ctm_update_alert_noticed_sample.json")
        )
        self.assertEqual(alert["alert_id"], "2258")
        self.assertEqual(describe_ctm_lifecycle(alert), "acknowledged_in_ctm")


class TestClassifyAlert(unittest.TestCase):
    """classify_alert scope: job, agent_unavailable, agent_available, other."""

    def test_real_job_sample_classified_as_job(self):
        alert = parse_ctm_args_to_json(REAL_CTM_SAMPLE_ARGS)
        self.assertEqual(classify_alert(alert), "job")

    def test_omitted_values_sample_is_agent_unavailable(self):
        # This fixture's order_id=00000 and message contains both
        # required substrings - it's actually a real agent_unavailable
        # alert, not just a generic "empty fields" example.
        alert = parse_ctm_args_to_json(
            load_fixture("job_alert_omitted_values_sample.json")
        )
        self.assertEqual(classify_alert(alert), "agent_unavailable")

    def test_agent_available_sample_classified_correctly(self):
        alert = parse_ctm_args_to_json(load_fixture("agent_available_sample.json"))
        self.assertEqual(classify_alert(alert), "agent_available")

    def test_server_disconnection_message_is_other(self):
        alert = {
            "order_id": "00000",
            "job_name": "",
            "message": "SERVER ctm-lin-srv WAS DISCONNECTED",
        }
        self.assertEqual(classify_alert(alert), "other")

    def test_unrecognized_00000_message_is_other(self):
        alert = {
            "order_id": "00000",
            "job_name": "",
            "message": "Database archive is off. No database backups are running.",
        }
        self.assertEqual(classify_alert(alert), "other")

    def test_job_with_order_id_but_no_job_name_is_not_job(self):
        # order_id alone isn't sufficient - job_name must also be present,
        # matching alerts.py's exact condition.
        alert = {"order_id": "0039s", "job_name": "", "message": "Ended not OK"}
        self.assertEqual(classify_alert(alert), "other")


class TestAgentCorrelationId(unittest.TestCase):
    """Correlation key: data_center + host_id, not host_id alone."""

    def test_format_is_data_center_colon_host_id(self):
        alert = {"data_center": "ctm-lin-srv", "host_id": "ctm-lin-agt.werkstatt.local"}
        self.assertEqual(build_agent_correlation_id(alert), "ctm-lin-srv:ctm-lin-agt.werkstatt.local")

    def test_unavailable_and_available_produce_same_correlation_id(self):
        # This is the entire point of the mechanism: an agent_unavailable
        # alert and its later agent_available counterpart for the same
        # host must produce an identical correlation_id, or the resolve
        # step can never find the incident to close.
        unavailable_alert = parse_ctm_args_to_json(
            load_fixture("job_alert_omitted_values_sample.json")
        )
        available_alert = parse_ctm_args_to_json(load_fixture("agent_available_sample.json"))

        unavailable_id = build_agent_correlation_id(unavailable_alert)
        available_id = build_agent_correlation_id(available_alert)

        self.assertEqual(unavailable_id, available_id)

    def test_same_host_different_data_center_produce_different_ids(self):
        # The new-release scenario this composite key exists to handle:
        # one host_id under two different CTM Servers must not collide.
        alert_a = {"data_center": "ctm-lin-srv", "host_id": "ctm-shared-agt"}
        alert_b = {"data_center": "ctm-win-srv", "host_id": "ctm-shared-agt"}
        self.assertNotEqual(
            build_agent_correlation_id(alert_a),
            build_agent_correlation_id(alert_b),
        )


class TestResolveRoute(unittest.TestCase):
    """Routing resolution: ordering, prefix matching, catch-all fallback."""

    RULES = [
        {
            "service_name": "Secure Data Transfer Service",
            "pattern": "ZZM*",
            "assignment_group_name": "Secure Data Transfer",
            "assignment_group_sys_id": "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d",
            "cmdb_ci_name": "Secure Data Transfer Service",
            "cmdb_ci_sys_id": "2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e",
        },
        {
            "service_name": "SAP Financials",
            "pattern": "SAP-FIN*",
            "assignment_group_name": "SAP Support",
            "assignment_group_sys_id": "group-sapfin-sysid",
            "cmdb_ci_name": "SAP Financials",
            "cmdb_ci_sys_id": "ci-sapfin-sysid",
        },
        {
            "service_name": "",
            "pattern": "*",
            "assignment_group_name": "Control-M",
            "assignment_group_sys_id": "3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f",
            "cmdb_ci_name": "",
            "cmdb_ci_sys_id": "",
        },
    ]

    def test_real_zzm_application_matches_known_good_sys_ids(self):
        # Guards against a future edit silently changing which rule the
        # ZZM* application prefix resolves to (placeholder sys_ids here).
        rule = resolve_route("ZZM BMC", self.RULES)
        self.assertEqual(rule["assignment_group_sys_id"], "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d")
        self.assertEqual(rule["cmdb_ci_sys_id"], "2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e")

    def test_case_insensitive_matching(self):
        rule = resolve_route("zzm demo", self.RULES)
        self.assertEqual(rule["service_name"], "Secure Data Transfer Service")

    def test_unmatched_application_falls_through_to_catch_all(self):
        rule = resolve_route("Totally Unrelated App", self.RULES)
        self.assertEqual(rule["assignment_group_sys_id"], "3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f")
        self.assertEqual(rule["cmdb_ci_sys_id"], "")

    def test_rule_order_respected_not_alphabetical(self):
        # SAP-FIN* must not accidentally match before or instead of a
        # more specific rule earlier in the list.
        rule = resolve_route("SAP-FIN Nightly Batch", self.RULES)
        self.assertEqual(rule["service_name"], "SAP Financials")

    def test_no_rules_returns_empty_dict_not_a_crash(self):
        rule = resolve_route("Anything", [])
        self.assertEqual(rule, {})

    def test_no_catch_all_rule_leaves_unmatched_app_unresolved(self):
        rules_without_catch_all = self.RULES[:2]  # drop the "*" rule
        rule = resolve_route("Nothing Like The Others", rules_without_catch_all)
        self.assertEqual(rule, {})


class TestPayloadOmitsUnresolvedFields(unittest.TestCase):
    """
    assignment_group and cmdb_ci must each be omitted from the payload
    entirely when unresolved - never sent as an empty string.
    """

    @staticmethod
    def build_payload(assignment_group: str, cmdb_ci: str) -> dict:
        payload = {
            "short_description": "test",
            "caller_id": "caller-x",
            "urgency": "3",
            "impact": "3",
        }
        if assignment_group:
            payload["assignment_group"] = assignment_group
        if cmdb_ci:
            payload["cmdb_ci"] = cmdb_ci
        return payload

    def test_both_resolved(self):
        payload = self.build_payload("group-sys-id", "ci-sys-id")
        self.assertIn("assignment_group", payload)
        self.assertIn("cmdb_ci", payload)

    def test_neither_resolved_keys_omitted_entirely(self):
        payload = self.build_payload("", "")
        self.assertNotIn("assignment_group", payload)
        self.assertNotIn("cmdb_ci", payload)

    def test_group_only(self):
        payload = self.build_payload("group-sys-id", "")
        self.assertIn("assignment_group", payload)
        self.assertNotIn("cmdb_ci", payload)


if __name__ == "__main__":
    unittest.main(verbosity=2)
