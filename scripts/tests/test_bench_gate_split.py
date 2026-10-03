#!/usr/bin/env python3
"""Unit tests of the gas gate after task LIB-05 M1-T1c: no baseline (every test obeys the rule), the
selection of one package, the evidence kept for the drift, the comparison of two runs, and the gas
table. Pure functions over rows and fixture directories: no snforge run.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import contextlib
import io
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

    def test_an_ignored_test_with_a_budget_and_no_row_is_an_error(self) -> None:
        bad = bench.budget_violations(pk(a=row(None, 5000, ran=False)))
        self.assertEqual(len(bad), 1)
        self.assertIn("cannot be verified", bad[0])

    def test_snforge_is_asked_for_the_ignored_tests_too(self) -> None:
        seen, envs = [], []

        class Done:
            returncode, stdout, stderr = 0, "Collected 0 test(s)\n", ""

        with mock.patch.object(bench.subprocess, "run", lambda cmd, **kw: seen.append(cmd) or envs.append(kw["env"]) or Done()), \
                mock.patch.object(bench, "write_evidence", lambda *args: None), \
                mock.patch.dict(bench.os.environ, {"RAYON_NUM_THREADS": "8"}):
            for scope, flag in (("all", "--include-ignored"), ("ignored", "--ignored")):
                bench.run_snforge("hexx", "check", scope=scope)
                self.assertIn(flag, seen[-1])
            bench.run_snforge("hexx", "check")
        self.assertNotIn("--include-ignored", seen[-1])
        self.assertNotIn("--ignored", seen[-1])
        self.assertEqual({e["RAYON_NUM_THREADS"] for e in envs}, {"1"})  # D-176

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

    def test_the_workspace_has_the_packages_of_the_ci_jobs(self) -> None:
        # The golden packages since LIB-04h: one test target each (AGENTS.md, "Golden tests").
        self.assertEqual(set(bench.workspace_packages()),
                         {"hexx", "takeover_tests", "consumer", "golden_hex", "golden_hex_t2",
                          "golden_impls", "golden_lm1", "golden_lm2", "golden_rings"})

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
    def write(self, dev: Path) -> None:
        dev.mkdir(parents=True, exist_ok=True)
        (dev / "hexx_unittest.test.sierra.json").write_text("sierra")
        (dev / "hexx_unittest.test.json").write_text("{}")
        (dev / "other_unittest.test.json").write_text("not this package")

    def test_raw_output_hashes_and_versions_are_kept_per_run(self) -> None:
        self.write(self.dir / "target" / "dev")
        with mock.patch.object(bench, "ROOT", self.dir), \
                mock.patch.object(bench, "ARTIFACTS", self.dir / "art"), \
                mock.patch.object(bench, "tool_version", lambda cmd: "1.2.3 " + cmd[0]):
            directory = bench.write_evidence("hexx", "raw output\n", "check")
            (self.dir / "target" / "dev" / "hexx_unittest.test.json").write_text("changed")
            bench.write_evidence("hexx", "second\n", "repeat-1")
        self.assertEqual((directory / "snforge-check.txt").read_text(), "raw output\n")
        self.assertEqual((directory / "snforge-repeat-1.txt").read_text(), "second\n")
        hashes = (directory / "artifacts-check.sha256").read_text().splitlines()
        self.assertEqual(len(hashes), 2)
        self.assertTrue(all("hexx_unittest" in line for line in hashes))
        # sha256("{}") is well known; the later run did not overwrite the earlier one
        self.assertIn("44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a  "
                      "target/dev/hexx_unittest.test.json", hashes)
        later = (directory / "artifacts-repeat-1.sha256").read_text()
        self.assertNotIn("44136fa3", later)
        versions = (directory / "versions.txt").read_text()
        for tool in ("scarb", "snforge", "universal-sierra-compiler"):
            self.assertIn(f"1.2.3 {tool}", versions)

    def test_a_missing_tool_is_reported_not_fatal(self) -> None:
        self.assertIn("unavailable", bench.tool_version(["definitely-not-a-tool-xyz"]))


class Repeat(Scratch):
    OUT = "Collected 2 test(s) from hexx package\n[PASS] hexx::d::a (l1_gas: ~0)\n" \
          "        sierra gas: {a}\n[PASS] hexx::d::b (l1_gas: ~0)\n        sierra gas: {b}\n"

    def run_repeat(self, first, second, hashes=("h", "h", "h")) -> tuple[int, str]:
        """`hashes`: the hash of the compiled file at the check, repeat 1, repeat 2."""
        art = self.dir / "art"
        (art / "hexx").mkdir(parents=True)
        (art / "hexx" / "artifacts-check.sha256").write_text(f"{hashes[0]}  target/dev/hexx_x.json\n")
        runs = iter([("repeat-1", first, hashes[1]), ("repeat-2", second, hashes[2])])

        def fake(package, label, test_filter=None, scope="regular"):
            expected, values, digest = next(runs)
            self.assertEqual(label, expected)
            self.assertEqual(scope, "regular")
            (art / package / f"artifacts-{label}.sha256").write_text(
                f"{digest}  target/dev/hexx_x.json\n")
            return self.OUT.format(a=values[0], b=values[1])

        err = io.StringIO()
        with mock.patch.object(bench, "ARTIFACTS", art), mock.patch.object(bench, "ROOT", self.dir), \
                mock.patch.object(bench, "run_snforge", fake), contextlib.redirect_stderr(err):
            return bench.repeat("hexx", "d"), err.getvalue()

    def test_identical_runs_on_identical_files_pass(self) -> None:
        status, out = self.run_repeat((10, 20), (10, 20))
        self.assertEqual(status, 0, out)
        self.assertIn("identical to those of check", out)

    def test_different_measurements_fail(self) -> None:
        status, out = self.run_repeat((10, 20), (10, 21))
        self.assertEqual(status, 1)
        self.assertIn("hexx::d::b: run 1 (20, True), run 2 (21, True)", out)

    def test_different_compiled_files_are_said_and_fail_even_with_equal_measurements(self) -> None:
        status, out = self.run_repeat((10, 20), (10, 20), hashes=("h", "h", "other"))
        self.assertEqual(status, 1)
        self.assertIn("THE COMPILED FILES OF repeat-2 DIFFER FROM THOSE OF check", out)
        self.assertIn("target/dev/hexx_x.json: check h, repeat-2 other", out)

    def test_no_test_matched_fails(self) -> None:
        art = self.dir / "art"
        (art / "hexx").mkdir(parents=True)
        with mock.patch.object(bench, "ARTIFACTS", art), mock.patch.object(bench, "ROOT", self.dir), \
                mock.patch.object(bench, "run_snforge", lambda *a, **k: "Collected 0 test(s)\n"), \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(bench.repeat("hexx", "nothing"), 1)


class Scopes(Scratch):
    """`hexx` is measured in two CI jobs, the tests without `#[ignore]` and the ignored ones."""

    def make(self) -> Path:
        pkg = self.dir / "pkg"
        (pkg / "src").mkdir(parents=True)
        (pkg / "src" / "lib.cairo").write_text(
            "#[test]\n#[available_gas(l2_gas: 10)]\nfn a() {}\n\n"
            "#[test]\n#[ignore] // printout\n#[available_gas(l2_gas: 20)]\nfn b() {}\n")
        return pkg

    def test_ignored_tests_are_found_in_the_sources(self) -> None:
        ignored: set[str] = set()
        declared = bench.declared_tests("p", self.make(), ignored)
        self.assertEqual(declared, {"p::a": 10, "p::b": 20})
        self.assertEqual(ignored, {"p::b"})

    def test_collect_keeps_the_tests_of_the_scope_and_all_are_collected(self) -> None:
        pkg = self.make()
        out = "Collected 1 test(s) from p package\n[PASS] p::b (l1_gas: ~0)\n        sierra gas: 19\n"
        with mock.patch.object(bench, "select_packages", lambda only: {"p": pkg}), \
                mock.patch.object(bench, "run_snforge", lambda *a, **k: out):
            packages, infos = bench.collect("p", "check", "ignored")
        self.assertEqual(set(packages["p"]), {"p::b"})
        self.assertEqual(infos["p"]["declared"], 1)  # `--ignored` collects only the ignored tests
        self.assertEqual(bench.reconcile(packages, infos)[0], [])
        with mock.patch.object(bench, "select_packages", lambda only: {"p": pkg}), \
                mock.patch.object(bench, "run_snforge", lambda *a, **k: out.replace("p::b", "p::a")):
            packages, infos = bench.collect("p", "check", "regular")
        self.assertEqual(infos["p"]["declared"], 2)  # the others are collected and ignored by snforge
        self.assertEqual(set(packages["p"]), {"p::a"})

    def test_a_scope_compares_only_its_snapshot_rows(self) -> None:
        (self.dir / "p.snap").write_text(
            "# gas: measured budget\np::a: 10 10\np::b: 20 20\np::gone: 5 6\n")
        infos = {"p": {"ignored_names": {"p::b"}, "all_names": {"p::a", "p::b"}}}
        with mock.patch.object(bench, "GAS", self.dir):
            regular = bench.snapshot_differences({"p": {"p::a": row(10, 10)}}, infos, "regular")
            ignored = bench.snapshot_differences({"p": {"p::b": row(20, 20)}}, infos, "ignored")
        # the row of a test that no longer exists is reported by both
        self.assertEqual([line.split(": ")[0] for line in regular], ["REMOVED p::gone"])
        self.assertEqual([line.split(": ")[0] for line in ignored], ["REMOVED p::gone"])

    def test_snapshot_needs_the_whole_scope(self) -> None:
        with mock.patch.object(bench.sys, "argv", ["bench.py", "snapshot", "--scope", "ignored"]):
            with self.assertRaises(SystemExit):
                bench.main()


class CheckPrintsEverything(unittest.TestCase):
    def test_a_violation_does_not_hide_the_snapshot_differences_nor_the_evidence(self) -> None:
        packages = {"hexx": {"hexx::a": row(2000, 1000)}}
        err = io.StringIO()
        with mock.patch.object(bench, "collect", lambda *a: (packages, {"hexx": {
                "collected": 1, "declared": 1}})), \
                mock.patch.object(bench, "read_snapshots", lambda only=None: {
                    "hexx::a": {"measured": 1500, "declared": 1000}}), \
                mock.patch.object(bench.sys, "argv", ["bench.py", "check", "--package", "hexx"]), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            status = bench.main()
        out = err.getvalue()
        self.assertEqual(status, 1)
        self.assertIn("below its measurement", out)
        self.assertIn("snapshot measured 1500", out)
        self.assertIn("now measured 2000", out)
        self.assertIn("target/gas-artifacts/hexx", out)


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
