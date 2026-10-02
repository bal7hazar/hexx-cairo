#!/usr/bin/env python3
"""Compiled class size of the `consumer` contract fixture (crates/consumer) against the Starknet
limits (plan, R-11). Adapted from the house `scripts/bytecode_size.py` of `glam-cairo`: the
attribution-probe subcommand (marginal cost per call site of a heavy library item) is dropped —
nothing in this package is heavy yet, that tool has no fixture to run against before LIB-05.

usage:
  scripts/bytecode_size.py [table]    build crates/consumer (release), print the size table
  scripts/bytecode_size.py snapshot   same, then write gas/bytecode.size
  scripts/bytecode_size.py check      same, then diff against gas/bytecode.size; exit 1 on ANY
                                       difference

Measured quantities, per contract (see the `LIMITS` block for their source):
  sierra_felts  length of `sierra_program` in `*.contract_class.json`
  casm_felts    length of `bytecode` in `*.compiled_contract_class.json`
  sierra_bytes  compact JSON of the class as the gateway serializes it (`sierra_program`,
                `contract_class_version`, `entry_points_by_type`, `abi` as a string; without the
                debug info, which a declare transaction does not carry)
  casm_bytes    compact JSON of the compiled class
The build is deterministic for a given toolchain (`.tool-versions`), so the check uses equality.

Dependency free (Python 3 standard library only).
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = "consumer"
SNAPSHOT = ROOT / "gas" / "bytecode.size"
METRICS = ["sierra_felts", "casm_felts", "sierra_bytes", "casm_bytes"]
HEADER = "# contract: " + " ".join(METRICS)

# Starknet limits. Source: https://docs.starknet.io/learn/cheatsheets/chain-info (Starknet
# v0.14.2 on Mainnet, v0.14.3 on Sepolia) and the sequencer that enforces them,
# https://github.com/starkware-libs/sequencer:
# * apollo_gateway `stateless_transaction_validator.rs`: `sierra_program.len()` <=
#   `max_contract_bytecode_size` (81920) and `serde_json::to_string(&contract_class).len()` <=
#   `max_contract_class_object_size` (4089446);
# * apollo_sierra_compilation_config: the Sierra -> CASM compilation fails above
#   `max_bytecode_size` = 80 * 1024 = 81920 CASM felts;
# * apollo_class_manager_config: `max_compiled_contract_class_object_size` = 4089446 bytes.
# The limits change between Starknet versions: they are parameters, update them here (copied
# unchanged from the house script, which read them 2026-09-21; not reverified by this task).
LIMITS = {
    "sierra_felts": 81920,
    "casm_felts": 81920,
    "sierra_bytes": 4089446,
    "casm_bytes": 4089446,
}


def build(cwd: Path, args: list[str]) -> None:
    cmd = ["scarb", "--release", "build"] + args
    print(f"$ {' '.join(cmd)}", file=sys.stderr)
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if p.returncode != 0:
        out = (p.stdout + p.stderr).splitlines()
        sys.exit("scarb build failed:\n" + "\n".join(out[-60:]))


def compact(obj) -> str:
    return json.dumps(obj, separators=(",", ":"))


def measure(target: Path, package: str) -> dict[str, dict[str, int]]:
    artifacts = json.loads((target / f"{package}.starknet_artifacts.json").read_text())
    res = {}
    for c in artifacts["contracts"]:
        sierra = json.loads((target / c["artifacts"]["sierra"]).read_text())
        casm = json.loads((target / c["artifacts"]["casm"]).read_text())
        declared = {
            "sierra_program": sierra["sierra_program"],
            "contract_class_version": sierra["contract_class_version"],
            "entry_points_by_type": sierra["entry_points_by_type"],
            "abi": compact(sierra["abi"]),
        }
        res[c["contract_name"]] = {
            "sierra_felts": len(sierra["sierra_program"]),
            "casm_felts": len(casm["bytecode"]),
            "sierra_bytes": len(compact(declared)),
            "casm_bytes": len(compact(casm)),
        }
    return res


def print_table(rows: dict[str, dict[str, int]], title: str) -> None:
    print(f"\n### {title}\n")
    print("| contract | Sierra felts | CASM felts | CASM / limit | Sierra class bytes "
          "| CASM class bytes | bytes / limit |")
    print("|---|--:|--:|--:|--:|--:|--:|")
    for name, r in sorted(rows.items(), key=lambda kv: kv[1]["casm_felts"]):
        felts = max(r["casm_felts"] / LIMITS["casm_felts"], r["sierra_felts"] / LIMITS["sierra_felts"])
        size = max(r["sierra_bytes"] / LIMITS["sierra_bytes"], r["casm_bytes"] / LIMITS["casm_bytes"])
        print(f"| `{name}` | {r['sierra_felts']:,} | {r['casm_felts']:,} | {100 * felts:.1f} % "
              f"| {r['sierra_bytes']:,} | {r['casm_bytes']:,} | {100 * size:.1f} % |")
    print(f"\nLimits: {LIMITS['sierra_felts']:,} Sierra felts, {LIMITS['casm_felts']:,} CASM felts, "
          f"{LIMITS['sierra_bytes']:,} bytes per class object (`scripts/bytecode_size.py`, `LIMITS`).")


def read_snapshot() -> dict[str, dict[str, int]]:
    snap = {}
    if not SNAPSHOT.exists():
        return snap
    for line in SNAPSHOT.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        name, vals = line.split(":", 1)
        snap[name] = dict(zip(METRICS, map(int, vals.split())))
    return snap


def write_snapshot(rows: dict[str, dict[str, int]]) -> None:
    SNAPSHOT.parent.mkdir(exist_ok=True)
    lines = [HEADER] + [f"{n}: " + " ".join(str(rows[n][m]) for m in METRICS) for n in sorted(rows)]
    SNAPSHOT.write_text("\n".join(lines) + "\n")
    print(f"wrote {SNAPSHOT.relative_to(ROOT)}", file=sys.stderr)


def fixtures() -> dict[str, dict[str, int]]:
    build(ROOT, ["-p", PACKAGE])
    return measure(ROOT / "target" / "release", PACKAGE)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("cmd", nargs="?", default="table", choices=["table", "snapshot", "check"])
    a = ap.parse_args()

    rows = fixtures()
    print_table(rows, "Consumer fixture (release profile)")
    if a.cmd == "snapshot":
        write_snapshot(rows)
    elif a.cmd == "check":
        snap, bad = read_snapshot(), []
        for name in sorted(set(rows) | set(snap)):
            new, old = rows.get(name), snap.get(name)
            if new != old:
                bad.append(f"{name}: {old} -> {new}")
        if bad:
            print("\n".join(bad), file=sys.stderr)
            sys.exit(f"bytecode size mismatch ({len(bad)}). Run `scripts/bytecode_size.py "
                     "snapshot` and commit gas/bytecode.size.")
        print(f"\nbytecode size snapshot OK ({len(rows)} contracts)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
