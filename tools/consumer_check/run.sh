#!/usr/bin/env bash
# Usage: tools/consumer_check/run.sh [HEXX_VERSION]
# Renders both consumer packages against `hexx = "=VERSION"` from the registry (never a path) in a
# scratch copy under work/consumer_check/ (git-ignored), builds `plain`, checks that its lock has no
# snforge_std, then builds and tests `with_tests`. The default version is the latest of the index.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
version="${1:-}"
if [ -z "$version" ]; then
  version="$("$here/versions.sh" | tail -n 1)"
fi
# The version reaches `rm -rf` and `sed` below: only a version string is accepted.
if ! [[ "$version" =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ ]]; then
  echo "run.sh: not a version: '$version'" >&2
  exit 2
fi
out="$root/work/consumer_check/$version"
rm -rf "$out"
mkdir -p "$out"
for pkg in plain with_tests; do
  cp -r "$here/$pkg" "$out/$pkg"
  sed "s/@HEXX_VERSION@/$version/" "$here/$pkg/Scarb.toml.in" >"$out/$pkg/Scarb.toml"
  rm "$out/$pkg/Scarb.toml.in"
done
echo "== hexx $version: plain"
(cd "$out/plain" && scarb build)
test -f "$out/plain/Scarb.lock" || { echo "FAIL: plain has no Scarb.lock" >&2; exit 1; }
if grep -q snforge_std "$out/plain/Scarb.lock"; then
  echo "FAIL: plain's Scarb.lock mentions snforge_std" >&2
  cat "$out/plain/Scarb.lock" >&2
  exit 1
fi
echo "plain: Scarb.lock has no snforge_std"
echo "== hexx $version: with_tests"
(cd "$out/with_tests" && scarb build && snforge test)
grep -A1 'name = "snforge_std"' "$out/with_tests/Scarb.lock"
