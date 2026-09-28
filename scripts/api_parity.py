#!/usr/bin/env python3
"""Generate the `hexx` 0.25.0 versus this package's public API parity table.

The parser is intentionally dependency free (house rule, `glam-cairo:scripts/api_parity.py`). It
is not a Rust or Cairo parser: it masks comments, finds balanced brace blocks, and recognizes the
small set of declarations `hexx` and this package use. The `hexx` inventory is embedded as JSON in
the generated Markdown so the normal CI check does not need a `hexx` checkout (--check reads it
back); `--refresh --hexx /path/to/hexx` regenerates it from a pinned checkout (plan §4.2).

Effective visibility (plan §4.2, fix loop 1 finding 4) is computed, not assumed: `build_module_tree`
walks every `mod NAME;` / `mod NAME { ... }` declaration from the crate root (`src/lib.rs` on the
Rust side, `crates/hexx/src/lib.cairo` on the Cairo side), classifies each module `pub`,
`pub(crate)` or private, and resolves `pub use child::Name` / `pub use child::{A, B}` /
`pub use child::*` re-exports (single path segment, relative to the module the `pub use` sits in —
verified to be the only form every `pub use` of the pinned `hexx` 0.25.0 checkout takes, end to
end from the crate root: no multi-segment or `crate::`-prefixed re-export exists in it). A
freestanding declaration (struct/enum/trait/fn/const, not inside an `impl` block) is part of the
public API iff its own module is reachable this way, or it is named in such a re-export from a
reachable module. An `impl Type { ... }` or `impl Trait for Type { ... }` block contributes to
`Type`'s (or `Trait`'s) surface regardless of which file the block itself sits in — Rust attaches
inherent and trait impls to the type globally, not to the privacy of the module the block is
written in — so impl scanning is gated on whether `Type`/`Trait` is itself reachable (or, for a
type imported from another crate, whether this crate's own source actually `use`s it), never on
the impl block's own file.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

VERSION = "0.25.0"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "API_PARITY.md"
EXTENSIONS_OUTPUT = ROOT / "docs" / "EXTENSIONS.md"
CAIRO_SRC = ROOT / "crates" / "hexx" / "src"
CAIRO_ROOT_FILE = CAIRO_SRC / "lib.cairo"
INVENTORY_START = "<!-- api-parity-hexx-inventory\n"
INVENTORY_END = "\napi-parity-hexx-inventory -->"

# Every owner of the generated table (plan §4.1 for the twelve mirror owners; `layout`, `storage`,
# `mesh` are the three modules plan §4.4 "Modules excluded as a whole" asks to inventory with a
# `dropped` row each, fix loop 1 finding 5). Extension owners (`board`, `finders`, `generators`,
# ...) are never in this set: they are inventoried by `--extensions` instead (plan §4.2 "Extras").
OWNER_ORDER = (
    "Hex", "EdgeDirection", "VertexDirection", "DirectionWay", "HexBounds", "HexOrientation",
    "conversions", "shapes", "algorithms", "GridEdge", "GridVertex", "HexSpanExt",
    "layout", "storage", "mesh",
)
OWNERS = frozenset(OWNER_ORDER)

# An owner whose items are attributed to more than one local Rust type (or, for `storage`, spread
# across several files that all feed the same owner bucket): a method/field/variant/const name
# alone is not a stable identity there (`shapes.rs`'s six shapes share `new`/`coords`;
# `storage`'s five files share `get`/`iter`/...; `mesh`'s six files share `new`/`Default`/...).
# Scoped by `Type.name` so they do not collapse on the (owner, kind, name) dedup `unique_items`
# does. Every other owner has exactly one local type per module (or none: `conversions`,
# `algorithms`), where a bare name is exact and matches plan §4.4's own un-prefixed rows.
MULTI_TYPE_OWNERS = frozenset({"shapes", "storage", "mesh"})

# hexx module path (as `build_module_tree` resolves it, root = ()) -> the display owner of every
# item declared in, or whose impl block sits in, that module's own file (plan §4.4 groups
# `Hex::all_edges`, defined in `hex/grid/edge.rs`, under `GridEdge`; `conversions.rs`'s methods,
# defined as `impl Hex { ... }`, under `conversions`: the plan groups by source file, not by impl
# target). A module not listed here has no local declaration of its own (a pure `mod`/`pub use`
# aggregator, e.g. `direction/mod.rs`, `algorithms/mod.rs`) and is walked only for reachability.
MODULE_OWNER: dict[tuple[str, ...], str] = {
    ("hex",): "Hex",
    ("hex", "impls"): "Hex",
    ("hex", "rings"): "Hex",
    ("hex", "swizzle"): "Hex",
    ("hex", "convert"): "Hex",
    ("hex", "euclidean"): "Hex",
    ("hex", "iter"): "HexSpanExt",
    ("hex", "grid", "edge"): "GridEdge",
    ("hex", "grid", "vertex"): "GridVertex",
    ("conversions",): "conversions",
    ("bounds",): "HexBounds",
    ("shapes",): "shapes",
    ("orientation",): "HexOrientation",
    ("direction", "edge_direction"): "EdgeDirection",
    ("direction", "vertex_direction"): "VertexDirection",
    ("direction", "way"): "DirectionWay",
    # Inline `pub mod angles { ... }` of `direction/mod.rs`: four f32 constants, always dropped
    # (RULES below). The bucket owner is arbitrary (EdgeDirection); nothing about the bucket
    # choice affects its status.
    ("direction", "angles"): "EdgeDirection",
    ("algorithms", "field_of_movement"): "algorithms",
    ("algorithms", "fov"): "algorithms",
    ("algorithms", "pathfinding"): "algorithms",
    ("layout",): "layout",
    ("storage",): "storage",
    ("storage", "hexagonal"): "storage",
    ("storage", "hexmod"): "storage",
    ("storage", "rect"): "storage",
    ("storage", "rombus"): "storage",
    ("mesh",): "mesh",
    ("mesh", "face"): "mesh",
    ("mesh", "column_builder"): "mesh",
    ("mesh", "heightmap_builder"): "mesh",
    ("mesh", "plane_builder"): "mesh",
    ("mesh", "uv_mapping"): "mesh",
}

# Modules with local declarations of more than one owner: resolved per `impl ... for <Target>`
# block instead of the fixed `MODULE_OWNER` map (`direction/impls.rs` carries both `EdgeDirection`
# and `VertexDirection` operator impls, with neither the sole type of the file).
DYNAMIC_MODULES = (("direction", "impls"),)

RUST_IMPL_TRAITS = {
    "Add", "AddAssign", "BitAnd", "BitOr", "BitXor", "Debug", "Default", "Deref", "Div",
    "DivAssign", "From", "FromIterator", "Mul", "MulAssign", "Neg", "Not", "PartialEq", "Product",
    "Rem", "RemAssign", "Shl", "Shr", "Sub", "SubAssign", "Sum",
}


@dataclass(frozen=True, order=True)
class Item:
    owner: str
    kind: str  # struct | enum | field | variant | trait | method | const | impl | type
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
    # For a `renamed` rule: the Cairo-side (kind, name) this item maps to, checked for presence
    # (fix loop 1 finding 3: a rename is only shown as `renamed` once its target actually exists;
    # until then the item reads `missing`, so `--check-release` catches it). `None` for `dropped`
    # rules, which have no Cairo target to check by definition.
    replacement: tuple[str, str] | None = None


def rule(owner: str, item: str, status: str, reason: str,
         replacement: tuple[str, str] | None = None) -> Rule:
    return Rule(re.compile(owner), re.compile(item), status, reason, replacement)


# Broad exclusion/rename rules (plan §4.2): matched only for items the direct name/owner match
# against the Cairo source and the curated COUNTERPARTS below did not already resolve. Every rule
# here corresponds to a row of plan §4.4 marked `excluded` or `counterpart` within a *kept*
# module, or to one of the three modules excluded as a whole (`layout`, `storage`, `mesh`, plan
# §4.4 "Modules excluded as a whole": every item they carry is `dropped`, matched by the
# catch-all rules at the end regardless of name). A `port` row needs no rule: with nothing
# implemented yet, it defaults to `missing` (house rule, "no stubbed success").
#
# Rule patterns match the item exactly as `build_impl_item` renders it: an impl whose target
# equals its owner (the common case, e.g. every `Hex` operator in `Hex`-owned files) carries no
# `for <target>` suffix; only a cross-owner or foreign-type target does (`From<Hex> for IVec2`).
# Fix loop 1 finding 6: the first version of these rules assumed the suffix unconditionally and
# silently failed to match `BitAnd<i32>`, `Mul<f32>` and others — every pattern below was
# re-verified against `python3 scripts/api_parity.py --refresh --hexx sources/hexx`'s actual
# rendered names, not against a hand-derived guess.
RULES = (
    # hex: f32 output/input, slice APIs, reference glue (src/hex/mod.rs, impls.rs, convert.rs,
    # euclidean.rs).
    rule("Hex", r"method:(?:to_array_f32|to_cubic_array_f32|as_vec2|round|from_slice|"
                r"write_to_slice|euclidean_length|euclidean_distance_to)",
         "dropped", "f32 output/input, or a slice API (house rule): the meaning needs floating "
                    "point, no exact integer restatement exists on-chain."),
    rule("Hex", r"impl:PartialEq<Hex>$", "dropped",
         "reference glue (`impl PartialEq<Hex> for &Hex`): Cairo values are Copy and passed by "
         "value."),
    # Interop with the companion package hexx_glam (L-M3, plan §9): the Cairo replacement lives
    # in a *different* package this parser never scans (`CAIRO_SRC` is `crates/hexx/src` only),
    # so `replacement` below can never resolve true from inside this crate's own inventory — by
    # design (fix loop 2 finding 3): a mapping to code this package cannot ever contain must read
    # `missing` forever, not `renamed`, since "renamed" would otherwise claim work this crate's
    # own parity table has no way to verify. Scheduled at L-M3 (`_INTEROP_ITEMS` below), not the
    # L-M2 every other Hex operator counterpart defaults to.
    rule("Hex", r"method:as_ivec2$", "renamed", "Into<Hex, IVec2> (hexx_glam).",
         replacement=("method", "as_ivec2")),
    rule("Hex", r"method:as_ivec3$", "renamed", "Into<Hex, IVec3> (hexx_glam).",
         replacement=("method", "as_ivec3")),
    rule("Hex", r"impl:From<\(f32,f32\)> for Hex|impl:From<\[f32;2\]> for Hex|"
                r"impl:From<Vec2> for Hex",
         "dropped", "f32 input."),
    rule("Hex", r"impl:From<Hex> for IVec2$", "renamed", "Into<Hex, IVec2> (hexx_glam).",
         replacement=("impl", "From<Hex> for IVec2")),
    rule("Hex", r"impl:From<Hex> for IVec3$", "renamed", "Into<Hex, IVec3> (hexx_glam).",
         replacement=("impl", "From<Hex> for IVec3")),
    rule("Hex", r"impl:From<IVec2> for Hex$", "renamed", "Into<IVec2, Hex> (hexx_glam).",
         replacement=("impl", "From<IVec2> for Hex")),
    rule("Hex", r"impl:Add<i32>$", "renamed", "add_scalar — Cairo's Add<T> is homogeneous.",
         replacement=("method", "add_scalar")),
    rule("Hex", r"impl:Sub<i32>$", "renamed", "sub_scalar — same reason.",
         replacement=("method", "sub_scalar")),
    rule("Hex", r"impl:Add<EdgeDirection>$", "renamed", "add_direction — same reason.",
         replacement=("method", "add_direction")),
    rule("Hex", r"impl:Sub<EdgeDirection>$", "renamed", "sub_direction — same reason.",
         replacement=("method", "sub_direction")),
    rule("Hex", r"impl:Add<VertexDirection>$", "renamed", "add_diagonal — same reason.",
         replacement=("method", "add_diagonal")),
    rule("Hex", r"impl:Sub<VertexDirection>$", "renamed", "sub_diagonal — same reason.",
         replacement=("method", "sub_diagonal")),
    rule("Hex", r"impl:Mul<i32>$", "renamed", "mul_scalar — same reason.",
         replacement=("method", "mul_scalar")),
    rule("Hex", r"impl:Div<i32>$", "renamed",
         "div_scalar — exact rational rescale, same rounding rule as hexx's f32 lerp; a "
         "documented deviation where hexx's own f32 error moves its result off that rule.",
         replacement=("method", "div_scalar")),
    rule("Hex", r"impl:Rem<i32>$", "renamed", "rem_scalar — same reason as div_scalar.",
         replacement=("method", "rem_scalar")),
    rule("Hex", r"impl:(?:Add|Sub|Mul|Div|Rem)Assign<(?:i32|EdgeDirection|VertexDirection)>$",
         "dropped",
         "heterogeneous assignment operators; the named *_scalar / *_direction / *_diagonal "
         "methods cover them (house rule for Vec * scalar)."),
    rule("Hex", r"impl:(?:Mul|Div|MulAssign|DivAssign)<f32>$", "dropped", "f32 operand."),
    rule("Hex", r"impl:Bit(?:And|Or|Xor)(?:<i32>)?$", "dropped",
         "Cairo's corelib has no bitwise operators on signed integers; a two's-complement "
         "emulation per component is more code than any use justifies, and no consumer names "
         "one (reversible, plan §12)."),
    rule("Hex", r"impl:Sh[lr]<(?:i8|i16|i32|u8|u16|u32|Hex)>$", "dropped",
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
    # `hexx`'s `Shr<u8>`/`Shl<u8>` are the *bodies* of `rotate_cw(n)`/`rotate_ccw(n)`
    # respectively (src/direction/impls.rs): each impl's presence check is against the named
    # method it forwards to, already an independently tracked mirror item — not a second, new
    # Cairo name (fix loop 2 finding 3: this pair previously had no `replacement` at all, so both
    # read "renamed" unconditionally, regardless of whether rotate_cw/rotate_ccw existed).
    rule("EdgeDirection|VertexDirection", r"impl:Shr<u8>$", "renamed",
         "Cairo has no shift operators for user types; the named rotate_cw(n) is the operator's "
         "body — nothing to add.", replacement=("method", "rotate_cw")),
    rule("EdgeDirection|VertexDirection", r"impl:Shl<u8>$", "renamed",
         "Cairo has no shift operators for user types; the named rotate_ccw(n) is the operator's "
         "body — nothing to add.", replacement=("method", "rotate_ccw")),
    rule("EdgeDirection|VertexDirection", r"impl:Mul<i32>$", "renamed", "mul_scalar(n) -> Hex.",
         replacement=("method", "mul_scalar")),
    # direction::angles (inline module of direction/mod.rs): f32 constants.
    rule("EdgeDirection",
         r"const:(?:DIRECTION_ANGLE_OFFSET_RAD|DIRECTION_ANGLE_OFFSET_DEGREES|"
         r"DIRECTION_ANGLE_RAD|DIRECTION_ANGLE_DEGREES)$",
         "dropped", "f32 constants (direction::angles)."),
    # orientation: HexOrientationData and its f32 matrices (src/orientation.rs).
    rule("HexOrientation",
         r"(?:struct:HexOrientationData|method:(?:flat|pointy|forward|inverse|"
         r"orientation_data)|impl:Deref$)",
         "dropped", "f32 matrices: HexLayout and world/screen space belong to the client "
                    "(L-G1 consequence)."),
    # Modules excluded as a whole (plan §4.4 "Modules excluded as a whole"): every item, whatever
    # its kind or name, is dropped for the module's own reason.
    rule("layout", r".*", "dropped",
         "layout: HexLayout and its 24 functions map hexes to f32 world positions; world and "
         "screen space belong to the client (L-G1 consequence, parity table)."),
    rule("storage", r".*", "dropped",
         "storage: on-chain state lives in the consumer's contract storage and boards live in "
         "bitmaps (`board`); the counterpart of the whole module is the extension, outside the "
         "parity table. The index formulas survive as mirror items (LayoutTrait::index, "
         "Hex::to_hexmod_coordinates), not as this module."),
    rule("mesh", r".*", "dropped",
         "mesh: rendering (MeshInfo, the mesh builders, UV options, faces) produces Vec<Vec3> "
         "vertices; no exact integer restatement exists on-chain."),
)

# Curated per-item map (plan §4.2): the counterparts whose Rust signature would otherwise trip a
# broad exclusion rule (an `impl Fn` callback, a `HashSet` return, a const generic array) — wins
# over RULES (audit finding 13 of the plan itself: the first version of the plan let the broad
# rules classify these signatures, which hid incomplete parity). Keyed by (owner, kind, name);
# value is (status_once_present, cairo_key, detail): `status_once_present` follows plan §1.1
# (`ported` when the Cairo name equals the Rust name, `renamed` otherwise) and, like a `renamed`
# RULES entry, is only shown once `cairo_key` (owner, kind, name) is actually present in the Cairo
# source — fix loop 1 finding 3: a counterpart mapping never makes an item `ported` (or `renamed`)
# by itself; an absent mapped counterpart reads `missing` until it exists, so `--check-release`
# catches a release that schedules it and does not ship it.
COUNTERPARTS: dict[tuple[str, str, str], tuple[str, tuple[str, str, str], str]] = {
    ("algorithms", "method", "field_of_movement"): (
        "ported", ("algorithms", "method", "field_of_movement"),
        "hexx::algorithms::field_of_movement(map: HexMap, from: u8, budget: u8, "
        "costs: Span<felt252>) -> felt252, forwarding to HexMapTrait::field_of_movement. Same "
        "cost model: hexx charges 1 + cost(h), the board charges k + 2 for class k, so class k "
        "is cost(h) = k + 1, None is a wall, cost(h) = 0 is any other walkable tile. At most 3 "
        "classes (cost 2..=4), a bounded board, the outer ring is wall."),
    ("algorithms", "method", "a_star"): (
        "ported", ("algorithms", "method", "a_star"),
        "hexx::algorithms::a_star(map, from, to, costs) -> Option<Span<u8>>, forwarding to "
        "search_path_weighted and reordering the path start to end, both included. Deviation: "
        "directed per-step costs (cost(a, b)) have no counterpart, only per-tile entry costs; "
        "ties follow the board's lowest-tile-index rule against hexx's unspecified heap order."),
    ("algorithms", "method", "range_fov"): (
        "ported", ("algorithms", "method", "range_fov"),
        "hexx::algorithms::range_fov(map, from, range) -> felt252: for every tile of "
        "hexagon_ring(from, range), the prefix of line up to the first wall. Deviation: the "
        "board's line tie rule (§6.6)."),
    ("algorithms", "method", "directional_fov"): (
        "ported", ("algorithms", "method", "directional_fov"),
        "hexx::algorithms::directional_fov(map, from, range, direction: EdgeDirection) -> "
        "felt252: the facing is an EdgeDirection, whose two vertex directions select the ring "
        "tiles whose diagonal_way_to matches one of them, then the board and line deviations of "
        "range_fov."),
    ("HexSpanExt", "trait", "HexIterExt"): (
        "renamed", ("HexSpanExt", "trait", "HexSpanExt"),
        "HexSpanExt on Span<Hex>: average through the exact div_scalar (same deviation), "
        "center, bounds."),
    ("HexBounds", "impl", "FromIterator<Hex>"): (
        "renamed", ("HexBounds", "method", "from_span"), "from_span(Span<Hex>) -> HexBounds."),
    ("Hex", "method", "cached_custom_ring_edges"): (
        "ported", ("Hex", "method", "cached_custom_ring_edges"),
        "const generic RANGE becomes a runtime `range: usize`; returns Span<Span<Hex>>."),
    ("Hex", "method", "cached_ring_edges"): (
        "ported", ("Hex", "method", "cached_ring_edges"), "same signature change as above."),
    ("Hex", "method", "cached_rings"): (
        "ported", ("Hex", "method", "cached_rings"), "same signature change as above."),
    ("Hex", "method", "cached_custom_rings"): (
        "ported", ("Hex", "method", "cached_custom_rings"), "same signature change as above."),
    ("Hex", "method", "circular_range"): (
        "renamed", ("Hex", "method", "circular_range_squared"),
        "circular_range_squared(range_squared: i32) -> Span<Hex>: the same set for "
        "range_squared = round(range^2) when range is an integer (f32 range replaced)."),
}


# ---------------------------------------------------------------------------------------------
# Parsing: masking, balanced blocks (shared by the Rust and the Cairo side)


def mask_comments(text: str, mask_strings: bool = True) -> str:
    """Replace comments (and, unless `mask_strings=False`, strings) by spaces while preserving
    offsets and newlines. `mask_strings=False` is for reading a `#[cfg(feature = "x")]`
    attribute's own string content, which the default mode (needed everywhere else, so a string
    literal's braces or parentheses never confuse brace/paren depth counting) would otherwise
    blank out — fix loop 2: `#[cfg(feature = "algorithms")]` read back as `#[cfg(feature = )]`
    before this, since only one masked copy of the text existed."""
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
            if mask_strings:
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
                if mask_strings:
                    if text[i] != "\n":
                        out[i] = " "
                    if text[i + 1] != "\n":
                        out[i + 1] = " "
                i += 2
                continue
            if text[i] == quote:
                state = "code"
            if mask_strings and text[i] != "\n":
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
    # Strip every module-path segment, not just a single `std::`/`core::`/`crate::` prefix:
    # `impl std::ops::Not for HexOrientation` left `ops::Not` after stripping `std::` alone,
    # which `build_impl_item`'s bare-identifier regex then silently rejected (fix loop 1: this
    # made the item vanish rather than read `ported`/`missing`).
    value = re.sub(r"(?:[A-Za-z_]\w*::)+", "", value)
    value = re.sub(r"\bSelf\b", self_type, value)
    value = value.replace("&", "").replace("mut ", "")
    return re.sub(r"\s+", "", value).strip(",")


def strip_leading_attrs(text: str) -> str:
    """Drop leading `#[...]` attribute markers (kept as-is by `mask_comments`, which only masks
    comments and strings) so a name regex anchored at the start of a fragment does not fail on
    `#[default]\\n    Flat` (fix loop 1 finding 7)."""
    return re.sub(r"^(?:\s*#\[[^\]]*\]\s*)+", "", text)


# ---------------------------------------------------------------------------------------------
# The module tree: `pub mod` / `mod` / `pub(crate) mod` and `pub use` reachability, generic on
# both sides (Rust and Cairo use the same syntax for these constructs).


@dataclass
class ModuleNode:
    path: tuple[str, ...]
    vis: str  # "pub" | "crate" | "private"
    text: str  # this module's own body, masked, with inline children's bodies blanked out
    source: str  # the file (or "<file>#<inline path>") this module's text came from
    cfg_enabled: bool = True  # this module's own `#[cfg(...)]`, evaluated (see `evaluate_cfg`)


MOD_DECL_RE = re.compile(r"(?m)^[ \t]*(pub(?:\(crate\))?\s+)?mod\s+([A-Za-z_]\w*)\s*(;|\{)")
ATTR_RE = re.compile(r"#\[\s*cfg\((.*)\)\s*\]\Z", re.S)

# The feature set `tools/refgen`'s `Cargo.toml` builds `hexx` with (plan §4.3): `algorithms` and
# `grid` are on; every other cargo feature `hexx` 0.25.0 defines is off. Fix loop 2 decision B
# (iii): evaluated, not ignored — a module or item gated by a feature outside this set is not
# part of what this crate can ever see or depend on, so it must not be treated as reachable.
ENABLED_CARGO_FEATURES = {"algorithms", "grid"}
KNOWN_DISABLED_CARGO_FEATURES = {"bevy_reflect", "facet", "mesh", "packed", "rayon", "serde"}

# `layout`, `storage` and `mesh` are inventoried whole, as "dropped", regardless of whether the
# feature that gates a module-level `pub mod` is on (plan §4.4 "Modules excluded as a whole": the
# percentage must stay honest against hexx's *whole* public surface, not just the subset this
# crate happens to depend on) — only `mesh` is actually cfg-gated among the three
# (`#[cfg(feature = "mesh")]`; `layout` and `storage` are unconditional). This does not change
# `mesh`'s status (`dropped` either way, RULES catch-all) or reachability for anything *outside*
# it: nothing else in the crate references a `mesh` type.
CFG_EXEMPT_TOP_LEVEL = frozenset({("mesh",)})


def evaluate_cfg(expr: str, location: str) -> bool:
    expr = expr.strip()
    m = re.match(r'feature\s*=\s*"([^"]+)"$', expr)
    if m:
        name = m.group(1)
        if name in ENABLED_CARGO_FEATURES:
            return True
        if name in KNOWN_DISABLED_CARGO_FEATURES:
            return False
        raise SystemExit(
            f"{location}: unrecognized cfg feature {name!r} on a public item; add it to "
            f"ENABLED_CARGO_FEATURES or KNOWN_DISABLED_CARGO_FEATURES in scripts/api_parity.py "
            f"once its status against tools/refgen's feature set is known (fix loop 2, decision B)"
        )
    if expr == "test":
        return False
    if re.fullmatch(r"any\(\s*\)", expr):
        return False
    if re.fullmatch(r"all\(\s*\)", expr):
        return True
    m = re.fullmatch(r"not\((.*)\)", expr, re.S)
    if m:
        return not evaluate_cfg(m.group(1), location)
    raise SystemExit(f"{location}: unrecognized cfg predicate {expr!r} on a public item")


def find_preceding_attr(text: str, pos: int, attr_re: re.Pattern[str]) -> str | None:
    """Walk backward from `pos` (the start of a declaration: a `mod`, or a `pub struct`/`pub
    enum`) over whitespace and a stack of immediately-adjacent `#[...]` attributes (any order:
    the wanted one need not be the closest), stopping at the first attribute `attr_re` matches, or
    as soon as the immediately preceding non-whitespace content is not an attribute at all.

    A manual scan, not a fixed-size lookback window: fix loop 2 found that a window (even a
    small, ReDoS-safe one) picks up an *earlier, unrelated* declaration's attribute whenever two
    declarations sit closer together than the window — `pub mod mesh;`'s
    `#[cfg(feature = "mesh")]` was wrongly attributed to `pub mod orientation;` and `pub mod
    shapes;`, both undecorated, a few dozen masked-doc-comment bytes later in `src/lib.rs`;
    `#[derive(Default)] pub struct A;` was wrongly attributed to a `pub struct B;` right after it,
    for the same reason (finding 15) — silently disabling, or deriving, declarations that carry
    no attribute of their own. Adjacency, not proximity, is the only correct rule for "which
    declaration does this attribute belong to"."""
    i = pos
    while True:
        j = i
        while j > 0 and text[j - 1] in " \t\r\n":
            j -= 1
        if j == 0 or text[j - 1] != "]":
            return None
        depth = 0
        k = j - 1
        while k >= 0:
            if text[k] == "]":
                depth += 1
            elif text[k] == "[":
                depth -= 1
                if depth == 0:
                    break
            k -= 1
        if k < 1 or text[k - 1] != "#":
            return None
        attr_start = k - 1
        attr_text = text[attr_start:j]
        m = attr_re.match(attr_text)
        if m:
            return m.group(1)
        i = attr_start  # some other attribute (`derive`, `allow`, `cfg`, ...): keep looking back


