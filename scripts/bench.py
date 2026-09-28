#!/usr/bin/env python3
"""Measures the Sierra gas of every snforge test of the workspace, enforces the budget rule
(COMMON.md §4, grimworld:docs/CAIRO.md §2) and maintains `gas/*.snap`.

The rule: every test carries `#[available_gas(l2_gas: N)]`, `N = ceil(1.05 * measured)`. This is
the `origami_hexmap` form (`GAS.md` of `sources/origami/crates/hexmap`), kept because it is what
the game's rules require and what the taken-over tests already do (plan §4.2) — as distinct from
the `glam-cairo` house form (paired `X__base` / `X__op` benches, `gas/<module>.snap` of net cost
deltas): this package's tests are not written in `X__base` / `X__op` pairs, so that form does not
apply here (see the LIB-04 report for which of the two forms derives from the other).

`gas/*.snap` is the single source of truth: `scripts/gas_tables.py` renders `docs/GAS.md` from it,
a pure function of committed data (no snforge run). The `#[available_gas]` budget is itself a
deterministic function of the snapshot's measured value (`ceil(1.05 * measured)`): one measurement,
two derived views — see the report for the answer this gives plan §4.2's question.

usage:
  scripts/bench.py run              measure every test, print a table, check nothing
  scripts/bench.py snapshot         same, then (re)write gas/<package>.snap
  scripts/bench.py check            same, then: (1) diff against gas/*.snap, exit 1 on any
                                     difference; (2) fail on any test with no #[available_gas],
                                     or whose budget is more than 5 % above its measurement
"""
from __future__ import annotations

import argparse
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


def workspace_packages() -> list[str]:
    manifest = tomllib.loads((ROOT / "Scarb.toml").read_text())
    members = manifest["workspace"]["members"]
    packages = []
    for member in members:
        path = ROOT / member if "*" not in member else None
        if path is None:
            base = ROOT / member.split("*")[0]
            for child in sorted(base.glob("*")):
                if (child / "Scarb.toml").is_file():
                    packages.append(tomllib.loads((child / "Scarb.toml").read_text())["package"]["name"])
            continue
        packages.append(tomllib.loads((path / "Scarb.toml").read_text())["package"]["name"])
    return packages


def declared_budgets(package_dir: Path) -> dict[str, int | None]:
    """Test function name (last path segment snforge prints) -> its declared `l2_gas` budget, or
    None when the test has no `#[available_gas(...)]`. Matched by function name only (assumed
    unique per package): attributes may appear before or after `#[test]`, in either order."""
    budgets: dict[str, int | None] = {}
    for path in list(package_dir.glob("src/**/*.cairo")) + list(package_dir.glob("tests/**/*.cairo")):
        text = path.read_text()
        for match in FN_RE.finditer(text):
            attrs, name = match.group(1), match.group(2)
            if "#[test]" not in attrs:
                continue
            gas_match = AVAILABLE_GAS_RE.search(attrs)
            budgets[name] = int(gas_match.group(1)) if gas_match else None
    return budgets


def run_snforge(package: str) -> str:
    cmd = ["snforge", "test", "-p", package, "--detailed-resources"]
    print("$", " ".join(cmd), file=sys.stderr)
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    out = p.stdout + p.stderr
    if p.returncode not in (0, 1):  # 1: some test failed, still parseable
        sys.exit(f"snforge failed for {package}:\n" + "\n".join(out.splitlines()[-40:]))
    return out


def parse_measurements(out: str) -> dict[str, tuple[int, bool]]:
    """Full test name (`pkg::mod::test_name`) -> (measured sierra gas, passed)."""
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
    """package -> {short_test_name: {"full": ..., "measured": int, "declared": int|None}}"""
    packages = {}
    for package in workspace_packages():
        package_dir = None
        for candidate in (ROOT / "crates").glob("*"):
            manifest = candidate / "Scarb.toml"
            if manifest.is_file() and tomllib.loads(manifest.read_text())["package"]["name"] == package:
                package_dir = candidate
                break
        if package_dir is None:
            continue
        budgets = declared_budgets(package_dir)
        measured = parse_measurements(run_snforge(package))
        rows = {}
        for full_name, (gas, passed) in measured.items():
            short = full_name.rsplit("::", 1)[-1]
            rows[short] = {
                "full": full_name, "measured": gas, "declared": budgets.get(short), "passed": passed,
            }
        packages[package] = rows
    return packages


def budget_violations(packages: dict[str, dict[str, dict]]) -> list[str]:
    import math
    bad = []
    for package, rows in packages.items():
        for name, row in sorted(rows.items()):
            if not row["passed"]:
                bad.append(f"{package}::{name}: test failed, cannot verify its gas budget")
                continue
            if row["declared"] is None:
                bad.append(f"{package}::{name}: no #[available_gas(l2_gas: ...)]")
                continue
            allowed = math.ceil(1.05 * row["measured"])
            if row["declared"] > allowed:
                bad.append(
                    f"{package}::{name}: budget {row['declared']} is more than 5 % above its "
                    f"measurement {row['measured']} (ceil(1.05x) = {allowed})"
                )
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
    for existing in GAS.glob("*.snap"):
        if existing.stem not in packages or not packages[existing.stem]:
            existing.unlink()
    for package, rows in packages.items():
        if not rows:
            continue
        lines = ["# gas: measured budget"]
        for name in sorted(rows):
            row = rows[name]
            lines.append(f"{package}::{name}: {row['measured']} {row['declared']}")
        (GAS / f"{package}.snap").write_text("\n".join(lines) + "\n")
        written += 1
    print(f"wrote {written} snapshot file(s) in gas/", file=sys.stderr)


def print_table(packages: dict[str, dict[str, dict]]) -> None:
    print("| test | measured (l2 gas) | budget | margin |\n|---|---:|---:|---:|")
    for package, rows in packages.items():
        for name in sorted(rows):
            row = rows[name]
            budget = row["declared"] if row["declared"] is not None else "—"
            margin = (f"{100 * (row['declared'] / row['measured'] - 1):.1f} %"
                      if row["declared"] is not None and row["passed"] else "—")
            print(f"| `{package}::{name}` | {row['measured']} | {budget} | {margin} |")


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
            f"{package}::{name}": {"measured": row["measured"], "declared": row["declared"]}
            for package, rows in packages.items() for name, row in rows.items()
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
        print(f"\ngas budgets and snapshot OK "
              f"({sum(len(r) for r in packages.values())} tests)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
