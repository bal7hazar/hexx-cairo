#!/usr/bin/env python3
"""Proof that the take-over of `origami_hexmap` 1.8.0 is a move (plan §5, task LIB-05 M1-T1a).

For every pair of `PAIRS` (and of the glob `TESTS_GLOB`), applies `REWRITES` to the source file
and compares the result with the destination, byte for byte. The rewrites are data, below, and
nothing else is applied: a moved file that needs another edit is an escalation, not a rewrite.

Exit status: 0 when every pair is `same`; 1 on a difference, on a destination file without a
source (in the directories the take-over fills), on a source file of the table without a
destination; 2 on a missing source checkout.

    python3 scripts/takeover_check.py --source sources/origami/crates/hexmap

The source is the read-only checkout of `dojoengine/origami` at the commit of
`sources/VERSIONS.md` (`04ab30c`), directory `crates/hexmap`. Without `--source`, the script
uses `sources/origami/crates/hexmap` when it exists, and says that it is skipped otherwise
(exit 0 only with `--skip-if-missing`, as `scripts/check.sh` calls it).
"""
from __future__ import annotations

import argparse
import difflib
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "sources" / "origami" / "crates" / "hexmap"
DEST = ROOT / "crates" / "hexx"

# --- The table (source relative to the source dir, destination relative to crates/hexx) --------

HELPERS = ("layout", "geometry", "asserter", "bits", "rng", "printer")
FINDERS = ("bfs", "dial")
GENERATORS = ("caver", "digger", "mazer", "spreader", "walker")

PAIRS: list[tuple[str, str]] = (
    [("src/map.cairo", "src/board/map.cairo"),
     ("src/types/direction.cairo", "src/board/direction.cairo")]
    + [(f"src/helpers/{n}.cairo", f"src/board/{n}.cairo") for n in HELPERS]
    + [(f"src/finders/{n}.cairo", f"src/finders/{n}.cairo") for n in FINDERS]
    + [(f"src/generators/{n}.cairo", f"src/generators/{n}.cairo") for n in GENERATORS]
    + [("tests/readme.cairo", "tests/readme.cairo"),
       ("GAS.md", "GAS-origami-1.8.0.md"),
       (".scarbignore", ".scarbignore")]
)

# `src/tests/*.cairo` of the source, every file but the tests of the type `u252` (dropped).
TESTS_GLOB = "src/tests/*.cairo"
TESTS_EXCLUDED = ("bench_u252.cairo",)

# Directories of the destination the take-over fills: a file there with no source is an error.
# (`src/board` also holds files no source has yet: listed in `OWN_FILES` when a task adds one.)
COVERED_DIRS = ("src/board", "src/finders", "src/generators", "src/tests", "tests")
OWN_FILES: tuple[str, ...] = ()

# --- The rewrites: (pattern, replacement), in order, applied to every file ---------------------

REWRITES: list[tuple[str, str]] = [
    (r"origami_hexmap::helpers::", "hexx::board::"),
    (r"origami_hexmap::types::direction(?![A-Za-z0-9_])", "hexx::board::direction"),
    (r"origami_hexmap::map(?![A-Za-z0-9_])", "hexx::board::map"),
    (r"origami_hexmap::", "hexx::"),
]

# What the removal of `u252` forces (plan §5.1, §5.4): per source file, in order. Each is listed
# in the report of the task with the line removed.
U252_REMOVALS: dict[str, list[tuple[str, str]]] = {
    "tests/readme.cairo": [
        # the import of the type
        (r", U252Trait, u252\}", "}"),
        # the test of the type (`test_readme_u252`), with its `#[test]` and the blank line after
        (r"#\[test\]\nfn test_readme_u252\(\) \{\n(?:(?!\}\n).*\n)*\}\n\n", ""),
    ],
}

# The `.scarbignore` names paths; the destination has the new ones.
PATH_REWRITES: dict[str, list[tuple[str, str]]] = {
    ".scarbignore": [
        (r"/src/helpers/printer\.cairo", "/src/board/printer.cairo"),
        (r"/GAS\.md", "/GAS-origami-1.8.0.md"),
    ],
}


def rewritten(rel: str, text: str) -> str:
    """The source text of `rel` after the rewrites of this file."""
    for pattern, repl in U252_REMOVALS.get(rel, []) + PATH_REWRITES.get(rel, []) + REWRITES:
        text = re.sub(pattern, repl, text)
    return text


