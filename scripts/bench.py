#!/usr/bin/env python3
"""Measures the Sierra gas of every snforge test of the workspace, enforces the budget rule
(COMMON.md §4, grimworld:docs/CAIRO.md §2) and maintains `gas/*.snap`.

The rule: every test carries `#[available_gas(l2_gas: N)]`. `N = ceil(1.05 * measured)` when a
budget is set or raised; lowering a budget needs nothing more than the lower number itself (a
cheaper measurement never has to hit the ceiling exactly to be accepted) — so `check` rejects a
budget **above** `ceil(1.05 * measured)` (more than 5 % of headroom) and a budget **below**
`measured` (the test would fail for lack of gas), and accepts anything in between. This is the
orchestrator's decision at fix loop 1 (finding 8): the auditor's suggested fix reads the rule as
an exact equality, `N = ceil(1.05 * measured)` on every check, which would force a budget churn on
every measurement drift smaller than 5 % and is not what COMMON.md §4 / `docs/CAIRO.md` §2 ask —
see the LIB-04 report, "Fix loop 1", for the dispute this records rather than applies.

This is the `origami_hexmap` form (`GAS.md` of `sources/origami/crates/hexmap`), kept because it
is what the game's rules require and what the taken-over tests already do (plan §4.2) — as
distinct from the `glam-cairo` house form (paired `X__base` / `X__op` benches, `gas/<module>.snap`
of net cost deltas): this package's tests are not written in `X__base` / `X__op` pairs, so that
form does not apply here (see the LIB-04 report for which of the two forms derives from the
other).

`gas/*.snap` is the single source of truth: `scripts/gas_tables.py` renders `docs/GAS.md` from it,
a pure function of committed data (no snforge run).

Every test is accounted for **by its full path** (`package::module::...::name` for a unit test,
`package_integrationtest::file_stem::module::...::name` for an integration test — matching what
snforge itself prints), not by function name alone — fix loop 1 finding 8: two tests with the
same short name in different modules used to collapse into one row, and a test snforge does not
measure at all (`#[ignore]`d, or excluded by a filter) produced no violation even with no budget,
because it was simply absent from `snforge`'s own output, the only thing `check` used to read.
`declared_tests` below finds every `#[test]` from the Cairo source directly (a small,
purpose-built module-path walker, not `scripts/api_parity.py`'s: that one computes *public API*
reachability, irrelevant to a private `#[cfg(test)] mod tests`, which is exactly where every unit
test of this workspace lives) — every module file reachable from `src/lib.cairo` (directory and
flat forms) and every integration test under `tests/` (fix loop 2 decision C: `declared_tests`
used to scan `src/lib.cairo` only, so an integration test under `tests/` produced no declared row
regardless of budget, and a flat file's own child module in a sibling directory was never found
at all). A `.cairo` file under `src/` or `tests/` that contains `#[test]` and that this walk never
reached is an error, not a silent skip. `check` requires every declared test to appear in what was
measured.

usage:
  scripts/bench.py run [--package P]       measure every test (of one package), print a table
  scripts/bench.py snapshot [--package P]  same, then (re)write gas/<package>.snap (only the
                                            packages measured)
  scripts/bench.py check [--package P]     same, then: (1) fail on any declared test that was not
                                            measured, or has no budget, or whose budget is outside
                                            [measured, ceil(1.05 * measured)]; (2) diff against
                                            gas/<package>.snap, exit 1 on any difference; the
                                            differences (test, both figures) and the location of
                                            the evidence are printed with the violations too
  scripts/bench.py check --package P --scope S --partition I/T
                                            one share of the package (snforge's `--partition`):
                                            the rule and the snapshot are enforced on the tests
                                            that share ran, and the names it measured are written
                                            to `partition-<scope>-<I>of<T>.json` in its evidence
  scripts/bench.py complete --package P --scope S --total T --reports DIR
                                            after the T partitions: fails when a declared test was
                                            measured in no partition or in two, when a partition
                                            report is missing or repeated, or when the snapshot
                                            has a row no partition measured
  scripts/bench.py pins --reports DIR --out OUT [--head SHA --merge SHA --base SHA]
                                            (CI, LIB-04i) assembles the `pins-*.json` every
                                            `check` leaves, whatever its verdict, into OUT:
                                            gas/<package>.snap of each package measured
                                            completely, gas/bytecode.size, budgets.json (the
                                            budgets to change) and manifest.json
  scripts/bench.py apply-pins DIR          writes the artefact `gas-pins-<head sha>` (downloaded
                                            into DIR) into the tree: gas/ and the budgets of the
                                            sources (not of the generated golden files: printed);
                                            refuses pins of another head than HEAD, warns when
                                            their base is not origin/main, exits 1 on anything
                                            left to do (a package not assembled, a test failed or
                                            unmeasured, a golden budget)
  scripts/bench.py repeat --package P [--filter F] [--partition I/T]
                                            run the tests matching F (default `digger`) twice, in
                                            the same job; fail if the compiled files differ from
                                            those of the check run (said as such) or the two
                                            measurements differ

Every test is measured, the `#[ignore]`d ones included (`snforge test --include-ignored`): an
ignored test has a snapshot row and is held to the rule like any other (M1-T1c fix loop 1).

Without `--package` every package of the workspace is measured (`scripts/check.sh`); CI runs one job
per package (task LIB-05 M1-T1c).

The evidence of a run (M1-T1c: two CI runs measured more than their snapshot on an unchanged tree,
and passed on the next run). Every snforge run of a package keeps, under
`target/gas-artifacts/<package>/` (`ARTIFACTS`; CI uploads the directory as an artefact of the job),
per run (`check`, `repeat-1`, `repeat-2`; none overwrites another): `snforge-<run>.txt` (the raw
output) and `artifacts-<run>.sha256` (SHA-256 of the compiled files of `target/dev/` that snforge
executes: `<package>_*.json`); and `versions.txt` (scarb, which prints the Cairo and Sierra
versions, snforge, and the Sierra-to-CASM compiler when it answers). `run`, `check` and `snapshot`
empty that directory first: in CI, setup-scarb's target cache (`cache-targets`) restores the
`target/` another gas job saved, its evidence and partition report included (t-0018).
A mismatch with the snapshot prints where they are. The exemption for the tests taken over from
`origami_hexmap` (a baseline file) is gone: every test obeys the rule.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tomllib
from collections.abc import Iterable
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAS = ROOT / "gas"
ARTIFACTS = ROOT / "target" / "gas-artifacts"
PASS_RE = re.compile(r"^\[(PASS|FAIL)\] (\S+)")
GAS_LINE_RE = re.compile(r"^\s*sierra gas:\s*(\d+)")
# A trailing comma is allowed: an attribute spread over several lines may end its argument with one.
AVAILABLE_GAS_RE = re.compile(r"available_gas\(\s*l2_gas\s*:\s*(\d+)\s*,?\s*\)")
# An attribute may be followed by a line comment (`#[ignore] // why`), and comment lines may sit
# between the attributes and `fn` (M1-T1a fix loop 1, finding 2).
FN_RE = re.compile(r"((?:#\[[^\]]*\](?:\s|//[^\n]*)*)+)fn\s+([A-Za-z_]\w*)\s*\(")
MOD_DECL_RE = re.compile(r"(?m)^[ \t]*(?:pub\s+)?mod\s+([A-Za-z_]\w*)\s*(;|\{)")


def workspace_packages() -> dict[str, Path]:
    """package name -> its directory, from the root Scarb.toml's `[workspace] members`."""
    manifest = tomllib.loads((ROOT / "Scarb.toml").read_text())
    packages: dict[str, Path] = {}
    for member in manifest["workspace"]["members"]:
        if "*" in member:
            candidates = sorted((ROOT / member.split("*")[0]).glob("*"))
        else:
            candidates = [ROOT / member]
        for path in candidates:
            manifest_path = path / "Scarb.toml"
            if manifest_path.is_file():
                name = tomllib.loads(manifest_path.read_text())["package"]["name"]
                packages[name] = path
    return packages


