"""The path selection of scripts/prepush.sh (`--select`): which build and which generated-artefact
check a set of changed paths triggers."""
import fcntl
import os
import subprocess
import shutil
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "prepush.sh"


def select(*paths: str) -> list[str]:
    out = subprocess.run(
        [str(SCRIPT), "--select"], input="\n".join(paths) + "\n", text=True,
        capture_output=True, check=True,
    ).stdout
    return out.splitlines()


class PrepushSelectionTest(unittest.TestCase):
    def test_docs_only_selects_nothing(self):
        self.assertEqual(select("README.md", "docs/research/LIB-03-porting-plan.md"), [])

    def test_hexx_source_builds_hexx_and_its_dependents_and_the_table_checks(self):
        steps = select("crates/hexx/src/hex.cairo")
        self.assertEqual(steps[:3], ["build consumer", "build hexx", "build takeover_tests"])
        for name in ("class-size", "api-parity", "extensions", "deviations", "takeover"):
            self.assertIn(f"check {name}", steps)
        self.assertNotIn("check gas-tables", steps)
        self.assertNotIn("check golden-vectors", steps)

    def test_lockfile_builds_the_workspace(self):
        steps = select("Scarb.lock")
        self.assertEqual(steps[0], "build workspace")
        self.assertIn("check class-size", steps)

    def test_accepted_figures_select_the_gas_table(self):
        self.assertEqual(select("gas/accepted.md"), ["check gas-tables"])

    def test_tool_versions_selects_class_size_takeover_and_gas_table(self):
        steps = select(".tool-versions")
        self.assertEqual(steps[0], "build workspace")
        for name in ("class-size", "takeover", "gas-tables"):
            self.assertIn(f"check {name}", steps)

    def test_gas_snapshot_selects_the_gas_table(self):
        self.assertEqual(select("gas/hexx.snap"), ["check gas-tables"])

    def test_nothing_that_builds_runs_without_a_cairo_input(self):
        for path in ("gas/bytecode.size", "gas/hexx.snap", "scripts/bytecode_size.py",
                     "docs/GAS.md", "AGENTS.md", ".github/workflows/ci.yml",
                     "tools/refgen/specs/hex.toml", "crates/hexx/tests/README.md"):
            steps = select(path)
            self.assertFalse([s for s in steps if s.startswith("build")], path)
            self.assertNotIn("check class-size", steps, path)

    def test_refgen_selects_the_golden_vectors(self):
        self.assertEqual(select("tools/refgen/specs/hex.toml"), ["check golden-vectors"])

    def test_board_line_source_selects_the_golden_vectors(self):
        steps = select("crates/hexx/src/board/line.cairo")
        self.assertIn("check golden-vectors", steps)
        self.assertIn("check takeover", steps)
        self.assertIn("check golden-vectors", select("docs/deviations/line_ties.md"))

    def test_takeover_covers_the_files_beside_the_sources(self):
        for path in ("crates/hexx/GAS-origami-1.8.0.md", "crates/hexx/.scarbignore"):
            steps = select(path)
            self.assertIn("check takeover", steps)
            self.assertFalse([s for s in steps if s.startswith("build")], path)

    def test_other_package_builds_only_itself(self):
        self.assertEqual(select("crates/takeover_tests/src/lib.cairo"), ["build takeover_tests"])


class PrepushLockTest(unittest.TestCase):
    def lock(self, path: str, wait: str = "1", env_path: str | None = None) -> str:
        env = dict(os.environ, HEAVY_BUILD_LOCK=path, PREPUSH_LOCK_WAIT=wait)
        if env_path is not None:
            env["PATH"] = env_path
        out = subprocess.run(["/bin/bash", str(SCRIPT), "--lock"], env=env, text=True,
                             capture_output=True, check=True)
        return out.stdout.strip() + "|" + out.stderr.strip()

    def test_no_lock_file_changes_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.lock(os.path.join(d, "absent.lock")), "none|")

    def test_no_flock_command_changes_nothing(self):
        # A PATH with `dirname` only: no flock(1), as on macOS.
        with tempfile.TemporaryDirectory() as d, tempfile.NamedTemporaryFile() as f:
            os.symlink(shutil.which("dirname"), os.path.join(d, "dirname"))
            self.assertEqual(self.lock(f.name, env_path=d), "none|")

    @unittest.skipIf(shutil.which("flock") is None, "no flock(1) on this machine")
    def test_unopenable_lock_is_its_own_error(self):
        with tempfile.TemporaryDirectory() as d:
            out = self.lock(d)
            self.assertTrue(out.startswith("error|prepush: cannot open the build lock "), out)
            self.assertNotIn("busy", out)

    @unittest.skipIf(shutil.which("flock") is None, "no flock(1) on this machine")
    def test_free_lock_is_taken(self):
        with tempfile.NamedTemporaryFile() as f:
            self.assertEqual(self.lock(f.name), "ok|")

    @unittest.skipIf(shutil.which("flock") is None, "no flock(1) on this machine")
    def test_busy_lock_skips_the_compile_after_the_wait(self):
        with tempfile.NamedTemporaryFile() as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            self.assertEqual(
                self.lock(f.name),
                "busy|prepush: build lock busy after 1 s: Cairo compile skipped, CI will compile")


if __name__ == "__main__":
    unittest.main()
