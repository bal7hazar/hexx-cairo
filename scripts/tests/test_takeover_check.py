#!/usr/bin/env python3
"""Unit tests of scripts/takeover_check.py (task LIB-05 M1-T1a).

Fixture trees are written under `scripts/tests/tmp/` (repo-local, gitignored). The formatter is
replaced by the identity (`scarb` is not needed): what is tested is the table, the rewrites, and
the three failure modes.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import io
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import takeover_check as t  # noqa: E402

TMP_ROOT = Path(__file__).resolve().parent / "tmp"


def identity(files: dict[str, str]) -> dict[str, str]:
    return dict(files)


class Rewrites(unittest.TestCase):
    def test_import_paths(self) -> None:
        cases = {
            "use origami_hexmap::helpers::bits::Bits;": "use hexx::board::bits::Bits;",
            "use origami_hexmap::types::direction::Direction;":
                "use hexx::board::direction::Direction;",
            "use origami_hexmap::map::{HexMap, HexMapTrait};":
                "use hexx::board::map::{HexMap, HexMapTrait};",
            "use origami_hexmap::finders::bfs::Bfs;": "use hexx::finders::bfs::Bfs;",
            "use origami_hexmap::tests::fixtures::*;": "use hexx::tests::fixtures::*;",
            "use origami_hexmap::{Direction, HexMap};": "use hexx::{Direction, HexMap};",
        }
        for source, expected in cases.items():
            self.assertEqual(t.rewritten("src/x.cairo", source), expected)

    def test_prefix_of_another_name_is_not_a_module(self) -> None:
        self.assertEqual(t.rewritten("src/x.cairo", "use origami_hexmap::mapping::X;"),
                         "use hexx::mapping::X;")

    def test_british_helpers_renamed_at_calls(self) -> None:
        # M1-T3, plan §5.2: the three helpers, at their definitions and calls
        line = "let m = layout.neighbour_mask(i); layout.edge_neighbours(i); neighbour_in(i);"
        self.assertEqual(t.rewritten("src/x.cairo", line),
                         "let m = layout.neighbor_mask(i); layout.edge_neighbors(i); neighbor_in(i);")

    def test_british_helpers_kept_in_prose_and_longer_names(self) -> None:
        # Not a call: the prose of `GAS.md`, a bench and a variant whose names contain the helper
        for line in ("| `neighbour_mask`: 1 lookup |", "`Layout::edge_neighbours`, `Layout::neighbour_in`",
                     "fn bench_neighbour_mask() {", "Variants::neighbour_mask_lookups(17, n)"):
            self.assertEqual(t.rewritten("src/x.cairo", line), line)

    def test_readme_u252_removed(self) -> None:
        source = (
            "use origami_hexmap::{Direction, HexMap, HexMapTrait, U252Trait, u252};\n\n"
            "#[test]\nfn test_readme_a() {\n    assert!(true);\n}\n\n"
            "#[test]\nfn test_readme_u252() {\n    let x: u252 = 1.into();\n}\n\n"
            "#[test]\nfn test_readme_b() {\n    assert!(true);\n}\n")
        expected = (
            "use hexx::{Direction, HexMap, HexMapTrait};\n\n"
            "#[test]\nfn test_readme_a() {\n    assert!(true);\n}\n\n"
            "#[test]\nfn test_readme_b() {\n    assert!(true);\n}\n")
        self.assertEqual(t.rewritten("tests/readme.cairo", source), expected)

    def test_scarbignore_paths(self) -> None:
        source = "/src/helpers/printer.cairo\n/GAS.md\n/src/tests/\n"
        self.assertEqual(t.rewritten(".scarbignore", source),
                         "/src/board/printer.cairo\n/GAS-origami-1.8.0.md\n/src/tests/\n")

    def test_no_other_rewrite(self) -> None:
        # The complete list of the briefs: four import rules (M1-T1a), three renames (M1-T3).
        self.assertEqual(len(t.REWRITES), 7)


class Check(unittest.TestCase):
    def setUp(self) -> None:
        self.root = TMP_ROOT / type(self).__name__ / self._testMethodName
        shutil.rmtree(self.root, ignore_errors=True)
        self.src, self.dst = self.root / "src_tree", self.root / "dst_tree"
        for pair_src, pair_dst in t.PAIRS:
            self.put(self.src, pair_src, "use origami_hexmap::helpers::bits::Bits;\n"
                     if pair_src.endswith(".cairo") else "text\n")
            self.put(self.dst, pair_dst, "use hexx::board::bits::Bits;\n"
                     if pair_dst.endswith(".cairo") else "text\n")
        self.put(self.src, "src/tests/fixtures.cairo", "use origami_hexmap::map::X;\n")
        self.put(self.dst, "src/tests/fixtures.cairo", "use hexx::board::map::X;\n")
        # Text that the rewrites of the readme and of `.scarbignore` do not touch.
        self.put(self.src, ".scarbignore", "/src/tests/\n")
        self.put(self.dst, ".scarbignore", "/src/tests/\n")

    def tearDown(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)

    @staticmethod
    def put(base: Path, rel: str, text: str) -> None:
        path = base / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_check(self) -> tuple[int, str]:
        out = io.StringIO()
        return t.check(self.src, self.dst, out, fmt=identity), out.getvalue()

    def test_all_same(self) -> None:
        problems, out = self.run_check()
        self.assertEqual(problems, 0, out)
        self.assertNotIn("DIFFERENT", out)
        self.assertIn(f"{len(t.PAIRS) + 1} pairs, 0 problem(s)", out)

    def test_difference_is_printed_and_counted(self) -> None:
        self.put(self.dst, "src/board/map.cairo", "use hexx::board::bits::Bits; // edited\n")
        problems, out = self.run_check()
        self.assertEqual(problems, 1)
        self.assertIn("src/map.cairo -> src/board/map.cairo: DIFFERENT", out)
        self.assertIn("+use hexx::board::bits::Bits; // edited", out)

    def test_destination_without_source(self) -> None:
        self.put(self.dst, "src/finders/extra.cairo", "fn f() {}\n")
        problems, out = self.run_check()
        self.assertEqual(problems, 1)
        self.assertIn("src/finders/extra.cairo: DESTINATION WITHOUT SOURCE", out)

    def test_source_without_destination(self) -> None:
        (self.dst / "src/generators/walker.cairo").unlink()
        problems, out = self.run_check()
        self.assertEqual(problems, 1)
        self.assertIn("MISSING DESTINATION", out)

    def test_a_test_file_of_the_source_without_destination(self) -> None:
        self.put(self.src, "src/tests/bench_new.cairo", "fn f() {}\n")
        problems, out = self.run_check()
        self.assertEqual(problems, 1)
        self.assertIn("src/tests/bench_new.cairo -> src/tests/bench_new.cairo: MISSING", out)

    def test_u252_tests_are_not_in_the_table(self) -> None:
        self.put(self.src, "src/tests/bench_u252.cairo", "fn f() {}\n")
        problems, _ = self.run_check()
        self.assertEqual(problems, 0)

    def test_gas_budget_lines_are_ignored_on_both_sides_and_only_those(self) -> None:
        self.put(self.src, "src/map.cairo",
                 "#[test]\n#[available_gas(l2_gas: 5000)]\nfn a() {}\n\n#[test]\nfn b() {}\n")
        self.put(self.dst, "src/board/map.cairo",
                 "#[test]\n    #[available_gas(l2_gas: 123)]\nfn a() {}\n\n#[test]\n"
                 "#[available_gas(l2_gas: 9)]\nfn b() {}\n")
        problems, out = self.run_check()
        self.assertEqual(problems, 0, out)
        # Any other line is still a difference, next to a budget line.
        self.put(self.dst, "src/board/map.cairo",
                 "#[test]\n#[available_gas(l2_gas: 123)]\nfn a() {}\n\n#[test]\nfn b() {} // x\n")
        problems, out = self.run_check()
        self.assertEqual(problems, 1)
        self.assertIn("src/map.cairo -> src/board/map.cairo: DIFFERENT", out)

    def test_a_comment_or_an_attribute_sharing_the_line_is_not_a_budget_line(self) -> None:
        self.assertEqual(t.without_budgets("//! `#[available_gas(l2_gas: 5)]` budget\n"),
                         "//! `#[available_gas(l2_gas: 5)]` budget\n")
        self.assertEqual(t.without_budgets("#[test] #[available_gas(l2_gas: 5)]\n"),
                         "#[test] #[available_gas(l2_gas: 5)]\n")
        self.assertEqual(t.without_budgets("  #[available_gas(l2_gas: 5)]\nfn a() {}\n"),
                         "fn a() {}\n")

    def test_formatted_form_is_accepted(self) -> None:
        self.put(self.dst, "src/board/map.cairo", "use hexx::board::bits::Bits; // sorted\n")

        def fmt(files: dict[str, str]) -> dict[str, str]:
            return {k: v.replace("Bits;\n", "Bits; // sorted\n") for k, v in files.items()}

        out = io.StringIO()
        problems = t.check(self.src, self.dst, out, fmt=fmt)
        # The pair whose destination is the formatted form is `same after scarb fmt`; the others
        # are `same` before the formatter is consulted.
        self.assertIn("src/map.cairo -> src/board/map.cairo: same after scarb fmt", out.getvalue())
        self.assertEqual(problems, 0)


if __name__ == "__main__":
    unittest.main()


class OnlyAdditions(unittest.TestCase):
    def test_added_lines_are_accepted(self) -> None:
        self.assertTrue(t.only_additions("a\nb\nc", "a\nx\nb\nc\ny"))

    def test_a_changed_removed_or_reordered_line_is_refused(self) -> None:
        self.assertFalse(t.only_additions("a\nb", "a\nB"))
        self.assertFalse(t.only_additions("a\nb\nc", "a\nc"))
        self.assertFalse(t.only_additions("a\nb\nc", "a\nc\nb"))

    def test_an_original_line_kept_only_in_a_comment_is_refused(self) -> None:
        original = "fn f() {\n    assert(ok, 'E');\n}"
        disguised = "fn f() {\n    assert(true, 'E');\n    // assert(ok, 'E');\n}"
        self.assertFalse(t.only_additions(original, disguised))

    def test_comments_do_not_matter_otherwise(self) -> None:
        self.assertTrue(t.only_additions("a // one\nb", "a\n// new\nx\nb // two"))
        self.assertTrue(t.only_additions("s = '//';", "s = '//';\ny"))
