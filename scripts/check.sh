#!/usr/bin/env bash
# Full quality gate, package-scoped (COMMON.md §3: local checks are package-scoped, the pull
# request CI is the full gate; this script is what CI itself runs, so running it locally is the
# same gate). Must be green before any task is reported as done.
set -euo pipefail
cd "$(dirname "$0")/.."

scarb fmt --check --workspace
scarb build --workspace
for dir in crates/*/; do
  pkg=$(basename "$dir")
  snforge test -p "$pkg"
done
# Fails on a test with no #[available_gas], a budget more than 5 % above its measurement, or a
# stale gas/*.snap.
python3 scripts/bench.py check
python3 scripts/gas_tables.py --check
# Class size of the crates/consumer contract fixture (gas/bytecode.size, release build).
python3 scripts/bytecode_size.py check
python3 -m unittest discover -s scripts/tests
python3 scripts/api_parity.py --check
python3 scripts/deviations.py --check
# Golden vectors are up to date with tools/refgen (skipped when the Rust toolchain is absent; CI
# always runs it in the `golden` job).
if command -v cargo >/dev/null 2>&1; then
  cargo run --quiet --locked --manifest-path tools/refgen/Cargo.toml -- check
else
  echo "cargo not found: skipping the golden vector check"
fi
echo "all checks passed"
