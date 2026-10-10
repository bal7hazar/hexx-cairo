#!/usr/bin/env python3
"""Generate docs/DEVIATIONS.md from the `#### Deviations` doc comments of `crates/hexx/src` and
`crates/hexx_glam/src`.

Adapted, unchanged in principle, from the house `scripts/deviations.py` of `glam-cairo`: every
ported item documents its Rust original with the template `Mirrors ...` / `#### Panics` /
`#### Deviations` (plan §4.2); this parser is dependency-free and recognizes that template rather
than parsing arbitrary Cairo. `--check` makes docs/DEVIATIONS.md a generated, reviewable
appendix: nothing is hand-edited there.

usage:
  scripts/deviations.py           rewrite docs/DEVIATIONS.md
  scripts/deviations.py --check   exit 1 if docs/DEVIATIONS.md is stale (CI and scripts/check.sh)
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "DEVIATIONS.md"
SOURCE_GLOBS = ("crates/hexx/src/**/*.cairo", "crates/hexx_glam/src/**/*.cairo")

DOC_RE = re.compile(r"^\s*///(?: ?(.*))?$")
DECL_RE = re.compile(
    r"^\s*(?:pub\s+)?(?:(fn)\s+([A-Za-z_][A-Za-z0-9_]*)|"
    r"(const)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:|"
    r"(struct|enum|trait|type)\s+([A-Za-z_][A-Za-z0-9_]*)|"
    r"(impl)\s+([A-Za-z_][A-Za-z0-9_]*))"
)
SECTION_RE = re.compile(r"^#### (Panics|Deviations)$")
MIRRORS_RE = re.compile(r"^Mirrors\s+(.*)$")


@dataclass(frozen=True)
class Item:
    path: str
    line: int
    owner: str
    kind: str
    name: str
    mirrors: str
    panics: str
    deviations: str


def source_paths() -> list[Path]:
    paths: set[Path] = set()
    for pattern in SOURCE_GLOBS:
        paths.update(ROOT.glob(pattern))
    # The crate root of `hexx` only re-exports; `hexx_glam` has no other file, its items are in
    # its `lib.cairo`.
    root = ROOT / "crates" / "hexx" / "src" / "lib.cairo"
    return sorted(path for path in paths if path != root)


def module_owner(path: Path) -> str:
    """Default owner from the file path, following the same file -> owner grouping
    `scripts/api_parity.py`'s `OWNER_FILES` uses (plan §4.4 groups by source file). Used only for
    items outside any `pub trait ...Trait` block; `owner_at` below, matching §2.2's "one trait
    per hexx source file" convention, is the common case."""
    stem = path.stem
    special = {
        "hex": "Hex", "impls": "Hex", "rings": "Hex", "swizzle": "Hex", "convert": "Hex",
        "euclidean": "Hex", "iter": "HexSpanExt", "edge": "GridEdge", "vertex": "GridVertex",
        "conversions": "conversions", "bounds": "HexBounds", "shapes": "shapes",
        "orientation": "HexOrientation", "lib": "HexGlam", "edge_direction": "EdgeDirection",
        "vertex_direction": "VertexDirection", "way": "DirectionWay",
        "field_of_movement": "algorithms", "pathfinding": "algorithms", "fov": "algorithms",
    }
    return special.get(stem, stem.capitalize())


def trait_ranges(lines: list[str]) -> list[tuple[int, int, str]]:
    """One-based inclusive ranges for public trait bodies."""
    ranges: list[tuple[int, int, str]] = []
    for index, line in enumerate(lines):
        match = re.match(r"^\s*pub\s+trait\s+([A-Za-z_][A-Za-z0-9_]*)", line)
        if not match:
            continue
        depth = 0
        opened = False
        for end in range(index, len(lines)):
            depth += lines[end].count("{") - lines[end].count("}")
            opened = opened or "{" in lines[end]
            if opened and depth == 0:
                ranges.append((index + 1, end + 1, match.group(1)))
                break
    return ranges


def owner_at(line: int, ranges: list[tuple[int, int, str]], fallback: str) -> str:
    for start, end, trait in ranges:
        if start <= line <= end:
            return trait.removesuffix("Trait")
    return fallback


def section_text(doc: list[str], heading: str) -> str:
    start = next((i + 1 for i, text in enumerate(doc) if text == f"#### {heading}"), None)
    if start is None:
        return ""
    body: list[str] = []
    for text in doc[start:]:
        if SECTION_RE.match(text) or MIRRORS_RE.match(text):
            break
        body.append(text)
    while body and not body[0]:
        body.pop(0)
    while body and not body[-1]:
        body.pop()
    return "\n".join(body)


