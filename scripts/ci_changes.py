#!/usr/bin/env python3
"""Which jobs of .github/workflows/ci.yml a pull request needs (LIB-04g).

Reads the changed paths on standard input, one per line (`git diff --name-only <base>...<head>`),
and prints one `<group>=true|false` line per group, ready for `$GITHUB_OUTPUT`. A job of ci.yml
runs when the group named in its `if:` is `true`.

Fail open: an empty list selects every group, and so does a change to the workflow or to this
script. A test is never skipped by accident.

A new job, or a new input of a job, must be added here (GROUPS) and in ci.yml. The mapping follows
the CHECKS table of scripts/prepush.sh, so that a push prepush lets through is classified the same
way in CI.

    git diff --name-only BASE...HEAD | python3 scripts/ci_changes.py >> "$GITHUB_OUTPUT"
    python3 scripts/ci_changes.py --all                                  (every group `true`)
"""
from __future__ import annotations

import re
import sys

# group -> extended regular expression on the repository-relative path (fullmatch).
GROUPS: dict[str, str] = {
    # job `links`: any Markdown file (lychee has no configuration file of its own).
    "links": r".*\.md",
    # job `scripts` (shellcheck scripts/*.sh).
    "shell": r"(scripts/[^/]*\.sh|\.githooks/.*)",
    # job `fmt`: scarb fmt, the unit tests of the scripts, the generated documents and their inputs.
    "docs_checks": (
        r".*\.cairo|Scarb\.(toml|lock)|crates/[^/]+/Scarb\.toml|\.tool-versions|scripts/.*"
        r"|docs/(API_PARITY|EXTENSIONS|DEVIATIONS|GAS)\.md|gas/.*"
    ),
    # job `takeover`.
    "takeover": r"(crates/hexx/.*|scripts/takeover_check\.py|\.tool-versions)",
    # jobs `test`, `package`, `gas`, `gas-complete`, `determinism`.
    "cairo": (
        r"(crates/.*|Scarb\.(toml|lock)|\.tool-versions|gas/.*"
        r"|scripts/(bench|bytecode_size)\.py)"
    ),
    # job `golden`.
    "golden": (
        r"(tools/refgen/.*|crates/hexx/tests/golden_[^/]*\.cairo"
        r"|crates/hexx/src/board/(line|tables|hexagon)\.cairo|docs/deviations/line_ties\.md)"
    ),
}

# A change to one of these selects every group.
SELECTS_ALL = re.compile(r"\.github/workflows/ci\.yml|scripts/ci_changes\.py")


def select(paths: list[str]) -> dict[str, bool]:
    """The groups a list of changed paths selects."""
    paths = [p.strip() for p in paths if p.strip()]
    if not paths or any(SELECTS_ALL.fullmatch(p) for p in paths):
        return {group: True for group in GROUPS}
    return {
        group: any(re.fullmatch(pattern, p) for p in paths)
        for group, pattern in GROUPS.items()
    }


def main(argv: list[str]) -> int:
    if argv[1:] == ["--all"]:
        paths: list[str] = []
    elif len(argv) > 1:
        print(__doc__, file=sys.stderr)
        return 2
    else:
        try:
            paths = sys.stdin.read().splitlines()
        except (OSError, UnicodeDecodeError):
            paths = []  # unreadable: every group
    for group, selected in select(paths).items():
        print(f"{group}={'true' if selected else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