def find_preceding_cfg(text: str, pos: int) -> str | None:
    return find_preceding_attr(text, pos, ATTR_RE)


def split_own_and_children(
    text: str, text_with_strings: str, source: str
) -> tuple[str, list[tuple[str, str, bool, str | None]]]:
    """`(own_text, [(name, vis, cfg_enabled, inline_body_or_None), ...])` for the `mod`
    declarations directly in `text` (not nested inside another inline `mod X { ... }` found
    earlier in the same text). `own_text` has every inline child's span blanked out, so a later
    scan of `own_text` for local declarations or `use` statements never double-counts a nested
    inline module's own content. `text_with_strings`: same file, same offsets, comments masked but
    string contents kept — reading a `#[cfg(feature = "x")]`'s own feature name needs it (`text`
    itself has already had `"x"` blanked, like every other string literal)."""
    chars = list(text)
    children: list[tuple[str, str, bool, str | None]] = []
    consumed_until = 0
    for m in MOD_DECL_RE.finditer(text):
        if m.start() < consumed_until:
            continue
        vis_raw = (m.group(1) or "").strip()
        vis = "pub" if vis_raw == "pub" else ("crate" if vis_raw else "private")
        name, term = m.group(2), m.group(3)
        cfg_expr = find_preceding_cfg(text_with_strings, m.start())
        cfg_enabled = True if cfg_expr is None else evaluate_cfg(cfg_expr, f"{source}: mod {name}")
        if term == ";":
            children.append((name, vis, cfg_enabled, None))
            end = m.end()
        else:
            open_pos = m.end() - 1
            close_pos = closing_brace(text, open_pos)
            children.append((name, vis, cfg_enabled, text[open_pos + 1:close_pos]))
            end = close_pos + 1
        for i in range(m.start(), end):
            if chars[i] != "\n":
                chars[i] = " "
        consumed_until = end
    return "".join(chars), children