def closing_brace(text: str, opening: int) -> int:
    depth = 0
    for i in range(opening, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return len(text)


def module_nodes(
    root_file: Path, root_dir: Path | None = None, root_text: str | None = None,
    bases: list[int] | None = None,
) -> list[tuple[tuple[str, ...], str, Path]]:
    """Every module of a Cairo crate (or of one `tests/` integration-test file) as
    `(path, own_text, file)`, walked from `root_file`, the same `mod NAME;` / `mod NAME { ... }`
    syntax `scripts/api_parity.py`'s walker uses (no `pub`/private distinction here: a test can be
    private and still be a test). `path` is relative to `root_file` itself; the caller prefixes it
    with the package (and, for an integration-test root, the file's own stem).

    `root_dir` is where `root_file`'s own `mod NAME;` children resolve; it defaults to
    `root_file.parent` (`src/lib.cairo` is the crate root, so its children sit directly in `src/`).
    A `tests/<stem>.cairo` integration-test root is itself a *flat file*, not a crate root: its own
    children resolve in the sibling directory named after it (`tests/<stem>/`), exactly like any
    other flat file's children one level down — the caller passes that directory explicitly.

    `bases`, when given, receives for each node (same order) the offset of its own text in its
    file: the text of a node keeps the length of the source (a child module is blanked, not cut),
    so an offset in it plus its base is an offset in the file (`test_sites`)."""
    nodes: list[tuple[tuple[str, ...], str, Path]] = []

    def visit(path: tuple[str, ...], dir_path: Path, text: str, file: Path, base: int = 0) -> None:
        chars = list(text)
        consumed_until = 0
        children: list[tuple[str, str | None, int]] = []
        for m in MOD_DECL_RE.finditer(text):
            if m.start() < consumed_until:
                continue
            name, term = m.group(1), m.group(2)
            if term == ";":
                children.append((name, None, 0))
                end = m.end()
            else:
                open_pos = m.end() - 1
                close_pos = closing_brace(text, open_pos)
                children.append((name, text[open_pos + 1:close_pos], base + open_pos + 1))
                end = close_pos + 1
            for i in range(m.start(), end):
                if chars[i] != "\n":
                    chars[i] = " "
            consumed_until = end
        nodes.append((path, "".join(chars), file))
        if bases is not None:
            bases.append(base)
        for name, inline_body, inline_base in children:
            child_path = path + (name,)
            if inline_body is not None:
                visit(child_path, dir_path, inline_body, file, inline_base)
                continue
            flat = dir_path / f"{name}.cairo"
            nested = dir_path / name / "mod.cairo"
            if flat.is_file():
                # `name`'s own further children (if `name.cairo` itself declares `mod
                # grandchild;`) resolve in a sibling directory named after it (`dir_path/name/`),
                # exactly as for the `X/mod.cairo` form below — the same bug `scripts/api_parity.py`
                # had (fix loop 2 finding 4/8): this used to pass `dir_path` unchanged, so a flat
                # parent's own child module (`foo.cairo` declaring `mod bar;`, real file
                # `foo/bar.cairo`) was never discovered.
                visit(child_path, dir_path / name, flat.read_text(), flat)
            elif nested.is_file():
                visit(child_path, dir_path / name, nested.read_text(), nested)
            # else: declared but the file does not exist (should not happen in a building
            # workspace) — skip rather than fail a gas check on a missing-file build error. A
            # `#[test]` left behind in an orphaned file is still caught: `declared_tests` below
            # separately walks every `.cairo` file under `src/` and `tests/` and errors on any
            # that this traversal never visited.

    if root_text is not None:
        # The text of the root is given (a source file after the rewrites of the take-over).
        visit((), root_dir if root_dir is not None else root_file.parent, root_text, root_file)
    elif root_file.is_file():
        visit((), root_dir if root_dir is not None else root_file.parent, root_file.read_text(),
              root_file)
    return nodes


def integration_test_roots(package_dir: Path) -> list[tuple[str, Path]]:
    """`(file_stem, file)` for every top-level `*.cairo` file directly under `tests/`: each is its
    own snforge integration-test crate root, printed as `<package>_integrationtest::<file_stem>::
    ...` — confirmed empirically against snforge 0.61.0 (`tests/flat.cairo`'s own `mod sub;`
    resolves in the sibling directory `tests/flat/sub.cairo`, exactly `src/`'s flat-file
    convention; a directory directly under `tests/` with no matching top-level file, or vice
    versa, is not a form snforge itself accepts, so it is not handled here)."""
    tests_dir = package_dir / "tests"
    if not tests_dir.is_dir():
        return []
    return sorted((p.stem, p) for p in tests_dir.glob("*.cairo"))


IGNORE_ATTR_RE = re.compile(r"#\[ignore\b")


def tests_of_nodes(prefix: tuple[str, ...], nodes: list[tuple[tuple[str, ...], str, Path]],
                   ignored: set[str] | None = None) -> dict[str, int | None]:
    """Full test name -> declared `l2_gas` budget (or None) for the `#[test]` functions of nodes;
    the names of those that carry `#[ignore]` are added to `ignored` when given."""
    tests: dict[str, int | None] = {}
    for path, text, _file in nodes:
        for match in FN_RE.finditer(text):
            attrs, name = match.group(1), match.group(2)
            if "#[test]" not in attrs:
                continue
            gas_match = AVAILABLE_GAS_RE.search(attrs)
            full = "::".join((*prefix, *path, name))
            tests[full] = int(gas_match.group(1)) if gas_match else None
            if ignored is not None and IGNORE_ATTR_RE.search(attrs):
                ignored.add(full)
    return tests


def declared_tests(package: str, package_dir: Path,
                   ignored: set[str] | None = None) -> dict[str, int | None]:
    """Full test name (`package::module::...::fn` for a unit test, `package_integrationtest::
    file_stem::module::...::fn` for an integration test — matching what snforge itself prints) ->
    its declared `l2_gas` budget, or None when the test has no `#[available_gas(...)]`. Attributes
    may appear before or after `#[test]`, in either order. Raises if a `.cairo` file under `src/`
    or `tests/` contains `#[test]` but this discovery never reached it (fix loop 2 decision C):
    such a file would otherwise produce no measurement and no declared row, silently exempting it
    from the gas budget rule."""
    tests: dict[str, int | None] = {}
    visited: set[Path] = set()

    def scan(prefix: tuple[str, ...], root_file: Path, root_dir: Path | None = None) -> None:
        nodes = module_nodes(root_file, root_dir)
        visited.update(file.resolve() for _, _, file in nodes)
        tests.update(tests_of_nodes(prefix, nodes, ignored))

    scan((package,), package_dir / "src" / "lib.cairo")
    for stem, root_file in integration_test_roots(package_dir):
        scan((f"{package}_integrationtest", stem), root_file, root_file.parent / stem)

    all_cairo = set((package_dir / "src").rglob("*.cairo"))
    tests_dir = package_dir / "tests"
    if tests_dir.is_dir():
        all_cairo |= set(tests_dir.rglob("*.cairo"))
    for file in sorted(all_cairo):
        if file.resolve() in visited:
            continue
        if "#[test]" in file.read_text():
            raise SystemExit(
                f"{file.resolve().relative_to(ROOT)}: contains #[test] but was not reached by "
                f"gas-test discovery (not declared by any `mod` reachable from src/lib.cairo, and "
                f"not a top-level file directly under tests/) — fix loop 2 decision C"
            )

    return tests


def test_sites(package: str, package_dir: Path) -> dict[str, tuple[Path, int, int]]:
    """Full test name (as `declared_tests`) -> (file, start, end): the span of its attributes in
    the file, the text `apply_budgets` rewrites."""
    sites: dict[str, tuple[Path, int, int]] = {}

    def scan(prefix: tuple[str, ...], root_file: Path, root_dir: Path | None = None) -> None:
        bases: list[int] = []
        nodes = module_nodes(root_file, root_dir, bases=bases)
        for (path, text, file), base in zip(nodes, bases):
            for match in FN_RE.finditer(text):
                if "#[test]" in match.group(1):
                    full = "::".join((*prefix, *path, match.group(2)))
                    sites[full] = (file, base + match.start(1), base + match.end(1))

    scan((package,), package_dir / "src" / "lib.cairo")
    for stem, root_file in integration_test_roots(package_dir):
        scan((f"{package}_integrationtest", stem), root_file, root_file.parent / stem)
    return sites


def tool_version(cmd: list[str]) -> str:
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as error:
        return f"unavailable ({error})"
    return (p.stdout + p.stderr).strip() or f"no output (exit {p.returncode})"


def artifact_hashes(package: str) -> dict[str, str]:
    """Relative path -> SHA-256 of the compiled files of `target/dev/` that snforge executes."""
    files = sorted(p for p in (ROOT / "target" / "dev").glob(f"{package}_*.json") if p.is_file())
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in files}