# The formatter of the pinned toolchain (`scarb fmt`, Scarb 2.19.4) with the configuration of
# `crates/hexx` (`[tool.fmt]` of its manifest and `[workspace.tool.fmt]`). It reorders the `use`
# lines whose path changed with the rewrites (`sort-module-level-items`); both sides are
# compared after it, as the brief requires.
FMT_MANIFEST = """[package]
name = "takeover_fmt"
version = "0.0.0"
edition = "2024_07"

[tool.fmt]
sort-module-level-items = true
max-line-length = 100
"""
FMT_DIR = ROOT / "target" / "takeover_fmt"


def scarb_fmt(files: dict[str, str]) -> dict[str, str]:
    """Formats `files` (relative path -> text) with `scarb fmt` in a scratch package."""
    shutil.rmtree(FMT_DIR, ignore_errors=True)
    (FMT_DIR / "src").mkdir(parents=True)
    (FMT_DIR / "Scarb.toml").write_text(FMT_MANIFEST)
    (FMT_DIR / "src" / "lib.cairo").write_text("")
    for rel, text in files.items():
        path = FMT_DIR / "src" / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    subprocess.run(["scarb", "--offline", "fmt"], cwd=FMT_DIR, check=True,
                   stdout=subprocess.DEVNULL)
    result = {rel: (FMT_DIR / "src" / rel).read_text() for rel in files}
    shutil.rmtree(FMT_DIR, ignore_errors=True)
    return result


def table(source: Path) -> list[tuple[str, str]]:
    """The pairs, with the glob of the tests expanded against the source."""
    tests = sorted(p.name for p in (source / "src" / "tests").glob("*.cairo")
                   if p.name not in TESTS_EXCLUDED)
    return PAIRS + [(f"src/tests/{n}", f"src/tests/{n}") for n in tests]


def check(source: Path, dest: Path, out=sys.stdout, fmt=scarb_fmt) -> int:
    """Prints every pair; returns the number of problems. `fmt` formats the rewritten Cairo
    sources (relative path -> text)."""
    problems = 0
    pairs = table(source)
    rewritten_cairo = {
        f"f{n}.cairo": rewritten(s_rel, (source / s_rel).read_bytes().decode("utf-8"))
        for n, (s_rel, _) in enumerate(pairs)
        if s_rel.endswith(".cairo") and (source / s_rel).is_file()}
    formatted = fmt(rewritten_cairo) if rewritten_cairo else {}
    for n, (src_rel, dst_rel) in enumerate(pairs):
        src, dst = source / src_rel, dest / dst_rel
        if not src.is_file():
            print(f"{src_rel} -> {dst_rel}: MISSING SOURCE", file=out)
            problems += 1
            continue
        if not dst.is_file():
            print(f"{src_rel} -> {dst_rel}: MISSING DESTINATION", file=out)
            problems += 1
            continue
        expected = rewritten(src_rel, src.read_bytes().decode("utf-8"))
        actual = dst.read_bytes().decode("utf-8")
        if expected == actual:
            print(f"{src_rel} -> {dst_rel}: same", file=out)
            continue
        if formatted.get(f"f{n}.cairo") == actual:
            print(f"{src_rel} -> {dst_rel}: same after scarb fmt", file=out)
            continue
        expected = formatted.get(f"f{n}.cairo", expected)
        problems += 1
        print(f"{src_rel} -> {dst_rel}: DIFFERENT", file=out)
        out.writelines(difflib.unified_diff(
            expected.splitlines(keepends=True), actual.splitlines(keepends=True),
            f"{src_rel} (rewritten)", dst_rel))
    known = {dst_rel for _, dst_rel in pairs} | set(OWN_FILES)
    for directory in COVERED_DIRS:
        base = dest / directory
        if not base.is_dir():
            continue
        for path in sorted(p for p in base.rglob("*") if p.is_file()):
            rel = path.relative_to(dest).as_posix()
            if rel not in known:
                print(f"{rel}: DESTINATION WITHOUT SOURCE", file=out)
                problems += 1
    print(f"{len(pairs)} pairs, {problems} problem(s)", file=out)
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE,
                        help="crates/hexmap of the pinned checkout of dojoengine/origami")
    parser.add_argument("--skip-if-missing", action="store_true",
                        help="exit 0, saying so, when the source is not there (scripts/check.sh)")
    args = parser.parse_args()
    if not (args.source / "src" / "map.cairo").is_file():
        message = f"takeover_check: no source checkout at {args.source}"
        if args.skip_if_missing:
            print(f"{message}: SKIPPED (fetch dojoengine/origami at 04ab30c to run it)")
            return 0
        print(message, file=sys.stderr)
        return 2
    return 1 if check(args.source, DEST) else 0


if __name__ == "__main__":
    sys.exit(main())