def build_module_tree(root_file: Path, comment_syntax: str = "rust") -> dict[tuple[str, ...], ModuleNode]:
    """Walk the module tree from `root_file` (`src/lib.rs` or `crates/hexx/src/lib.cairo`).
    `comment_syntax` is unused (both languages mask the same way) but documents the two callers."""
    del comment_syntax
    nodes: dict[tuple[str, ...], ModuleNode] = {}

    def visit(path: tuple[str, ...], dir_path: Path, raw: str, vis: str, cfg_enabled: bool,
              source: str) -> None:
        text = mask_comments(raw)
        text_with_strings = mask_comments(raw, mask_strings=False)
        own_text, children = split_own_and_children(text, text_with_strings, source)
        nodes[path] = ModuleNode(path=path, vis=vis, text=own_text, source=source,
                                  cfg_enabled=cfg_enabled)
        for name, child_vis, child_cfg_enabled, inline_body in children:
            child_path = path + (name,)
            if inline_body is not None:
                # `inline_body` is a slice of `text` (comments and strings already masked): the
                # inline case has no separate raw source to re-derive a strings-preserved copy
                # from, so a `#[cfg(feature = "x")]` immediately inside an *inline* `mod { ... }`
                # (none of hexx's do) would not resolve its own feature name. Not hit by the
                # pinned checkout; would raise (unrecognized cfg feature ''), not silently pass.
                visit(child_path, dir_path, inline_body, child_vis, child_cfg_enabled,
                      f"{source}#{name}")
                continue
            ext = ".cairo" if root_file.suffix == ".cairo" else ".rs"
            flat = dir_path / f"{name}{ext}"
            nested = dir_path / name / f"mod{ext}"
            if flat.is_file():
                # `name`'s own further children (if `name`.rs itself declares `mod grandchild;`)
                # resolve in a sibling directory named after it (`dir_path/name/`), exactly as
                # for the `X/mod.ext` form below — fix loop 2 finding 4: this used to pass
                # `dir_path` unchanged, so a flat parent's own child module could never be found
                # (`foo.rs` declaring `mod bar;`, real file `foo/bar.rs`, raised "cannot resolve").
                visit(child_path, dir_path / name, flat.read_text(), child_vis, child_cfg_enabled,
                      str(flat.relative_to(root_file.parents[1])))
            elif nested.is_file():
                visit(child_path, dir_path / name, nested.read_text(), child_vis, child_cfg_enabled,
                      str(nested.relative_to(root_file.parents[1])))
            else:
                raise SystemExit(f"cannot resolve `mod {name};` declared in {source}: looked for "
                                  f"{flat} and {nested}")

    visit((), root_file.parent, root_file.read_text(), "pub", True,
          str(root_file.relative_to(root_file.parents[1])))
    return nodes


