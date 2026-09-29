#!/usr/bin/env python3
"""Unit tests of the gas gate after task LIB-05 M1-T1c: no baseline (every test obeys the rule), the
selection of one package, the evidence kept for the drift, the comparison of two runs, and the gas
table. Pure functions over rows and fixture directories: no snforge run.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import shutil
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bench  # noqa: E402
import gas_tables  # noqa: E402

TMP_ROOT = Path(__file__).resolve().parent / "tmp"


def row(measured, declared, passed=True, ran=None):
    ran = measured is not None if ran is None else ran
    return {"measured": measured, "declared": declared,
            "passed": None if measured is None else passed, "ran": ran, "ignored": False,
            "is_declared": True}


def pk(**rows):
    return {"hexx": rows}


class Scratch(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = TMP_ROOT / type(self).__name__ / self._testMethodName
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.dir, ignore_errors=True)


class EveryTestObeysTheRule(unittest.TestCase):
    def test_a_conformant_test_is_accepted(self) -> None:
        self.assertEqual(bench.budget_violations(pk(a=row(1000, 1050), b=row(1000, 1000))), [])
        self.assertEqual(bench.budget_violations(pk(a=row(None, 5000, ran=False))), [])

    def test_no_test_is_exempt(self) -> None:
        packages = pk(over=row(1000, 2000), none=row(1000, None), ign=row(None, None, ran=False),
                      below=row(1000, 900), failed=row(1000, 1050, passed=False))
        self.assertEqual(len(bench.budget_violations(packages)), 5)

    def test_there_is_no_baseline_left(self) -> None:
        for name in ("BASELINE", "read_baseline", "baseline_update", "nonconformant",
                     "INHERITED", "approved_inherited", "takeover_proof"):
            self.assertFalse(hasattr(bench, name), name)
        self.assertFalse((bench.GAS / "takeover-baseline.txt").exists())
        self.assertFalse((bench.GAS / "takeover-tests.txt").exists())


class PackageSelection(Scratch):
    def test_all_packages_by_default_and_one_on_request(self) -> None:
        packages = bench.workspace_packages()
        self.assertEqual(set(bench.select_packages(None)), set(packages))
        self.assertEqual(list(bench.select_packages("hexx")), ["hexx"])

    def test_an_unknown_package_is_an_error(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            bench.select_packages("nope")
        self.assertIn("unknown package", str(ctx.exception))

    def test_the_workspace_has_the_three_packages_of_the_ci_jobs(self) -> None:
        self.assertEqual(set(bench.workspace_packages()), {"hexx", "takeover_tests", "consumer"})

    def test_snapshot_rewrites_only_the_packages_measured(self) -> None:
        (self.dir / "hexx.snap").write_text("# gas: measured budget\nhexx::old: 1 2\n")
        (self.dir / "consumer.snap").write_text("# gas: measured budget\nconsumer::x: 3 4\n")
        with mock.patch.object(bench, "GAS", self.dir):
            bench.write_snapshots({"hexx": {"hexx::a": row(10, 11)}})
        self.assertEqual((self.dir / "hexx.snap").read_text(),
                         "# gas: measured budget\nhexx::a: 10 11\n")
        self.assertEqual((self.dir / "consumer.snap").read_text(),
                         "# gas: measured budget\nconsumer::x: 3 4\n")

    def test_the_snapshot_read_is_that_of_the_packages_measured(self) -> None:
        (self.dir / "hexx.snap").write_text("# gas: measured budget\nhexx::a: 1 2\n")
        (self.dir / "consumer.snap").write_text("# gas: measured budget\nconsumer::x: 3 4\n")
        with mock.patch.object(bench, "GAS", self.dir):
            self.assertEqual(set(bench.read_snapshots(["consumer"])), {"consumer::x"})
            self.assertEqual(set(bench.read_snapshots()), {"hexx::a", "consumer::x"})


class SnapshotDifferences(Scratch):
    def test_a_moved_measurement_names_the_test_and_both_figures(self) -> None:
        (self.dir / "hexx.snap").write_text(
            "# gas: measured budget\nhexx::a: 1000 1050\nhexx::b: 2000 2100\nhexx::gone: 5 6\n")
        packages = {"hexx": {"hexx::a": row(1011, 1062), "hexx::b": row(2000, 2100),
                             "hexx::c": row(7, 8)}}
        with mock.patch.object(bench, "GAS", self.dir):
            bad = bench.snapshot_differences(packages)
        self.assertEqual(len(bad), 3, bad)
        changed = [line for line in bad if line.startswith("CHANGED")][0]
        self.assertIn("hexx::a", changed)
        self.assertIn("snapshot measured 1000", changed)
        self.assertIn("now measured 1011 (+1.10 %)", changed)
        self.assertTrue(any(line.startswith("ADDED") and "hexx::c" in line for line in bad))
        self.assertTrue(any(line.startswith("REMOVED") and "hexx::gone" in line for line in bad))

    def test_no_difference(self) -> None:
        (self.dir / "hexx.snap").write_text("# gas: measured budget\nhexx::a: 1000 1050\n")
        with mock.patch.object(bench, "GAS", self.dir):
            self.assertEqual(bench.snapshot_differences({"hexx": {"hexx::a": row(1000, 1050)}}), [])


class Evidence(Scratch):
    def test_raw_output_hashes_and_versions_are_kept(self) -> None:
        dev = self.dir / "target" / "dev"
        dev.mkdir(parents=True)
        (dev / "hexx_unittest.test.sierra.json").write_text("sierra")
        (dev / "hexx_unittest.test.json").write_text("{}")
        (dev / "other_unittest.test.json").write_text("not this package")
        with mock.patch.object(bench, "ROOT", self.dir), \
                mock.patch.object(bench, "ARTIFACTS", self.dir / "art"), \
                mock.patch.object(bench, "tool_version", lambda cmd: "1.2.3 " + cmd[0]):
            directory = bench.write_evidence("hexx", "raw output\n")
        self.assertEqual((directory / "snforge-detailed-resources.txt").read_text(), "raw output\n")
        hashes = (directory / "artifacts.sha256").read_text().splitlines()
        self.assertEqual(len(hashes), 2)
        self.assertTrue(all("hexx_unittest" in line for line in hashes))
        # sha256("{}") is well known
        self.assertIn("44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a  "
                      "target/dev/hexx_unittest.test.json", hashes)
        versions = (directory / "versions.txt").read_text()
        for tool in ("scarb", "snforge", "universal-sierra-compiler"):
            self.assertIn(f"1.2.3 {tool}", versions)

    def test_a_missing_tool_is_reported_not_fatal(self) -> None:
        self.assertIn("unavailable", bench.tool_version(["definitely-not-a-tool-xyz"]))


class Repeat(unittest.TestCase):
    OUT = "Collected 2 test(s) from hexx package\n[PASS] hexx::d::a (l1_gas: ~0)\n" \
          "        sierra gas: {a}\n[PASS] hexx::d::b (l1_gas: ~0)\n        sierra gas: {b}\n"

    def run_repeat(self, first: tuple[int, int], second: tuple[int, int]) -> int:
        outputs = iter([self.OUT.format(a=first[0], b=first[1]),
                        self.OUT.format(a=second[0], b=second[1])])
        with mock.patch.object(bench, "run_snforge", lambda *args: next(outputs)):
            return bench.repeat("hexx", "d")

    def test_identical_runs_pass(self) -> None:
        self.assertEqual(self.run_repeat((10, 20), (10, 20)), 0)

    def test_different_runs_fail(self) -> None:
        self.assertEqual(self.run_repeat((10, 20), (10, 21)), 1)

    def test_no_test_matched_fails(self) -> None:
        with mock.patch.object(bench, "run_snforge", lambda *args: "Collected 0 test(s)\n"):
            self.assertEqual(bench.repeat("hexx", "nothing"), 1)


class GasTables(unittest.TestCase):
    def test_a_test_without_budget_and_a_stale_one_are_shown_plainly(self) -> None:
        text = gas_tables.render({"hexx": {"t::a": (1000, None), "t::b": (1000, 2000),
                                           "t::c": (1000, 1050)}})
        self.assertIn("| `t::a` | 1,000 | none | — |", text)
        self.assertIn("| `t::b` | 1,000 | 2,000 | 100.0 % (stale: exceeds the rule) |", text)
        self.assertIn("| `t::c` | 1,000 | 1,050 | 5.0 % |", text)
        self.assertIn("3 measured test(s).", text)
        self.assertNotIn("inherited", text)

    def test_snapshot_line_with_none_is_parsed_by_both_readers(self) -> None:
        tmp = TMP_ROOT / "GasTables" / "snap"
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir(parents=True)
        (tmp / "hexx.snap").write_text("# gas: measured budget\nhexx::t::a: 1000 None\n"
                                       "hexx::t::b: 5 6\n")
        old_bench, old_tables = bench.GAS, gas_tables.GAS
        bench.GAS = gas_tables.GAS = tmp
        try:
            self.assertEqual(bench.read_snapshots()["hexx::t::a"],
                             {"measured": 1000, "declared": None})
            self.assertEqual(gas_tables.read_snapshots()["hexx"]["hexx::t::a"], (1000, None))
            self.assertEqual(gas_tables.read_snapshots()["hexx"]["hexx::t::b"], (5, 6))
        finally:
            bench.GAS, gas_tables.GAS = old_bench, old_tables
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
