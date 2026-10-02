"""No `scarb` call of the scripts puts an option before its subcommand.

The machine's scarb shim takes the heavy build lock only when the subcommand is the first
argument of `scarb`; a call like `scarb --release build` would run outside the lock.
"""

from __future__ import annotations

import ast
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


# The label of bench.py's `scarb --version` row names that exempt call in words, verbatim.
VERSION_LABEL = "scarb (cairo and sierra of `scarb --version`)"


def option_first_calls(source: str) -> list[int]:
    """Lines of the Python `source` where a scarb argument list may have an option after "scarb".

    A list or tuple literal, or a `+` of them (`["scarb"] + ["--offline", "fmt"]`), whose first
    element is the string "scarb" and whose second starts with "-"; also a string containing
    `scarb -...` (`"cd x && scarb --release build"`). A `scarb` list whose second element is not
    a literal string (a name, a starred item, a `+` with a non-literal operand) cannot be
    checked and is flagged too. The exact `["scarb", "--version"]` is exempt: it builds nothing
    and takes no lock.
    """
    unknown = object()  # an operand or item that is not a literal list element

    def flat(node: ast.AST) -> list:
        if isinstance(node, (ast.List, ast.Tuple)):
            return [e if not isinstance(e, ast.Starred) else unknown for e in node.elts]
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
            left = flat(node.left)
            return left if unknown in left else left + flat(node.right)
        return [unknown]

    def text(node) -> str | None:
        return node.value if isinstance(node, ast.Constant) and isinstance(node.value, str) else None

    lines = []
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, (ast.List, ast.Tuple, ast.BinOp)):
            elts = flat(node)
            if text(elts[0] if elts else None) != "scarb":
                continue
            if len(elts) == 1 and isinstance(node, (ast.List, ast.Tuple)):
                continue  # `["scarb"]` alone; what follows is judged on the enclosing `+`
            second = text(elts[1]) if len(elts) > 1 else None
            if second is None or second.startswith("-"):
                if [text(e) for e in elts] != ["scarb", "--version"]:
                    lines.append(node.lineno)
        elif text(node) not in (None, VERSION_LABEL) and re.search(r"\bscarb +-", text(node)):
            lines.append(node.lineno)
    return lines


class NoOptionBeforeSubcommand(unittest.TestCase):
    """Every scarb call of the scripts and tools, Python or shell, keeps the subcommand first."""

    SHELL = re.compile(r"\bscarb +-")
    # lock.sh's two refusal messages name the option it rewrites, verbatim.
    LOCK_SH_REFUSALS = (
        '  [ $# -ge 4 ] || refuse "scarb --manifest-path needs a path and a subcommand"',
        """  case "$3" in -*) refuse "scarb --manifest-path needs a path, not '$3'" ;; esac""",
    )

    def files(self, suffix: str) -> list[Path]:
        root = SCRIPTS.parent
        found = [p for p in SCRIPTS.glob("*") if p.suffix == suffix]
        found += [p for p in (root / "tools").rglob("*")
                  if p.suffix == suffix and "target" not in p.relative_to(root).parts]
        return sorted(found)

    def test_no_python_script_calls_scarb_with_an_option_first(self) -> None:
        self.assertGreater(len(self.files(".py")), 3)
        for path in self.files(".py"):
            rel = path.relative_to(SCRIPTS.parent).as_posix()
            self.assertEqual(option_first_calls(path.read_text()), [], rel)

    def test_no_shell_script_calls_scarb_with_an_option_first(self) -> None:
        self.assertGreater(len(self.files(".sh")), 2)
        for path in self.files(".sh"):
            rel = path.relative_to(SCRIPTS.parent).as_posix()
            for n, line in enumerate(path.read_text().splitlines(), 1):
                if line.lstrip().startswith("#"):
                    continue
                if rel == "scripts/lock.sh" and line in self.LOCK_SH_REFUSALS:
                    continue
                self.assertIsNone(self.SHELL.search(line), f"{rel}:{n}: {line.strip()}")

    def test_the_guard_catches_the_forms(self) -> None:
        for src in ('x = ["scarb", "--release", "build"]', 'x = ["scarb"] + ["--offline", "fmt"]',
                    'x = [\n    "scarb",\n    "--release",\n    "build",\n]',
                    'x = ["scarb"] + ["-q"] + ["build"]', 'x = "scarb -q build"',
                    'run("cd x && scarb --release build", shell=True)', 'x = ("scarb", "--release", "build")',
                    'x = ["scarb"] + opts + ["build"]', 'x = ["scarb", *opts, "build"]',
                    'x = ["scarb", opts[0], "build"]', 'x = ["scarb"] + args'):
            self.assertNotEqual(option_first_calls(src), [], src)
        for src in ('x = ["scarb", "build"]', 'x = ["scarb", "build"] + ["--release"]',
                    'x = ["scarb", "--version"]', 'x = ["scarb_dir", "-x"]', 'x = ("scarb", "build")',
                    'x = ["scarb", "build"] + opts', 'run("scarb build --release", shell=True)'):
            self.assertEqual(option_first_calls(src), [], src)
        for line in ("scarb --offline fmt", "  scarb --manifest-path x build"):
            self.assertIsNotNone(self.SHELL.search(line), line)
        for line in ("scarb build --release", "scarb_dir -x"):
            self.assertIsNone(self.SHELL.search(line), line)


if __name__ == "__main__":
    unittest.main()