def hashes_file(package: str, label: str) -> Path:
    return ARTIFACTS / package / f"artifacts-{label}.sha256"


def read_hashes(path: Path) -> dict[str, str] | None:
    if not path.is_file():
        return None
    return {line.split("  ", 1)[1]: line.split("  ", 1)[0]
            for line in path.read_text().splitlines() if line}


def write_evidence(package: str, out: str, label: str) -> Path:
    """Keeps what is needed to find the cause of a measurement that moved on an unchanged tree,
    **per run** (`label`: `check`, `repeat-1`, `repeat-2`, ...; a later run never overwrites an
    earlier one): the raw output of snforge (`snforge-<label>.txt`), the SHA-256 of the compiled
    files it executed (`artifacts-<label>.sha256`), and, once, the versions of the tools
    (`versions.txt`). Returns the directory."""
    directory = ARTIFACTS / package
    directory.mkdir(parents=True, exist_ok=True)
    (directory / f"snforge-{label}.txt").write_text(out)
    hashes_file(package, label).write_text(
        "".join(f"{digest}  {path}\n" for path, digest in artifact_hashes(package).items()))
    versions = {
        "scarb (cairo and sierra of `scarb --version`)": ["scarb", "--version"],
        "snforge": ["snforge", "--version"],
        "universal-sierra-compiler (Sierra to CASM, used by snforge)":
            ["universal-sierra-compiler", "--version"],
    }
    (directory / "versions.txt").write_text("".join(
        f"## {name}\n{tool_version(cmd)}\n\n" for name, cmd in versions.items()))
    return directory


def clear_evidence(packages: Iterable[str]) -> None:
    """Empties `target/gas-artifacts/<package>/` before a run measures the package, so that a job
    uploads only its own evidence and partition report: a `target/` restored from a cache (CI's
    setup-scarb, `cache-targets`) holds those of the job that saved it."""
    for package in packages:
        shutil.rmtree(ARTIFACTS / package, ignore_errors=True)


SCOPES = ("all", "regular", "ignored")
SCOPE_FLAGS = {"all": ["--include-ignored"], "regular": [], "ignored": ["--ignored"]}


def parse_partition(text: str) -> tuple[int, int]:
    """`INDEX/TOTAL` as snforge reads it (1-based)."""
    m = re.fullmatch(r"(\d+)/(\d+)", text)
    if not m or not 1 <= int(m.group(1)) <= int(m.group(2)):
        raise argparse.ArgumentTypeError(f"{text!r}: expected INDEX/TOTAL with 1 <= INDEX <= TOTAL")
    return int(m.group(1)), int(m.group(2))


def run_snforge(package: str, label: str, test_filter: str | None = None,
                scope: str = "regular", partition: tuple[int, int] | None = None) -> str:
    """One snforge run of a package. `scope`: the tests it runs (`all`: the `#[ignore]`d ones
    too; `ignored`: only those). The gate measures the ignored tests like the others (M1-T1c fix
    loop 1, finding 2)."""
    cmd = ["snforge", "test", "-p", package, "--detailed-resources", *SCOPE_FLAGS[scope]]
    if partition:
        cmd += ["--partition", f"{partition[0]}/{partition[1]}"]
    if test_filter:
        cmd.append(test_filter)
    print("$", " ".join(cmd), file=sys.stderr)
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                       env={**os.environ, "RAYON_NUM_THREADS": "1"})  # D-176: measured builds are single-threaded
    out = p.stdout + p.stderr
    write_evidence(package, out, label)
    if p.returncode not in (0, 1):  # 1: some test failed, still parseable
        sys.exit(f"snforge failed for {package}:\n" + "\n".join(out.splitlines()[-40:]))
    return out


FUZZ_MAX_RE = re.compile(r"l2_gas:\s*\{max:\s*~(\d+)")
IGNORE_RE = re.compile(r"^\[IGNORE\] (\S+)")
COLLECTED_RE = re.compile(r"^Collected (\d+) test\(s\)")


class Snforge:
    """What one `snforge test --detailed-resources` run printed: `ran` (every test reported PASS or
    FAIL -> passed), `measured` (name -> (gas, passed)), `ignored`, and `collected`.

    A plain test is measured by its `sierra gas: N` line. A fuzz test prints no such line: its
    result line reads `[PASS] name (runs: 256, (l1_gas: {max: ~0, ...}, l1_data_gas: {...},
    l2_gas: {max: ~186639, min: ~106432, mean: ~128053, std deviation: ~13553}))` (snforge 0.61.0,
    sample in scripts/tests/fixtures/), and its measurement is that `max` (the rules are held to the
    maximum over the runs)."""

    def __init__(self, ran, measured, ignored, collected):
        self.ran, self.measured, self.ignored, self.collected = ran, measured, ignored, collected


