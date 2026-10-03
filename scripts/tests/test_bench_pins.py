#!/usr/bin/env python3
"""Unit tests of the pins CI publishes (task LIB-04i): the report every `check` leaves, whatever
its verdict; the assembly of the reports of all the gas jobs into snapshots, budgets and a
manifest (`pins`); and their application to the tree (`apply-pins`): the budget written into
`#[available_gas(l2_gas: N)]` or inserted, a generated golden package left alone. No snforge run.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

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


def report(package, scope, index, total, rows, unmeasured=()):
    return {"package": package, "scope": scope, "partition": [index, total],
            "rows": {n: {"measured": m, "declared": d, "passed": True} for n, (m, d) in rows.items()},
            "unmeasured": list(unmeasured), "path": f"{package}-{scope}-{index}"}


class Scratch(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = TMP_ROOT / type(self).__name__ / self._testMethodName
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.dir, ignore_errors=True)

    def write(self, rel: str, text: str) -> Path:
        path = self.dir / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path


class BudgetRule(unittest.TestCase):
    def test_a_budget_the_rule_accepts_is_kept(self) -> None:
        self.assertEqual(bench.budget_for(100, 100), 100)
        self.assertEqual(bench.budget_for(100, 105), 105)
        self.assertEqual(bench.budget_for(100, 103), 103)

    def test_a_missing_too_high_or_too_low_budget_becomes_the_ceiling(self) -> None:
        self.assertEqual(bench.budget_for(100, None), 105)
        self.assertEqual(bench.budget_for(100, 106), 105)
        self.assertEqual(bench.budget_for(100, 99), 105)
        self.assertEqual(bench.budget_for(1001, 10**9), 1052)  # ceil(1051.05)


class PinsReport(Scratch):
    def test_check_rows_are_written_with_the_measured_and_the_unmeasured(self) -> None:
        rows = {"p": {
            "p::a": {"measured": 10, "declared": None, "passed": True, "ran": True,
                     "ignored": False, "is_declared": True},
            "p::b": {"measured": 20, "declared": 21, "passed": False, "ran": True,
                     "ignored": False, "is_declared": True},
            "p::c": {"measured": None, "declared": 5, "passed": None, "ran": True,
                     "ignored": False, "is_declared": True},
        }}
        with mock.patch.object(bench, "ARTIFACTS", self.dir):
            bench.write_pins_reports(rows, "regular", (2, 6))
            bench.write_pins_reports(rows, "all", None)
        found = bench.read_pins_reports(self.dir)
        self.assertEqual([(r["scope"], r["partition"]) for r in found],
                         [("all", [1, 1]), ("regular", [2, 6])])
        self.assertEqual(found[0]["rows"], {
            "p::a": {"measured": 10, "declared": None, "passed": True},
            "p::b": {"measured": 20, "declared": 21, "passed": False}})
        self.assertEqual(found[0]["unmeasured"], ["p::c"])


class Assembly(unittest.TestCase):
    def test_a_package_in_partitions_of_two_scopes_is_one_snapshot(self) -> None:
        reports = [report("hexx", "regular", i, 2, {f"hexx::r{i}": (100 * i, 100 * i)})
                   for i in (1, 2)]
        reports.append(report("hexx", "ignored", 1, 1, {"hexx::i": (50, None)}))
        rows, budgets, incomplete, unmeasured = bench.assemble_pins(reports)
        self.assertEqual(incomplete, {})
        self.assertEqual(rows["hexx"], {"hexx::r1": {"measured": 100, "declared": 100},
                                        "hexx::r2": {"measured": 200, "declared": 200},
                                        "hexx::i": {"measured": 50, "declared": 53}})
        self.assertEqual(budgets, {"hexx::i": 53})
        self.assertEqual(unmeasured, [])

    def test_a_missing_partition_or_scope_leaves_the_package_out(self) -> None:
        reports = [report("hexx", "regular", 1, 2, {"hexx::a": (1, 1)}),
                   report("c", "regular", 1, 1, {"c::a": (1, 1)}),
                   report("ok", "all", 1, 1, {"ok::a": (1, 1)})]
        rows, _, incomplete, _ = bench.assemble_pins(reports)
        self.assertEqual(sorted(rows), ["ok"])
        self.assertEqual(incomplete["hexx"], ["scope regular: partition 2/2 has 0 reports",
                                              "no report of scope ignored"])
        self.assertEqual(incomplete["c"], ["no report of scope ignored"])

    def test_a_repeated_partition_is_incomplete(self) -> None:
        reports = [report("p", "all", 1, 1, {"p::a": (1, 1)}),
                   report("p", "all", 1, 1, {"p::a": (2, 2)})]
        _, _, incomplete, _ = bench.assemble_pins(reports)
        self.assertIn("scope all: partition 1/1 has 2 reports", incomplete["p"])
        self.assertIn("p::a: measured twice, differently", incomplete["p"])

    def test_the_unmeasured_tests_are_listed(self) -> None:
        _, _, _, unmeasured = bench.assemble_pins(
            [report("p", "all", 1, 1, {}, unmeasured=["p::slow"])])
        self.assertEqual(unmeasured, ["p::slow"])


class PinsCommand(Scratch):
    def test_the_artefact_holds_snapshots_budgets_bytecode_size_and_manifest(self) -> None:
        reports = self.dir / "reports"
        for r in (report("p", "all", 1, 1, {"p::a": (100, None), "p::b": (10, 10)}),
                  report("q", "regular", 1, 1, {"q::a": (1, 1)})):
            self.write(f"reports/gas-{r['package']}/pins-{r['scope']}-1of1.json", json.dumps(r))
        self.write("reports/gas-consumer-all-x/bytecode.size", "# contract: x\nHexxSink: 1 2 3 4\n")
        out = self.dir / "out"
        with contextlib.redirect_stderr(io.StringIO()):
            status = bench.pins(reports, out, {"head": "h", "merge": "m", "base": "b"})
        self.assertEqual(status, 0)
        self.assertEqual((out / "gas" / "p.snap").read_text(),
                         "# gas: measured budget\np::a: 100 105\np::b: 10 10\n")
        self.assertFalse((out / "gas" / "q.snap").exists())
        self.assertEqual((out / "gas" / "bytecode.size").read_text(),
                         "# contract: x\nHexxSink: 1 2 3 4\n")
        self.assertEqual(json.loads((out / "budgets.json").read_text()), {"p::a": 105})
        manifest = json.loads((out / "manifest.json").read_text())
        self.assertEqual((manifest["head"], manifest["merge"], manifest["base"]), ("h", "m", "b"))
        self.assertEqual(manifest["snapshots"], ["p"])
        self.assertEqual(list(manifest["incomplete"]), ["q"])
        self.assertTrue(manifest["bytecode_size"])

    def test_the_snapshot_text_is_that_of_write_snapshots(self) -> None:
        rows = {"p": {"p::b": {"measured": 2, "declared": 3}, "p::a": {"measured": 1,
                                                                        "declared": None}}}
        with mock.patch.object(bench, "GAS", self.dir), \
                contextlib.redirect_stderr(io.StringIO()):
            bench.write_snapshots(rows)
        self.assertEqual((self.dir / "p.snap").read_text(), bench.snapshot_text(rows["p"]))


SOURCE = (
    "pub fn f() {}\n\n"
    "#[cfg(test)]\nmod tests {\n"
    "    #[test]\n    #[available_gas(l2_gas: 1)]\n    fn same() {}\n\n"
    "    #[test]\n    fn bare() {}\n\n"
    "    mod inner {\n"
    "        #[test]\n        #[available_gas(l2_gas: 7)]\n        fn same() {}\n"
    "    }\n"
    "}\n"
)


class ApplyBudgets(Scratch):
    def test_budgets_replace_or_insert_and_inline_modules_are_told_apart(self) -> None:
        lib = self.write("pkg/src/lib.cairo", SOURCE)
        self.write("pkg/tests/flat.cairo", "#[test]\nfn it() {}\n")
        sites = bench.test_sites("pkg", self.dir / "pkg")
        missing = bench.apply_budgets({"pkg::tests::bare": 42, "pkg::tests::inner::same": 99,
                                       "pkg_integrationtest::flat::it": 5, "pkg::gone": 1}, sites)
        self.assertEqual(missing, ["pkg::gone"])
        text = lib.read_text()
        self.assertIn("    #[test]\n    #[available_gas(l2_gas: 42)]\n    fn bare() {}", text)
        self.assertIn("        #[available_gas(l2_gas: 99)]\n        fn same() {}", text)
        self.assertIn("    #[available_gas(l2_gas: 1)]\n    fn same() {}", text)
        self.assertEqual((self.dir / "pkg/tests/flat.cairo").read_text(),
                         "#[test]\n#[available_gas(l2_gas: 5)]\nfn it() {}\n")
        self.assertEqual(bench.declared_tests("pkg", self.dir / "pkg"), {
            "pkg::tests::same": 1, "pkg::tests::bare": 42, "pkg::tests::inner::same": 99,
            "pkg_integrationtest::flat::it": 5})


class ApplyPins(Scratch):
    def test_gas_files_copied_budgets_applied_golden_printed(self) -> None:
        lib = self.write("crates/pkg/src/lib.cairo", SOURCE)
        art = self.dir / "art"
        self.write("art/gas/pkg.snap", "# gas: measured budget\npkg::tests::bare: 40 42\n")
        self.write("art/gas/bytecode.size", "# contract: x\n")
        self.write("art/budgets.json", json.dumps({"pkg::tests::bare": 42,
                                                   "golden_x_integrationtest::g::t": 9}))
        self.write("art/manifest.json", json.dumps({"head": "h", "incomplete": {},
                                                    "unmeasured": []}))
        gas = self.dir / "gas"
        gas.mkdir()
        err = io.StringIO()
        with mock.patch.object(bench, "GAS", gas), \
                mock.patch.object(bench, "workspace_packages",
                                  lambda: {"pkg": self.dir / "crates/pkg"}), \
                contextlib.redirect_stderr(err):
            status = bench.apply_pins(art)
        self.assertEqual(sorted(p.name for p in gas.iterdir()), ["bytecode.size", "pkg.snap"])
        self.assertIn("#[available_gas(l2_gas: 42)]\n    fn bare()", lib.read_text())
        self.assertIn("golden_x_integrationtest::g::t: 9", err.getvalue())
        self.assertEqual(status, 1)  # the golden budget is left to the thread

    def test_a_clean_artefact_applies_with_status_zero(self) -> None:
        self.write("crates/pkg/src/lib.cairo", SOURCE)
        art = self.dir / "art"
        self.write("art/gas/pkg.snap", "# gas: measured budget\n")
        self.write("art/budgets.json", "{}")
        self.write("art/manifest.json", json.dumps({"incomplete": {}, "unmeasured": []}))
        gas = self.dir / "gas"
        gas.mkdir()
        with mock.patch.object(bench, "GAS", gas), \
                mock.patch.object(bench, "workspace_packages",
                                  lambda: {"pkg": self.dir / "crates/pkg"}), \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(bench.apply_pins(art), 0)


if __name__ == "__main__":
    unittest.main()
