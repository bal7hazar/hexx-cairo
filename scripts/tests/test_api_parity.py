#!/usr/bin/env python3
"""Unit tests of scripts/api_parity.py.

Fix loop 1 (audit `[GPT-6-Sol]`, `sources/audits/LIB-04-audit-gpt-6-sol-pass-1.md`) findings
covered here: 3 (a counterpart never grants `ported`/`renamed` without the Cairo item actually
present), 4 (reachability is a real `pub mod`/`pub use` walk, tested end to end on private,
`pub(crate)` and re-exported fixture paths — not the file-list heuristic the first version used),
6 (representative real items classified against plan §4.4, using the pinned checkout), 7 (the
canonical L-M1 list, transcribed and tested; `#[default]`-attributed variants and derived
`Default`).

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import api_parity as ap  # noqa: E402


class ReachabilityFixtureTree(unittest.TestCase):
    """Fix loop 1 finding 4: `build_module_tree` / `compute_reachable_modules` /
    `collect_bridges` walked end to end on a small synthetic crate, not the real `hexx` source —
    exercising a private module, a `pub(crate)` module, a named re-export and a glob re-export,
    each with one item that is exported and one that is not."""

    def build(self, root_text: str, files: dict[str, str]) -> dict[tuple[str, ...], ap.ModuleNode]:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "src").mkdir()
            (root / "src" / "lib.rs").write_text(root_text)
            for rel, text in files.items():
                path = root / "src" / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            return ap.build_module_tree(root / "src" / "lib.rs")

    def test_private_module_item_unreachable_unless_named_in_a_pub_use(self) -> None:
        nodes = self.build(
            root_text="mod inner;\n",
            files={
                "inner.rs": (
                    "pub fn exported() {}\n"
                    "pub fn not_exported() {}\n"
                ),
            },
        )
        # No `pub use` at all: `inner` (private, bare `mod inner;`) is unreachable, so neither
        # function is part of the public API, whatever their own `pub` keyword says.
        reachable = ap.compute_reachable_modules(nodes)
        self.assertNotIn(("inner",), reachable)
        bridged, globs = ap.collect_bridges(nodes, reachable)
        self.assertFalse(ap.declared_reachable(("inner",), "exported", reachable, bridged, globs))
        self.assertFalse(
            ap.declared_reachable(("inner",), "not_exported", reachable, bridged, globs)
        )

    def test_named_reexport_bridges_one_name_but_not_its_sibling(self) -> None:
        nodes = self.build(
            root_text="mod inner;\npub use inner::exported;\n",
            files={
                "inner.rs": (
                    "pub fn exported() {}\n"
                    "pub fn not_exported() {}\n"
                ),
            },
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs = ap.collect_bridges(nodes, reachable)
        self.assertTrue(ap.declared_reachable(("inner",), "exported", reachable, bridged, globs))
        self.assertFalse(
            ap.declared_reachable(("inner",), "not_exported", reachable, bridged, globs)
        )

    def test_pub_crate_module_and_pub_crate_use_do_not_bridge(self) -> None:
        # The `direction::way` / `Way` trait shape of hexx 0.25.0 itself: a `pub(crate) mod`, one
        # name re-exported with a real `pub use`, one only ever named in a `pub(crate) use`.
        nodes = self.build(
            root_text=(
                "pub(crate) mod inner;\n"
                "pub use inner::Exported;\n"
                "pub(crate) use inner::NotExported;\n"
            ),
            files={
                "inner.rs": "pub struct Exported;\npub struct NotExported;\n",
            },
        )
        reachable = ap.compute_reachable_modules(nodes)
        self.assertNotIn(("inner",), reachable)
        bridged, globs = ap.collect_bridges(nodes, reachable)
        self.assertTrue(ap.declared_reachable(("inner",), "Exported", reachable, bridged, globs))
        self.assertFalse(
            ap.declared_reachable(("inner",), "NotExported", reachable, bridged, globs)
        )

    def test_glob_reexport_bridges_every_name(self) -> None:
        nodes = self.build(
            root_text="mod inner;\npub use inner::*;\n",
            files={"inner.rs": "pub fn a() {}\npub fn b() {}\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs = ap.collect_bridges(nodes, reachable)
        self.assertIn(("inner",), globs)
        self.assertTrue(ap.declared_reachable(("inner",), "a", reachable, bridged, globs))
        self.assertTrue(ap.declared_reachable(("inner",), "b", reachable, bridged, globs))

    def test_impl_block_of_a_reachable_type_counts_wherever_it_sits(self) -> None:
        # hex/convert.rs's shape: `Hex` is declared and reachable in one module; a *different*,
        # otherwise-empty module (never itself reachable) carries `impl Hex { ... }`. The method
        # must still be discovered, because Rust attaches inherent impls to the type globally.
        nodes = self.build(
            root_text="pub mod hex;\nmod extra;\n",
            files={
                "hex.rs": "pub struct Hex;\n",
                "extra.rs": "impl Hex {\n    pub fn helper() {}\n}\n",
            },
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs = ap.collect_bridges(nodes, reachable)
        reachable_types = {
            n for n in ap.local_declared_types(nodes[("hex",)].text)
            if ap.declared_reachable(("hex",), n, reachable, bridged, globs)
        }
        self.assertEqual({"Hex"}, reachable_types)
        items = ap.scan_inherent_impls(
            nodes[("extra",)].text, owner="Hex", source="extra.rs",
            reachable_type_names=reachable_types, prefix=False,
        )
        self.assertIn(("Hex", "method", "helper"), {i.key for i in items})


class PublicFieldsVariantsAndTraitMembers(unittest.TestCase):
    def test_struct_fields_are_items(self) -> None:
        text = ap.mask_comments("pub struct Hex {\n    pub x: i32,\n    pub y: i32,\n}\n")
        items = ap.scan_declarations(text, "Hex", "hex/mod.rs", name_ok=lambda n: True, prefix=False)
        kinds_names = {(i.kind, i.name) for i in items}
        self.assertEqual({("struct", "Hex"), ("field", "x"), ("field", "y")}, kinds_names)

    def test_enum_variants_are_items(self) -> None:
        text = ap.mask_comments("pub enum OffsetHexMode {\n    Even,\n    Odd,\n}\n")
        items = ap.scan_declarations(text, "conversions", "conversions.rs", lambda n: True, False)
        kinds_names = {(i.kind, i.name) for i in items}
        self.assertEqual(
            {("enum", "OffsetHexMode"), ("variant", "Even"), ("variant", "Odd")}, kinds_names
        )

    def test_attributed_default_variant_is_still_a_variant(self) -> None:
        # Fix loop 1 finding 7: `#[default]` on a variant made the whole fragment fail the
        # variant-name regex (anchored at the start, which then saw `#` first).
        text = ap.mask_comments(
            "pub enum HexOrientation {\n    Pointy,\n    #[default]\n    Flat,\n}\n"
        )
        items = ap.scan_declarations(text, "HexOrientation", "orientation.rs", lambda n: True, False)
        names = {i.name for i in items if i.kind == "variant"}
        self.assertEqual({"Pointy", "Flat"}, names)

    def test_derived_default_is_an_impl_item(self) -> None:
        text = ap.mask_comments(
            "#[derive(Debug, Copy, Clone, PartialEq, Eq, Hash, Default)]\n"
            "pub enum HexOrientation {\n    Pointy,\n    #[default]\n    Flat,\n}\n"
        )
        items = ap.scan_declarations(text, "HexOrientation", "orientation.rs", lambda n: True, False)
        self.assertIn(("HexOrientation", "impl", "Default"), {i.key for i in items})

    def test_private_tuple_field_is_not_a_public_field(self) -> None:
        # `pub struct EdgeDirection(pub(crate) u8);`: the field is pub(crate), not pub — the
        # regex `pub\s+(?!\()` must not match `pub(crate)`.
        text = ap.mask_comments("pub struct EdgeDirection(pub(crate) u8);\n")
        items = ap.scan_declarations(text, "EdgeDirection", "edge_direction.rs", lambda n: True, False)
        self.assertEqual([("struct", "EdgeDirection")], [(i.kind, i.name) for i in items])

    def test_reexported_trait_is_scanned_with_its_members(self) -> None:
        text = ap.mask_comments(
            "pub trait HexIterExt: Iterator {\n"
            "    fn average(&self) -> Hex;\n"
            "    fn center(&self) -> Hex;\n"
            "    fn bounds(&self) -> HexBounds;\n"
            "}\n"
        )
        items = ap.scan_trait_declarations(text, "HexSpanExt", "hex/iter.rs", lambda n: True, False)
        names = {(i.kind, i.name) for i in items}
        self.assertIn(("trait", "HexIterExt"), names)
        self.assertIn(("method", "average"), names)
        self.assertIn(("method", "center"), names)
        self.assertIn(("method", "bounds"), names)


class MultiTypeOwnerScoping(unittest.TestCase):
    """`shapes`/`storage`/`mesh`: several local types share one owner bucket, so a bare method
    or field name is not a stable identity (fix loop 1, and the original AC-4 fix that first
    caught it for `shapes.rs`)."""

    def test_same_named_methods_of_two_local_types_do_not_collapse(self) -> None:
        text = ap.mask_comments(
            "pub struct A;\n"
            "pub struct B;\n"
            "impl A {\n    pub fn new() -> A { A }\n}\n"
            "impl B {\n    pub fn new() -> B { B }\n}\n"
        )
        items = ap.scan_declarations(text, "shapes", "shapes.rs", lambda n: True, prefix=True)
        reachable_types = {"A", "B"}
        items = list(items) + ap.scan_inherent_impls(
            text, "shapes", "shapes.rs", reachable_types, prefix=True
        )
        names = {i.name for i in items if i.kind == "method"}
        self.assertEqual({"A.new", "B.new"}, names)


class CounterpartsAndRulesPresenceGating(unittest.TestCase):
    """Fix loop 1 finding 3: `ported`/`renamed` require the Cairo item to actually be present.
    A counterpart or a rule mapping is a *plan*, not evidence of completion."""

    def test_counterparts_entry_is_missing_until_its_cairo_target_exists(self) -> None:
        # cairo_key deliberately differs from item.key (kind: trait vs method) so this exercises
        # the COUNTERPARTS branch of classify(), not the direct-match branch (whose own "already
        # ported" case is a separate, simpler path with nothing to gate).
        item = ap.Item("HexSpanExt", "trait", "HexIterExt", "hex/iter.rs")
        cairo_key = ("HexSpanExt", "trait", "HexSpanExt")
        fake_counterparts = {item.key: ("renamed", cairo_key, "test detail")}
        with mock.patch.object(ap, "COUNTERPARTS", fake_counterparts):
            statuses, _ = ap.classify([item], [])  # no Cairo item at all
            self.assertEqual("missing", statuses[item][0])
            self.assertIn("HexSpanExt", statuses[item][1])

            cairo_item = ap.Item(*cairo_key, "crates/hexx/src/hex/iter.cairo")
            statuses, _ = ap.classify([item], [cairo_item])
            self.assertEqual(("renamed", "test detail"), statuses[item])

    def test_counterparts_entry_wins_over_a_matching_exclusion_rule_once_present(self) -> None:
        item = ap.Item("HexSpanExt", "trait", "HexIterExt", "hex/iter.rs")
        cairo_key = ("HexSpanExt", "trait", "HexSpanExt")
        fake_rule = ap.rule("HexSpanExt", r"trait:HexIterExt", "dropped",
                             "test: would wrongly exclude HexIterExt")
        fake_counterparts = {item.key: ("renamed", cairo_key, "real counterpart detail")}
        cairo_item = ap.Item(*cairo_key, "crates/hexx/src/hex/iter.cairo")
        with mock.patch.object(ap, "RULES", (fake_rule,)), \
             mock.patch.object(ap, "COUNTERPARTS", fake_counterparts):
            statuses, _ = ap.classify([item], [cairo_item])
        self.assertEqual(("renamed", "real counterpart detail"), statuses[item])

    def test_without_a_counterparts_entry_the_rule_applies(self) -> None:
        item = ap.Item("algorithms", "method", "range_fov", "algorithms/fov.rs")
        fake_rule = ap.rule("algorithms", r"method:range_fov", "dropped", "test reason")
        with mock.patch.object(ap, "RULES", (fake_rule,)), mock.patch.object(ap, "COUNTERPARTS", {}):
            statuses, _ = ap.classify([item], [])
        self.assertEqual(("dropped", "test reason"), statuses[item])

    def test_renamed_rule_with_a_replacement_is_missing_until_present(self) -> None:
        item = ap.Item("Hex", "impl", "Mul<i32>", "hex/impls.rs")
        fake_rule = ap.rule("Hex", r"impl:Mul<i32>$", "renamed", "mul_scalar",
                             replacement=("method", "mul_scalar"))
        with mock.patch.object(ap, "RULES", (fake_rule,)), mock.patch.object(ap, "COUNTERPARTS", {}):
            statuses, _ = ap.classify([item], [])
            self.assertEqual("missing", statuses[item][0])
            cairo_item = ap.Item("Hex", "method", "mul_scalar", "crates/hexx/src/hex.cairo")
            statuses, _ = ap.classify([item], [cairo_item])
            self.assertEqual(("renamed", "mul_scalar"), statuses[item])

    def test_dropped_status_never_needs_a_cairo_target(self) -> None:
        item = ap.Item("Hex", "impl", "BitAnd", "hex/impls.rs")
        fake_rule = ap.rule("Hex", r"impl:BitAnd$", "dropped", "no bitwise operators")
        with mock.patch.object(ap, "RULES", (fake_rule,)), mock.patch.object(ap, "COUNTERPARTS", {}):
            statuses, _ = ap.classify([item], [])
        self.assertEqual(("dropped", "no bitwise operators"), statuses[item])


class ScheduledReleaseCheck(unittest.TestCase):
    """AC-3: "an item scheduled for a release and absent fails the check of that release" — and
    fix loop 1 finding 3's consequence: a *counterpart-mapped* item scheduled for a release and
    still absent must fail that release's check too, not read a false `ported`."""

    def test_missing_item_scheduled_at_or_before_the_release_fails(self) -> None:
        item = ap.Item("Hex", "struct", "Hex", "hex/mod.rs")
        self.assertIn(item.key, ap._L_M1)
        self.assertEqual(1, ap.check_release([item], [], "L-M1"))

    def test_present_item_passes(self) -> None:
        item = ap.Item("Hex", "struct", "Hex", "hex/mod.rs")
        self.assertEqual(0, ap.check_release([item], [item], "L-M1"))

    def test_item_scheduled_after_the_release_does_not_block_it(self) -> None:
        item = ap.Item("Hex", "method", "range", "hex/mod.rs")
        self.assertNotIn(item.key, ap._L_M1)
        self.assertEqual(0, ap.check_release([item], [], "L-M1"))

    def test_absent_mapped_counterpart_scheduled_for_a_release_fails_it(self) -> None:
        # fix loop 1 finding 3's own example: an L-M3 algorithms counterpart, never implemented,
        # must fail an L-M3 release check — it must not silently read `ported`.
        item = ap.Item("algorithms", "method", "a_star", "algorithms/pathfinding.rs")
        self.assertEqual("L-M3", ap.milestone_of(item, "missing"))
        self.assertIn(item.key, ap.COUNTERPARTS)
        self.assertEqual(1, ap.check_release([item], [], "L-M3"))