def parse_output(out: str) -> Snforge:
    ran: dict[str, bool] = {}
    measured: dict[str, tuple[int, bool]] = {}
    ignored: set[str] = set()
    collected = None
    current = None
    passed = True
    for line in out.splitlines():
        m = PASS_RE.match(line)
        if m:
            current = m.group(2)
            passed = m.group(1) == "PASS"
            ran[current] = passed
            fuzz = FUZZ_MAX_RE.search(line)
            if fuzz:
                measured[current] = (int(fuzz.group(1)), passed)
                current = None
            continue
        ig = IGNORE_RE.match(line)
        if ig:
            ignored.add(ig.group(1))
            continue
        c = COLLECTED_RE.match(line)
        if c:
            collected = int(c.group(1))
            continue
        if current is None:
            continue
        g = GAS_LINE_RE.match(line)
        if g:
            measured[current] = (int(g.group(1)), passed)
            current = None
    return Snforge(ran, measured, ignored, collected)


def parse_measurements(out: str) -> dict[str, tuple[int, bool]]:
    """Full test name (`pkg::mod::...::name`, exactly as snforge prints it) -> (measured gas,
    passed)."""
    return parse_output(out).measured


def select_packages(only: str | None) -> dict[str, Path]:
    """The packages to measure: all of the workspace, or the one named."""
    packages = workspace_packages()
    if only is None:
        return packages
    if only not in packages:
        sys.exit(f"unknown package {only!r}: the workspace has {', '.join(sorted(packages))}")
    return {only: packages[only]}


def in_scope(name: str, ignored: set[str], scope: str) -> bool:
    return scope == "all" or (name in ignored) == (scope == "ignored")


def collect(only: str | None = None, label: str = "check", scope: str = "all",
            partition: tuple[int, int] | None = None) -> tuple[dict[str, dict[str, dict]], dict[str, dict]]:
    """(rows, infos). rows: package -> {full_test_name: {"measured": int|None, "declared":
    int|None, "passed": bool|None, "ran": bool, "ignored": bool}} for the tests of `scope` (`all`,
    `regular`: those without `#[ignore]`, `ignored`); `measured` is None for a test snforge did
    not run and for a test it ran but printed no usable measurement for (`ran` is True: an error
    of `check`). infos: package -> {"collected": int|None, "declared": int (the tests snforge
    collects: all those of the package, but with `--ignored`, which collects only the ignored), "ignored_names": set, "all_names":
    set}. With a `partition` (snforge splits all the tests of the package, whatever the scope and
    the filter, and `Collected` counts those of the share): `declared` is what the share ran or
    ignored, in scope; `partition_seen` is the count `collected` must equal. That every declared
    test is in some share is `completeness`'s check."""
    packages: dict[str, dict[str, dict]] = {}
    infos: dict[str, dict] = {}
    for package, package_dir in select_packages(only).items():
        ignored_names: set[str] = set()
        all_declared = declared_tests(package, package_dir, ignored_names)
        declared = {n: b for n, b in all_declared.items() if in_scope(n, ignored_names, scope)}
        if partition:
            out = parse_output(run_snforge(package, label, scope=scope, partition=partition))
            seen = set(out.ran) | out.ignored
            declared = {n: b for n, b in declared.items() if n in seen}
        else:
            out = parse_output(run_snforge(package, label, scope=scope))
        rows: dict[str, dict] = {}
        reported_ignored = out.ignored if scope != "regular" else out.ignored & set(declared)
        for full in sorted(set(declared) | set(out.ran) | reported_ignored):
            gas_passed = out.measured.get(full)
            rows[full] = {
                "declared": declared.get(full),
                "measured": gas_passed[0] if gas_passed else None,
                "passed": gas_passed[1] if gas_passed else None,
                "ran": full in out.ran,
                "ignored": full in reported_ignored,
                "is_declared": full in declared,
            }
        packages[package] = rows
        infos[package] = {"collected": out.collected,
                          "declared": len(ignored_names) if scope == "ignored" else len(all_declared),
                          "ignored_names": ignored_names, "all_names": set(all_declared)}
        if partition:
            infos[package]["declared"] = len(set(out.ran) | out.ignored)
    return packages, infos


def reconcile(packages: dict[str, dict[str, dict]], infos: dict[str, dict]) -> tuple[list[str], list[str]]:
    """(errors, count lines): tests declared in the sources = tests snforge collected; every test
    that ran has a gas row; every declared test without a row is ignored."""
    bad: list[str] = []
    lines: list[str] = []
    for package, rows in sorted(packages.items()):
        info = infos[package]
        with_row = sum(1 for r in rows.values() if r["ran"] and r["measured"] is not None)
        ignored = sum(1 for r in rows.values() if r["ignored"])
        lines.append(f"{package}: declared {info['declared']}, collected {info['collected']}, "
                     f"with a gas row {with_row}, ignored {ignored}")
        if info["collected"] != info["declared"]:
            bad.append(f"{package}: {info['declared']} tests declared in the sources but "
                       f"snforge collected {info['collected']}")
        for name, r in sorted(rows.items()):
            if not r.get("is_declared", True):
                bad.append(f"{name}: snforge reported it but discovery did not find it in the "
                           f"sources")
            elif r["ran"] and r["measured"] is None:
                bad.append(f"{name}: ran but no gas measurement could be parsed from the "
                           f"output of snforge")
            elif not r["ran"] and not r["ignored"]:
                bad.append(f"{name}: declared, but snforge neither ran nor ignored it")
    return bad, lines



def budget_violations(packages: dict[str, dict[str, dict]]) -> list[str]:
    """Every test obeys the rule: it has a budget (or is measured with none: an error), and the
    budget is in [measured, ceil(1.05 * measured)]."""
    bad = []
    for rows in packages.values():
        for name, row in sorted(rows.items()):
            if row["measured"] is None:
                if row.get("ran"):
                    bad.append(f"{name}: ran but no gas measurement could be parsed from the "
                               f"output of snforge")
                else:
                    bad.append(f"{name}: not measured (ignored or filtered), so its budget "
                               f"{row['declared']} cannot be verified: every test is measured, "
                               f"the ignored ones included (--include-ignored)")
                continue
            if row["passed"] is False:
                bad.append(f"{name}: test failed, cannot verify its gas budget")
                continue
            if row["declared"] is None:
                bad.append(f"{name}: no #[available_gas(l2_gas: ...)]")
                continue
            measured, declared = row["measured"], row["declared"]
            ceiling = math.ceil(1.05 * measured)
            if declared > ceiling:
                bad.append(f"{name}: budget {declared} is more than 5 % above its measurement "
                           f"{measured} (ceil(1.05x) = {ceiling})")
            elif declared < measured:
                bad.append(f"{name}: budget {declared} is below its measurement {measured}; "
                           f"the test would fail for lack of gas")
    return bad


