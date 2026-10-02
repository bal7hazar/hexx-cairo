"""No `scarb` call of the scripts puts an option before its subcommand.

The machine's scarb shim takes the heavy build lock only when the subcommand is the first
argument of `scarb`; a call like `scarb --release build` would run outside the lock.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import bytecode_size as b  # noqa: E402

FAKE = '#!/bin/sh\necho "args=$*"\necho "profile=${SCARB_PROFILE:-}"\necho "manifest=${SCARB_MANIFEST_PATH:-}"\n'


class FakeScarb(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        bin_dir = Path(self.tmp.name)
        scarb = bin_dir / "scarb"
        scarb.write_text(FAKE)
        scarb.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}",
                    "HEXMAP_BUILD_LOCK_HELD": "1"}
        self.env.pop("HEAVY_BUILD_LOCK_HELD", None)
        self.env.pop("SCARB_PROFILE", None)
        self.env.pop("SCARB_MANIFEST_PATH", None)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def lock(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([str(SCRIPTS / "lock.sh"), *args], env=self.env,
                              capture_output=True, text=True)

    def test_lock_sh_moves_manifest_path_to_the_environment(self) -> None:
        p = self.lock("scarb", "--manifest-path", "x/Scarb.toml", "build", "-p", "hexx")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("args=build -p hexx", p.stdout)
        self.assertIn("manifest=x/Scarb.toml", p.stdout)

    def test_lock_sh_plain_call_is_unchanged(self) -> None:
        p = self.lock("scarb", "build")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("args=build\n", p.stdout)
        self.assertIn("manifest=\n", p.stdout)

    def test_lock_sh_still_refuses_other_options_before_the_subcommand(self) -> None:
        for args in (("scarb", "--release", "build"), ("scarb", "--manifest-path", "--x", "build"),
                     ("scarb", "--manifest-path", "x")):
            self.assertEqual(self.lock(*args).returncode, 2, args)

    def test_bytecode_size_build_keeps_the_subcommand_first(self) -> None:
        # build() hands the subprocess's output to nobody on success: run its command itself.
        captured: dict = {}
        real = subprocess.run

        def spy(cmd, **kw):
            captured["cmd"], captured["env"] = cmd, kw["env"]
            fake = [str(Path(self.tmp.name) / "scarb")] + cmd[1:]  # the shim would wait on the lock
            return real(fake, **{**kw, "env": self.env | kw["env"]})

        subprocess.run = spy
        try:
            b.build(Path(self.tmp.name), ["-p", "consumer"])
        finally:
            subprocess.run = real
        self.assertEqual(captured["cmd"], ["scarb", "build", "-p", "consumer"])
        self.assertEqual(captured["env"]["SCARB_PROFILE"], "release")


class NoOptionBeforeSubcommand(unittest.TestCase):
    def test_no_script_calls_scarb_with_an_option_first(self) -> None:
        bad = re.compile(r'\["scarb",\s*"-')
        allowed = {"scripts/bench.py"}  # `scarb --version` builds nothing, takes no lock
        for path in sorted((SCRIPTS).glob("*.py")) + sorted((SCRIPTS.parent / "tools").rglob("*.py")):
            rel = path.relative_to(SCRIPTS.parent).as_posix()
            if rel in allowed:
                continue
            for n, line in enumerate(path.read_text().splitlines(), 1):
                self.assertIsNone(bad.search(line), f"{rel}:{n}: {line.strip()}")


if __name__ == "__main__":
    unittest.main()