class CanonicalMilestoneList(unittest.TestCase):
    """Fix loop 1 finding 7: the L-M1 set is the canonical list of plan §8 ("The mirror items of
    L-M1 ... the canonical list; §4.4 and §7 follow it"), transcribed exactly, not best-effort."""

    def test_l_m1_has_exactly_the_items_plan_section_8_names(self) -> None:
        # Counts stated by plan §8: Hex (struct + 14 named members), the two enums with their
        # variants and Default/Not, the two offset-conversion methods, EdgeDirection (struct +
        # ALL_DIRECTIONS + iter + the 30 compass constants + 5 named methods + the From impl).
        hex_items = {k for k in ap._L_M1 if k[0] == "Hex"}
        self.assertEqual(15, len(hex_items))
        edge_direction_items = {k for k in ap._L_M1 if k[0] == "EdgeDirection"}
        self.assertEqual(11 + 30, len(edge_direction_items))
        self.assertEqual(30, len(ap._EDGE_DIRECTION_CONSTANTS))
        self.assertEqual(30, len(set(ap._EDGE_DIRECTION_CONSTANTS)))  # no duplicate name
        # Explicitly not L-M1 (plan §8's own list of what moved to L-M2): `hex()`, `splat`, the
        # operators, `mul_scalar`, `DoubledHexMode`, EdgeDirection's `Neg`/`Debug`.
        for owner, kind, name in (
            ("Hex", "method", "hex"), ("Hex", "method", "splat"),
            ("Hex", "impl", "Mul<i32>"), ("conversions", "enum", "DoubledHexMode"),
            ("EdgeDirection", "impl", "Neg"), ("EdgeDirection", "impl", "Debug"),
        ):
            self.assertNotIn((owner, kind, name), ap._L_M1)

    def test_milestone_of_dropped_item_is_never_a_release(self) -> None:
        item = ap.Item("Hex", "impl", "BitAnd", "hex/impls.rs")
        self.assertEqual("—", ap.milestone_of(item, "dropped"))

    def test_module_excluded_as_a_whole_has_no_milestone(self) -> None:
        item = ap.Item("layout", "struct", "HexLayout", "layout.rs")
        self.assertEqual("—", ap.milestone_of(item, "missing"))