def read_snapshots(only: Iterable[str] | None = None) -> dict[str, dict[str, int]]:
    """The rows of gas/*.snap (of the packages named, when given)."""
    snap = {}
    for path in sorted(GAS.glob("*.snap")):
        if only is not None and path.stem not in only:
            continue
        for line in path.read_text().splitlines():
            if line.startswith("#") or not line.strip():
                continue
            name, vals = line.rsplit(":", 1)
            measured, budget = vals.split()
            snap[name] = {"measured": int(measured),
                          "declared": None if budget == "None" else int(budget)}
    return snap


def write_snapshots(packages: dict[str, dict[str, dict]]) -> None:
    """(Re)writes gas/<package>.snap of the packages measured, and of no other."""
    GAS.mkdir(exist_ok=True)
    written = 0
    for package, all_rows in packages.items():
        rows = {n: r for n, r in all_rows.items() if r["measured"] is not None}
        path = GAS / f"{package}.snap"
        if not rows:
            path.unlink(missing_ok=True)
            continue
        lines = ["# gas: measured budget"]
        for name in sorted(rows):
            row = rows[name]
            lines.append(f"{name}: {row['measured']} {row['declared']}")
        path.write_text("\n".join(lines) + "\n")
        written += 1
    print(f"wrote {written} snapshot file(s) in gas/", file=sys.stderr)


def print_table(packages: dict[str, dict[str, dict]]) -> None:
    print("| test | measured (l2 gas) | budget | margin |\n|---|---:|---:|---:|")
    for rows in packages.values():
        for name in sorted(rows):
            row = rows[name]
            measured = row["measured"] if row["measured"] is not None else "—"
            budget = row["declared"] if row["declared"] is not None else "—"
            margin = (f"{100 * (row['declared'] / row['measured'] - 1):.1f} %"
                      if row["declared"] is not None and row["measured"] else "—")
            print(f"| `{name}` | {measured} | {budget} | {margin} |")


def snapshot_differences(packages: dict[str, dict[str, dict]], infos: dict[str, dict] | None = None,
                         scope: str = "all", partition: bool = False) -> list[str]:
    """The tests whose measurement or budget differs from gas/<package>.snap, with both figures.
    With a `scope` other than `all` only the rows of that scope are compared: the ignored tests
    for `ignored`, and for `regular` the others; a row of a test that no longer exists is compared
    in both (`infos` gives the names of the sources). With a `partition` only the rows of the
    tests that share ran are compared: the rows of the others belong to the other shares, and a
    row no share measured is `completeness`'s to report."""
    snap = read_snapshots(packages)
    if partition:
        ran = {name for rows in packages.values() for name in rows}
        snap = {n: v for n, v in snap.items() if n in ran}
    elif scope != "all" and infos:
        ignored = set().union(*(i["ignored_names"] for i in infos.values()))
        known = set().union(*(i["all_names"] for i in infos.values()))
        snap = {n: v for n, v in snap.items()
                if in_scope(n, ignored, scope) or n not in known}
    current = {
        name: {"measured": row["measured"], "declared": row["declared"]}
        for rows in packages.values() for name, row in rows.items()
        if row["measured"] is not None
    }
    bad = []
    for name in sorted(set(current) | set(snap)):
        new, old = current.get(name), snap.get(name)
        if old is None:
            bad.append(f"ADDED   {name}: measured {new['measured']}, budget {new['declared']}")
        elif new is None:
            bad.append(f"REMOVED {name}: snapshot has measured {old['measured']}, budget "
                       f"{old['declared']}")
        elif new != old:
            delta = 100 * (new["measured"] / old["measured"] - 1) if old["measured"] else 0.0
            bad.append(f"CHANGED {name}: snapshot measured {old['measured']}, budget "
                       f"{old['declared']}; now measured {new['measured']} ({delta:+.2f} %), "
                       f"budget {new['declared']}")
    return bad


def repeat(package: str, test_filter: str, partition: tuple[int, int] | None = None) -> int:
    """Runs the tests matching `test_filter` twice, back to back, and fails if the compiled files
    of a run are not those of the check (or of the other repeat), if the two runs measure any of
    them differently, or if none matches. The hashes are compared first: two measurements are a
    comparison of the same code only when the hashes are equal, and a difference of hashes is the
    evidence sought, said as such. With a `partition` only that share is run, so that over the
    partitions of a package every matching test is run twice once; a share where none matches is
    not an error (it is for a whole package)."""
    extra = {"partition": partition} if partition else {}
    first = parse_output(run_snforge(package, "repeat-1", test_filter, **extra)).measured
    second = parse_output(run_snforge(package, "repeat-2", test_filter, **extra)).measured
    where = ARTIFACTS.relative_to(ROOT) / package
    status = 0
    reference_label, reference = "check", read_hashes(hashes_file(package, "check"))
    if reference is None:
        reference_label, reference = "repeat-1", read_hashes(hashes_file(package, "repeat-1"))
        print(f"repeat: no hashes of a check run in {where}; comparing the repeats only",
              file=sys.stderr)
    for label in ("repeat-1", "repeat-2"):
        hashes = read_hashes(hashes_file(package, label))
        if label == reference_label or hashes == reference:
            continue
        status = 1
        print(f"repeat: THE COMPILED FILES OF {label} DIFFER FROM THOSE OF {reference_label} "
              f"(the runs are not of the same code; hashes in {where}):", file=sys.stderr)
        for path in sorted(set(reference or {}) | set(hashes or {})):
            if (reference or {}).get(path) != (hashes or {}).get(path):
                print(f"  {path}: {reference_label} {(reference or {}).get(path)}, "
                      f"{label} {(hashes or {}).get(path)}", file=sys.stderr)
    if not first:
        print(f"repeat: no test of {package} matches {test_filter!r}"
              + (f" in partition {partition[0]}/{partition[1]}" if partition else ""),
              file=sys.stderr)
        return status if partition else 1
    differing = [name for name in sorted(set(first) | set(second))
                 if first.get(name) != second.get(name)]
    if differing:
        status = 1
        print(f"repeat: {len(differing)} of {len(first)} tests matching {test_filter!r} measured "
              f"differently between two runs (raw outputs and hashes in {where}):",
              file=sys.stderr)
        for name in differing:
            print(f"  {name}: run 1 {first.get(name)}, run 2 {second.get(name)}", file=sys.stderr)
    if status == 0:
        print(f"repeat: {len(first)} tests of {package} matching {test_filter!r} measured the "
              f"same in two runs, on compiled files identical to those of {reference_label}",
              file=sys.stderr)
    return status


PARTITION_REPORT_RE = re.compile(r"^partition-(\w+)-(\d+)of(\d+)\.json$")


def partition_report_path(package: str, scope: str, partition: tuple[int, int]) -> Path:
    return ARTIFACTS / package / f"partition-{scope}-{partition[0]}of{partition[1]}.json"


def write_partition_reports(packages: dict[str, dict[str, dict]], scope: str,
                            partition: tuple[int, int]) -> None:
    """Keeps, with the evidence of the run, the names this share measured: `completeness` reads
    them, one report per partition job."""
    for package, rows in packages.items():
        path = partition_report_path(package, scope, partition)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({
            "package": package, "scope": scope, "partition": list(partition),
            "measured": sorted(n for n, r in rows.items() if r["measured"] is not None),
        }, indent=1) + "\n")


