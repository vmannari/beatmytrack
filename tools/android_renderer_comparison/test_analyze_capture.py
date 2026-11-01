"""Offline regression tests for renderer-probe evidence analysis."""
import base64
import json
import unittest
from pathlib import Path
from unittest.mock import patch

import analyze_capture as analysis


def log(line):
    return {"type":"probe_log", "line":line}


def report_rows(report):
    encoded = base64.b64encode(json.dumps(report).encode()).decode()
    chunks = [encoded[i:i+20] for i in range(0, len(encoded), 20)]
    return [log(f"BMT_PERF_CHUNK {i}/{len(chunks)} {chunk}") for i,chunk in enumerate(chunks)]


class AnalysisTests(unittest.TestCase):
    def test_sentinels_and_no_fabricated_cross_poll_edges(self):
        report = {"renderer":"gl_compatibility", "requested_renderer":"gl_compatibility", "finished":True,
                  "expected_cases":1, "cases":[{"phase":"load_star_first"}], "errors":[]}
        first = "16666666\n1 1000000000 2\n1 1016000000 2\n1 1032000000 2\n1 9223372036854775807 2\n1 1900000000 2\n"
        second = "16666666\n1 2000000000 2\n1 2016000000 2\n1 0 2\n"
        rows = [{"type":"start", "package":"org.beatmytrack.rendererprobe.gl20261031"},
                log("BMT_PERF_BEGIN load_star_first"),
                {"type":"surface_poll", "phase":"load_star_first", "supported":True, "raw":first, "gap_ms":10},
                {"type":"surface_poll", "phase":"load_star_first", "supported":True, "raw":first, "gap_ms":20},
                {"type":"surface_poll", "phase":"load_star_first", "supported":True, "raw":second, "gap_ms":30},
                *report_rows(report), log("BMT_PERF_FINISHED 0"),
                {"type":"end", "finished":True, "gate_seen":True, "gate_start_seen":True}]
        result = analysis.analyze(rows)
        self.assertEqual(result["actual_renderer"], "gl_compatibility")
        self.assertEqual(result["surface"]["invalid_timestamp_rows"], 3)
        self.assertEqual(result["surface"]["successive_nonoverlap"], 1)
        self.assertEqual(result["surface"]["global_observed_edges"]["observed_edges"], 3)
        self.assertEqual(result["surface"]["global_observed_edges"]["max_ms"], 16.0)
        self.assertTrue(any("no common timestamp" in p for p in result["problems"]))

    def test_missing_or_conflicting_chunks_fail_closed(self):
        report = {"renderer":"mobile", "finished":True, "expected_cases":0, "cases":[], "errors":[]}
        chunks = report_rows(report)
        result, errors, _, _ = analysis.decode_report(chunks[:-1])
        self.assertIsNone(result)
        self.assertTrue(any("incomplete" in x for x in errors))
        result, errors, _, _ = analysis.decode_report(chunks + [log("BMT_PERF_CHUNK 0/%d different" % len(chunks))])
        self.assertIsNotNone(result) if not errors else self.assertTrue(any("Conflicting" in x for x in errors))

    def test_wrong_renderer_missing_markers_and_audit_are_not_acceptance(self):
        report = {"renderer":"gl_compatibility", "requested_renderer":"mobile", "finished":True,
                  "expected_cases":1, "cases":[{"phase":"load_star_first"}], "errors":[]}
        rows = [{"type":"start", "package":"org.beatmytrack.rendererprobe.vk20261031"},
                *report_rows(report), log("BMT_PERF_FINISHED 0"),
                {"type":"end", "finished":True, "gate_seen":False, "gate_start_seen":True}]
        result = analysis.analyze(rows)
        self.assertTrue(any("Actual renderer differs" in x for x in result["problems"]))
        self.assertTrue(any("gate-ready" in x for x in result["problems"]))
        self.assertTrue(any("Phase-begin" in x for x in result["problems"]))
        comparison = analysis.compare(result,result,{"unexpected":["assets/example"]})
        self.assertFalse(comparison["apk_static_content_audit_passed"])
        self.assertFalse(comparison["controlled_comparison_established"])
        self.assertIsNone(comparison["metadata"]["model"]["match"])

    def test_template_revision_is_scoped_and_checks_receipt(self):
        text = "EXIT=0\nTEMPLATE_REVISION=aaaa\nGENERATED_COMPACT_REVISION=bbbb\nREVISION_EQUAL=false\n"
        with patch.object(Path, "read_text", return_value=text):
            result = analysis.read_template_probe(Path("example.log"))
        self.assertTrue(result["probe_valid"])
        self.assertFalse(result["revision_equal"])
        self.assertIn("not observed runtime cache hit", result["scope"])
        with patch.object(Path, "read_text", return_value=text.replace("EXIT=0", "EXIT=1")):
            self.assertFalse(analysis.read_template_probe(Path("example.log"))["probe_valid"])


if __name__ == "__main__":
    unittest.main()
