#!/usr/bin/env python3
"""Unit tests of the gas gate after the audit of M1-T1a (fix loop 1): fuzz measurements, discovery
of attributes followed by a comment, the reconciliation of counts, the approved set of inherited
tests. `fixtures/snforge_*.txt` are real outputs of `snforge test --detailed-resources` (snforge
0.61.0, this repository, captured 2026-09-29), kept verbatim.

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
import takeover_check as tc  # noqa: E402

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"
TMP_ROOT = HERE / "tmp"


def row(measured, declared, passed=True, ran=None, ignored=False, is_declared=True):
    ran = measured is not None if ran is None else ran
    return {"measured": measured, "declared": declared,
            "passed": None if measured is None else passed, "ran": ran, "ignored": ignored,
            "is_declared": is_declared}


class ParseRealOutput(unittest.TestCase):
    def test_fuzz_test_is_measured_by_its_maximum(self) -> None:
        out = bench.parse_output((FIXTURES / "snforge_fuzz.txt").read_text())
        name = "hexx::tests::bench_spreader::bench_spreader_generate_empty_17x14_1"
        self.assertEqual(out.ran, {name: True})
        self.assertEqual(out.measured, {name: (186639, True)})
        self.assertEqual(out.collected, 1)

    def test_plain_test_is_measured_by_its_sierra_gas(self) -> None:
        out = bench.parse_output((FIXTURES / "snforge_plain.txt").read_text())
        name = "hexx::tests::properties::test_properties_hexagon"
        self.assertEqual(out.measured, {name: (12113482, True)})

    def test_ignored_tests_are_listed_and_not_measured(self) -> None:
        out = bench.parse_output((FIXTURES / "snforge_ignored.txt").read_text())
        self.assertEqual(out.ran, {})
        self.assertEqual(out.measured, {})
        self.assertEqual(sorted(out.ignored), [
            "hexx::tests::bench_caver::test_bench_caver_print_fills",
            "hexx::tests::bench_caver::test_bench_caver_print_rules",
            "hexx::tests::bench_caver::test_bench_caver_print_stats"])
        self.assertEqual(out.collected, 3)

    def test_a_test_that_ran_without_a_readable_measurement_is_ran_but_not_measured(self) -> None:
        out = bench.parse_output("Collected 1 test(s) from hexx package\n"
                                 "[PASS] hexx::t::odd (something unforeseen: ~5)\n")
        self.assertEqual(out.ran, {"hexx::t::odd": True})
        self.assertEqual(out.measured, {})


class FuzzRules(unittest.TestCase):
    def test_the_maximum_is_held_to_the_rules(self) -> None:
        # max 186639: ceil(1.05 x) = 195971
        self.assertEqual(bench.budget_violations({"hexx": {"f": row(186639, 195971)}}), [])
        over = bench.budget_violations({"hexx": {"f": row(186639, 196000)}})
        self.assertEqual(len(over), 1)
        self.assertIn("more than 5 %", over[0])
        below = bench.budget_violations({"hexx": {"f": row(186639, 186000)}})
        self.assertIn("below its measurement", below[0])

    def test_ran_without_measurement_is_an_error_even_with_a_budget(self) -> None:
        # The audit's scenario: measured None, declared 2000: used to return [].
        bad = bench.budget_violations({"hexx": {"hexx::fuzz": row(None, 2000, ran=True)}}, set())
        self.assertEqual(len(bad), 1)
        self.assertIn("no gas measurement could be parsed", bad[0])

    def test_ran_without_measurement_is_an_error_in_the_baseline_too(self) -> None:
        bad = bench.budget_violations({"hexx": {"hexx::fuzz": row(None, None, ran=True)}},
                                      {"hexx::fuzz"})
        self.assertTrue(any("no gas measurement could be parsed" in b for b in bad))


class Discovery(unittest.TestCase):
    def setUp(self) -> None:
        self.pkg = TMP_ROOT / type(self).__name__ / self._testMethodName
        shutil.rmtree(self.pkg, ignore_errors=True)
        (self.pkg / "src").mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.pkg, ignore_errors=True)

    def test_attribute_followed_by_a_comment(self) -> None:
        (self.pkg / "src" / "lib.cairo").write_text(
            "#[test]\n#[ignore] // Printouts: `snforge test x --include-ignored`\nfn a() {}\n\n"
            "#[test]\n// a comment line between\n#[available_gas(l2_gas: 5)]\nfn b() {}\n\n"
            "#[test]\n#[fuzzer(seed: 7)] // fuzz\n#[available_gas(l2_gas: 9)]\nfn c(k: u16) {}\n")
        self.assertEqual(bench.declared_tests("p", self.pkg), {"p::a": None, "p::b": 5, "p::c": 9})

    def test_the_three_caver_tests_of_the_audit_are_discovered(self) -> None:
        found = bench.declared_tests("hexx", bench.ROOT / "crates" / "hexx")
        for name in ("print_stats", "print_rules", "print_fills"):
            self.assertIn(f"hexx::tests::bench_caver::test_bench_caver_{name}", found)
        self.assertEqual(len(found), 811)


class Reconcile(unittest.TestCase):
    def test_counts_agree(self) -> None:
        packages = {"hexx": {"a": row(10, 11), "b": row(None, 5, ignored=True)}}
        bad, lines = bench.reconcile(packages, {"hexx": {"collected": 2, "declared": 2}})
        self.assertEqual(bad, [])
        self.assertEqual(lines, ["hexx: declared 2, collected 2, with a gas row 1, ignored 1"])

    def test_declared_differs_from_collected(self) -> None:
        packages = {"hexx": {"a": row(10, 11)}}
        bad, _ = bench.reconcile(packages, {"hexx": {"collected": 2, "declared": 1}})
        self.assertEqual(len(bad), 1)
        self.assertIn("1 tests declared in the sources but snforge collected 2", bad[0])

    def test_ran_without_a_row(self) -> None:
        bad, _ = bench.reconcile({"hexx": {"a": row(None, 5, ran=True)}},
                                 {"hexx": {"collected": 1, "declared": 1}})
        self.assertEqual(len(bad), 1)
        self.assertIn("ran but no gas measurement", bad[0])

    def test_declared_neither_run_nor_ignored(self) -> None:
        bad, _ = bench.reconcile({"hexx": {"a": row(None, 5)}},
                                 {"hexx": {"collected": 1, "declared": 1}})
        self.assertEqual(len(bad), 1)
        self.assertIn("neither ran nor ignored", bad[0])

    def test_reported_by_snforge_but_not_discovered(self) -> None:
        bad, _ = bench.reconcile({"hexx": {"a": row(10, 11, is_declared=False)}},
                                 {"hexx": {"collected": 1, "declared": 0}})
        self.assertEqual(len(bad), 2)


class ApprovedSet(unittest.TestCase):
    def test_entry_outside_the_approved_set_is_an_error(self) -> None:
        packages = {"hexx": {"hexx::new": row(1000, None), "hexx::old": row(1000, None)}}
        # the audit's scenario: a test author adds `hexx::new` to the baseline by hand
        bad = bench.budget_violations(packages, {"hexx::new", "hexx::old"}, {"hexx::old"})
        self.assertEqual(len(bad), 1)
        self.assertIn("hexx::new", bad[0])
        self.assertIn("not a test inherited", bad[0])

    def test_inherited_entries_are_accepted(self) -> None:
        packages = {"hexx": {"hexx::old": row(1000, None)}}
        self.assertEqual(bench.budget_violations(packages, {"hexx::old"}, {"hexx::old"}), [])

    def test_baseline_command_refuses_a_new_test_even_with_the_flag(self) -> None:
        packages = {"hexx": {"hexx::new": row(1000, None), "hexx::old": row(1000, None)}}
        with self.assertRaises(SystemExit) as ctx:
            bench.baseline_update({"hexx::old"}, packages, allow_growth=True,
                                  approved={"hexx::old"})
        self.assertIn("not inherited", str(ctx.exception))
        new, growth = bench.baseline_update({"hexx::old"}, packages, allow_growth=True,
                                            approved={"hexx::old", "hexx::new"})
        self.assertEqual((new, growth), ({"hexx::old", "hexx::new"}, ["hexx::new"]))


class Inherited(unittest.TestCase):
    def setUp(self) -> None:
        self.root = TMP_ROOT / type(self).__name__ / self._testMethodName
        shutil.rmtree(self.root, ignore_errors=True)
        self.source = self.root / "hexmap"
        (self.source / "src").mkdir(parents=True)
        (self.source / "tests").mkdir()
        (self.source / "src" / "map.cairo").write_text(
            "use origami_hexmap::helpers::bits::Bits;\n\n#[cfg(test)]\nmod tests {\n"
            "    #[test]\n    #[available_gas(l2_gas: 5)]\n    fn test_map_a() {}\n\n"
            "    #[test]\n    #[ignore] // why\n    fn test_map_b() {}\n}\n")
        (self.source / "tests" / "readme.cairo").write_text(
            "use origami_hexmap::{HexMap, U252Trait, u252};\n\n#[test]\nfn test_readme_x() {}\n\n"
            "#[test]\nfn test_readme_u252() {\n    let x = 1;\n}\n\n#[test]\nfn test_readme_y() {}\n")
        self.pairs = [("src/map.cairo", "src/board/map.cairo"),
                      ("tests/readme.cairo", "tests/readme.cairo")]
        self.list = self.root / "takeover-tests.txt"

    def tearDown(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)

    def inherited(self) -> set[str]:
        with mock.patch.object(tc, "PAIRS", self.pairs):
            return bench.inherited_tests(self.source)

    def test_names_follow_the_destination_module_path(self) -> None:
        self.assertEqual(self.inherited(), {
            "hexx::board::map::tests::test_map_a", "hexx::board::map::tests::test_map_b",
            "hexx_integrationtest::readme::test_readme_x",
            "hexx_integrationtest::readme::test_readme_y"})  # no test_readme_u252

    def test_committed_list_is_used_without_a_source(self) -> None:
        self.list.write_text(bench.render_inherited({"hexx::a", "hexx::b"}))
        names, origin = bench.approved_inherited(None, self.list)
        self.assertEqual(names, {"hexx::a", "hexx::b"})
        self.assertEqual(origin, "takeover-tests.txt")
        names, _ = bench.approved_inherited(self.root / "absent", self.list)
        self.assertEqual(names, {"hexx::a", "hexx::b"})

    def test_neither_source_nor_list_is_an_error(self) -> None:
        with self.assertRaises(SystemExit):
            bench.approved_inherited(None, self.list)

    def test_source_wins_and_must_agree_with_the_list(self) -> None:
        proved = []
        with mock.patch.object(tc, "PAIRS", self.pairs):
            self.list.write_text(bench.render_inherited(self.inherited()))
            names, _ = bench.approved_inherited(self.source, self.list, proof=proved.append)
            self.assertEqual(names, self.inherited())
            self.assertEqual(proved, [self.source])  # the move was proved first
            # a hand-extended list is caught where the source is available
            self.list.write_text(bench.render_inherited(self.inherited() | {"hexx::new"}))
            with self.assertRaises(SystemExit) as ctx:
                bench.approved_inherited(self.source, self.list, proof=lambda s: None)
            self.assertIn("disagrees with the source", str(ctx.exception))

    def test_a_failing_proof_of_the_move_is_an_error(self) -> None:
        def refuse(source: Path) -> None:
            raise SystemExit("scripts/takeover_check.py does not prove the move")
        with self.assertRaises(SystemExit):
            bench.approved_inherited(self.source, self.list, proof=refuse)

    def test_committed_list_matches_the_pinned_source_when_present(self) -> None:
        if not (bench.DEFAULT_SOURCE / "src" / "map.cairo").is_file():
            self.skipTest("no checkout of the pinned source")
        self.assertEqual(bench.read_inherited(), bench.inherited_tests(bench.DEFAULT_SOURCE))


if __name__ == "__main__":
    unittest.main()