class RealCheckoutClassification(unittest.TestCase):
    """Fix loop 1 finding 6: the parser run for real on the pinned `hexx` 0.25.0 checkout,
    classification of a representative list of real items checked against plan §4.4. Skipped
    (not failed) where the checkout is unavailable: `sources/hexx` is a read-only local clone of
    this task's environment (`sources/VERSIONS.md`), never committed (`.gitignore`: `/sources/`)
    and not fetched by any CI job — there is no pinned Rust source tree for CI to check this
    against, unlike `tools/refgen`, which depends on the published crate via Cargo instead."""

    HEXX_ROOT = Path(__file__).resolve().parents[2] / "sources" / "hexx"

    def setUp(self) -> None:
        if not (self.HEXX_ROOT / "src" / "lib.rs").is_file():
            self.skipTest(f"{self.HEXX_ROOT} not present (local-only checkout, see class docstring)")
        self.hexx = ap.parse_hexx(self.HEXX_ROOT)
        self.statuses, _ = ap.classify(self.hexx, [])  # nothing is ported yet in this task
        self.by_key = {i.key: i for i in self.hexx}

    def status_of(self, owner: str, kind: str, name: str) -> str:
        key = (owner, kind, name)
        self.assertIn(key, self.by_key, f"{key} not found by the parser")
        return self.statuses[self.by_key[key]][0]

    def test_bitand_i32_and_mul_f32_are_excluded(self) -> None:
        self.assertEqual("dropped", self.status_of("Hex", "impl", "BitAnd<i32>"))
        self.assertEqual("dropped", self.status_of("Hex", "impl", "Mul<f32>"))

    def test_cached_rings_and_circular_range_are_counterparts(self) -> None:
        # Nothing is implemented in this task, so both read `missing` (finding 3) — but as a
        # *counterpart*, not silently absent from the inventory or misclassified by a broad rule.
        self.assertEqual("missing", self.status_of("Hex", "method", "cached_rings"))
        self.assertIn(("Hex", "method", "cached_rings"), ap.COUNTERPARTS)
        self.assertEqual("missing", self.status_of("Hex", "method", "circular_range"))
        self.assertIn(("Hex", "method", "circular_range"), ap.COUNTERPARTS)

    def test_the_four_algorithms_are_missing_until_implemented(self) -> None:
        for name in ("field_of_movement", "a_star", "range_fov", "directional_fov"):
            self.assertEqual("missing", self.status_of("algorithms", "method", name))

    def test_every_l_m1_item_is_discovered(self) -> None:
        undiscovered = [k for k in ap._L_M1 if k not in self.by_key]
        self.assertEqual([], undiscovered)

    def test_layout_storage_mesh_are_entirely_dropped(self) -> None:
        for owner in ("layout", "storage", "mesh"):
            owned = [i for i in self.hexx if i.owner == owner]
            self.assertTrue(owned, f"no items discovered for {owner}")
            non_dropped = [i for i in owned if self.statuses[i][0] != "dropped"]
            self.assertEqual([], non_dropped)


if __name__ == "__main__":
    unittest.main()
