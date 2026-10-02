"""scripts/ci_changes.py: which groups of jobs a set of changed paths selects (LIB-04g)."""
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import ci_changes  # noqa: E402

SCRIPT = Path(__file__).resolve().parents[1] / "ci_changes.py"


def selected(*paths: str) -> set[str]:
    return {g for g, on in ci_changes.select(list(paths)).items() if on}


ALL = set(ci_changes.GROUPS)


class CiChangesTest(unittest.TestCase):
    def test_documents_only_select_links_only(self):
        self.assertEqual(selected("STATUS.md", "PLAN.md", "docs/briefs/x.md"), {"links"})

    def test_generated_documents_select_their_check_and_links(self):
        self.assertEqual(selected("docs/GAS.md"), {"links", "docs_checks"})

    def test_hexx_source_selects_docs_checks_takeover_cairo(self):
        self.assertEqual(
            selected("crates/hexx/src/hex.cairo"), {"docs_checks", "takeover", "cairo"})

    def test_other_crate_source_does_not_select_takeover(self):
        self.assertEqual(selected("crates/consumer/src/lib.cairo"), {"docs_checks", "cairo"})

    def test_gas_snapshot_selects_docs_checks_and_cairo(self):
        self.assertEqual(selected("gas/hexx.snap"), {"docs_checks", "cairo"})

    def test_license_files_select_links(self):
        self.assertEqual(selected("LICENSE"), {"links"})
        self.assertEqual(selected("LICENSE-origami"), {"links"})

    def test_gitignore_selects_cairo(self):
        self.assertEqual(selected(".gitignore"), {"cairo"})

    def test_refgen_selects_golden_only(self):
        self.assertEqual(selected("tools/refgen/src/specs/hex.rs"), {"golden"})
        self.assertIn("docs_checks", selected("crates/hexx/src/board/line.cairo"))
        self.assertIn("golden", selected("crates/hexx/src/board/line.cairo"))
        self.assertEqual(
            selected("crates/hexx/tests/golden_hex.cairo"),
            {"docs_checks", "takeover", "cairo", "golden"})

    def test_shell_scripts_select_shell_and_docs_checks(self):
        self.assertEqual(selected("scripts/prepush.sh"), {"shell", "docs_checks"})
        self.assertEqual(selected(".githooks/pre-push"), {"shell"})

    def test_bench_script_selects_cairo(self):
        self.assertEqual(selected("scripts/bench.py"), {"docs_checks", "cairo"})
        self.assertEqual(selected("scripts/api_parity.py"), {"docs_checks"})

    def test_toolchain_pin_selects_every_test(self):
        self.assertEqual(
            selected(".tool-versions"), {"docs_checks", "takeover", "cairo"})

    def test_workflow_selects_all(self):
        self.assertEqual(selected(".github/workflows/ci.yml"), ALL)
        self.assertEqual(selected("README.md", ".github/workflows/ci.yml"), ALL)

    def test_this_script_selects_all(self):
        self.assertEqual(selected("scripts/ci_changes.py"), ALL)

    def test_other_workflow_selects_nothing(self):
        self.assertEqual(selected(".github/workflows/release-check.yml"), set())

    def test_empty_list_selects_all(self):
        self.assertEqual(selected(), ALL)
        self.assertEqual(selected("", "  "), ALL)

    def test_command_line_output(self):
        out = subprocess.run(
            [sys.executable, str(SCRIPT)], input="STATUS.md\n", text=True,
            capture_output=True, check=True).stdout.splitlines()
        self.assertEqual(
            out, ["links=true", "shell=false", "docs_checks=false", "takeover=false",
                  "cairo=false", "golden=false"])
        out = subprocess.run(
            [sys.executable, str(SCRIPT), "--all"], text=True,
            capture_output=True, check=True).stdout.splitlines()
        self.assertEqual(out, [f"{g}=true" for g in ci_changes.GROUPS])


if __name__ == "__main__":
    unittest.main()
