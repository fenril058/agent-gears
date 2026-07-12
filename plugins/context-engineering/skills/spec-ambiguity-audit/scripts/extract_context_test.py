#!/usr/bin/env python3
"""Unit tests for extract_context.py.

Run: python3 extract_context_test.py
"""

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parent / "extract_context.py"

spec = importlib.util.spec_from_file_location("extract_context", SCRIPT)
extract_context = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extract_context)


class ParseRangeTest(unittest.TestCase):
    def test_single_line(self):
        self.assertEqual(extract_context.parse_range("5"), (5, 5))

    def test_span(self):
        self.assertEqual(extract_context.parse_range("10-12"), (10, 12))

    def test_reversed_span_rejected(self):
        with self.assertRaises(ValueError):
            extract_context.parse_range("8-3")

    def test_zero_rejected(self):
        with self.assertRaises(ValueError):
            extract_context.parse_range("0")

    def test_negative_rejected(self):
        with self.assertRaises(ValueError):
            extract_context.parse_range("-3")


class MergeRangesTest(unittest.TestCase):
    def test_expands_by_margin(self):
        merged = extract_context.merge_ranges([(5, 5, "a")], margin=2, max_line=100)
        self.assertEqual(merged, [(3, 7, ["a"])])

    def test_clamps_to_file_length(self):
        merged = extract_context.merge_ranges([(18, 20, "a")], margin=5, max_line=20)
        self.assertEqual(merged, [(13, 20, ["a"])])

    def test_merges_overlapping_windows(self):
        merged = extract_context.merge_ranges(
            [(5, 5, "a"), (7, 7, "b")], margin=1, max_line=100
        )
        self.assertEqual(merged, [(4, 8, ["a", "b"])])

    def test_merges_adjacent_windows(self):
        # window a ends at 6, window b starts at 7: adjacent, must merge into one.
        merged = extract_context.merge_ranges(
            [(5, 5, "a"), (8, 8, "b")], margin=1, max_line=100
        )
        self.assertEqual(merged, [(4, 9, ["a", "b"])])

    def test_keeps_disjoint_windows_separate(self):
        merged = extract_context.merge_ranges(
            [(5, 5, "a"), (50, 50, "b")], margin=1, max_line=100
        )
        self.assertEqual(merged, [(4, 6, ["a"]), (49, 51, ["b"])])


class CliTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.file = Path(self.tmp.name) / "sample.txt"
        self.file.write_text("\n".join(str(n) for n in range(1, 21)) + "\n")

    def run_cli(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(self.file), *args],
            capture_output=True,
            text=True,
        )

    def test_normal_extraction(self):
        result = self.run_cli("--margin", "1", "--range", "10")
        self.assertEqual(result.returncode, 0)
        self.assertIn("=== 行 9-11", result.stdout)

    def test_out_of_range_citation_is_an_error(self):
        result = self.run_cli("--range", "999")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("beyond the file's 20 lines", result.stderr)

    def test_reversed_range_is_an_error(self):
        result = self.run_cli("--range", "8-3")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("start must be <= end", result.stderr)

    def test_empty_file_is_an_error(self):
        empty = Path(self.tmp.name) / "empty.txt"
        empty.write_text("")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(empty), "--range", "1"],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is empty", result.stderr)

    def test_no_ranges_is_an_error(self):
        result = self.run_cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no ranges given", result.stderr)


if __name__ == "__main__":
    unittest.main()
