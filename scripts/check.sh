#!/usr/bin/env bash
# Full quality gate, package-scoped (COMMON.md §3: local checks are package-scoped, the pull
# request CI is the full gate; this script is what CI itself runs — every CI job except `links`
# and `scripts` (Markdown links, shellcheck: repository-wide, not package-scoped, kept as their
# own jobs since LIB-01) runs this file or a subset of it). Must be green before any task is
# reported as done.
#
# What this script covers: format, build and test every package, the gas budget rule and its
# snapshot, class size, the parity/deviations/extensions docs and their own unit tests, and (with
# a Rust toolchain on PATH) the golden vectors of tools/refgen.
#
# What only CI covers: Markdown links and shellcheck (jobs `links`, `scripts` of
# .github/workflows/ci.yml) — repository-wide checks with nothing to gain from being
# package-scoped locally.
set -euo pipefail
cd "$(dirname "$0")/.."

# D-176: one build. The compiler places the `withdraw_gas` check of a call-graph cycle by salsa
# intern-id order, which follows rayon's thread order (D-154); on one thread a build is one build,
# so a local gate measures what CI measures (ci.yml and release-check.yml set the same variable).
export RAYON_NUM_THREADS=1

scarb fmt --check --workspace
scarb build --workspace
for dir in crates/*/; do
  pkg=$(basename "$dir")
  snforge test -p "$pkg"
done
# Fails on a declared test snforge did not measure (ignored, filtered) with no budget, a budget
# outside [measured, ceil(1.05 * measured)] (a fuzz test: its maximum), a test that ran with no
# parsable measurement, counts (declared / collected / with a row / ignored) that do not agree, or
# a stale gas/*.snap. No test is exempt (task M1-T1c removed the baseline of the take-over). CI
# runs this once per package (`--package`), in its own job, and keeps the evidence of each run.
python3 scripts/bench.py check
python3 scripts/gas_tables.py --check
# Class size of the crates/consumer contract fixture (gas/bytecode.size, release build).
python3 scripts/bytecode_size.py check
python3 -m unittest discover -s scripts/tests
python3 scripts/api_parity.py --check
python3 scripts/api_parity.py --extensions --check
python3 scripts/deviations.py --check
# The take-over of origami_hexmap 1.8.0 is a move: every moved file equals its source after the
# rewrites of the script. Needs the read-only checkout of dojoengine/origami at 04ab30c
# (sources/origami); says so and skips when it is not there (CI clones it in the `takeover` job).
python3 scripts/takeover_check.py --skip-if-missing
# Golden vectors are up to date with tools/refgen. CI's dedicated `golden` job always has a Rust
# toolchain and always runs this; locally, and in every other CI job, a missing `cargo` is a
# failure unless CHECK_SKIP_GOLDEN=1 is set on purpose (a machine or a CI job with no Rust
# toolchain at all) — fix loop 1 finding 10: this used to print a warning and continue, so the
# "full" local gate could pass without ever running the one check that guards tools/refgen.
if command -v cargo >/dev/null 2>&1; then
  cargo run --quiet --locked --manifest-path tools/refgen/Cargo.toml -- check
elif [ "${CHECK_SKIP_GOLDEN:-}" = "1" ]; then
  echo "cargo not found: skipping the golden vector check (CHECK_SKIP_GOLDEN=1)"
else
  echo "cargo not found and CHECK_SKIP_GOLDEN is not 1: the golden vector check cannot be skipped silently" >&2
  exit 1
fi
echo "all checks passed"