def read_partition_reports(directory: Path) -> list[dict]:
    """Every `partition-<scope>-<I>of<T>.json` under `directory` (the artefacts of the partition
    jobs, each in its own subdirectory), with its `path`."""
    reports = []
    for path in sorted(directory.rglob("partition-*.json")):
        if PARTITION_REPORT_RE.match(path.name):
            reports.append({**json.loads(path.read_text()), "path": str(path)})
    return reports


def completeness(package: str, scope: str, total: int, reports: list[dict],
                 declared: set[str], snapshot: set[str]) -> list[str]:
    """The errors of a package measured in `total` partitions (empty: it was measured completely,
    each test once). `reports`: what the partition jobs kept; `declared`: the tests of the scope
    in the sources; `snapshot`: the names of the rows of gas/<package>.snap of the scope (those of
    tests that no longer exist included). Fails when a partition has no report or two, when a test
    declared was measured in no partition or in two, when a test was measured that the sources do
    not declare, or when a row of the snapshot was measured by no partition."""
    bad: list[str] = []
    by_index: dict[int, list[dict]] = {}
    for report in reports:
        if (report["package"], report["scope"], report["partition"][1]) != (package, scope, total):
            bad.append(f"{report['path']}: a report of {report['package']} {report['scope']} "
                       f"{report['partition'][0]}/{report['partition'][1]}, not of {package} "
                       f"{scope} in {total} partitions")
            continue
        by_index.setdefault(report["partition"][0], []).append(report)
    for index in range(1, total + 1):
        found = by_index.get(index, [])
        if not found:
            bad.append(f"partition {index}/{total} left no report")
        elif len(found) > 1:
            bad.append(f"partition {index}/{total} has {len(found)} reports")
    counted: dict[str, list[int]] = {}
    for index, found in sorted(by_index.items()):
        for report in found:
            for name in report["measured"]:
                counted.setdefault(name, []).append(index)
    for name in sorted(declared - set(counted)):
        bad.append(f"{name}: declared, measured in no partition")
    for name, indices in sorted(counted.items()):
        if len(indices) > 1:
            bad.append(f"{name}: measured {len(indices)} times, in partitions "
                       f"{', '.join(f'{i}/{total}' for i in indices)}")
        if name not in declared:
            bad.append(f"{name}: measured but not declared in the sources")
    for name in sorted(snapshot - set(counted)):
        bad.append(f"{name}: a row of gas/{package}.snap that no partition measured (stale)")
    return bad


def complete(package: str, scope: str, total: int, directory: Path) -> int:
    """`complete` of the command line: `completeness` over the reports under `directory`."""
    packages = select_packages(package)
    ignored: set[str] = set()
    declared = declared_tests(package, packages[package], ignored)
    in_this_scope = {n for n in declared if in_scope(n, ignored, scope)}
    snapshot = {n for n in read_snapshots([package])
                if in_scope(n, ignored, scope) or n not in declared}
    bad = completeness(package, scope, total, read_partition_reports(directory),
                       in_this_scope, snapshot)
    if bad:
        print(f"{package} ({scope}) is not measured completely in {total} partitions:",
              file=sys.stderr)
        for line in bad:
            print(f"  {line}", file=sys.stderr)
        return 1
    print(f"{package} ({scope}): {len(in_this_scope)} tests, each measured once across "
          f"{total} partitions, and the snapshot has no stale row", file=sys.stderr)
    return 0


# LIB-04i: the pins of a CI run. Every `check` leaves what it measured (`pins-<scope>-<I>of<T>.json`,
# whatever its verdict); `pins` assembles those of all the gas jobs into the files a thread
# commits, and `apply-pins` writes them into the tree. A pin of hexx is never built uncapped on the
# VPS: CI's Linux run is its source (D-182).
PINS_REPORT_RE = re.compile(r"^pins-(\w+)-(\d+)of(\d+)\.json$")
BUDGETS = "budgets.json"
MANIFEST = "manifest.json"


def pins_report_path(package: str, scope: str, partition: tuple[int, int] | None) -> Path:
    index, total = partition or (1, 1)
    return ARTIFACTS / package / f"pins-{scope}-{index}of{total}.json"


def write_pins_reports(packages: dict[str, dict[str, dict]], scope: str,
                       partition: tuple[int, int] | None) -> None:
    """Keeps, with the evidence of a `check`, every test it measured: its measurement, its budget
    in the sources and whether it passed; and the tests that ran without a measurement."""
    for package, rows in packages.items():
        path = pins_report_path(package, scope, partition)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({
            "package": package, "scope": scope, "partition": list(partition or (1, 1)),
            "rows": {n: {"measured": r["measured"], "declared": r["declared"], "passed": r["passed"]}
                     for n, r in sorted(rows.items()) if r["measured"] is not None},
            "unmeasured": sorted(n for n, r in rows.items()
                                 if r["measured"] is None and r.get("is_declared", True)),
        }, indent=1) + "\n")


def read_pins_reports(directory: Path) -> list[dict]:
    reports = []
    for path in sorted(directory.rglob("pins-*.json")):
        if PINS_REPORT_RE.match(path.name):
            reports.append({**json.loads(path.read_text()), "path": str(path)})
    return reports


def budget_for(measured: int, declared: int | None) -> int:
    """The budget a test carries after `apply-pins`: its own when the rule accepts it (in
    [measured, ceil(1.05 * measured)]), else `ceil(1.05 * measured)`."""
    ceiling = math.ceil(1.05 * measured)
    if declared is not None and measured <= declared <= ceiling:
        return declared
    return ceiling


def shares_problems(reports: list[dict]) -> list[str]:
    """Why the reports of one package are not one complete measurement (empty: they are): every
    scope `all`, or both `regular` and `ignored`, each with every partition 1..T exactly once."""
    by_scope: dict[str, dict[int, list[int]]] = {}
    for report in reports:
        index, total = report["partition"]
        by_scope.setdefault(report["scope"], {}).setdefault(total, []).append(index)
    bad = []
    wanted = ["all"] if "all" in by_scope else ["regular", "ignored"]
    for scope in sorted(set(by_scope) - set(wanted)):
        bad.append(f"scope {scope} measured beside scope all")
    for scope in wanted:
        totals = by_scope.get(scope)
        if not totals:
            bad.append(f"no report of scope {scope}")
            continue
        if len(totals) > 1:
            bad.append(f"scope {scope} in {', '.join(map(str, sorted(totals)))} partitions at once")
            continue
        total, indices = next(iter(totals.items()))
        for index in range(1, total + 1):
            if indices.count(index) != 1:
                bad.append(f"scope {scope}: partition {index}/{total} has "
                           f"{indices.count(index)} reports")
    return bad