def compute_reachable_modules(
    nodes: dict[tuple[str, ...], ModuleNode], cfg_exempt: frozenset = CFG_EXEMPT_TOP_LEVEL
) -> set[tuple[str, ...]]:
    reachable: set[tuple[str, ...]] = {()}
    for path in sorted(nodes, key=len):
        if not path:
            continue
        parent = path[:-1]
        node = nodes[path]
        if parent in reachable and node.vis == "pub" and (node.cfg_enabled or path in cfg_exempt):
            reachable.add(path)
    return reachable


# `pub use path::to::Name;`, an alias (`as Alias`), a group (`path::{A, B as C}`), a nested group
# (`path::{A, sub::{B, C}}` — the pinned checkout's own `direction/edge_direction.rs` uses exactly
# this, `use crate::{Hex, ..., angles::{DIRECTION_ANGLE_RAD, ...}};`), a glob (`path::*`), and
# `crate::`/`self::`-prefixed or plain multi-segment paths: fix loop 2 finding 4 generalizes this
# from the single-relative-segment form fix loop 1 supported. A form this parser does not
# recognize (a glob nested inside a group) raises, naming the file and the statement — never
# silently skipped.
USE_STATEMENT_RE = re.compile(r"(?m)^[ \t]*(pub(?:\(crate\))?\s+)?use\s+([^;]+);")


def resolve_use_segments(segments: list[str], current_path: tuple[str, ...]) -> tuple[str, ...]:
    if segments and segments[0] == "crate":
        return tuple(segments[1:])
    if segments and segments[0] == "self":
        return current_path + tuple(segments[1:])
    return current_path + tuple(segments)


def parse_use_tree(
    expr: str, current_path: tuple[str, ...], location: str,
    entries: list[tuple[tuple[str, ...], str, str | None]], globs: list[tuple[str, ...]],
) -> None:
    """Recursively walks one `use` tree node (`crate::{A, sub::{B as C}, D::*}`-shaped), appending
    every named leaf as `(target_module_path, original_name, alias_or_None)` to `entries` and
    every glob leaf's target path to `globs`."""
    expr = expr.strip()
    brace_pos = expr.find("{")
    if brace_pos >= 0:
        if not expr.endswith("}"):
            raise SystemExit(f"{location}: malformed use group (trailing text after '}}'): {expr!r}")
        close_pos = closing_brace(expr, brace_pos)
        if close_pos != len(expr) - 1:
            raise SystemExit(f"{location}: malformed use group (trailing text after '}}'): {expr!r}")
        prefix = expr[:brace_pos].rstrip().rstrip(":").rstrip()
        segments = [s.strip() for s in prefix.split("::") if s.strip()] if prefix else []
        sub_path = resolve_use_segments(segments, current_path)
        for raw in split_top_level(expr[brace_pos + 1:close_pos], ","):
            raw = raw.strip()
            if raw:
                parse_use_tree(raw, sub_path, location, entries, globs)
        return
    if expr.endswith("*"):
        prefix = expr[:-1].rstrip().rstrip(":").rstrip()
        if "{" in prefix or "}" in prefix:
            raise SystemExit(f"{location}: a glob inside a use group is not supported: {expr!r}")
        segments = [s.strip() for s in prefix.split("::") if s.strip()] if prefix else []
        globs.append(resolve_use_segments(segments, current_path))
        return
    m = re.fullmatch(r"(.*?)(?:\s+as\s+([A-Za-z_]\w*))?", expr, re.S)
    base, alias = m.group(1).strip(), m.group(2)
    segments = [s.strip() for s in base.split("::") if s.strip()]
    if not segments:
        raise SystemExit(f"{location}: malformed use path: {expr!r}")
    name = segments.pop()
    entries.append((resolve_use_segments(segments, current_path), name, alias))


