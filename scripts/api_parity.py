#!/usr/bin/env python3
"""Generate the `hexx` 0.25.0 versus this package's public API parity table.

The parser is intentionally dependency free (house rule, `glam-cairo:scripts/api_parity.py`). It
is not a Rust or Cairo parser: it masks comments, finds balanced brace blocks, and recognizes the
small set of declarations `hexx` and this package use. The `hexx` inventory is embedded as JSON in
the generated Markdown so the normal CI check does not need a `hexx` checkout (--check reads it
back); `--refresh --hexx /path/to/hexx` regenerates it from a pinned checkout (plan §4.2).

Effective visibility (plan §4.2): a module or a free item that is not `pub` all the way from
`src/lib.rs`, and not bridged by a `pub use` re-export, is not part of the public API even when its
own declaration says `pub` (`hex::iter::ExactSizeHexIterator`, `direction::way::Way`: both `pub`,
neither reachable). `PRIVATE_MODULES` lists the two cases of `hexx` 0.25.0 that need this: only the
types named in the parent's `pub use` are scanned from the private file, everything else in it is
ignored (`Way`, `ExactSizeHexIterator` and its own trait impls never enter the inventory).
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

VERSION = "0.25.0"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "API_PARITY.md"
EXTENSIONS_OUTPUT = ROOT / "docs" / "EXTENSIONS.md"
CAIRO_SRC = ROOT / "crates" / "hexx" / "src"
INVENTORY_START = "<!-- api-parity-hexx-inventory\n"
INVENTORY_END = "\napi-parity-hexx-inventory -->"

# Every owner of the generated table (plan §4.1): the mirror types/modules, plus `HexSpanExt`
# (the counterpart of the `HexIterExt` trait, plan §4.4 "swizzles, conversions, euclidean,
# iterator helpers"). Extension owners (`board`, `finders`, `generators`, ...) are never in this
# set: they are inventoried by `--extensions` instead (plan §4.2 "Extras").
OWNER_ORDER = (
    "Hex", "EdgeDirection", "VertexDirection", "DirectionWay", "HexBounds", "HexOrientation",
    "conversions", "shapes", "algorithms", "GridEdge", "GridVertex", "HexSpanExt",
)
OWNERS = frozenset(OWNER_ORDER)

# hexx source file (relative to the checkout root) -> fixed owner of every item found in it,
# whichever impl block it sits in (plan §4.4 groups `Hex::all_edges`, defined in `grid/edge.rs`,
# under `GridEdge`; `conversions.rs`'s methods, defined as `impl Hex { ... }`, under `conversions`:
# the plan groups by source file, not by impl target — the same convention `glam-cairo`'s
# `TYPE_FILES` uses).
OWNER_FILES = {
    "src/hex/mod.rs": "Hex",
    "src/hex/impls.rs": "Hex",
    "src/hex/rings.rs": "Hex",
    "src/hex/swizzle.rs": "Hex",
    "src/hex/convert.rs": "Hex",
    "src/hex/euclidean.rs": "Hex",
    "src/hex/grid/edge.rs": "GridEdge",
    "src/hex/grid/vertex.rs": "GridVertex",
    "src/conversions.rs": "conversions",
    "src/bounds.rs": "HexBounds",
    "src/shapes.rs": "shapes",
    "src/orientation.rs": "HexOrientation",
    "src/direction/edge_direction.rs": "EdgeDirection",
    "src/direction/vertex_direction.rs": "VertexDirection",
    "src/algorithms/field_of_movement.rs": "algorithms",
    "src/algorithms/pathfinding.rs": "algorithms",
    "src/algorithms/fov.rs": "algorithms",
}

# Files with more than one owner: owner is resolved per `impl ... for <Target>` block instead of
# fixed by file (`src/direction/impls.rs` carries both `EdgeDirection` and `VertexDirection`
# operator impls).
DYNAMIC_FILES = ("src/direction/impls.rs",)

# Effective-visibility exception (plan §4.2, audit finding 12): a private (or `pub(crate)`) module
# whose declaration file still holds `pub` items, reachable only through the parent's `pub use`.
# `types`: the names re-exported from that file; only those are scanned from it.
PRIVATE_MODULES = {
    "src/hex/iter.rs": {"owner": "HexSpanExt", "types": ("HexIterExt",)},
    "src/direction/way.rs": {"owner": "DirectionWay", "types": ("DirectionWay",)},
}

RUST_IMPL_TRAITS = {
    "Add", "AddAssign", "BitAnd", "BitOr", "BitXor", "Debug", "Default", "Div", "DivAssign",
    "From", "FromIterator", "Mul", "MulAssign", "Neg", "Not", "PartialEq", "Product", "Rem",
    "RemAssign", "Shl", "Shr", "Sub", "SubAssign", "Sum",
}


@dataclass(frozen=True, order=True)
class Item:
    owner: str
    kind: str  # struct | enum | field | variant | trait | method | const | impl
    name: str
    source: str = ""

    @property
    def key(self) -> tuple[str, str, str]:
        return (self.owner, self.kind, self.name)

    def as_json(self) -> dict[str, str]:
        return {"owner": self.owner, "kind": self.kind, "name": self.name, "source": self.source}


@dataclass(frozen=True)
class Rule:
    owner: re.Pattern[str]
    item: re.Pattern[str]
    status: str
    reason: str
    replacement: str = ""


def rule(owner: str, item: str, status: str, reason: str, replacement: str = "") -> Rule:
    return Rule(re.compile(owner), re.compile(item), status, reason, replacement)


# Broad exclusion/rename rules (plan §4.2): matched only for items the direct name/owner match
# against the Cairo source and the curated COUNTERPARTS below did not already resolve. Every rule
# here corresponds to a row of plan §4.4 marked `excluded` or `counterpart` within a *kept* module;
# `port` rows need no rule: with nothing implemented yet, they default to `missing` (house rule,
# "no stubbed success" — see module docstring and the report for what this does not cover: the
# three modules excluded as a whole, `layout`, `storage`, `mesh`, plan §4.4 "Modules excluded as a
# whole", are not walked by this parser, a scope limit recorded in the report, not a silent gap).
RULES = (
    # hex: f32 output/input, slice APIs, reference glue (src/hex/mod.rs, impls.rs, convert.rs,
    # euclidean.rs).
    rule("Hex", r"method:(?:to_array_f32|to_cubic_array_f32|as_vec2|round|from_slice|"
                r"write_to_slice|euclidean_length|euclidean_distance_to)",
         "dropped", "f32 output/input, or a slice API (house rule): the meaning needs floating "
                    "point, no exact integer restatement exists on-chain."),
    rule("Hex", r"impl:PartialEq<Hex> for &Hex", "dropped",
         "reference glue: Cairo values are Copy and passed by value."),
    rule("Hex", r"method:(?:as_ivec2|as_ivec3)", "renamed",
         "moved to the companion package hexx_glam (L-M3), as Into<Hex, IVec2> / "
         "Into<Hex, IVec3>, the same convention nalgebra_glam uses."),
    rule("Hex", r"impl:From<\(f32,f32\)> for Hex|impl:From<\[f32;2\]> for Hex|"
                r"impl:From<Vec2> for Hex",
         "dropped", "f32 input."),
    rule("Hex", r"impl:From<Hex> for IVec2|impl:From<Hex> for IVec3|impl:From<IVec2> for Hex",
         "renamed", "moved to the companion package hexx_glam (L-M3)."),
    rule("Hex", r"impl:Add<i32> for Hex", "renamed",
         "add_scalar — Cairo's Add<T> is homogeneous."),
    rule("Hex", r"impl:Sub<i32> for Hex", "renamed", "sub_scalar — same reason."),
    rule("Hex", r"impl:Add<EdgeDirection> for Hex", "renamed", "add_direction — same reason."),
    rule("Hex", r"impl:Sub<EdgeDirection> for Hex", "renamed", "sub_direction — same reason."),
    rule("Hex", r"impl:Add<VertexDirection> for Hex", "renamed", "add_diagonal — same reason."),
    rule("Hex", r"impl:Sub<VertexDirection> for Hex", "renamed", "sub_diagonal — same reason."),
    rule("Hex", r"impl:Mul<i32> for Hex", "renamed", "mul_scalar — same reason."),
    rule("Hex", r"impl:Div<i32> for Hex", "renamed",
         "div_scalar — exact rational rescale, same rounding rule as hexx's f32 lerp; a "
         "documented deviation where hexx's own f32 error moves its result off that rule."),
    rule("Hex", r"impl:Rem<i32> for Hex", "renamed", "rem_scalar — same reason as div_scalar."),
    rule("Hex", r"impl:(?:Add|Sub|Mul|Div|Rem)Assign<(?:i32|EdgeDirection|VertexDirection)> "
                r"for Hex",
         "dropped",
         "heterogeneous assignment operators; the named *_scalar / *_direction / *_diagonal "
         "methods cover them (house rule for Vec * scalar)."),
    rule("Hex", r"impl:(?:Mul|Div|MulAssign|DivAssign)<f32> for Hex", "dropped", "f32 operand."),
    rule("Hex", r"impl:Bit(?:And|Or|Xor)(?:<i32>)? for Hex", "dropped",
         "Cairo's corelib has no bitwise operators on signed integers; a two's-complement "
         "emulation per component is more code than any use justifies, and no consumer names "
         "one (reversible, plan §12)."),
    rule("Hex", r"impl:Sh[lr]<(?:i8|i16|i32|u8|u16|u32|Hex)> for Hex", "dropped",
         "same reason: no shifts on signed integers in the corelib."),
    # direction: f32 angle functions (both EdgeDirection and VertexDirection carry the same 18
    # names, src/direction/edge_direction.rs, vertex_direction.rs).
    rule("EdgeDirection|VertexDirection",
         r"method:(?:angle_between|angle_degrees_between|angle_to|angle_degrees_to|angle_flat|"
         r"angle_pointy|angle|unit_vector|world_unit_vector|angle_flat_degrees|"
         r"angle_pointy_degrees|angle_degrees|from_pointy_angle_degrees|from_flat_angle_degrees|"
         r"from_pointy_angle|from_flat_angle|from_angle_degrees|from_angle)$",
         "dropped",
         "f32 angles and vectors. Integer counterparts of \"the direction of a hex\" exist on "
         "Hex (way_to, main_direction_to, neighbor_direction); of \"rotate by an angle\", "
         "rotate_cw(n)."),
    rule("EdgeDirection|VertexDirection", r"impl:Sh[lr]<u8> for (?:Edge|Vertex)Direction",
         "renamed",
         "Cairo has no shift operators for user types; the named rotate_cw(n) / rotate_ccw(n) "
         "are the operators' bodies — nothing to add."),
    rule("EdgeDirection|VertexDirection", r"impl:Mul<i32> for (?:Edge|Vertex)Direction",
         "renamed", "mul_scalar(n) -> Hex."),
    # orientation: HexOrientationData and its f32 matrices (src/orientation.rs).
    rule("HexOrientation",
         r"(?:struct:HexOrientationData|method:(?:flat|pointy|forward|inverse|"
         r"orientation_data)|impl:Deref for HexOrientation)",
         "dropped", "f32 matrices: HexLayout and world/screen space belong to the client "
                    "(L-G1 consequence)."),
)

# Curated per-item map (plan §4.2): the counterparts whose Rust signature would otherwise trip a
# broad exclusion rule (an `impl Fn` callback, a `HashSet` return, a const generic array) — wins
# over RULES (audit finding 13: the first version of the plan let the broad rules classify these
# signatures, which hid incomplete parity). Keyed by (owner, kind, name); value is
# (status, cairo_name, detail). `status` follows plan §1.1: `ported` when the Cairo name equals
# the Rust name, `renamed` otherwise.
COUNTERPARTS: dict[tuple[str, str, str], tuple[str, str, str]] = {
    ("algorithms", "method", "field_of_movement"): (
        "ported", "field_of_movement",
        "hexx::algorithms::field_of_movement(map: HexMap, from: u8, budget: u8, "
        "costs: Span<felt252>) -> felt252, forwarding to HexMapTrait::field_of_movement. Same "
        "cost model: hexx charges 1 + cost(h), the board charges k + 2 for class k, so class k "
        "is cost(h) = k + 1, None is a wall, cost(h) = 0 is any other walkable tile. At most 3 "
        "classes (cost 2..=4), a bounded board, the outer ring is wall."),
    ("algorithms", "method", "a_star"): (
        "ported", "a_star",
        "hexx::algorithms::a_star(map, from, to, costs) -> Option<Span<u8>>, forwarding to "
        "search_path_weighted and reordering the path start to end, both included. Deviation: "
        "directed per-step costs (cost(a, b)) have no counterpart, only per-tile entry costs; "
        "ties follow the board's lowest-tile-index rule against hexx's unspecified heap order."),
    ("algorithms", "method", "range_fov"): (
        "ported", "range_fov",
        "hexx::algorithms::range_fov(map, from, range) -> felt252: for every tile of "
        "hexagon_ring(from, range), the prefix of line up to the first wall. Deviation: the "
        "board's line tie rule (§6.6)."),
    ("algorithms", "method", "directional_fov"): (
        "ported", "directional_fov",
        "hexx::algorithms::directional_fov(map, from, range, direction: EdgeDirection) -> "
        "felt252: the facing is an EdgeDirection, whose two vertex directions select the ring "
        "tiles whose diagonal_way_to matches one of them, then the board and line deviations of "
        "range_fov."),
    ("HexSpanExt", "trait", "HexIterExt"): (
        "renamed", "HexSpanExt",
        "HexSpanExt on Span<Hex>: average through the exact div_scalar (same deviation), "
        "center, bounds."),
    ("HexBounds", "impl", "FromIterator<Hex>"): (
        "renamed", "from_span", "from_span(Span<Hex>) -> HexBounds."),
}


# ---------------------------------------------------------------------------------------------
# Parsing: masking, balanced blocks (shared by the Rust and the Cairo side)


def mask_comments(text: str) -> str:
    """Replace comments and strings by spaces while preserving offsets and newlines."""
    out = list(text)
    i = 0
    state = "code"
    quote = ""
    while i < len(text):
        pair = text[i:i + 2]
        if state == "code" and pair == "//":
            state = "line"
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if state == "code" and pair == "/*":
            state = "block"
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if state == "code" and text[i] == '"':
            state, quote = "string", text[i]
            out[i] = " "
            i += 1
            continue
        if state == "line":
            if text[i] == "\n":
                state = "code"
            else:
                out[i] = " "
            i += 1
            continue
        if state == "block":
            if pair == "*/":
                out[i] = out[i + 1] = " "
                state = "code"
                i += 2
            else:
                if text[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        if state == "string":
            if text[i] == "\\" and i + 1 < len(text):
                if text[i] != "\n":
                    out[i] = " "
                if text[i + 1] != "\n":
                    out[i + 1] = " "
                i += 2
                continue
            if text[i] == quote:
                state = "code"
            if text[i] != "\n":
                out[i] = " "
            i += 1
            continue
        i += 1
    return "".join(out)


def closing_brace(text: str, opening: int) -> int:
    depth = 0
    for i in range(opening, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError(f"unclosed brace at byte {opening}")


def blocks(text: str, pattern: re.Pattern[str]) -> list[tuple[re.Match[str], int, int]]:
    found = []
    for match in pattern.finditer(text):
        opening = text.find("{", match.start(), match.end() + 2)
        if opening >= 0:
            found.append((match, opening, closing_brace(text, opening)))
    return found


def split_top_level(body: str, sep: str = ",") -> list[str]:
    parts, start, depth = [], 0, 0
    for i, char in enumerate(body):
        if char in "([{<":
            depth += 1
        elif char in ")]}>":
            depth -= 1
        elif char == sep and depth == 0:
            parts.append(body[start:i])
            start = i + 1
    parts.append(body[start:])
    return [p.strip() for p in parts if p.strip()]


def clean_type(value: str, self_type: str = "") -> str:
    value = re.sub(r"'[_a-zA-Z0-9]+", "", value)
    value = value.replace("crate::", "").replace("std::", "").replace("core::", "")
    value = re.sub(r"\bSelf\b", self_type, value)
    value = value.replace("&", "").replace("mut ", "")
    return re.sub(r"\s+", "", value).strip(",")


# ---------------------------------------------------------------------------------------------
# The hexx (Rust) side


def scan_struct_enum(text: str, owner: str, source: str, allowed: set[str] | None,
                      prefix_fields: bool = False) -> list[Item]:
    """`prefix_fields`: when a file declares more than one local struct/enum under the same
    owner (`shapes.rs`'s six shapes), field and variant names alone are not a stable identity —
    `left` of `PointyRectangle` and `left` of `FlatRectangle` would collapse into one item on
    `unique_items`'s (owner, kind, name) dedup. Prefixing with `Type.` keeps them distinct."""
    items: list[Item] = []
    struct_re = re.compile(r"\bpub\s+struct\s+([A-Za-z_]\w*)\s*\{")
    tuple_re = re.compile(r"\bpub\s+struct\s+([A-Za-z_]\w*)\s*\(([^;]*)\)\s*;")
    enum_re = re.compile(r"\bpub\s+enum\s+([A-Za-z_]\w*)(?:<[^\{]*>)?\s*\{")

    def scoped(type_name: str, name: str) -> str:
        return f"{type_name}.{name}" if prefix_fields else name

    for match, opening, end in blocks(text, struct_re):
        name = match.group(1)
        if allowed is not None and name not in allowed:
            continue
        items.append(Item(owner, "struct", name, source))
        for line in text[opening + 1:end].splitlines():
            field = re.match(r"\s*pub\s+([a-z_]\w*)\s*:", line)
            if field:
                items.append(Item(owner, "field", scoped(name, field.group(1)), source))

    for match in tuple_re.finditer(text):
        name = match.group(1)
        if allowed is not None and name not in allowed:
            continue
        items.append(Item(owner, "struct", name, source))
        for index, part in enumerate(split_top_level(match.group(2))):
            if re.match(r"^pub\s+(?!\()", part):
                items.append(Item(owner, "field", scoped(name, str(index)), source))

    for match, opening, end in blocks(text, enum_re):
        name = match.group(1)
        if allowed is not None and name not in allowed:
            continue
        items.append(Item(owner, "enum", name, source))
        for part in split_top_level(text[opening + 1:end]):
            variant = re.match(r"^([A-Za-z_]\w*)", part)
            if variant:
                items.append(Item(owner, "variant", scoped(name, variant.group(1)), source))
    return items


def scan_trait(text: str, owner: str, source: str, names: set[str]) -> list[Item]:
    items: list[Item] = []
    trait_re = re.compile(r"\bpub\s+trait\s+([A-Za-z_]\w*)[^\{]*\{")
    for match, opening, end in blocks(text, trait_re):
        name = match.group(1)
        if name not in names:
            continue
        items.append(Item(owner, "trait", name, source))
        for fn in re.finditer(r"\bfn\s+([A-Za-z_]\w*)\s*\(", text[opening + 1:end]):
            items.append(Item(owner, "method", fn.group(1), source))
    return items


def scan_free_items(text: str, owner: str, source: str) -> list[Item]:
    """`pub fn` / `pub const` anywhere in the file: free functions and inherent-impl methods
    alike (the file already carries one fixed owner — plan §4.4 groups by source file, see
    `OWNER_FILES`)."""
    items = []
    for match in re.finditer(r"\bpub\s+(?:const\s+)?fn\s+([A-Za-z_]\w*)", text):
        items.append(Item(owner, "method", match.group(1), source))
    for match in re.finditer(r"\bpub\s+const\s+([A-Z][A-Z0-9_]*)\s*:", text):
        items.append(Item(owner, "const", match.group(1), source))
    return items


def build_impl_item(owner: str, trait_expr: str, target: str) -> Item | None:
    match = re.match(r"([A-Za-z][A-Za-z0-9_]*)(?:<(.*)>)?$", trait_expr)
    if not match:
        return None
    trait, arg = match.group(1), match.group(2)
    if trait not in RUST_IMPL_TRAITS:
        return None
    if trait == "From" and arg:
        name = f"From<{arg}> for {target}"
    elif arg:
        name = f"{trait}<{arg}>"
    else:
        name = trait
    if target != owner:
        name += f" for {target}"
    return Item(owner, "impl", name, "")


def scan_impls(text: str, owner_or_dynamic: str | None, source: str,
               allowed_targets: set[str]) -> list[Item]:
    """`impl Trait<Args> for Target { ... }`. `owner_or_dynamic=None`: owner = target (only
    `src/direction/impls.rs`, which carries impls of two owners in one file). `allowed_targets`:
    the file's own owner plus every locally declared struct/enum plus the global `OWNERS` — a
    target outside that set is a private helper (`Node` of `algorithms/pathfinding.rs`, not
    `pub struct`) and contributes nothing to the public API."""
    items = []
    impl_re = re.compile(r"(?m)^\s*impl(?:\s*<[^\n{]*>)?\s+(.+?)\s+for\s+([A-Za-z_]\w*)\s*\{")
    for match in impl_re.finditer(text):
        target = match.group(2).strip()
        if target not in allowed_targets:
            continue
        owner = owner_or_dynamic or target
        trait_expr = clean_type(match.group(1), self_type=target)
        item = build_impl_item(owner, trait_expr, target)
        if item:
            items.append(item)
    return items


# A file whose owner covers more than one local struct with its own inherent impl (only
# `shapes.rs`: six shapes share method names `new` / `coords`, and some share field names —
# `left`/`right`/`top`/`bottom` of `PointyRectangle` and `FlatRectangle`). Scoped by type name
# (`scan_multi_struct_file`) so they do not collapse into one item on the (owner, kind, name)
# dedup `unique_items` does. Every other `OWNER_FILES` entry has one local type per file (or
# none, `conversions.rs`), where the plain per-file scan (plan §4.4's own grouping) is exact.
MULTI_STRUCT_FILES = ("src/shapes.rs",)


def scan_multi_struct_file(text: str, owner: str, source: str) -> list[Item]:
    items = list(scan_struct_enum(text, owner, source, allowed=None, prefix_fields=True))
    local_types = {i.name for i in items if i.kind in ("struct", "enum")}
    for type_name in local_types:
        inherent_re = re.compile(rf"(?m)^\s*impl\s+{re.escape(type_name)}\s*\{{")
        for _, opening, end in blocks(text, inherent_re):
            body = text[opening + 1:end]
            for fn in re.finditer(r"\bpub\s+(?:const\s+)?fn\s+([A-Za-z_]\w*)", body):
                items.append(Item(owner, "method", f"{type_name}.{fn.group(1)}", source))
            for const in re.finditer(r"\bpub\s+const\s+([A-Z][A-Z0-9_]*)\s*:", body):
                items.append(Item(owner, "const", f"{type_name}.{const.group(1)}", source))
    # Module-level free functions (`parallelogram(...)`, `triangle(...)`, ...) are not indented
    # (an impl body's own `pub fn` always is, under this source's rustfmt): a bare name is
    # already unique, and matches plan §4.4's own un-prefixed rows for them.
    for match in re.finditer(r"(?m)^pub\s+(?:const\s+)?fn\s+([A-Za-z_]\w*)", text):
        items.append(Item(owner, "method", match.group(1), source))
    items.extend(scan_impls(text, owner, source, allowed_targets=local_types | OWNERS | {owner}))
    return items


def parse_hexx(hexx_root: Path) -> list[Item]:
    items: set[Item] = set()
    for rel, owner in OWNER_FILES.items():
        path = hexx_root / rel
        if not path.is_file():
            raise SystemExit(f"required hexx source missing: {path}")
        text = mask_comments(path.read_text())
        source = rel.removeprefix("src/")
        if rel in MULTI_STRUCT_FILES:
            items.update(scan_multi_struct_file(text, owner, source))
            continue
        struct_items = scan_struct_enum(text, owner, source, allowed=None)
        items.update(struct_items)
        local_types = {i.name for i in struct_items if i.kind in ("struct", "enum")}
        items.update(scan_free_items(text, owner, source))
        items.update(scan_impls(text, owner, source, allowed_targets=local_types | OWNERS | {owner}))

    for rel in DYNAMIC_FILES:
        path = hexx_root / rel
        text = mask_comments(path.read_text())
        source = rel.removeprefix("src/")
        items.update(scan_impls(text, None, source, allowed_targets=OWNERS))

    for rel, cfg in PRIVATE_MODULES.items():
        path = hexx_root / rel
        text = mask_comments(path.read_text())
        source = rel.removeprefix("src/")
        owner, names = cfg["owner"], set(cfg["types"])
        items.update(scan_struct_enum(text, owner, source, allowed=names))
        items.update(scan_trait(text, owner, source, names))
        items.update(scan_impls_for_targets(text, owner, source, names))
    return unique_items(items)


def scan_impls_for_targets(text: str, owner: str, source: str, names: set[str]) -> list[Item]:
    """Inherent and trait impls of a re-exported type living in a private module
    (`impl<T> DirectionWay<T> { ... }`, `impl<T> From<T> for DirectionWay<T>`): the type name may
    carry generics (`DirectionWay<T>`), so the plain `impl Trait for Target` scan of `scan_impls`
    (which requires a bare identifier target) does not see them."""
    items = []
    inherent_re = re.compile(r"(?m)^\s*impl(?:\s*<[^\n{]*>)?\s+([A-Za-z_]\w*)(?:<[^\n{]*>)?\s*\{")
    for match, opening, end in blocks(text, inherent_re):
        if match.group(1) not in names:
            continue
        items.extend(scan_free_items(text[opening + 1:end], owner, source))
    trait_impl_re = re.compile(
        r"(?m)^\s*impl(?:\s*<[^\n{]*>)?\s+(.+?)\s+for\s+([A-Za-z_]\w*)(?:<[^\n{]*>)?\s*\{"
    )
    for match in trait_impl_re.finditer(text):
        target = match.group(2)
        if target not in names:
            continue
        trait_expr = clean_type(match.group(1), self_type=target)
        item = build_impl_item(owner, trait_expr, target)
        if item:
            items.append(item)
    return items


# ---------------------------------------------------------------------------------------------
# The Cairo side (this package)


def parse_cairo() -> list[Item]:
    items: set[Item] = set()
    if not CAIRO_SRC.is_dir():
        return []
    trait_re = re.compile(r"\bpub\s+trait\s+([A-Za-z_]\w*)[^\{]*\{")
    impl_of_re = re.compile(r"\bpub\s+impl\s+[A-Za-z_]\w*\s+of\s+([A-Za-z_]\w*)(?:<[^\{]*>)?\s*\{")
    struct_re = re.compile(r"\bpub\s+struct\s+([A-Za-z_]\w*)\s*\{")
    enum_re = re.compile(r"\bpub\s+enum\s+([A-Za-z_]\w*)(?:<[^\{]*>)?\s*\{")

    for path in sorted(CAIRO_SRC.rglob("*.cairo")):
        text = mask_comments(path.read_text())
        source = str(path.relative_to(ROOT))

        for match, opening, end in blocks(text, struct_re) + blocks(text, enum_re):
            name = match.group(1)
            if name not in OWNERS:
                continue
            kind = "struct" if match.re is struct_re else "enum"
            items.add(Item(name, kind, name, source))
            body = text[opening + 1:end]
            for field in re.finditer(r"\bpub\s+([a-z_]\w*)\s*:", body):
                items.add(Item(name, "field", field.group(1), source))
            for variant in re.finditer(r"(?m)^\s*([A-Za-z_]\w*)\s*(?:[:,]|$)", body):
                items.add(Item(name, "variant", variant.group(1), source))

        for match, opening, end in blocks(text, trait_re):
            owner = match.group(1).removesuffix("Trait")
            if owner not in OWNERS:
                continue
            body = text[opening + 1:end]
            for fn in re.finditer(r"\bfn\s+([A-Za-z_]\w*)\s*(?:<[^;{()]*>)?\s*\(", body):
                items.add(Item(owner, "method", fn.group(1), source))
            for const in re.finditer(r"\bconst\s+([A-Z][A-Z0-9_]*)\s*:", body):
                items.add(Item(owner, "const", const.group(1), source))

        for match, opening, end in blocks(text, impl_of_re):
            owner = match.group(1).removesuffix("Trait")
            if owner not in OWNERS:
                continue
            body = text[opening + 1:end]
            for fn in re.finditer(r"\bfn\s+([A-Za-z_]\w*)\s*(?:<[^;{()]*>)?\s*\(", body):
                items.add(Item(owner, "method", fn.group(1), source))
    return unique_items(items)


def unique_items(items: set[Item] | list[Item]) -> list[Item]:
    result: dict[tuple[str, str, str], Item] = {}
    for item in sorted(items):
        result.setdefault(item.key, item)
    return sorted(result.values())


# ---------------------------------------------------------------------------------------------
# Classification (plan §4.2: direct match, then COUNTERPARTS, then RULES, else missing)


def rendered(item: Item) -> str:
    return f"{item.kind}:{item.name}"


def find_rule(item: Item) -> Rule | None:
    text = rendered(item)
    for candidate in RULES:
        if candidate.owner.fullmatch(item.owner) and candidate.item.search(text):
            return candidate
    return None


def classify(hexx: list[Item], cairo: list[Item]) -> tuple[dict[Item, tuple[str, str]], list[Item]]:
    cairo_by_key = {item.key: item for item in cairo}
    consumed: set[tuple[str, str, str]] = set()
    result: dict[Item, tuple[str, str]] = {}
    for item in hexx:
        if item.key in cairo_by_key:
            result[item] = ("ported", "")
            consumed.add(item.key)
            continue
        counterpart = COUNTERPARTS.get(item.key)
        if counterpart:
            status, cairo_name, detail = counterpart
            result[item] = (status, f"{cairo_name} — {detail}" if status != "ported" else detail)
            replacement_key = (item.owner, item.kind, cairo_name)
            if replacement_key in cairo_by_key:
                consumed.add(replacement_key)
            continue
        matched = find_rule(item)
        if matched:
            result[item] = (matched.status, matched.reason)
            continue
        result[item] = ("missing", "Not found in the Cairo public surface.")
    extras = [item for item in cairo if item.key not in consumed]
    return result, extras


# ---------------------------------------------------------------------------------------------
# Milestones (best-effort tag, informational — see the report; not gated by --check, only by the
# unit-tested --check-release, which no CI job invokes before a release is cut)

_L_M1 = {
    ("Hex", "struct", "Hex"), ("Hex", "field", "x"), ("Hex", "field", "y"),
    ("Hex", "const", "ZERO"), ("Hex", "const", "NEIGHBORS_COORDS"), ("Hex", "method", "new"),
    ("Hex", "method", "x"), ("Hex", "method", "y"), ("Hex", "method", "z"),
    ("Hex", "method", "const_sub"), ("Hex", "method", "length"), ("Hex", "method", "ulength"),
    ("Hex", "method", "distance_to"), ("Hex", "method", "unsigned_distance_to"),
    ("Hex", "method", "line_to"),
    ("conversions", "enum", "OffsetHexMode"), ("conversions", "variant", "Even"),
    ("conversions", "variant", "Odd"), ("conversions", "method", "to_offset_coordinates"),
    ("conversions", "method", "from_offset_coordinates"),
    ("EdgeDirection", "struct", "EdgeDirection"), ("EdgeDirection", "const", "ALL_DIRECTIONS"),
    ("EdgeDirection", "method", "iter"), ("EdgeDirection", "method", "index"),
    ("EdgeDirection", "method", "into_hex"), ("EdgeDirection", "method", "const_neg"),
    ("EdgeDirection", "method", "clockwise"), ("EdgeDirection", "method", "counter_clockwise"),
    ("EdgeDirection", "method", "rotate_ccw"), ("EdgeDirection", "method", "rotate_cw"),
    ("EdgeDirection", "impl", "From<EdgeDirection> for Hex"),
    ("HexOrientation", "enum", "HexOrientation"), ("HexOrientation", "variant", "Pointy"),
    ("HexOrientation", "variant", "Flat"),
}


def milestone_of(item: Item, status: str) -> str:
    if status == "dropped":
        return "—"
    if item.key in _L_M1:
        return "L-M1"
    if item.owner == "algorithms":
        return "L-M3"
    return "L-M2"


# ---------------------------------------------------------------------------------------------
# Rendering


def anchor(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def display_item(item: Item) -> str:
    return f"{item.kind} `{item.name}`"


def render(hexx: list[Item], cairo: list[Item]) -> str:
    statuses, extras = classify(hexx, cairo)
    owners = [o for o in OWNER_ORDER if any(i.owner == o for i in hexx) or any(i.owner == o for i in extras)]
    lines = [
        f"# API parity with hexx {VERSION}",
        "",
        "Generated by `python3 scripts/api_parity.py --refresh --hexx /path/to/hexx` (pinned "
        "checkout, plan §0). `--check` (in `scripts/check.sh` and CI) reads the embedded "
        "inventory below and needs no hexx checkout. Percent is "
        "`(ported + renamed) / all hexx items`. Milestone is best-effort (see the report); not a "
        "release gate here — no publication is granted at this task (COMMON.md, brief LIB-04).",
        "",
        "**Scope limit** (recorded in the LIB-04 report): `layout`, `storage` and `mesh` are "
        "excluded as whole modules (plan §4.4 \"Modules excluded as a whole\"); this parser does "
        "not walk them, so their ~148 items are not individually listed as `dropped` rows here. "
        "The percentage below is computed over the modules this parser does walk.",
        "",
        "## Summary",
        "",
        "| Owner | Ported | Dropped | Renamed | Missing | Extra | Parity |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    totals = [0, 0, 0, 0, 0]
    for owner in owners:
        owned = [item for item in hexx if item.owner == owner]
        counts = {name: sum(statuses[item][0] == name for item in owned)
                  for name in ("ported", "dropped", "renamed", "missing")}
        extra_count = sum(item.owner == owner for item in extras)
        denominator = len(owned)
        parity = 100.0 if denominator == 0 else 100.0 * (counts["ported"] + counts["renamed"]) / denominator
        for i, name in enumerate(("ported", "dropped", "renamed", "missing")):
            totals[i] += counts[name]
        totals[4] += extra_count
        lines.append(
            f"| [{owner}](#{anchor(owner)}) | {counts['ported']} | {counts['dropped']} | "
            f"{counts['renamed']} | {counts['missing']} | {extra_count} | {parity:.1f}% |"
        )
    denominator = len(hexx)
    parity = 100.0 if not denominator else 100.0 * (totals[0] + totals[2]) / denominator
    lines.append(f"| **Total** | **{totals[0]}** | **{totals[1]}** | **{totals[2]}** | "
                 f"**{totals[3]}** | **{totals[4]}** | **{parity:.1f}%** |")

    for owner in owners:
        lines += ["", f"## {owner}", "", "### hexx items", "",
                  "| Item | Status | Milestone | Rule/detail |", "|---|---|---|---|"]
        owned = [item for item in hexx if item.owner == owner]
        if owned:
            for item in owned:
                status, detail = statuses[item]
                lines.append(
                    f"| {display_item(item)} | {status} | {milestone_of(item, status)} | "
                    f"{detail or 'Same public name.'} |"
                )
        else:
            lines.append("| _None_ | — | — | Cairo-only owner. |")
        lines += ["", "### Cairo-only items", ""]
        owner_extras = [item for item in extras if item.owner == owner]
        if owner_extras:
            lines.extend(f"- {display_item(item)}" for item in owner_extras)
        else:
            lines.append("- None.")

    inventory = json.dumps([item.as_json() for item in hexx], indent=2, sort_keys=True)
    lines += ["", "## Embedded hexx inventory", "",
              "This machine-readable block is updated only by `--refresh`.", "",
              INVENTORY_START + inventory + INVENTORY_END, ""]
    return "\n".join(lines)


# Extension modules (plan §2.2: `board`, `finders`, `generators`) are outside the parity table
# (COMMON.md §7). None exists yet in this trivial package (LIB-05 adds the first one); the scan
# is here so `--extensions` stays correct once they land.
EXTENSION_MODULES = ("board", "finders", "generators")


def parse_extensions() -> dict[str, list[Item]]:
    result: dict[str, list[Item]] = {name: [] for name in EXTENSION_MODULES}
    if not CAIRO_SRC.is_dir():
        return result
    for module in EXTENSION_MODULES:
        module_dir = CAIRO_SRC / module
        if not module_dir.is_dir():
            continue
        items: set[Item] = set()
        for path in sorted(module_dir.rglob("*.cairo")):
            text = mask_comments(path.read_text())
            source = str(path.relative_to(ROOT))
            for match in re.finditer(r"\bpub\s+(?:const\s+)?fn\s+([A-Za-z_]\w*)", text):
                items.add(Item(module, "method", match.group(1), source))
            for match in re.finditer(r"\bpub\s+struct\s+([A-Za-z_]\w*)", text):
                items.add(Item(module, "struct", match.group(1), source))
            for match in re.finditer(r"\bpub\s+enum\s+([A-Za-z_]\w*)", text):
                items.add(Item(module, "enum", match.group(1), source))
        result[module] = unique_items(items)
    return result


def render_extensions(extensions: dict[str, list[Item]]) -> str:
    lines = [
        "# Extensions",
        "",
        "Generated by `python3 scripts/api_parity.py --extensions`. What Cairo and the network "
        "require beyond `hexx` (COMMON.md §7): boards as bitmaps in one felt, generation, "
        "floods, assembly. Outside the parity table (`docs/API_PARITY.md`), listed here by "
        "module so it stays inventoried (plan §4.2).",
        "",
    ]
    any_items = False
    for module, items in extensions.items():
        lines += [f"## `{module}`", ""]
        if items:
            any_items = True
            for item in items:
                lines.append(f"- {display_item(item)} (`{item.source}`)")
        else:
            lines.append("_None yet._")
        lines.append("")
    if not any_items:
        lines.append(
            "No extension module exists in this package yet (LIB-04 scaffolds the tooling only; "
            "the first extension item is a task of milestone L-M1, LIB-05)."
        )
    return "\n".join(lines).rstrip() + "\n"


def write_or_check(path: Path, generated: str, check: bool) -> int:
    current = path.read_text() if path.exists() else ""
    if check:
        if current == generated:
            print(f"{path.relative_to(ROOT)} is up to date")
            return 0
        print(f"{path.relative_to(ROOT)} is stale; run python3 scripts/api_parity.py", file=sys.stderr)
        diff = difflib.unified_diff(current.splitlines(), generated.splitlines(),
                                    fromfile=str(path), tofile="generated", lineterm="")
        for line in list(diff)[:80]:
            print(line, file=sys.stderr)
        return 1
    path.write_text(generated)
    print(f"wrote {path.relative_to(ROOT)}")
    return 0


def load_inventory(path: Path) -> list[Item]:
    if not path.is_file():
        raise SystemExit(f"{path} does not exist; run with --refresh and --hexx first")
    text = path.read_text()
    start = text.find(INVENTORY_START)
    end = text.find(INVENTORY_END, start + len(INVENTORY_START))
    if start < 0 or end < 0:
        raise SystemExit(f"{path} has no embedded hexx inventory; run with --refresh")
    data = json.loads(text[start + len(INVENTORY_START):end])
    return sorted(Item(**entry) for entry in data)


def check_release(hexx: list[Item], cairo: list[Item], release: str) -> int:
    """Every item scheduled at or before `release` must not be `missing` (AC-3: "an item
    scheduled for a release and absent fails the check of that release"). Milestone order:
    L-M1 < L-M2 < L-M3. Not part of `--check`/CI: no release is cut by this task (brief, Out)."""
    order = {"L-M1": 1, "L-M2": 2, "L-M3": 3}
    statuses, _ = classify(hexx, cairo)
    due = order.get(release)
    if due is None:
        raise SystemExit(f"unknown release {release!r}; expected one of {sorted(order)}")
    missing = [
        item for item in hexx
        if statuses[item][0] == "missing" and order.get(milestone_of(item, "missing"), 99) <= due
    ]
    if missing:
        print(f"{len(missing)} item(s) scheduled by {release} are still missing:", file=sys.stderr)
        for item in missing[:40]:
            print(f"  {item.owner}::{item.name} ({milestone_of(item, 'missing')})", file=sys.stderr)
        return 1
    print(f"every item scheduled by {release} is present")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="fail if docs/API_PARITY.md is stale")
    modes.add_argument("--refresh", action="store_true", help="refresh the embedded hexx inventory")
    modes.add_argument("--extensions", action="store_true", help="(re)generate docs/EXTENSIONS.md")
    modes.add_argument("--check-release", metavar="MILESTONE",
                        help="fail if an item scheduled by MILESTONE (L-M1, L-M2, L-M3) is missing")
    parser.add_argument("--hexx", type=Path, default=Path("/tmp/hexx"),
                        help="hexx 0.25.0 checkout (used only with --refresh)")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.extensions:
        return write_or_check(EXTENSIONS_OUTPUT, render_extensions(parse_extensions()), check=False)
    hexx = parse_hexx(args.hexx) if args.refresh else load_inventory(OUTPUT)
    cairo = parse_cairo()
    if args.check_release:
        return check_release(hexx, cairo, args.check_release)
    generated = render(hexx, cairo)
    return write_or_check(OUTPUT, generated, args.check)


if __name__ == "__main__":
    raise SystemExit(main())