def assemble_pins(reports: list[dict], expected: Iterable[str] = ()) -> dict:
    """The pins of a run, as a dict: `rows` (package -> {test: {"measured", "declared"}} for each
    package measured completely, `declared` being the budget after `apply-pins`), `budgets` (test
    -> new budget, for the tests whose budget changes), `incomplete` (package -> why its snapshot
    is not assembled; a package of `expected` with no report at all is one: "no report"),
    `empty` (the packages measured completely with no test at all, no `unmeasured` one either:
    their snapshot is removed, as `write_snapshots` does; a package whose tests all ran with no
    measurement keeps its snapshot), `unmeasured` (the tests that ran with no measurement: no row) and
    `failed` (the tests measured but failed: their row is the figure of a failing run)."""
    by_package: dict[str, list[dict]] = {package: [] for package in expected}
    for report in reports:
        by_package.setdefault(report["package"], []).append(report)
    result: dict = {"rows": {}, "budgets": {}, "incomplete": {}, "empty": [], "unmeasured": [],
                    "failed": []}
    for package, found in sorted(by_package.items()):
        if not found:
            result["incomplete"][package] = ["no report"]
            continue
        problems = shares_problems(found)
        merged: dict[str, dict] = {}
        skipped = False
        for report in found:
            result["unmeasured"].extend(report.get("unmeasured", []))
            skipped = skipped or bool(report.get("unmeasured"))
            for name, row in report["rows"].items():
                if name in merged and merged[name] != row:
                    problems.append(f"{name}: measured twice, differently")
                merged[name] = row
        result["failed"].extend(n for n, row in merged.items() if row.get("passed") is False)
        if problems:
            result["incomplete"][package] = problems
            continue
        if not merged:
            if not skipped:
                result["empty"].append(package)
            continue
        rows = result["rows"][package] = {}
        for name, row in sorted(merged.items()):
            budget = budget_for(row["measured"], row["declared"])
            if budget != row["declared"]:
                result["budgets"][name] = budget
            rows[name] = {"measured": row["measured"], "declared": budget}
    result["unmeasured"] = sorted(set(result["unmeasured"]))
    result["failed"] = sorted(set(result["failed"]))
    return result


def snapshot_text(rows: dict[str, dict]) -> str:
    """The text of gas/<package>.snap for these rows (as `write_snapshots`)."""
    return "\n".join(["# gas: measured budget"] + [
        f"{name}: {rows[name]['measured']} {rows[name]['declared']}" for name in sorted(rows)]) + "\n"


def pins(directory: Path, out: Path, commits: dict[str, str],
         expected: Iterable[str] | None = None) -> int:
    """`pins` of the command line: the artefact a thread downloads. `out/gas/<package>.snap` for
    each package measured completely, `out/gas/bytecode.size` when the consumer job measured it,
    `out/budgets.json` and `out/manifest.json`. `expected`: the packages the run should have
    measured (default: those of the workspace, each a job of the gas matrix). Exits 0 whatever was
    missing (the manifest says it): the gas jobs are the gate, this only publishes their figures."""
    result = assemble_pins(read_pins_reports(directory),
                           workspace_packages() if expected is None else expected)
    rows = result["rows"]
    (out / "gas").mkdir(parents=True, exist_ok=True)
    for package, package_rows in rows.items():
        (out / "gas" / f"{package}.snap").write_text(snapshot_text(package_rows))
    sizes = sorted(directory.rglob("bytecode.size"))
    if sizes:
        shutil.copyfile(sizes[0], out / "gas" / "bytecode.size")
    (out / BUDGETS).write_text(json.dumps(result["budgets"], indent=1, sort_keys=True) + "\n")
    (out / MANIFEST).write_text(json.dumps({
        **commits, "snapshots": sorted(rows), "bytecode_size": bool(sizes),
        "incomplete": result["incomplete"], "empty": result["empty"],
        "unmeasured": result["unmeasured"], "failed": result["failed"],
        "budgets_changed": len(result["budgets"]),
    }, indent=1, sort_keys=True) + "\n")
    print(f"pins: {len(rows)} snapshot(s) ({', '.join(sorted(rows)) or 'none'}), "
          f"{len(result['budgets'])} budget(s) to change, bytecode.size "
          f"{'yes' if sizes else 'no'}", file=sys.stderr)
    for package, problems in result["incomplete"].items():
        print(f"  {package} not assembled: {'; '.join(problems)}", file=sys.stderr)
    for name in result["unmeasured"]:
        print(f"  {name}: ran with no measurement (no row; a budget too low fails the test "
              f"before snforge prints its gas)", file=sys.stderr)
    for name in result["failed"]:
        print(f"  {name}: failed", file=sys.stderr)
    return 0


def apply_budgets(budgets: dict[str, int], sites: dict[str, tuple[Path, int, int]]) -> list[str]:
    """Writes each budget into `#[available_gas(l2_gas: N)]` of its test (the number replaced, or
    the attribute inserted on its own line after `#[test]`). Returns the tests it could not place
    (not found in the sources)."""
    edits: dict[Path, list[tuple[int, int, str]]] = {}
    missing = []
    for name, budget in sorted(budgets.items()):
        if name not in sites:
            missing.append(name)
            continue
        file, start, end = sites[name]
        text = file.read_text()
        attrs = text[start:end]
        gas = AVAILABLE_GAS_RE.search(attrs)
        if gas:
            edits.setdefault(file, []).append(
                (start + gas.start(1), start + gas.end(1), str(budget)))
            continue
        test = start + attrs.index("#[test]")
        before = text[text.rfind("\n", 0, test) + 1:test]
        indent = before if not before.strip() else ""
        at = test + len("#[test]")
        edits.setdefault(file, []).append((at, at, f"\n{indent}#[available_gas(l2_gas: {budget})]"))
    for file, file_edits in edits.items():
        text = file.read_text()
        for start, end, new in sorted(file_edits, reverse=True):
            text = text[:start] + new + text[end:]
        file.write_text(text)
    return missing


GENERATED_PREFIX = "golden_"


def git_rev(ref: str) -> str | None:
    p = subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
                       cwd=ROOT, capture_output=True, text=True)
    return p.stdout.strip() or None


def git_is_ancestor(ancestor: str, descendant: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", ancestor, descendant],
                          cwd=ROOT, capture_output=True).returncode == 0


