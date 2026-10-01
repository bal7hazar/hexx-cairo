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
versions, snforge, and the Sierra-to-CASM compiler when it answers).
A mismatch with the snapshot prints where they are. The exemption for the tests taken over from
`origami_hexmap` (a baseline file) is gone: every test obeys the rule.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
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
AVAILABLE_GAS_RE = re.compile(r"available_gas\(\s*l2_gas\s*:\s*(\d+)\s*\)")
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
    root_file: Path, root_dir: Path | None = None, root_text: str | None = None
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
    other flat file's children one level down — the caller passes that directory explicitly."""
    nodes: list[tuple[tuple[str, ...], str, Path]] = []

    def visit(path: tuple[str, ...], dir_path: Path, text: str, file: Path) -> None:
        chars = list(text)
        consumed_until = 0
        children: list[tuple[str, str | None]] = []
        for m in MOD_DECL_RE.finditer(text):
            if m.start() < consumed_until:
                continue
            name, term = m.group(1), m.group(2)
            if term == ";":
                children.append((name, None))
                end = m.end()
            else:
                open_pos = m.end() - 1
                close_pos = closing_brace(text, open_pos)
                children.append((name, text[open_pos + 1:close_pos]))
                end = close_pos + 1
            for i in range(m.start(), end):
                if chars[i] != "\n":
                    chars[i] = " "
            consumed_until = end
        nodes.append((path, "".join(chars), file))
        for name, inline_body in children:
            child_path = path + (name,)
            if inline_body is not None:
                visit(child_path, dir_path, inline_body, file)
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
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("cmd", choices=["run", "snapshot", "check", "repeat", "complete"])
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
                    help="complete only: the directory holding the partition reports")
    args = ap.parse_args()

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
    packages, infos = collect(args.package, args.cmd, args.scope, args.partition)
    if args.partition:
        write_partition_reports(packages, args.scope, args.partition)
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
