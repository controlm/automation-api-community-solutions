#!/usr/bin/env python3
# Filename: test_ctm_job_report.py
"""
Test script for ctm_job_report.py - no network calls, no live Control-M
instance required. Covers build_job_report's degrade-on-failure behavior,
save_job_report's write path, and main()'s alert-type gating (only 'job'
alerts get a report; everything else is a no-op, mirroring
ctm_to_snow_incident.py's own scope decisions).

Run with:  python3 test_ctm_job_report.py
"""

import json
import os
import shutil
import unittest
from unittest.mock import patch

import ctm_client
from ctm_job_report import (
    build_job_report,
    save_job_report,
    load_report_tracking,
    JOB_REPORT_DIR,
    JOB_REPORT_TRACKING_FILE,
)

JOB_ALERT = {
    "data_center": "ctm-lin-srv",
    "order_id": "0039s",
    "job_name": "ZZM PreFlight Check",
    "alert_id": "2256",
}


def _cleanup_data_dir():
    if os.path.isdir(JOB_REPORT_DIR):
        shutil.rmtree(JOB_REPORT_DIR)
    if os.path.exists(JOB_REPORT_TRACKING_FILE):
        os.remove(JOB_REPORT_TRACKING_FILE)


class TestBuildJobReport(unittest.TestCase):
    """
    build_job_report enrichment: skips API calls entirely when
    CONTROLM_URL isn't configured, fetches all three when it is, and
    degrades individual fields (not the whole report) on a per-call
    failure - this pipeline's only job is the report, so a partial
    Control-M outage should still produce whatever it can.
    """

    def test_unconfigured_controlm_skips_api_calls_entirely(self):
        with patch.object(ctm_client, "get_job_status") as gs:
            report = build_job_report({"CONTROLM_URL": "", "CONTROLM_API_KEY": ""}, JOB_ALERT)
        gs.assert_not_called()
        self.assertEqual(report["alert"], JOB_ALERT)
        self.assertNotIn("job_status", report)

    def test_configured_fetches_all_three_with_correct_args(self):
        ctm_config = {"CONTROLM_URL": "https://ctm.example.com/automation-api", "CONTROLM_API_KEY": "tok"}
        with patch.object(ctm_client, "get_job_status", return_value={"status": "Ended OK"}) as gs, \
             patch.object(ctm_client, "get_job_log", return_value="log text") as gl, \
             patch.object(ctm_client, "get_job_output", return_value="output text") as go:
            report = build_job_report(ctm_config, JOB_ALERT)

        gs.assert_called_once_with(ctm_config, "ctm-lin-srv", "0039s")
        gl.assert_called_once_with(ctm_config, "ctm-lin-srv", "0039s")
        go.assert_called_once_with(ctm_config, "ctm-lin-srv", "0039s", run_no=0)
        self.assertEqual(report["job_status"], {"status": "Ended OK"})
        self.assertEqual(report["job_log"], "log text")
        self.assertEqual(report["job_output"], "output text")

    def test_one_call_failing_does_not_affect_the_others(self):
        ctm_config = {"CONTROLM_URL": "https://ctm.example.com/automation-api", "CONTROLM_API_KEY": "tok"}
        with patch.object(ctm_client, "get_job_status", side_effect=RuntimeError("HTTP 500 - boom")), \
             patch.object(ctm_client, "get_job_log", return_value="log text"), \
             patch.object(ctm_client, "get_job_output", return_value="output text"):
            report = build_job_report(ctm_config, JOB_ALERT)

        self.assertIsNone(report["job_status"])
        self.assertIn("HTTP 500 - boom", report["job_status_error"])
        self.assertEqual(report["job_log"], "log text")
        self.assertEqual(report["job_output"], "output text")


class TestSaveJobReport(unittest.TestCase):
    """save_job_report: writes to data/job_reports/<alert_id>.json and
    never raises - a disk error here must be logged, not crash the run."""

    def tearDown(self):
        _cleanup_data_dir()

    def test_writes_report_keyed_by_alert_id(self):
        report = {"alert": JOB_ALERT, "job_status": {"status": "Ended OK"}}

        path = save_job_report(JOB_ALERT, report)

        self.assertEqual(path, os.path.join(JOB_REPORT_DIR, "2256.json"))
        with open(path) as f:
            on_disk = json.load(f)
        self.assertEqual(on_disk, report)

    def test_write_failure_returns_empty_string_not_a_crash(self):
        with patch("builtins.open", side_effect=OSError("disk full")):
            path = save_job_report(JOB_ALERT, {"alert": JOB_ALERT})
        self.assertEqual(path, "")


class TestMainAlertTypeGating(unittest.TestCase):
    """
    main() only ever writes a report for 'job'-classified alerts - agent
    and other alert types are a clean no-op here (the incident pipeline,
    not this one, is what handles them).
    """

    def setUp(self):
        _cleanup_data_dir()
        self._saved_argv = list(__import__("sys").argv)

    def tearDown(self):
        _cleanup_data_dir()
        import sys
        sys.argv = self._saved_argv

    def _run_main_with_args(self, ctm_args):
        import sys
        import ctm_job_report
        sys.argv = ["ctm_job_report.py"] + ctm_args
        with patch.object(ctm_client, "get_job_status", return_value={"status": "Ended OK"}), \
             patch.object(ctm_client, "get_job_log", return_value="log text"), \
             patch.object(ctm_client, "get_job_output", return_value="output text"):
            return ctm_job_report.main()

    def test_job_alert_writes_a_report(self):
        exit_code = self._run_main_with_args([
            "call_type:", "I", "alert_id:", "9001", "status:", "Not_Noticed",
            "data_center:", "ctm-lin-srv", "order_id:", "0039s",
            "job_name:", "ZZM PreFlight Check", "message:", "Ended not OK",
        ])
        self.assertEqual(exit_code, 0)
        self.assertTrue(os.path.exists(os.path.join(JOB_REPORT_DIR, "9001.json")))
        self.assertEqual(load_report_tracking()["9001"]["action"], "wrote_job_report")

    def test_agent_alert_is_a_no_op(self):
        exit_code = self._run_main_with_args([
            "call_type:", "I", "alert_id:", "9002", "status:", "Not_Noticed",
            "data_center:", "ctm-lin-srv", "order_id:", "00000", "job_name:", "",
            "message:", "STATUS OF AGENT PLATFORM ctm-lin-em.werkstatt.local CHANGED TO UNAVAILABLE",
        ])
        self.assertEqual(exit_code, 0)
        self.assertFalse(os.path.exists(JOB_REPORT_DIR))
        self.assertEqual(load_report_tracking()["9002"]["action"], "skipped_not_a_job_alert")

    def test_duplicate_alert_id_is_skipped_second_time(self):
        args = [
            "call_type:", "I", "alert_id:", "9003", "status:", "Not_Noticed",
            "data_center:", "ctm-lin-srv", "order_id:", "0039s",
            "job_name:", "ZZM PreFlight Check", "message:", "Ended not OK",
        ]
        self._run_main_with_args(args)
        report_path = os.path.join(JOB_REPORT_DIR, "9003.json")
        mtime_first = os.path.getmtime(report_path)

        with patch.object(ctm_client, "get_job_status") as gs:
            exit_code = self._run_main_with_args(args)
            gs.assert_not_called()

        self.assertEqual(exit_code, 0)
        self.assertEqual(os.path.getmtime(report_path), mtime_first)


if __name__ == "__main__":
    unittest.main(verbosity=2)
