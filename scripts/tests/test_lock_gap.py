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
    """Every scarb call of the scripts and tools, Python or shell, keeps the subcommand first."""

    # Any form: `["scarb", "-x"`, `"scarb -x ..."`, `scarb -x` in a shell line.
    BAD = re.compile(r"""["']scarb["']\s*,\s*["']-|\bscarb +-""")
    # The only calls allowed to carry an option first: `scarb --version` builds nothing and takes
    # no lock; lock.sh's own refusal messages name the option it rewrites.
    EXACT = '["scarb", "--version"]'

    def files(self) -> list[Path]:
        root = SCRIPTS.parent
        found = [p for p in SCRIPTS.glob("*") if p.suffix in (".py", ".sh")]
        found += [p for p in (root / "tools").rglob("*") if p.suffix in (".py", ".sh")
                  and "target" not in p.relative_to(root).parts]
        return sorted(found)

    def test_no_script_calls_scarb_with_an_option_first(self) -> None:
        self.assertGreater(len(self.files()), 5)
        for path in self.files():
            rel = path.relative_to(SCRIPTS.parent).as_posix()
            for n, line in enumerate(path.read_text().splitlines(), 1):
                if line.lstrip().startswith("#") or self.EXACT in line:
                    continue
                if rel == "scripts/lock.sh" and line.lstrip().startswith(("[ ", "case ")) and "refuse " in line:
                    continue
                self.assertIsNone(self.BAD.search(line), f"{rel}:{n}: {line.strip()}")

    def test_the_guard_catches_the_forms(self) -> None:
        for line in ('["scarb", "--release", "build"]', "scarb --offline fmt", '"scarb -q build"',
                     "  scarb --manifest-path x build"):
            self.assertIsNotNone(self.BAD.search(line), line)
        for line in ('["scarb", "build"]', "scarb build --release", "scarb_dir -x"):
            self.assertIsNone(self.BAD.search(line), line)


if __name__ == "__main__":
    unittest.main()