def collect_use_statements(
    nodes: dict[tuple[str, ...], ModuleNode], reachable: set[tuple[str, ...]]
) -> tuple[dict[tuple[str, ...], set[str]], set[tuple[str, ...]], set[str]]:
    """`(bridged, glob_targets, used_names)`: `bridged[target_path]` is the set of *original*
    names (never the alias: reachability of a declaration is keyed by where and how it was
    declared, not by the path a re-export gives it — fix loop 2, see `declared_reachable`)
    re-exported from `target_path` by a `pub use` sitting in a reachable module; `glob_targets` is
    the set of module paths re-exported wholesale (`pub use target::*;`) from a reachable module;
    `used_names` is every name imported by any `use` statement anywhere (`pub` or not, reachable
    module or not — fix loop 1: a private module's own `use glam::IVec2;` still matters, because
    an `impl From<Hex> for IVec2` can sit in that same private file)."""
    bridged: dict[tuple[str, ...], set[str]] = {}
    glob_targets: set[tuple[str, ...]] = set()
    used_names: set[str] = set()
    for path, node in nodes.items():
        for m in USE_STATEMENT_RE.finditer(node.text):
            vis = (m.group(1) or "").strip()
            location = f"{node.source}: use {m.group(2)}"
            entries: list[tuple[tuple[str, ...], str, str | None]] = []
            globs: list[tuple[str, ...]] = []
            parse_use_tree(m.group(2), path, location, entries, globs)
            used_names.update(name for _target, name, _alias in entries)
            if vis != "pub" or path not in reachable:
                continue  # plain / pub(crate) use, or inside an unreachable module: no bridge
            for target_path, name, _alias in entries:
                if target_path in nodes:
                    bridged.setdefault(target_path, set()).add(name)
            for target_path in globs:
                if target_path in nodes:
                    glob_targets.add(target_path)
    return bridged, glob_targets, used_names


def declared_reachable(
    path: tuple[str, ...], name: str,
    reachable: set[tuple[str, ...]], bridged: dict[tuple[str, ...], set[str]],
    glob_targets: set[tuple[str, ...]],
) -> bool:
    return path in reachable or name in bridged.get(path, ()) or path in glob_targets


# ---------------------------------------------------------------------------------------------
# The hexx (Rust) side: local declarations and impl blocks, filtered by the reachability computed
# above.

STRUCT_HEAD_RE = re.compile(r"\bpub\s+struct\s+([A-Za-z_]\w*)")
ENUM_HEAD_RE = re.compile(r"\bpub\s+enum\s+([A-Za-z_]\w*)")
TRAIT_RE = re.compile(r"\bpub\s+trait\s+([A-Za-z_]\w*)[^\n\{]*\{")
TYPE_ALIAS_RE = re.compile(r"\bpub\s+type\s+([A-Za-z_]\w*)\s*(?:<[^=;\n]*>)?\s*=")
DERIVE_RE = re.compile(r"#\[\s*derive\((.*)\)\s*\]\Z", re.S)


def scoped(prefix: bool, type_name: str, name: str) -> str:
    return f"{type_name}.{name}" if prefix else name


def find_declaration_body(text: str, pos: int) -> tuple[str, int] | None:
    """From `pos` (the end of `pub struct NAME` / `pub enum NAME`), skip a balanced `<...>`
    generic parameter list if there is one, then return the `({`, `(` or `;`}, index)` of
    whichever of those three comes next — brace body, tuple-struct parens (handled separately by
    the caller), or a unit struct/forward declaration.

    A manual character scan, not a regex: fix loop 1 finding 4's rewrite first used
    `(?:<[^{;(]*>)?\\s*\\{`, which is a negated character class with no matching literal nearby
    once a large span of masked-out text (an inline `#[cfg(test)] mod ... { ... }` blanked to
    spaces by `split_own_and_children`) sat between a struct and its brace — Python's `re` engine
    backtracks character by character through the whole gap, squared over every attempted start
    position, and hung for minutes on `storage/rect.rs`. A hand-written scan is O(gap), once,
    with no backtracking possible, whatever the gap contains."""
    i, n = pos, len(text)
    while i < n and text[i] in " \t\r\n":
        i += 1
    if i < n and text[i] == "<":
        depth = 0
        while i < n:
            if text[i] == "<":
                depth += 1
            elif text[i] == ">":
                depth -= 1
                i += 1
                if depth == 0:
                    break
                continue
            i += 1
        while i < n and text[i] in " \t\r\n":
            i += 1
    if i < n and text[i] in "{(;":
        return text[i], i
    return None


def local_declared_types(text: str) -> set[str]:
    """Every `pub struct`/`pub enum` name declared directly in this text (not filtered by
    reachability: used to build the crate-wide reachable-type-name set and to scope multi-type
    owners)."""
    return {m.group(1) for m in STRUCT_HEAD_RE.finditer(text)} | {
        m.group(1) for m in ENUM_HEAD_RE.finditer(text)
    }


def local_declared_traits(text: str) -> set[str]:
    return {m.group(1) for m in TRAIT_RE.finditer(text)}


def scan_declarations(text: str, owner: str, source: str, name_ok, prefix: bool) -> list[Item]:
    """Struct/enum/type-alias declarations local to this module, filtered by `name_ok(name)`
    (the module's own reachability), with their fields/variants and any derived trait `RULES`
    would otherwise miss (fix loop 1 finding 7: `#[default]`-attributed variants and a derived,
    not explicitly written, `impl Default`)."""
    items: list[Item] = []

    for match in STRUCT_HEAD_RE.finditer(text):
        name = match.group(1)
        body = find_declaration_body(text, match.end())
        if body is None or body[0] == "(":
            continue  # tuple struct: no brace body here, or unresolved (skipped, not hung)
        if not name_ok(name):
            continue
        items.append(Item(owner, "struct", name, source))
        if body[0] == "{":
            end = closing_brace(text, body[1])
            for line in text[body[1] + 1:end].splitlines():
                f = re.match(r"\s*pub\s+([a-z_]\w*)\s*:", line)
                if f:
                    items.append(Item(owner, "field", scoped(prefix, name, f.group(1)), source))
        items.extend(derived_impl_items(text, match.start(), owner, name, source))

    for match in re.finditer(r"\bpub\s+struct\s+([A-Za-z_]\w*)\s*\(([^;\n]*)\)\s*;", text):
        name = match.group(1)
        if not name_ok(name):
            continue
        items.append(Item(owner, "struct", name, source))
        for index, part in enumerate(split_top_level(match.group(2))):
            if re.match(r"^pub\s+(?!\()", part):
                items.append(Item(owner, "field", scoped(prefix, name, str(index)), source))

    for match in ENUM_HEAD_RE.finditer(text):
        name = match.group(1)
        body = find_declaration_body(text, match.end())
        if body is None or body[0] != "{":
            continue
        if not name_ok(name):
            continue
        items.append(Item(owner, "enum", name, source))
        end = closing_brace(text, body[1])
        for part in split_top_level(text[body[1] + 1:end]):
            variant = re.match(r"^([A-Za-z_]\w*)", strip_leading_attrs(part))
            if variant:
                items.append(Item(owner, "variant", scoped(prefix, name, variant.group(1)), source))
        items.extend(derived_impl_items(text, match.start(), owner, name, source))

    for match in TYPE_ALIAS_RE.finditer(text):
        name = match.group(1)
        if name_ok(name):
            items.append(Item(owner, "type", name, source))

    return items


def derived_impl_items(text: str, decl_start: int, owner: str, type_name: str,
                        source: str) -> list[Item]:
    """`#[derive(..., Default, ...)]` immediately before a struct/enum: a derived trait has no
    explicit `impl Trait for Type { ... }` text for `scan_impls` to find. Limited to `Default`
    (fix loop 1 finding 7 names it explicitly; `Debug`/`PartialEq`/`Eq`/`Hash`/`Copy`/`Clone` are
    commonly derived too but plan §4.4 does not itemize them for any type, and generalizing to
    every derived trait here would manufacture new disagreements against the plan's own counts
    that finding 5/6 did not ask for — recorded as a scope limit in the report, not silently).

    Bound by adjacency (`find_preceding_attr`), not a fixed lookback window: fix loop 2 finding 15
    — a 400-character window still let `#[derive(Default)] pub struct A;` bind to the *next*
    declaration, `pub struct B;`, whenever both sat within the window (as they always do for two
    short adjacent declarations), attributing a derived `Default` to a type that never asked for
    one."""
    del source
    attr = find_preceding_attr(text, decl_start, DERIVE_RE)
    if attr is None:
        return []
    traits = {t.strip() for t in attr.split(",")}
    if "Default" not in traits:
        return []
    built = build_impl_item(owner, "Default", type_name)
    return [built] if built else []


