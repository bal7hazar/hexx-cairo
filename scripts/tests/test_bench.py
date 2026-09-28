#!/usr/bin/env python3
"""Unit tests of scripts/bench.py.

Fix loop 2 (audit `[GPT-6-Sol]` pass 2, `sources/audits/LIB-04-audit-gpt-6-sol-pass-2.md`,
finding 8, decision C) covered here: `declared_tests` discovers every unit test reachable from
`src/lib.cairo` (directory and flat forms, including a flat file's own child module in a sibling
directory) and every integration test under `tests/` (each top-level file its own snforge root,
named `<package>_integrationtest::<file_stem>::...`, confirmed empirically against snforge
0.61.0 — see REPORT.md, "Fix loop 2"); a `.cairo` file under `src/` or `tests/` that contains
`#[test]` and that this discovery does not reach raises, naming the file.

Every fixture tree is written under `scripts/tests/tmp/` (repo-local, gitignored), not a host
temp directory: decision B(viii) of fix loop 2 — a read-only sandbox may have no writable `/tmp`.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bench  # noqa: E402

TMP_ROOT = Path(__file__).resolve().parent / "tmp"


class FixtureCrateCase(unittest.TestCase):
    """Base class: `self.write(rel, text)` places a file under a fresh package directory at
    `scripts/tests/tmp/<TestClass>/<test_method>/`; `self.pkg` is that directory."""

    def setUp(self) -> None:
        self.pkg = TMP_ROOT / type(self).__name__ / self._testMethodName
        if self.pkg.exists():
            shutil.rmtree(self.pkg)
        self.pkg.mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.pkg, ignore_errors=True)

    def write(self, rel: str, text: str) -> None:
        path = self.pkg / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


class UnitTestDiscovery(FixtureCrateCase):
    def test_test_in_a_cfg_test_mod_is_found_with_its_budget(self) -> None:
        self.write("src/lib.cairo", (
            "pub fn add(a: u32, b: u32) -> u32 { a + b }\n\n"
            "#[cfg(test)]\nmod tests {\n"
            "    #[test]\n    #[available_gas(l2_gas: 100)]\n    fn test_add() {}\n"
            "}\n"
        ))
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual({"pkg::tests::test_add": 100}, tests)

    def test_test_without_available_gas_has_a_none_budget(self) -> None:
        self.write("src/lib.cairo", (
            "#[cfg(test)]\nmod tests {\n    #[test]\n    fn test_add() {}\n}\n"
        ))
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual({"pkg::tests::test_add": None}, tests)

    def test_flat_module_child_in_a_sibling_directory_is_found(self) -> None:
        # The exact bug of finding 8: this used to raise "cannot resolve" or silently skip,
        # because `module_nodes` passed the parent's own directory (not `foo/`) when recursing
        # into `foo.cairo`'s own children.
        self.write("src/lib.cairo", "mod foo;\n")
        self.write("src/foo.cairo", "mod bar;\n")
        self.write("src/foo/bar.cairo", (
            "#[test]\n#[available_gas(l2_gas: 50)]\nfn test_nested() {}\n"
        ))
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual({"pkg::foo::bar::test_nested": 50}, tests)

    def test_directory_module_child_is_found(self) -> None:
        self.write("src/lib.cairo", "mod foo;\n")
        self.write("src/foo/mod.cairo", (
            "#[test]\n#[available_gas(l2_gas: 60)]\nfn test_dir() {}\n"
        ))
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual({"pkg::foo::test_dir": 60}, tests)


class IntegrationTestDiscovery(FixtureCrateCase):
    """Naming confirmed empirically: `snforge test --detailed-resources` on a throwaway fixture
    package prints `<package>_integrationtest::<file_stem>::...::<name>` for every test under
    `tests/`, with a top-level file's own child module resolving in the sibling directory named
    after that file (exactly `src/`'s flat-file convention, one level down)."""

    def test_top_level_test_file_is_its_own_integrationtest_root(self) -> None:
        self.write("src/lib.cairo", "")
        self.write("tests/flat.cairo", (
            "#[test]\n#[available_gas(l2_gas: 200)]\nfn test_flat() {}\n"
        ))
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual({"pkg_integrationtest::flat::test_flat": 200}, tests)

    def test_top_level_test_files_own_child_resolves_in_its_sibling_directory(self) -> None:
        self.write("src/lib.cairo", "")
        self.write("tests/flat.cairo", "mod sub;\n")
        self.write("tests/flat/sub.cairo", (
            "#[test]\n#[available_gas(l2_gas: 300)]\nfn test_sub() {}\n"
        ))
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual({"pkg_integrationtest::flat::sub::test_sub": 300}, tests)

    def test_absent_tests_directory_yields_no_integration_roots(self) -> None:
        self.write("src/lib.cairo", "")
        self.assertEqual([], bench.integration_test_roots(self.pkg))

    def test_unit_and_integration_tests_coexist(self) -> None:
        self.write("src/lib.cairo", (
            "#[cfg(test)]\nmod tests {\n"
            "    #[test]\n    #[available_gas(l2_gas: 10)]\n    fn test_unit() {}\n"
            "}\n"
        ))
        self.write("tests/flat.cairo", (
            "#[test]\n#[available_gas(l2_gas: 20)]\nfn test_integ() {}\n"
        ))
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual(
            {"pkg::tests::test_unit": 10, "pkg_integrationtest::flat::test_integ": 20}, tests
        )


class UndiscoveredTestFileRaises(FixtureCrateCase):
    def test_src_file_with_a_test_not_declared_by_any_mod_raises(self) -> None:
        self.write("src/lib.cairo", "pub fn add(a: u32, b: u32) -> u32 { a + b }\n")
        self.write("src/orphan.cairo", "#[test]\nfn test_orphan() {}\n")
        with self.assertRaises(SystemExit) as ctx:
            bench.declared_tests("pkg", self.pkg)
        self.assertIn("orphan.cairo", str(ctx.exception))
        self.assertIn("#[test]", str(ctx.exception))

    def test_tests_directory_file_not_at_top_level_raises(self) -> None:
        # `tests/sub/deep.cairo` with no top-level `tests/sub.cairo` declaring `mod deep;`: not a
        # form snforge accepts, so discovery never reaches it either.
        self.write("src/lib.cairo", "")
        self.write("tests/sub/deep.cairo", "#[test]\nfn test_deep() {}\n")
        with self.assertRaises(SystemExit) as ctx:
            bench.declared_tests("pkg", self.pkg)
        self.assertIn("deep.cairo", str(ctx.exception))

    def test_a_file_with_no_test_at_all_is_not_an_error(self) -> None:
        self.write("src/lib.cairo", "pub fn add(a: u32, b: u32) -> u32 { a + b }\n")
        self.write("src/orphan.cairo", "pub fn unrelated() {}\n")
        # No `mod orphan;` in lib.cairo, and no `#[test]` in orphan.cairo either: not reached, but
        # not an error — only an undiscovered *test* file is.
        tests = bench.declared_tests("pkg", self.pkg)
        self.assertEqual({}, tests)


if __name__ == "__main__":
    unittest.main()
