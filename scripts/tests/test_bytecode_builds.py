"""Tests of the second observed builds of a class (gas/bytecode.builds, decision D-164)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bytecode_size as b  # noqa: E402

A = {"sierra_felts": 27092, "casm_felts": 49375, "sierra_bytes": 1395788, "casm_bytes": 997126}
B = {"sierra_felts": 27101, "casm_felts": 49375, "sierra_bytes": 1396211, "casm_bytes": 997304}
C = dict(B, sierra_felts=27102)


class Builds(unittest.TestCase):
    def test_the_snapshot_value_is_accepted(self) -> None:
        self.assertTrue(b.accepted("X", A, A, {}))

    def test_a_recorded_second_build_is_accepted_exactly(self) -> None:
        self.assertTrue(b.accepted("X", B, A, {"X": [B]}))

    def test_a_third_value_fails(self) -> None:
        self.assertFalse(b.accepted("X", C, A, {"X": [B]}))

    def test_a_build_of_another_contract_does_not_count(self) -> None:
        self.assertFalse(b.accepted("Y", B, A, {"X": [B]}))

    def test_a_new_or_removed_contract_still_fails(self) -> None:
        self.assertFalse(b.accepted("X", None, A, {"X": [B]}))
        self.assertFalse(b.accepted("X", B, None, {"X": [B]}))

    def test_the_committed_file_parses(self) -> None:
        builds = b.read_builds()
        self.assertEqual(builds.get("HexxGenerators"), [B])


if __name__ == "__main__":
    unittest.main()