def scan_trait_declarations(text: str, owner: str, source: str, name_ok, prefix: bool) -> list[Item]:
    items = []
    for match, opening, end in blocks(text, TRAIT_RE):
        name = match.group(1)
        if not name_ok(name):
            continue
        items.append(Item(owner, "trait", name, source))
        for fn in re.finditer(r"\bfn\s+([A-Za-z_]\w*)\s*\(", text[opening + 1:end]):
            items.append(Item(owner, "method", scoped(prefix, name, fn.group(1)), source))
    return items


FREE_FN_RE = re.compile(r"\bpub\s+(?:const\s+)?fn\s+([A-Za-z_]\w*)")
FREE_CONST_RE = re.compile(r"\bpub\s+const\s+([A-Z][A-Z0-9_]*)\s*:")
INHERENT_FN_RE = re.compile(r"\bpub\s+(?:const\s+)?fn\s+([A-Za-z_]\w*)")
INHERENT_CONST_RE = re.compile(r"\bpub\s+const\s+([A-Z][A-Z0-9_]*)\s*:")
ANY_IMPL_RE = re.compile(r"(?m)^\s*impl\b[^\n{]*\{")


def mask_impl_bodies(text: str) -> str:
    """Blank out every `impl ... { ... }` block's body (not its header), so a free-item scan run
    on the result finds only genuinely module-level `pub fn`/`pub const` — fix loop 2: the
    previous design instead required column 0 (`(?m)^pub fn`) to reject impl-block content, which
    also rejects a free item that is merely *indented*, as everything inside an inline
    `pub mod angles { pub const ...; }` is in the source: none of `direction::angles`'s four
    constants were ever discovered by `FREE_CONST_RE` before this fix (impl blocks never nest in
    valid Rust, so this single pass cannot itself blank out an already-blanked impl body)."""
    chars = list(text)
    for m in ANY_IMPL_RE.finditer(text):
        open_pos = text.find("{", m.start())
        if open_pos < 0:
            continue
        close_pos = closing_brace(text, open_pos)
        for i in range(open_pos + 1, close_pos):
            if chars[i] != "\n":
                chars[i] = " "
    return "".join(chars)


def build_impl_item(owner: str, trait_expr: str, target: str) -> Item | None:
    match = re.match(r"([A-Za-z][A-Za-z0-9_]*)(?:<(.*)>)?$", trait_expr)
    if not match:
        return None
    trait, arg = match.group(1), match.group(2)
    if trait not in RUST_IMPL_TRAITS:
        return None
    # `From<A> for B` always names both sides (plan §4.4 writes "From<IVec2> for Hex" even where
    # target and owner are the same "Hex"): the branch below already appends "for {target}"
    # unconditionally, so it must not fall through to the generic `target != owner` append too —
    # fix loop 1: it did, producing "From<EdgeDirection> for Hex for Hex" whenever target and
    # owner actually differed, which matched no RULES pattern and no _L_M1 key.
    if trait == "From" and arg:
        return Item(owner, "impl", f"From<{arg}> for {target}", "")
    name = f"{trait}<{arg}>" if arg else trait
    if target != owner:
        name += f" for {target}"
    return Item(owner, "impl", name, "")


# Target tolerates trailing generics (`Face<VERTS, TRIS>`, `RectMap<T>`) and an optional leading
# `&` (`impl PartialEq<Hex> for &Hex`) — fix loop 1: the previous pattern required a bare
# identifier directly before `{`, silently skipping every generic-target impl of `layout`,
# `storage` and `mesh` (finding 5) and the reference-glue impl of `Hex` (which RULES already
# expected to see and classify, not silently never parse).
IMPL_RE = re.compile(r"(?m)^\s*impl(?:\s*<[^\n{]*>)?\s+(.+?)\s+for\s+&?([A-Za-z_]\w*)(?:<[^\n{]*>)?\s*\{")
INHERENT_IMPL_RE = re.compile(r"(?m)^\s*impl(?:\s*<[^\n{]*>)?\s+([A-Za-z_]\w*)(?:<[^\n{]*>)?\s*\{")


def scan_impls(text: str, owner_or_dynamic: str | None, source: str,
               allowed_targets: set[str], prefix_targets: set[str]) -> list[Item]:
    """`impl Trait<Args> for Target { ... }`. `owner_or_dynamic=None`: owner = target (only
    `direction/impls.rs`, which carries impls of two owners in one file). `allowed_targets`: the
    crate-wide reachable type/trait names plus every name this crate's own source `use`s (so a
    foreign target like `IVec2` is still discovered when hexx itself references it) — a target
    outside that set is a private helper (`Node` of `algorithms/pathfinding.rs`, never `pub`, never
    imported) and contributes nothing to the public API."""
    items = []
    for match in IMPL_RE.finditer(text):
        target = match.group(2).strip()
        if target not in allowed_targets:
            continue
        owner = owner_or_dynamic or target
        trait_expr = clean_type(match.group(1), self_type=target)
        item = build_impl_item(owner, trait_expr, target)
        if item:
            if target in prefix_targets:
                item = Item(item.owner, item.kind, f"{target}.{item.name}", item.source)
            items.append(item)
    return items


def scan_inherent_impls(text: str, owner: str, source: str, reachable_type_names: set[str],
                         prefix: bool) -> list[Item]:
    """`impl Type { pub fn ... }`, scoped per type: an associated function or constant is public
    exactly when its *type* is reachable (`Hex::ZERO`'s reachability is `Hex`'s, not a separate
    re-export of the name `ZERO`), whatever module the `impl` block itself sits in — `reachable_
    type_names` is the crate-wide set `parse_hexx` computes once, not this file's own local
    declarations: `conversions.rs` and `hex/grid/edge.rs` both carry `impl Hex { ... }` blocks for
    a type declared elsewhere (fix loop 1: scoping this to file-local types only made every
    associated constant of `EdgeDirection`, and every method conversions.rs and grid/edge.rs add
    to `Hex`, silently vanish, since none of their *individual* names are separately re-exported —
    only the type name is)."""
    items = []
    for match, opening, end in blocks(text, INHERENT_IMPL_RE):
        type_name = match.group(1)
        if type_name not in reachable_type_names:
            continue
        body = text[opening + 1:end]
        for fn in INHERENT_FN_RE.finditer(body):
            items.append(Item(owner, "method", scoped(prefix, type_name, fn.group(1)), source))
        for const in INHERENT_CONST_RE.finditer(body):
            items.append(Item(owner, "const", scoped(prefix, type_name, const.group(1)), source))
    return items


def scan_module(text: str, owner: str, source: str, name_ok, reachable_type_names: set[str],
                 prefix: bool) -> list[Item]:
    """Every kind of local public item of one module file: type/trait declarations (with fields,
    variants, derived `Default`), their associated impl-block content, and genuinely free
    (module-level, not inside any `impl`) functions. `prefix`: scope method/field/const/variant
    names by their owning type (`MULTI_TYPE_OWNERS`) or leave them bare (every other owner, where
    a bare name is already exact)."""
    items = scan_declarations(text, owner, source, name_ok, prefix)
    items.extend(scan_trait_declarations(text, owner, source, name_ok, prefix))
    items.extend(scan_inherent_impls(text, owner, source, reachable_type_names, prefix))
    # Module-level free functions (`hex()`, `parallelogram()`, ...) and free constants
    # (`direction::angles`'s four `f32` constants, fix loop 2 finding 5) are found on a copy of
    # `text` with every `impl` block's body blanked out, so an indented free item (everything in
    # an inline `pub mod angles { pub const ...; }` is indented, in the source, exactly like an
    # impl body's own content) is still found, while an impl body's own `pub fn`/`pub const`
    # (scanned separately, above, scoped per type) is not double-counted.
    free_text = mask_impl_bodies(text)
    for match in FREE_FN_RE.finditer(free_text):
        if name_ok(match.group(1)):
            items.append(Item(owner, "method", match.group(1), source))
    for match in FREE_CONST_RE.finditer(free_text):
        if name_ok(match.group(1)):
            items.append(Item(owner, "const", match.group(1), source))
    return items


def parse_hexx(hexx_root: Path) -> list[Item]:
    nodes = build_module_tree(hexx_root / "src" / "lib.rs")
    reachable = compute_reachable_modules(nodes)
    bridged, glob_targets, used_names = collect_use_statements(nodes, reachable)

    def name_ok_at(path: tuple[str, ...]):
        return lambda name: declared_reachable(path, name, reachable, bridged, glob_targets)

    reachable_type_names: set[str] = set()
    reachable_trait_names: set[str] = set()
    for path, node in nodes.items():
        ok = name_ok_at(path)
        reachable_type_names |= {n for n in local_declared_types(node.text) if ok(n)}
        reachable_trait_names |= {n for n in local_declared_traits(node.text) if ok(n)}
    allowed_targets = reachable_type_names | reachable_trait_names | used_names

    items: set[Item] = set()
    for path, owner in MODULE_OWNER.items():
        node = nodes[path]
        ok = name_ok_at(path)
        prefix = owner in MULTI_TYPE_OWNERS
        items.update(scan_module(node.text, owner, node.source, ok, reachable_type_names, prefix))
        prefix_targets = local_declared_types(node.text) if prefix else set()
        items.update(scan_impls(node.text, owner, node.source, allowed_targets, prefix_targets))

    for path in DYNAMIC_MODULES:
        node = nodes[path]
        items.update(scan_impls(node.text, None, node.source, allowed_targets, set()))

    return unique_items(items)


