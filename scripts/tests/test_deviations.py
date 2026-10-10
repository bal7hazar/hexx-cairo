"""Unit tests of scripts/deviations.py."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import deviations as dv  # noqa: E402


class SourcePaths(unittest.TestCase):
    def test_lists_the_companion_package_but_not_the_crate_root(self) -> None:
        paths = {p.relative_to(dv.ROOT).as_posix() for p in dv.source_paths()}
        self.assertIn("crates/hexx_glam/src/lib.cairo", paths)
        self.assertNotIn("crates/hexx/src/lib.cairo", paths)

    def test_companion_deviations_are_listed(self) -> None:
        text = dv.OUTPUT.read_text()
        self.assertIn("crates/hexx_glam/src/lib.cairo", text)


if __name__ == "__main__":
    unittest.main()
