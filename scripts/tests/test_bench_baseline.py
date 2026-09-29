#!/usr/bin/env python3
"""Unit tests of the take-over baseline (scripts/bench.py `baseline`, `check`; scripts/gas_tables.py),
task LIB-05 M1-T1a follow-up 1. Pure functions over rows: no snforge run.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bench  # noqa: E402
import gas_tables  # noqa: E402

TMP_ROOT = Path(__file__).resolve().parent / "tmp"


def row(measured, declared, passed=True):
    return {"measured": measured, "declared": declared,
            "passed": None if measured is None else passed}


def pk(**rows):
    return {"hexx": rows}


class Conformance(unittest.TestCase):
    def test_conformant(self) -> None:
        self.assertTrue(bench.conformant(row(1000, 1050)))
        self.assertTrue(bench.conformant(row(1000, 1000)))
        self.assertTrue(bench.conformant(row(None, 5000)))  # ignored with a budget: unjudgeable

    def test_not_conformant(self) -> None:
        self.assertFalse(bench.conformant(row(1000, 1051)))
        self.assertFalse(bench.conformant(row(1000, None)))
        self.assertFalse(bench.conformant(row(None, None)))

    def test_nonconformant_set(self) -> None:
        packages = pk(a=row(1000, 1050), b=row(1000, 2000), c=row(1000, None), d=row(None, None))
        self.assertEqual(bench.nonconformant(packages), {"b", "c", "d"})


class Check(unittest.TestCase):
    def test_not_in_baseline_obeys_every_rule(self) -> None:
        packages = pk(over=row(1000, 2000), none=row(1000, None), ign=row(None, None),
                      below=row(1000, 900), failed=row(1000, 1050, passed=False))
        bad = bench.budget_violations(packages, set())
        self.assertEqual(len(bad), 5, bad)

    def test_baseline_exempts_the_two_rules(self) -> None:
        packages = pk(over=row(1000, 2000), none=row(1000, None), ign=row(None, None))
        self.assertEqual(bench.budget_violations(packages, {"over", "none", "ign"}), [])

    def test_baseline_still_fails_below_budget_and_failed_tests(self) -> None:
        packages = pk(below=row(1000, 900), failed=row(1000, None, passed=False))
        bad = bench.budget_violations(packages, {"below", "failed"})
        # `below` is also reported as conformant (a stale baseline entry): three messages
        self.assertEqual(len(bad), 3, bad)
        self.assertTrue(any("below its measurement" in b for b in bad))
        self.assertTrue(any("test failed" in b for b in bad))

    def test_baseline_does_not_cover_another_test(self) -> None:
        packages = pk(over=row(1000, 2000), other=row(1000, 2000))
        bad = bench.budget_violations(packages, {"over"})
        self.assertEqual(len(bad), 1)
        self.assertIn("other", bad[0])

    def test_baseline_test_that_became_conformant_is_an_error(self) -> None:
        bad = bench.budget_violations(pk(fixed=row(1000, 1050)), {"fixed"})
        self.assertEqual(len(bad), 1)
        self.assertIn("conformant now", bad[0])
        self.assertIn("bench.py baseline", bad[0])

    def test_baseline_test_that_no_longer_exists_is_an_error(self) -> None:
        bad = bench.budget_violations(pk(a=row(1000, 1050)), {"gone"})
        self.assertEqual(len(bad), 1)
        self.assertIn("does not exist any more", bad[0])
        self.assertIn("bench.py baseline", bad[0])

    def test_no_baseline_file_is_an_empty_baseline(self) -> None:
        self.assertEqual(bench.budget_violations(pk(a=row(1000, 1050)), None), [])
        self.assertEqual(len(bench.budget_violations(pk(a=row(1000, None)), None)), 1)


class BaselineCommand(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = TMP_ROOT / type(self).__name__ / self._testMethodName
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_bootstrap_without_file(self) -> None:
        new, growth = bench.baseline_update(None, pk(a=row(1000, 2000), b=row(1000, 1000)))
        self.assertEqual(new, {"a"})
        self.assertEqual(growth, [])

    def test_shrinks(self) -> None:
        new, growth = bench.baseline_update({"a", "b"}, pk(a=row(1000, 2000), b=row(1000, 1000)))
        self.assertEqual((new, growth), ({"a"}, []))

    def test_refuses_growth(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            bench.baseline_update({"a"}, pk(a=row(1000, 2000), c=row(1000, None)))
        self.assertIn("refuses", str(ctx.exception))
        self.assertIn("c", str(ctx.exception))

    def test_growth_with_the_flag(self) -> None:
        new, growth = bench.baseline_update({"a"}, pk(a=row(1000, 2000), c=row(1000, None)),
                                            allow_growth=True)
        self.assertEqual((new, growth), ({"a", "c"}, ["c"]))

    def test_file_round_trip_sorted_with_header(self) -> None:
        path = self.dir / "takeover-baseline.txt"
        text = bench.render_baseline({"z::b", "a::c", "m::a"})
        path.write_text(text)
        self.assertEqual(bench.read_baseline(path), {"z::b", "a::c", "m::a"})
        body = [line for line in text.splitlines() if not line.startswith("#")]
        self.assertEqual(body, ["a::c", "m::a", "z::b"])
        header = text.split("a::c")[0]
        for phrase in ("Take-over baseline", "Generated by", "only shrinks", "M1-T1c empties it"):
            self.assertIn(phrase, header)

    def test_missing_file_reads_as_none(self) -> None:
        self.assertIsNone(bench.read_baseline(self.dir / "absent.txt"))


class GasTables(unittest.TestCase):
    def test_no_crash_on_a_test_without_budget(self) -> None:
        text = gas_tables.render({"hexx": {"t::a": (1000, None), "t::b": (1000, 2000),
                                           "t::c": (1000, 1050)}}, {"t::a", "t::b"})
        self.assertIn("| `t::a` | 1,000 | none (inherited) | — |", text)
        self.assertIn("| `t::b` | 1,000 | 2,000 | 100.0 % (inherited) |", text)
        self.assertIn("| `t::c` | 1,000 | 1,050 | 5.0 % |", text)
        self.assertIn("3 measured test(s), 2 inherited", text)

    def test_not_inherited_without_budget_is_not_called_inherited(self) -> None:
        text = gas_tables.render({"hexx": {"t::a": (1000, None)}}, set())
        self.assertIn("| `t::a` | 1,000 | none | — |", text)
        self.assertNotIn("none (inherited)", text)

    def test_snapshot_line_with_none_is_parsed_by_both_readers(self) -> None:
        line = "hexx::t::a: 1000 None"
        name, vals = line.rsplit(":", 1)
        measured, budget = vals.split()
        self.assertEqual((measured, budget), ("1000", "None"))
        # the two readers, on a real file
        tmp = TMP_ROOT / "GasTables" / "snap"
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir(parents=True)
        (tmp / "hexx.snap").write_text("# gas: measured budget\n" + line + "\nhexx::t::b: 5 6\n")
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