# ---------------------------------------------------------------------------------------------
# The Cairo side (this package): the same reachability walk, Cairo syntax.


# Cairo declaration heads (name only; `find_declaration_body`, shared with the Rust side, finds
# the brace robustly — fix loop 2 finding 4's Rust-side fix applies here identically: a fixed
# regex tail like `[^\n{]*\{` cannot see past a struct's generics onto a second line).
CAIRO_STRUCT_HEAD_RE = re.compile(r"\bpub\s+struct\s+([A-Za-z_]\w*)")
CAIRO_ENUM_HEAD_RE = re.compile(r"\bpub\s+enum\s+([A-Za-z_]\w*)")
CAIRO_TRAIT_RE = re.compile(r"\bpub\s+trait\s+([A-Za-z_]\w*)[^\{]*\{")
CAIRO_IMPL_OF_RE = re.compile(r"\bpub\s+impl\s+[A-Za-z_]\w*\s+of\s+([A-Za-z_]\w*)(?:<[^\{]*>)?\s*\{")
CAIRO_FREE_FN_RE = re.compile(r"\bpub\s+fn\s+([A-Za-z_]\w*)")
CAIRO_FREE_CONST_RE = re.compile(r"\bpub\s+const\s+([A-Za-z_]\w*)\s*:")


def build_cairo_tree():
    """`(nodes, reachable, bridged, glob_targets)` of the Cairo source tree from
    `crates/hexx/src/lib.cairo`, or `None` if that file does not exist yet — shared by
    `parse_cairo` (the twelve mirror owners) and `parse_extensions` (fix loop 2 finding 14: both
    walk the *same* reachability computation; only which declarations they keep, and how they
    name the owner, differs)."""
    if not CAIRO_ROOT_FILE.is_file():
        return None
    nodes = build_module_tree(CAIRO_ROOT_FILE)
    reachable = compute_reachable_modules(nodes, cfg_exempt=frozenset())
    bridged, glob_targets, _used_names = collect_use_statements(nodes, reachable)
    return nodes, reachable, bridged, glob_targets


def scan_cairo_tree(
    nodes: dict[tuple[str, ...], ModuleNode], reachable: set[tuple[str, ...]],
    bridged: dict[tuple[str, ...], set[str]], glob_targets: set[tuple[str, ...]],
    owner_of,
) -> list[Item]:
    """Walk every node of a Cairo module tree, keeping a declaration only when `owner_of(path,
    name) -> str | None` returns an owner for it (`None` skips it) — the one traversal `parse_
    cairo` and `parse_extensions` share (fix loop 2 finding 14)."""
    items: set[Item] = set()
    for path, node in nodes.items():
        ok = lambda name, path=path: declared_reachable(path, name, reachable, bridged, glob_targets)
        text, source = node.text, node.source

        for head_re, kind in ((CAIRO_STRUCT_HEAD_RE, "struct"), (CAIRO_ENUM_HEAD_RE, "enum")):
            for match in head_re.finditer(text):
                name = match.group(1)
                owner = owner_of(path, name) if ok(name) else None
                if owner is None:
                    continue
                body = find_declaration_body(text, match.end())
                if body is None or body[0] != "{":
                    continue
                items.add(Item(owner, kind, name, source))
                end = closing_brace(text, body[1])
                inner = text[body[1] + 1:end]
                for field_m in re.finditer(r"\bpub\s+([a-z_]\w*)\s*:", inner):
                    items.add(Item(owner, "field", scoped(owner != name, name, field_m.group(1)),
                                    source))
                if kind == "enum":
                    for variant_m in re.finditer(r"(?m)^\s*([A-Za-z_]\w*)\s*(?:[:,]|$)",
                                                  strip_leading_attrs(inner)):
                        items.add(Item(owner, "variant",
                                       scoped(owner != name, name, variant_m.group(1)), source))

        for match, opening, end in blocks(text, CAIRO_TRAIT_RE):
            trait_name = match.group(1)
            type_name = trait_name.removesuffix("Trait")
            # Reachability is checked against the trait's own declared name (what is actually
            # `pub`, and what a `pub use` would re-export); the owner bucket is asked for the
            # derived type name (`Hex`, not `HexTrait`), matching `OWNERS`/the extension's
            # per-type scoping — fix loop 2: the first version of this unification asked
            # `owner_of` for `trait_name`, which is never a member of `OWNERS`, so no mirror
            # trait was ever attributed to anything.
            owner = owner_of(path, type_name) if ok(trait_name) else None
            if owner is None:
                continue
            items.add(Item(owner, "trait", trait_name, source))
            body = text[opening + 1:end]
            for fn in re.finditer(r"\bfn\s+([A-Za-z_]\w*)\s*(?:<[^;{()]*>)?\s*\(", body):
                items.add(Item(owner, "method", scoped(owner != type_name, type_name, fn.group(1)),
                                source))
            for const in re.finditer(r"\bconst\s+([A-Za-z_]\w*)\s*:", body):
                items.add(Item(owner, "const",
                                scoped(owner != type_name, type_name, const.group(1)), source))

        for match, opening, end in blocks(text, CAIRO_IMPL_OF_RE):
            trait_name = match.group(1)
            type_name = trait_name.removesuffix("Trait")
            # An impl's own reachability follows its trait's (Cairo impls are not separately
            # named on the public path the way a Rust inherent impl's methods are); `owner_of`
            # is asked for the derived type name, as in the trait-declaration branch above, so
            # the same type consistently maps to the same owner whether accessed through its
            # trait declaration or through one of (potentially several) `pub impl ... of` blocks.
            owner = owner_of(path, type_name) if ok(trait_name) else None
            if owner is None:
                continue
            body = text[opening + 1:end]
            for fn in re.finditer(r"\bfn\s+([A-Za-z_]\w*)\s*(?:<[^;{()]*>)?\s*\(", body):
                items.add(Item(owner, "method", scoped(owner != type_name, type_name, fn.group(1)),
                                source))

        for match in CAIRO_FREE_FN_RE.finditer(mask_impl_bodies(text)):
            name = match.group(1)
            owner = owner_of(path, name) if ok(name) else None
            if owner is not None:
                items.add(Item(owner, "method", name, source))
        for match in CAIRO_FREE_CONST_RE.finditer(mask_impl_bodies(text)):
            name = match.group(1)
            owner = owner_of(path, name) if ok(name) else None
            if owner is not None:
                items.add(Item(owner, "const", name, source))
    return unique_items(items)


def parse_cairo() -> list[Item]:
    tree = build_cairo_tree()
    if tree is None:
        return []
    nodes, reachable, bridged, glob_targets = tree

    def owner_of(path: tuple[str, ...], name: str) -> str | None:
        del path
        return name if name in OWNERS else None

    return scan_cairo_tree(nodes, reachable, bridged, glob_targets, owner_of)


def unique_items(items: set[Item] | list[Item]) -> list[Item]:
    result: dict[tuple[str, str, str], Item] = {}
    for item in sorted(items):
        result.setdefault(item.key, item)
    return sorted(result.values())


# ---------------------------------------------------------------------------------------------
# Classification (plan §4.2: direct match, then COUNTERPARTS, then RULES, else missing — fix loop
# 1 finding 3: `ported`/`renamed` require the Cairo target to actually be present; `dropped` never
# does, since a dropped item has no Cairo target by definition)


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
            status, cairo_key, detail = counterpart
            if cairo_key in cairo_by_key:
                result[item] = (status, detail)
                consumed.add(cairo_key)
            else:
                cname = cairo_key[2]
                result[item] = ("missing", f"counterpart of {cname} — {detail} — not yet ported")
            continue
        matched = find_rule(item)
        if matched:
            if matched.status == "renamed" and matched.replacement:
                replacement_key = (item.owner, matched.replacement[0], matched.replacement[1])
                if replacement_key in cairo_by_key:
                    result[item] = ("renamed", matched.reason)
                    consumed.add(replacement_key)
                else:
                    result[item] = ("missing", f"not yet ported as {matched.reason}")
            else:
                result[item] = (matched.status, matched.reason)
            continue
        result[item] = ("missing", "Not found in the Cairo public surface.")
    extras = [item for item in cairo if item.key not in consumed]
    return result, extras


