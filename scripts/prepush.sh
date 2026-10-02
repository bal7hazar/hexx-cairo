#!/usr/bin/env bash
# Short pre-push gate: a subset of scripts/check.sh that stops the red CI runs a short local check
# would have stopped (formatting, a script's unit test, a compile error, a generated artefact not
# regenerated). Aim: under two minutes on a typical change. Run by .githooks/pre-push (set
# `git config core.hooksPath .githooks` once per clone) and by hand before every push.
#
# What it does NOT replace: scripts/check.sh (the full gate: every test, the gas budgets and
# snapshots, measured code and pins) and CI. Run check.sh before asking for a review of a change
# that touches measured code or pins.
#
# Always: format, the unit tests of the scripts.
# On the files changed against origin/main (the commits being pushed plus the working tree):
#   - build: `scarb build` of each crates/<pkg> with a changed file; the whole workspace when the
#     root manifest, Scarb.lock or .tool-versions changed. A change with no Cairo source, manifest,
#     Scarb.lock or .tool-versions runs no `scarb build` at all (the class-size check, which builds,
#     has only those inputs as its trigger; no build waits on the shared build lock for nothing).
#   - each generated-artefact check, only when one of its inputs changed (table below).
#
#   scripts/prepush.sh               run the gate
#   scripts/prepush.sh --select      read changed paths on stdin, print the checks selected (tests)
set -euo pipefail
cd "$(dirname "$0")/.."

# D-176: one build, as scripts/check.sh and CI (see check.sh).
export RAYON_NUM_THREADS=1

# Which paths trigger which generated-artefact check (extended regular expressions on the
# repository-relative path). One line per check: name::command::trigger.
CHECKS=(
  "gas-tables::python3 scripts/gas_tables.py --check::^(gas/[^/]*\.(snap|md)|docs/GAS\.md|scripts/gas_tables\.py|\.tool-versions)$"
  "class-size::python3 scripts/bytecode_size.py check::^(crates/(consumer|hexx)/src/.*\.cairo|Scarb\.(toml|lock)|crates/[^/]+/Scarb\.toml|\.tool-versions)$"
  "api-parity::python3 scripts/api_parity.py --check::^(docs/API_PARITY\.md|scripts/api_parity\.py|crates/hexx/src/.*\.cairo)$"
  "extensions::python3 scripts/api_parity.py --extensions --check::^(docs/EXTENSIONS\.md|scripts/api_parity\.py|crates/hexx/src/.*\.cairo)$"
  "deviations::python3 scripts/deviations.py --check::^(docs/DEVIATIONS\.md|scripts/deviations\.py|crates/hexx/src/.*\.cairo)$"
  "takeover::python3 scripts/takeover_check.py --skip-if-missing::^(scripts/takeover_check\.py|\.tool-versions|crates/hexx/(src/|tests/|GAS-origami-1\.8\.0\.md$|\.scarbignore$).*)$"
  "golden-vectors::golden::^(tools/refgen/.*|crates/hexx/tests/golden_.*\.cairo|crates/hexx/src/board/(line|tables|hexagon)\.cairo|docs/deviations/line_ties\.md)$"
)
# A change here builds the whole workspace.
WORKSPACE_TRIGGER='^(Scarb\.toml|Scarb\.lock|\.tool-versions)$'

# stdin: changed paths. stdout: one line per selected step, `build <target>` or `check <name>`.
select_steps() {
  local paths manifest
  paths=$(cat)
  if grep -Eq "$WORKSPACE_TRIGGER" <<<"$paths"; then
    echo "build workspace"
  else
    local pkgs
    pkgs=$(sed -nE 's#^crates/([^/]+)/(.*\.cairo|Scarb\.toml)$#\1#p' <<<"$paths" | sort -u)
    # A touched package also builds every package whose manifest depends on it by path
    # (`<pkg> = { path = "../<pkg>" ...`): a change under crates/hexx builds consumer and
    # takeover_tests too. Dependents are read from the manifests, not listed.
    local pkg dependent all=$pkgs
    for pkg in $pkgs; do
      for manifest in crates/*/Scarb.toml; do
        dependent=$(basename "$(dirname "$manifest")")
        if grep -Eq "^$pkg *= *\{ *path *= *\"\.\./$pkg\"" "$manifest"; then
          all=$(printf '%s\n%s\n' "$all" "$dependent")
        fi
      done
    done
    while read -r pkg; do
      # A directory under crates/ that is gone (a deleted package) has nothing to build.
      if [ -n "$pkg" ] && [ -d "crates/$pkg" ]; then echo "build $pkg"; fi
    done < <(sort -u <<<"$all")
  fi
  local entry name trigger
  for entry in "${CHECKS[@]}"; do
    name=${entry%%::*}
    trigger=${entry##*::}
    if grep -Eq "$trigger" <<<"$paths"; then
      echo "check $name"
    fi
  done
}

if [ "${1:-}" = "--select" ]; then
  select_steps
  exit 0
fi

fail() {
  echo "prepush: FAILED: $1" >&2
  exit 1
}

# Changed files: against the merge base with origin/main, so the commits being pushed and any
# uncommitted change of a tracked file, plus untracked files.
if git rev-parse --verify --quiet origin/main >/dev/null; then
  base=$(git merge-base origin/main HEAD)
else
  echo "prepush: origin/main not found, selecting every check" >&2
  base=$(git hash-object -t tree /dev/null)
fi
changed=$( (git diff --name-only "$base"; git ls-files --others --exclude-standard) | sort -u)

scarb fmt --check --workspace || fail "format (scarb fmt --check --workspace)"
python3 -m unittest discover -s scripts/tests >/dev/null 2>&1 \
  || { python3 -m unittest discover -s scripts/tests 2>&1 | tail -n 30 >&2; fail "unit tests of the scripts"; }

# The steps are computed first (a failure of select_steps stops the script, set -e) and read on
# fd 3, with stdin of every step from /dev/null, so no step can eat the list.
steps=$(select_steps <<<"$changed")
while read -r kind target <&3; do
  [ -n "$kind" ] || continue
  if [ "$kind" = build ]; then
    if [ "$target" = workspace ]; then
      scarb build --workspace </dev/null || fail "build (scarb build --workspace)"
    else
      scarb build -p "$target" </dev/null || fail "build (scarb build -p $target)"
    fi
    continue
  fi
  for entry in "${CHECKS[@]}"; do
    [ "${entry%%::*}" = "$target" ] || continue
    command=${entry#*::}
    command=${command%::*}
    if [ "$command" = golden ]; then
      if command -v cargo >/dev/null 2>&1; then
        cargo run --quiet --locked --manifest-path tools/refgen/Cargo.toml -- check </dev/null \
          || fail "golden vectors (tools/refgen)"
      else
        echo "prepush: cargo not found, golden vector check left to CI" >&2
      fi
    else
      # shellcheck disable=SC2086 # the command is a fixed word list from CHECKS
      $command </dev/null || fail "$target ($command)"
    fi
  done
done 3<<<"$steps"

echo "prepush: all checks passed"
