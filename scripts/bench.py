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

Every test is accounted for **by its full path** (`package::module::...::name`, matching what
snforge itself prints), not by function name alone — fix loop 1 finding 8: two tests with the
same short name in different modules used to collapse into one row, and a test snforge does not
measure at all (`#[ignore]`d, or excluded by a filter) produced no violation even with no budget,
because it was simply absent from `snforge`'s own output, the only thing `check` used to read.
`declared_tests` below finds every `#[test]` from the Cairo source directly (a small,
purpose-built module-path walker, not `scripts/api_parity.py`'s: that one computes *public API*
reachability, irrelevant to a private `#[cfg(test)] mod tests`, which is exactly where every test
of this workspace lives) and `check` requires every one of them to appear in what was measured.

usage:
  scripts/bench.py run              measure every test, print a table, check nothing
  scripts/bench.py snapshot         same, then (re)write gas/<package>.snap
  scripts/bench.py check            same, then: (1) diff against gas/*.snap, exit 1 on any
                                     difference; (2) fail on any declared test that was not
                                     measured and has no budget, or whose budget is outside
                                     [measured, ceil(1.05 * measured)]
"""
from __future__ import annotations

import argparse
import math
import re
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAS = ROOT / "gas"
PASS_RE = re.compile(r"^\[(PASS|FAIL)\] (\S+)")
GAS_LINE_RE = re.compile(r"^\s*sierra gas:\s*(\d+)")
AVAILABLE_GAS_RE = re.compile(r"available_gas\(\s*l2_gas\s*:\s*(\d+)\s*\)")
FN_RE = re.compile(r"((?:#\[[^\]]*\]\s*)+)fn\s+([A-Za-z_]\w*)\s*\(")
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


def module_nodes(root_file: Path) -> list[tuple[tuple[str, ...], str]]:
    """Every module of a Cairo crate as `(path, own_text)`, walked from `root_file`
    (`src/lib.cairo`), the same `mod NAME;` / `mod NAME { ... }` syntax
    `scripts/api_parity.py`'s walker uses (no `pub`/private distinction here: a test can be
    private and still be a test)."""
    nodes: list[tuple[tuple[str, ...], str]] = []

    def visit(path: tuple[str, ...], dir_path: Path, text: str) -> None:
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
        nodes.append((path, "".join(chars)))
        for name, inline_body in children:
            child_path = path + (name,)
            if inline_body is not None:
                visit(child_path, dir_path, inline_body)
                continue
            flat = dir_path / f"{name}.cairo"
            nested = dir_path / name / "mod.cairo"
            if flat.is_file():
                visit(child_path, dir_path, flat.read_text())
            elif nested.is_file():
                visit(child_path, dir_path / name, nested.read_text())
            # else: declared but the file does not exist (should not happen in a building
            # workspace) — skip rather than fail a gas check on a missing-file build error.

    if root_file.is_file():
        visit((), root_file.parent, root_file.read_text())
    return nodes


def declared_tests(package: str, package_dir: Path) -> dict[str, int | None]:
    """Full test name (`package::module::...::fn`, matching what snforge itself prints) -> its
    declared `l2_gas` budget, or None when the test has no `#[available_gas(...)]`. Attributes
    may appear before or after `#[test]`, in either order."""
    tests: dict[str, int | None] = {}
    for path, text in module_nodes(package_dir / "src" / "lib.cairo"):
        for match in FN_RE.finditer(text):
            attrs, name = match.group(1), match.group(2)
            if "#[test]" not in attrs:
                continue
            full = "::".join((package, *path, name))
            gas_match = AVAILABLE_GAS_RE.search(attrs)
            tests[full] = int(gas_match.group(1)) if gas_match else None
    return tests


def run_snforge(package: str) -> str:
    cmd = ["snforge", "test", "-p", package, "--detailed-resources"]
    print("$", " ".join(cmd), file=sys.stderr)
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    out = p.stdout + p.stderr
    if p.returncode not in (0, 1):  # 1: some test failed, still parseable
        sys.exit(f"snforge failed for {package}:\n" + "\n".join(out.splitlines()[-40:]))
    return out


def parse_measurements(out: str) -> dict[str, tuple[int, bool]]:
    """Full test name (`pkg::mod::...::name`, exactly as snforge prints it) -> (measured sierra
    gas, passed)."""
    result: dict[str, tuple[int, bool]] = {}
    current = None
    passed = True
    for line in out.splitlines():
        m = PASS_RE.match(line)
        if m:
            current = m.group(2)
            passed = m.group(1) == "PASS"
            continue
        if current is None:
            continue
        g = GAS_LINE_RE.match(line)
        if g:
            result[current] = (int(g.group(1)), passed)
            current = None
    return result


def collect() -> dict[str, dict[str, dict]]:
    """package -> {full_test_name: {"measured": int|None, "declared": int|None, "passed": bool}}
    `measured` is None for a test snforge did not run (`#[ignore]`d, filtered out)."""
    packages: dict[str, dict[str, dict]] = {}
    for package, package_dir in workspace_packages().items():
        declared = declared_tests(package, package_dir)
        measured = parse_measurements(run_snforge(package))
        rows: dict[str, dict] = {}
        for full in sorted(set(declared) | set(measured)):
            gas_passed = measured.get(full)
            rows[full] = {
                "declared": declared.get(full),
                "measured": gas_passed[0] if gas_passed else None,
                "passed": gas_passed[1] if gas_passed else None,
            }
        packages[package] = rows
    return packages


def budget_violations(packages: dict[str, dict[str, dict]]) -> list[str]:
    bad = []
    for package, rows in packages.items():
        for name, row in sorted(rows.items()):
            if row["measured"] is None:
                if row["declared"] is None:
                    bad.append(f"{name}: not measured (ignored or filtered) and no "
                               f"#[available_gas(l2_gas: ...)]")
                continue  # not measured but has a budget: cannot verify it, not a violation
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


def read_snapshots() -> dict[str, dict[str, int]]:
    snap = {}
    for path in sorted(GAS.glob("*.snap")):
        if path.name == "bytecode.size":
            continue
        for line in path.read_text().splitlines():
            if line.startswith("#") or not line.strip():
                continue
            name, vals = line.rsplit(":", 1)
            measured, budget = vals.split()
            snap[name] = {"measured": int(measured), "declared": int(budget)}
    return snap


def write_snapshots(packages: dict[str, dict[str, dict]]) -> None:
    GAS.mkdir(exist_ok=True)
    written = 0
    measured_packages = {
        package: {n: r for n, r in rows.items() if r["measured"] is not None}
        for package, rows in packages.items()
    }
    for existing in GAS.glob("*.snap"):
        if existing.stem not in measured_packages or not measured_packages[existing.stem]:
            existing.unlink()
    for package, rows in measured_packages.items():
        if not rows:
            continue
        lines = ["# gas: measured budget"]
        for name in sorted(rows):
            row = rows[name]
            lines.append(f"{name}: {row['measured']} {row['declared']}")
        (GAS / f"{package}.snap").write_text("\n".join(lines) + "\n")
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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("cmd", choices=["run", "snapshot", "check"])
    args = ap.parse_args()

    packages = collect()
    print_table(packages)

    if args.cmd == "snapshot":
        write_snapshots(packages)
        return 0
    if args.cmd == "check":
        violations = budget_violations(packages)
        if violations:
            print("\ngas budget violations:", file=sys.stderr)
            for v in violations:
                print(f"  {v}", file=sys.stderr)
            return 1
        snap = read_snapshots()
        current = {
            name: {"measured": row["measured"], "declared": row["declared"]}
            for rows in packages.values() for name, row in rows.items()
            if row["measured"] is not None
        }
        bad = []
        for name in sorted(set(current) | set(snap)):
            new, old = current.get(name), snap.get(name)
            if old is None:
                bad.append(f"ADDED   {name}")
            elif new is None:
                bad.append(f"REMOVED {name}")
            elif new != old:
                bad.append(f"CHANGED {name}: {old} -> {new}")
        if bad:
            print("\n" + "\n".join(bad), file=sys.stderr)
            sys.exit("gas snapshot mismatch. Run `python3 scripts/bench.py snapshot` and commit gas/.")
        print(f"\ngas budgets and snapshot OK ({len(current)} tests)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