def mirrors_text(doc: list[str]) -> str:
    for index, text in enumerate(doc):
        match = MIRRORS_RE.match(text)
        if not match:
            continue
        body = [match.group(1)]
        for continuation in doc[index + 1:]:
            if not continuation or SECTION_RE.match(continuation):
                break
            body.append(continuation)
        return "\n".join(body)
    return ""


def parse_file(path: Path) -> list[Item]:
    lines = path.read_text().splitlines()
    ranges = trait_ranges(lines)
    fallback = module_owner(path)
    result: list[Item] = []
    index = 0
    while index < len(lines):
        first = DOC_RE.match(lines[index])
        if not first:
            index += 1
            continue
        doc: list[str] = []
        while index < len(lines):
            match = DOC_RE.match(lines[index])
            if not match:
                break
            doc.append(match.group(1) or "")
            index += 1
        if "#### Deviations" not in doc:
            continue

        declaration = index
        while declaration < len(lines):
            stripped = lines[declaration].strip()
            if not stripped or stripped.startswith("#["):
                declaration += 1
                continue
            break
        if declaration == len(lines):
            raise ValueError(f"{path.relative_to(ROOT)}:{index}: doc block has no declaration")
        match = DECL_RE.match(lines[declaration])
        if not match:
            raise ValueError(
                f"{path.relative_to(ROOT)}:{declaration + 1}: cannot identify documented item: "
                f"{lines[declaration].strip()}"
            )
        if match.group(1):
            kind, name = "fn", match.group(2)
        elif match.group(3):
            kind, name = "const", match.group(4)
        elif match.group(5):
            kind, name = match.group(5), match.group(6)
        else:
            kind, name = "impl", match.group(8)

        owner = owner_at(declaration + 1, ranges, fallback)
        if kind in {"struct", "enum", "trait", "type"}:
            owner = name.removesuffix("Trait")
        result.append(
            Item(
                path=path.relative_to(ROOT).as_posix(),
                line=declaration + 1,
                owner=owner,
                kind=kind,
                name=name,
                mirrors=mirrors_text(doc),
                panics=section_text(doc, "Panics"),
                deviations=section_text(doc, "Deviations"),
            )
        )
    return result


def inventory() -> list[Item]:
    return [item for path in source_paths() for item in parse_file(path)]


def single_line(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def markdown_cell(text: str) -> str:
    return single_line(text).replace("\\", "\\\\").replace("|", "\\|") or "—"


def render(items: list[Item]) -> str:
    lines = [
        "# Deviations from hexx 0.25.0",
        "",
        "Generated by `python3 scripts/deviations.py` from the `#### Deviations` doc-comment "
        "section of every documented item of `crates/hexx/src` and `crates/hexx_glam/src` (plan §4.2). `--check` (in "
        "`scripts/check.sh` and CI) keeps this file a reviewable, generated appendix — nothing "
        "here is hand-edited.",
        "",
        f"{len(items)} documented deviation(s).",
        "",
        "| Source | Owner | Kind | Item | Mirrors | Panics | Deviations |",
        "|---|---|---|---|---|---|---|",
    ]
    for item in items:
        source = f"`{item.path}:{item.line}`"
        cells = (
            source,
            f"`{item.owner}`",
            f"`{item.kind}`",
            f"`{item.name}`",
            markdown_cell(item.mirrors),
            markdown_cell(item.panics),
            markdown_cell(item.deviations),
        )
        lines.append("| " + " | ".join(cells) + " |")
    return "\n".join(lines) + "\n"


def write_or_check(generated: str, check: bool) -> int:
    current = OUTPUT.read_text() if OUTPUT.exists() else ""
    if check:
        if current == generated:
            print(f"{OUTPUT.relative_to(ROOT)} is up to date")
            return 0
        print(f"{OUTPUT.relative_to(ROOT)} is stale; run python3 scripts/deviations.py",
              file=sys.stderr)
        diff = difflib.unified_diff(current.splitlines(), generated.splitlines(),
                                    fromfile=str(OUTPUT), tofile="generated", lineterm="")
        for line in list(diff)[:80]:
            print(line, file=sys.stderr)
        return 1
    OUTPUT.write_text(generated)
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit 1 if docs/DEVIATIONS.md is stale")
    args = parser.parse_args()
    try:
        items = inventory()
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    return write_or_check(render(items), args.check)


if __name__ == "__main__":
    raise SystemExit(main())
