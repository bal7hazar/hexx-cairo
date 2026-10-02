#!/usr/bin/env python3
"""Unit tests of the partitions of the gas gate (task LIB-04c): the partition argument, the share
that `check` measures, the comparison with its snapshot rows only, and the completeness of the
partitions of a package (a test in no partition, a test in two, a stale row). No snforge run.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import argparse
import contextlib
import io
import json
import shutil
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bench  # noqa: E402

TMP_ROOT = Path(__file__).resolve().parent / "tmp"


def report(index, total, *names, package="p", scope="regular"):
    return {"package": package, "scope": scope, "partition": [index, total],
            "measured": list(names), "path": "r" + str(index)}


class Scratch(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = TMP_ROOT / type(self).__name__ / self._testMethodName
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.dir, ignore_errors=True)


class PartitionArgument(unittest.TestCase):
    def test_index_over_total(self) -> None:
        self.assertEqual(bench.parse_partition("2/3"), (2, 3))

    def test_malformed_or_out_of_range_is_refused(self) -> None:
        for text in ("0/3", "4/3", "3", "a/b", "1/", "1/3/3"):
            with self.assertRaises(argparse.ArgumentTypeError, msg=text):
                bench.parse_partition(text)

    def test_snforge_gets_the_partition(self) -> None:
        seen = []

        class Done:
            returncode, stdout, stderr = 0, "Collected 0 test(s)\n", ""

        def fake_run(cmd, **kwargs):
            seen.append(cmd)
            return Done()

        with mock.patch.object(bench.subprocess, "run", fake_run), \
                mock.patch.object(bench, "write_evidence", lambda *a: None), \
                contextlib.redirect_stderr(io.StringIO()):
            bench.run_snforge("hexx", "check", scope="regular", partition=(2, 3))
            bench.run_snforge("hexx", "check", scope="regular")
        self.assertEqual(seen[0][-2:], ["--partition", "2/3"])
        self.assertNotIn("--partition", seen[1])


class ShareOfAPackage(Scratch):
    def make(self) -> Path:
        pkg = self.dir / "pkg"
        (pkg / "src").mkdir(parents=True)
        (pkg / "src" / "lib.cairo").write_text("".join(
            "#[test]\n#[available_gas(l2_gas: %d)]\nfn t%d() {}\n\n" % (10 * i, i)
            for i in (1, 2, 3)))
        return pkg

    OUT = ("Running partition run: 1/2\nCollected 2 test(s) from p package\n"
           "[PASS] p::t1 (l1_gas: ~0)\n        sierra gas: 10\n"
           "[PASS] p::t3 (l1_gas: ~0)\n        sierra gas: 30\n")

    def collect(self):
        pkg = self.make()
        with mock.patch.object(bench, "select_packages", lambda only: {"p": pkg}), \
                mock.patch.object(bench, "run_snforge", lambda *a, **k: self.OUT):
            return bench.collect("p", "check", "regular", (1, 2))

    def test_only_the_tests_of_the_share_are_rows_and_the_count_agrees(self) -> None:
        packages, infos = self.collect()
        self.assertEqual(set(packages["p"]), {"p::t1", "p::t3"})
        self.assertEqual(bench.reconcile(packages, infos)[0], [])

    def test_a_count_that_disagrees_is_still_an_error(self) -> None:
        packages, infos = self.collect()
        infos["p"]["collected"] = 3
        self.assertEqual(len(bench.reconcile(packages, infos)[0]), 1)

    def test_a_test_the_sources_do_not_declare_is_an_error(self) -> None:
        pkg = self.make()
        out = self.OUT + "[PASS] p::ghost (l1_gas: ~0)\n        sierra gas: 1\n"
        with mock.patch.object(bench, "select_packages", lambda only: {"p": pkg}), \
                mock.patch.object(bench, "run_snforge", lambda *a, **k: out):
            packages, infos = bench.collect("p", "check", "regular", (1, 2))
        self.assertTrue(any("p::ghost" in e for e in bench.reconcile(packages, infos)[0]))

    def test_only_the_rows_of_the_share_are_compared(self) -> None:
        (self.dir / "p.snap").write_text(
            "# gas: measured budget\np::t1: 10 10\np::t2: 20 20\np::t3: 30 30\np::gone: 5 6\n")
        packages, infos = self.collect()
        with mock.patch.object(bench, "GAS", self.dir):
            self.assertEqual(bench.snapshot_differences(packages, infos, "regular", True), [])
            # without a partition the rows of the other shares read as removed
            whole = bench.snapshot_differences(packages, infos, "regular")
        self.assertEqual([x.split(": ")[0] for x in whole],
                         ["REMOVED p::gone", "REMOVED p::t2"])

    def test_a_moved_row_of_the_share_is_still_reported(self) -> None:
        (self.dir / "p.snap").write_text("# gas: measured budget\np::t1: 11 12\np::t3: 30 30\n")
        packages, infos = self.collect()
        with mock.patch.object(bench, "GAS", self.dir):
            bad = bench.snapshot_differences(packages, infos, "regular", True)
        self.assertEqual(len(bad), 1)
        self.assertIn("CHANGED p::t1", bad[0])

    def test_the_names_measured_are_kept_for_the_completeness_job(self) -> None:
        packages, _ = self.collect()
        with mock.patch.object(bench, "ARTIFACTS", self.dir / "art"):
            bench.write_partition_reports(packages, "regular", (1, 2))
            found = bench.read_partition_reports(self.dir / "art")
        self.assertEqual(len(found), 1)
        self.assertEqual((found[0]["package"], found[0]["scope"], found[0]["partition"]),
                         ("p", "regular", [1, 2]))
        self.assertEqual(found[0]["measured"], ["p::t1", "p::t3"])


class Completeness(unittest.TestCase):
    DECLARED = {"p::a", "p::b", "p::c"}

    def check(self, reports, declared=None, snapshot=None, total=2):
        declared = self.DECLARED if declared is None else declared
        return bench.completeness("p", "regular", total, reports, declared,
                                  declared if snapshot is None else snapshot)

    def test_every_test_once_is_complete(self) -> None:
        self.assertEqual(self.check([report(1, 2, "p::a", "p::c"), report(2, 2, "p::b")]), [])

    def test_a_test_removed_from_every_partition_fails(self) -> None:
        bad = self.check([report(1, 2, "p::a"), report(2, 2, "p::b")])
        self.assertEqual(bad, ["p::c: declared, measured in no partition",
                               "p::c: a row of gas/p.snap that no partition measured (stale)"])

    def test_a_test_measured_twice_fails(self) -> None:
        bad = self.check([report(1, 2, "p::a", "p::b"), report(2, 2, "p::b", "p::c")])
        self.assertEqual(len(bad), 1)
        self.assertIn("p::b: measured 2 times, in partitions 1/2, 2/2", bad[0])

    def test_a_stale_snapshot_row_fails(self) -> None:
        bad = self.check([report(1, 2, "p::a", "p::c"), report(2, 2, "p::b")],
                         snapshot=self.DECLARED | {"p::gone"})
        self.assertEqual(bad, ["p::gone: a row of gas/p.snap that no partition measured (stale)"])

    def test_a_missing_or_repeated_partition_report_fails(self) -> None:
        missing = self.check([report(1, 2, "p::a", "p::b", "p::c")])
        self.assertIn("partition 2/2 left no report", missing)
        again = dict(report(2, 2), path="again")
        twice = self.check([report(1, 2, "p::a", "p::b", "p::c"), report(2, 2), again])
        self.assertIn("partition 2/2 has 2 reports", twice)

    def test_a_test_measured_that_the_sources_do_not_declare_fails(self) -> None:
        bad = self.check([report(1, 2, "p::a", "p::c"), report(2, 2, "p::b", "p::x")])
        self.assertEqual(bad, ["p::x: measured but not declared in the sources"])

    def test_a_report_of_another_total_or_scope_fails(self) -> None:
        bad = self.check([report(1, 3, "p::a"),
                          report(1, 2, "p::a", "p::b", "p::c", scope="ignored"), report(2, 2)])
        self.assertTrue(any("not of p regular in 2 partitions" in line for line in bad))
        self.assertIn("partition 1/2 left no report", bad)


class CompleteCommand(Scratch):
    def make(self) -> Path:
        pkg = self.dir / "pkg"
        (pkg / "src").mkdir(parents=True)
        (pkg / "src" / "lib.cairo").write_text(
            "#[test]\n#[available_gas(l2_gas: 10)]\nfn a() {}\n\n"
            "#[test]\n#[available_gas(l2_gas: 10)]\nfn b() {}\n\n"
            "#[test]\n#[ignore]\n#[available_gas(l2_gas: 10)]\nfn c() {}\n")
        return pkg

    def run_complete(self, reports, snap) -> tuple[int, str]:
        pkg = self.make()
        art = self.dir / "dl"
        for i, r in enumerate(reports):
            (art / ("gas-" + str(i))).mkdir(parents=True)
            name = "partition-%s-%dof%d.json" % (r["scope"], r["partition"][0], r["partition"][1])
            (art / ("gas-" + str(i)) / name).write_text(json.dumps(r))
        (self.dir / "p.snap").write_text("# gas: measured budget\n" + snap)
        err = io.StringIO()
        with mock.patch.object(bench, "select_packages", lambda only: {"p": pkg}), \
                mock.patch.object(bench, "GAS", self.dir), contextlib.redirect_stderr(err):
            return bench.complete("p", "regular", 2, art), err.getvalue()

    SNAP = "p::a: 10 10\np::b: 10 10\np::c: 10 10\n"

    def test_the_ignored_tests_are_not_the_scope_of_regular(self) -> None:
        status, out = self.run_complete(
            [report(1, 2, "p::a"), report(2, 2, "p::b")], self.SNAP)
        self.assertEqual(status, 0, out)

    def test_a_missing_test_fails_through_the_reports_read_from_disk(self) -> None:
        status, out = self.run_complete([report(1, 2, "p::a"), report(2, 2)], self.SNAP)
        self.assertEqual(status, 1)
        self.assertIn("p::b: declared, measured in no partition", out)

    def test_a_stale_row_fails(self) -> None:
        status, out = self.run_complete(
            [report(1, 2, "p::a"), report(2, 2, "p::b")], self.SNAP + "p::gone: 1 2\n")
        self.assertEqual(status, 1)
        self.assertIn("p::gone", out)


class OnlyItsOwnEvidence(Scratch):
    """A gas job uploads `target/gas-artifacts/<package>/`; in CI setup-scarb restores `target/`
    from the cache another gas job saved, with that job's evidence and partition report
    (t-0018: `gas-hexx-regular-p2of6-.../partition-ignored-3of3.json`). `check` empties the
    directory of the package it measures before measuring."""

    def test_a_restored_report_of_another_job_is_gone_before_the_check_measures(self) -> None:
        art = self.dir / "art"
        (art / "p").mkdir(parents=True)
        (art / "p" / "partition-ignored-3of3.json").write_text("{}\n")
        (art / "p" / "snforge-check.txt").write_text("another job\n")
        (art / "other").mkdir()
        (art / "other" / "versions.txt").write_text("kept\n")
        seen = []

        def collect(*args, **kwargs):
            seen.append(sorted(art.rglob("*")))
            raise SystemExit(0)

        argv = ["bench.py", "check", "--package", "p", "--scope", "regular", "--partition", "2/6"]
        with mock.patch.object(bench, "ARTIFACTS", art), \
                mock.patch.object(bench, "select_packages", lambda only: {"p": self.dir}), \
                mock.patch.object(bench, "collect", collect), mock.patch.object(sys, "argv", argv), \
                self.assertRaises(SystemExit):
            bench.main()
        self.assertEqual(seen, [[art / "other", art / "other" / "versions.txt"]])

    def test_repeat_keeps_the_evidence_of_the_check(self) -> None:
        art = self.dir / "art"
        (art / "hexx").mkdir(parents=True)
        (art / "hexx" / "artifacts-check.sha256").write_text("h  target/dev/hexx_x.json\n")
        argv = ["bench.py", "repeat", "--package", "hexx"]
        with mock.patch.object(bench, "ARTIFACTS", art), \
                mock.patch.object(bench, "select_packages", lambda only: {"hexx": self.dir}), \
                mock.patch.object(bench, "repeat", lambda *a: 0), mock.patch.object(sys, "argv", argv):
            self.assertEqual(bench.main(), 0)
        self.assertTrue((art / "hexx" / "artifacts-check.sha256").is_file())


if __name__ == "__main__":
    unittest.main()
