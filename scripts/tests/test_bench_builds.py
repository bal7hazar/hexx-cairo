"""Tests of the second observed builds of a test (gas/<package>.builds, D-164 extended to the gas
gate): the snapshot's value or the exact recorded second value passes, anything else fails."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bench  # noqa: E402

T = "p::t::a"
SNAP, SECOND, BUDGET = 1000, 1010, 1050


def row(measured, declared=BUDGET):
    return {"measured": measured, "declared": declared, "passed": True, "ran": True,
            "ignored": False, "is_declared": True}


class SecondBuild(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)
        (self.dir / "p.snap").write_text(
            f"# gas: measured budget\n{T}: {SNAP} {BUDGET}\n")
        self.write(f"{T}: {SECOND}  # CI run 1\n")

    def write(self, text: str) -> None:
        (self.dir / "p.builds").write_text(text)

    def patched(self):
        return mock.patch.multiple(bench, GAS=self.dir, ROOT=self.dir)

    def diff(self, measured, declared=BUDGET, second=None):
        with self.patched():
            return bench.snapshot_differences({"p": {T: row(measured, declared)}}, None, "all",
                                              False, second)

    def read(self):
        with self.patched():
            return bench.read_builds()

    def test_the_snapshot_value_passes(self) -> None:
        second: list[str] = []
        self.assertEqual(self.diff(SNAP, second=second), [])
        self.assertEqual(second, [])

    def test_the_exact_second_value_passes_and_is_reported(self) -> None:
        second: list[str] = []
        self.assertEqual(self.diff(SECOND, second=second), [])
        self.assertEqual(len(second), 1)
        self.assertTrue(second[0].startswith(f"SECOND BUILD {T}"))

    def test_a_third_value_fails(self) -> None:
        for value in (SNAP + 1, SECOND - 1, SECOND + 1, SNAP - 1):
            bad = self.diff(value)
            self.assertEqual(len(bad), 1, value)
            self.assertTrue(bad[0].startswith("CHANGED"))

    def test_a_changed_budget_with_the_second_value_fails(self) -> None:
        self.assertTrue(self.diff(SECOND, declared=BUDGET + 1)[0].startswith("CHANGED"))

    def test_without_a_builds_file_the_second_value_fails(self) -> None:
        (self.dir / "p.builds").unlink()
        self.assertTrue(self.diff(SECOND)[0].startswith("CHANGED"))

    def test_the_file_parses(self) -> None:
        self.assertEqual(self.read(), {T: SECOND})

    def test_a_malformed_line_fails_loudly(self) -> None:
        for text in (f"{T} {SECOND}\n", f"{T}: abc\n", f"{T}:\n", f": {SECOND}\n", f"{T}: 1 2\n"):
            self.write(text)
            with self.assertRaises(SystemExit, msg=text):
                self.read()

    def test_a_duplicated_line_fails_loudly(self) -> None:
        self.write(f"{T}: {SECOND}\n{T}: {SECOND + 1}\n")
        with self.assertRaises(SystemExit):
            self.read()

    def test_a_row_absent_from_the_snapshot_fails_loudly(self) -> None:
        self.write(f"p::t::missing: {SECOND}\n")
        with self.assertRaises(SystemExit):
            self.read()

    def test_a_value_equal_to_the_snapshot_fails_loudly(self) -> None:
        self.write(f"{T}: {SNAP}\n")
        with self.assertRaises(SystemExit):
            self.read()

    def test_only_the_packages_measured_are_read(self) -> None:
        with self.patched():
            self.assertEqual(bench.read_builds(["q"]), {})


class Committed(unittest.TestCase):
    def test_the_committed_file_has_the_40_rows_and_parses(self) -> None:
        builds = bench.read_builds(["takeover_tests"])
        self.assertEqual(len(builds), 40)
        snap = bench.read_snapshots(["takeover_tests"])
        for name, value in builds.items():
            self.assertLessEqual(value, snap[name]["declared"], name)


if __name__ == "__main__":
    unittest.main()