def apply_pins(directory: Path) -> int:
    """`apply-pins` of the command line: the downloaded artefact into the tree. Copies its
    snapshots and bytecode.size into gas/ and writes its budgets into the sources, except into the
    generated golden files (`crates/golden_*`), whose budgets are printed for the spec of
    tools/refgen (`gas.<test name>`)."""
    manifest = json.loads((directory / MANIFEST).read_text())
    budgets = json.loads((directory / BUDGETS).read_text())
    head = git_rev("HEAD")
    if manifest.get("head") != head:
        print(f"apply-pins: these pins are of head {manifest.get('head')}, the checkout is at "
              f"{head}: nothing applied. Download the gas-pins artefact of the run of this head.",
              file=sys.stderr)
        return 1
    main_rev = git_rev("origin/main")
    if manifest.get("base") and manifest["base"] != main_rev:
        print(f"apply-pins: WARNING: the run measured the merge into base {manifest['base']}, "
              f"origin/main is now {main_rev}"
              + ("" if git_is_ancestor(manifest["base"], main_rev or "") else
                 " (and the base is not one of its ancestors; git fetch first: your origin/main may be "
                 "older than the run)")
              + ": main moved since the run; re-run CI on this head before applying, or let the "
              "confirming run decide.", file=sys.stderr)
    for path in sorted((directory / "gas").glob("*")):
        shutil.copyfile(path, GAS / path.name)
        print(f"wrote gas/{path.name}", file=sys.stderr)
    for package in manifest.get("empty", []):
        if (GAS / f"{package}.snap").exists():
            (GAS / f"{package}.snap").unlink()
            print(f"removed gas/{package}.snap (no test measured)", file=sys.stderr)
    status = 0
    packages = workspace_packages()
    by_package: dict[str, dict[str, int]] = {}
    for name, budget in budgets.items():
        package = name.split("::", 1)[0].removesuffix("_integrationtest")
        by_package.setdefault(package, {})[name] = budget
    for package, package_budgets in sorted(by_package.items()):
        if package.startswith(GENERATED_PREFIX):
            print(f"{package} is generated: set these budgets in the spec of tools/refgen "
                  f"(`gas.<test>`), then regenerate:", file=sys.stderr)
            for name, budget in sorted(package_budgets.items()):
                print(f"  {name}: {budget}", file=sys.stderr)
            status = 1
            continue
        if package not in packages:
            print(f"{package}: not a package of the workspace; budgets not applied",
                  file=sys.stderr)
            status = 1
            continue
        missing = apply_budgets(package_budgets, test_sites(package, packages[package]))
        print(f"{package}: {len(package_budgets) - len(missing)} budget(s) written",
              file=sys.stderr)
        for name in missing:
            print(f"  {name}: not found in the sources", file=sys.stderr)
            status = 1
    for package, problems in manifest.get("incomplete", {}).items():
        print(f"{package}: not measured completely by the run, gas/{package}.snap left as it is "
              f"({'; '.join(problems)})", file=sys.stderr)
        status = 1
    for name in manifest.get("unmeasured", []):
        print(f"{name}: ran with no measurement; raise or remove its budget and run CI again",
              file=sys.stderr)
        status = 1
    for name in manifest.get("failed", []):
        print(f"{name}: failed in the run; its row is the figure of a failing test: fix it and "
              f"run CI again", file=sys.stderr)
        status = 1
    print(f"pins of head {manifest.get('head')} (merge {manifest.get('merge')} of base "
          f"{manifest.get('base')}) applied; now `python3 scripts/gas_tables.py`", file=sys.stderr)
    return status


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("cmd", choices=["run", "snapshot", "check", "repeat", "complete", "pins",
                                    "apply-pins"])
    ap.add_argument("directory", nargs="?", type=Path, default=None,
                    help="apply-pins only: the downloaded artefact gas-pins-<head sha>")
    ap.add_argument("--package", default=None,
                    help="measure this package only (default: every package of the workspace); "
                         "required by `repeat`")
    ap.add_argument("--scope", choices=SCOPES, default="all",
                    help="the tests measured: all (the `#[ignore]`d ones included, the default), "
                         "regular (without `#[ignore]`), ignored (only those); CI splits `hexx` "
                         "in two jobs, regular and ignored, for its time; `snapshot` needs all")
    ap.add_argument("--filter", default="digger",
                    help="repeat only: the snforge test filter (default: %(default)s)")
    ap.add_argument("--partition", type=parse_partition, default=None, metavar="INDEX/TOTAL",
                    help="run, check or repeat one share of the package (snforge's `--partition`, "
                         "1-based); not with `snapshot`")
    ap.add_argument("--total", type=int, default=None,
                    help="complete only: the number of partitions of the package")
    ap.add_argument("--reports", type=Path, default=None,
                    help="complete and pins: the directory holding the reports of the gas jobs")
    ap.add_argument("--out", type=Path, default=None,
                    help="pins only: the directory to write the artefact into")
    for commit in ("head", "merge", "base"):
        ap.add_argument(f"--{commit}", default=None,
                        help=f"pins only: the {commit} commit of the run, kept in the manifest")
    args = ap.parse_args()

    if args.directory is not None and args.cmd != "apply-pins":
        sys.exit(f"{args.cmd} takes no directory argument (only apply-pins does)")

    if args.cmd == "pins":
        if args.reports is None or args.out is None:
            sys.exit("pins needs --reports and --out")
        return pins(args.reports, args.out,
                    {"head": args.head, "merge": args.merge, "base": args.base})

    if args.cmd == "apply-pins":
        if args.directory is None:
            sys.exit("apply-pins needs the directory of the downloaded artefact")
        return apply_pins(args.directory)

    if args.cmd == "repeat":
        if args.package is None:
            sys.exit("repeat needs --package")
        select_packages(args.package)
        return repeat(args.package, args.filter, args.partition)

    if args.cmd == "complete":
        if args.package is None or args.total is None or args.reports is None:
            sys.exit("complete needs --package, --total and --reports")
        return complete(args.package, args.scope, args.total, args.reports)

    if args.partition and args.cmd == "snapshot":
        sys.exit("snapshot rewrites the whole snapshot of a package: no --partition")
    if args.partition and args.package is None:
        sys.exit("--partition needs --package")

    if args.cmd == "snapshot" and args.scope != "all":
        sys.exit("snapshot rewrites the whole snapshot of a package: --scope all")
    clear_evidence(select_packages(args.package))
    packages, infos = collect(args.package, args.cmd, args.scope, args.partition)
    if args.partition:
        write_partition_reports(packages, args.scope, args.partition)
    if args.cmd == "check":
        write_pins_reports(packages, args.scope, args.partition)
    print_table(packages)
    errors, counts = reconcile(packages, infos)
    print("\nreconciliation (declared in the sources / collected by snforge / with a gas row / "
          "ignored):", file=sys.stderr)
    for line in counts:
        print(f"  {line}", file=sys.stderr)

    if args.cmd == "snapshot":
        write_snapshots(packages)
        return 0
    if args.cmd == "check":
        violations = errors + budget_violations(packages)
        bad = snapshot_differences(packages, infos, args.scope, bool(args.partition))
        where = ", ".join(str(ARTIFACTS.relative_to(ROOT) / package) for package in packages)
        if violations:
            print("\ngas budget violations:", file=sys.stderr)
            for v in violations:
                print(f"  {v}", file=sys.stderr)
        if bad:
            print("\nsnapshot differences:\n" + "\n".join(bad), file=sys.stderr)
        if violations or bad:
            print(f"\nartefacts of this run (raw output of snforge, SHA-256 of the compiled "
                  f"files, versions): {where}; in CI, the artefact `gas-<package>-<scope>-<commit>` of "
                  f"the job", file=sys.stderr)
        if violations:
            return 1
        if bad:
            sys.exit("gas snapshot mismatch. If the source changed, run `python3 scripts/bench.py "
                     "snapshot` and commit gas/; if it did not, keep the artefacts and report "
                     "the drift.")
        current = sum(len([r for r in rows.values() if r["measured"] is not None])
                      for rows in packages.values())
        print(f"\ngas budgets and snapshot OK ({current} tests)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