# ---------------------------------------------------------------------------------------------
# Milestones: the canonical L-M1 list, transcribed exactly from plan §8 ("The mirror items of
# L-M1, each with its trace (the canonical list; §4.4 and §7 follow it)") — fix loop 1 decision 7.
# Not best-effort: every key below is named by that paragraph, or is a field/variant/constant of
# a type it names in full (Hex's fields x/y; OffsetHexMode's variants Even/Odd; HexOrientation's
# variants Pointy/Flat; EdgeDirection's 30 compass constants, named in plan §4.4's own row since
# §8 only says "the 30 constants"). Unit-tested against a fixture in scripts/tests, and (skipped
# where the checkout is unavailable) against the pinned sources/hexx.

_EDGE_DIRECTION_CONSTANTS = (
    "X_NEG_Y", "FLAT_TOP_RIGHT", "FLAT_NORTH_EAST", "POINTY_TOP_RIGHT", "POINTY_NORTH_EAST",
    "NEG_Y", "FLAT_TOP", "FLAT_NORTH", "POINTY_TOP_LEFT", "POINTY_NORTH_WEST",
    "NEG_X", "FLAT_TOP_LEFT", "FLAT_NORTH_WEST", "POINTY_LEFT", "POINTY_WEST",
    "NEG_X_Y", "FLAT_BOTTOM_LEFT", "FLAT_SOUTH_WEST", "POINTY_BOTTOM_LEFT", "POINTY_SOUTH_WEST",
    "Y", "FLAT_BOTTOM", "FLAT_SOUTH", "POINTY_BOTTOM_RIGHT", "POINTY_SOUTH_EAST",
    "X", "FLAT_BOTTOM_RIGHT", "FLAT_SOUTH_EAST", "POINTY_RIGHT", "POINTY_EAST",
)
assert len(_EDGE_DIRECTION_CONSTANTS) == 30

_L_M1: set[tuple[str, str, str]] = {
    ("Hex", "struct", "Hex"), ("Hex", "field", "x"), ("Hex", "field", "y"),
    ("Hex", "method", "new"),
    ("Hex", "method", "x"), ("Hex", "method", "y"), ("Hex", "method", "z"),
    ("Hex", "const", "ZERO"),
    ("Hex", "method", "const_sub"),
    ("Hex", "method", "length"), ("Hex", "method", "ulength"),
    ("Hex", "method", "distance_to"), ("Hex", "method", "unsigned_distance_to"),
    ("Hex", "const", "NEIGHBORS_COORDS"),
    ("Hex", "method", "line_to"),
    ("conversions", "enum", "OffsetHexMode"),
    ("conversions", "variant", "Even"), ("conversions", "variant", "Odd"),
    ("conversions", "method", "from_offset_coordinates"),
    ("conversions", "method", "to_offset_coordinates"),
    ("HexOrientation", "enum", "HexOrientation"),
    ("HexOrientation", "variant", "Pointy"), ("HexOrientation", "variant", "Flat"),
    ("HexOrientation", "impl", "Default"),
    ("HexOrientation", "impl", "Not"),
    ("EdgeDirection", "struct", "EdgeDirection"),
    ("EdgeDirection", "const", "ALL_DIRECTIONS"),
    ("EdgeDirection", "method", "iter"),
    ("EdgeDirection", "method", "index"), ("EdgeDirection", "method", "into_hex"),
    ("EdgeDirection", "method", "const_neg"), ("EdgeDirection", "method", "clockwise"),
    ("EdgeDirection", "method", "counter_clockwise"), ("EdgeDirection", "method", "rotate_cw"),
    ("EdgeDirection", "method", "rotate_ccw"),
    ("EdgeDirection", "impl", "From<EdgeDirection> for Hex"),
} | {("EdgeDirection", "const", name) for name in _EDGE_DIRECTION_CONSTANTS}

# Interop with the companion package hexx_glam, scheduled L-M3 (plan §9, §4.4's own "L-M3" rows
# for these five items) — fix loop 2 finding 3: they used to fall through to the generic L-M2
# default with every other Hex operator counterpart, which is wrong specifically for these five.
_INTEROP_ITEMS: set[tuple[str, str, str]] = {
    ("Hex", "method", "as_ivec2"), ("Hex", "method", "as_ivec3"),
    ("Hex", "impl", "From<Hex> for IVec2"), ("Hex", "impl", "From<Hex> for IVec3"),
    ("Hex", "impl", "From<IVec2> for Hex"),
}


def milestone_of(item: Item, status: str) -> str:
    if status == "dropped":
        return "—"
    if item.key in _L_M1:
        return "L-M1"
    if item.owner == "algorithms" or item.key in _INTEROP_ITEMS:
        return "L-M3"
    if item.owner in ("layout", "storage", "mesh"):
        return "—"
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
        "`(ported + renamed) / all hexx items`, computed over every module this parser walks — "
        "`layout`, `storage` and `mesh` included (plan §4.4 \"Modules excluded as a whole\"), "
        "each of them entirely `dropped`. Milestone L-M1 is the canonical list of plan §8, "
        "transcribed exactly and unit-tested; no publication is granted at this task (COMMON.md, "
        "brief LIB-04).",
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
    """The whole public surface of `EXTENSION_MODULES` — traits and their members, impls,
    constants, fields, variants — through the same reachability walk `parse_cairo` uses (fix loop
    2 finding 14: the previous version scanned `pub fn`/`pub struct`/`pub enum` with three
    unrelated regexes, over every `.cairo` file under the module's directory regardless of
    whether Scarb's own module tree ever reaches it, and missed trait declarations, their
    members, impls and constants entirely — the same reachability walk both sides need is what
    `scan_cairo_tree` now provides to both). Every item is scoped `Type.name` (`scoped(True, ...)`
    is forced below): an extension module is inherently multi-type (`board` alone carries
    `HexMap`, `Direction`, `Layout`, ...), the same reasoning as `MULTI_TYPE_OWNERS`. Works in
    both the directory form (`board/map.cairo`, `board/direction.cairo`, ...) and a flat form
    (`board.cairo` declaring `pub mod map;` to a sibling `board/map.cairo`) — the same module-tree
    walker plan §2.2's directory tree and a flat file both resolve through (fix loop 2 finding 4)."""
    result: dict[str, list[Item]] = {name: [] for name in EXTENSION_MODULES}
    tree = build_cairo_tree()
    if tree is None:
        return result
    nodes, reachable, bridged, glob_targets = tree

    def owner_of(path: tuple[str, ...], name: str) -> str | None:
        del name
        return path[0] if path and path[0] in EXTENSION_MODULES else None

    by_module: dict[str, list[Item]] = {name: [] for name in EXTENSION_MODULES}
    for item in scan_cairo_tree(nodes, reachable, bridged, glob_targets, owner_of):
        by_module.setdefault(item.owner, []).append(item)
    for module in EXTENSION_MODULES:
        result[module] = unique_items(by_module.get(module, []))
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
    L-M1 < L-M2 < L-M3 < L-M4 (`milestone_of` never actually returns "L-M4" today — nothing in
    the plan's classification is scheduled there yet — so `--check-release L-M4` currently reduces
    to "every non-dropped item is present"; it exists so `.github/workflows/release-check.yml`'s
    version→milestone table, `1.x -> L-M4` per D-132, is a check this tool can run without raising
    "unknown release"). Not part of `--check`/CI: no release is cut by this task (brief, Out)."""
    order = {"L-M1": 1, "L-M2": 2, "L-M3": 3, "L-M4": 4}
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
    # `--check` and `--extensions` combine (decision of fix loop 1, finding 10: `--extensions
    # --check` is a real CI mode, verifying docs/EXTENSIONS.md instead of writing it). `--refresh`
    # and `--check-release` are standalone modes, exclusive with everything else.
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--refresh", action="store_true", help="refresh the embedded hexx inventory")
    modes.add_argument("--check-release", metavar="MILESTONE",
                        help="fail if an item scheduled by MILESTONE (L-M1, L-M2, L-M3, L-M4) is "
                             "missing")
    parser.add_argument("--check", action="store_true",
                         help="fail if the target (docs/API_PARITY.md, or docs/EXTENSIONS.md with "
                              "--extensions) is stale, instead of writing it")
    parser.add_argument("--extensions", action="store_true",
                         help="target docs/EXTENSIONS.md instead of docs/API_PARITY.md")
    parser.add_argument("--hexx", type=Path, default=Path("/tmp/hexx"),
                         help="hexx 0.25.0 checkout (used only with --refresh)")
    args = parser.parse_args()
    if args.extensions and (args.refresh or args.check_release):
        parser.error("--extensions is incompatible with --refresh/--check-release")
    return args


def main() -> int:
    args = parse_args()
    if args.extensions:
        generated = render_extensions(parse_extensions())
        return write_or_check(EXTENSIONS_OUTPUT, generated, check=args.check)
    hexx = parse_hexx(args.hexx) if args.refresh else load_inventory(OUTPUT)
    cairo = parse_cairo()
    if args.check_release:
        return check_release(hexx, cairo, args.check_release)
    generated = render(hexx, cairo)
    return write_or_check(OUTPUT, generated, args.check)


if __name__ == "__main__":
    raise SystemExit(main())
