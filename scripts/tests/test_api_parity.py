#!/usr/bin/env python3
"""Unit tests of scripts/api_parity.py.

Fix loop 2 (audit `[GPT-6-Sol]` pass 2, `sources/audits/LIB-04-audit-gpt-6-sol-pass-2.md`)
findings covered here: 3 (every `renamed` rule and counterpart is presence-gated, interop items
schedule L-M3), 4 (a real `mod`/`use` walk: aliases, `crate::`/`self::` and nested-group paths,
cfg evaluation, the flat-file-with-sibling-directory form; an unsupported form raises, naming the
file and the statement), 5 (`Deref` and `direction::angles`'s constants), 14 (the extension
inventory walks the whole public surface — traits, members, impls, constants, fields, variants —
through the same reachability walk, in directory and flat forms), 15 (a derive binds to the
declaration immediately following it, never a type sharing its lookback window).

Every fixture tree is written under `scripts/tests/tmp/` (repo-local, gitignored), not a host
temp directory: decision B(viii) of fix loop 2 — a read-only sandbox may have no writable `/tmp`.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import shutil
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import api_parity as ap  # noqa: E402

TMP_ROOT = Path(__file__).resolve().parent / "tmp"


class FixtureTreeCase(unittest.TestCase):
    """Base class: `self.build(root_text, files)` writes a small Rust-shaped crate under
    `scripts/tests/tmp/<TestClass>/<test_method>/` and returns its module tree."""

    def setUp(self) -> None:
        self._fixture_dir = TMP_ROOT / type(self).__name__ / self._testMethodName
        if self._fixture_dir.exists():
            shutil.rmtree(self._fixture_dir)
        self._fixture_dir.mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self._fixture_dir, ignore_errors=True)

    def build(self, root_text: str, files: dict[str, str],
              root_name: str = "lib.rs") -> dict[tuple[str, ...], ap.ModuleNode]:
        root = self._fixture_dir
        (root / "src").mkdir(exist_ok=True)
        (root / "src" / root_name).write_text(root_text)
        for rel, text in files.items():
            path = root / "src" / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return ap.build_module_tree(root / "src" / root_name)


class ReachabilityFixtureTree(FixtureTreeCase):
    """Fix loop 1 finding 4, still exercised the same way after fix loop 2's rewrite: a private
    module, a `pub(crate)` module, a named re-export and a glob re-export, each with one item
    that is exported and one that is not."""

    def test_private_module_item_unreachable_unless_named_in_a_pub_use(self) -> None:
        nodes = self.build(
            root_text="mod inner;\n",
            files={"inner.rs": "pub fn exported() {}\npub fn not_exported() {}\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        self.assertNotIn(("inner",), reachable)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        self.assertFalse(ap.declared_reachable(("inner",), "exported", reachable, bridged, globs))
        self.assertFalse(
            ap.declared_reachable(("inner",), "not_exported", reachable, bridged, globs)
        )

    def test_named_reexport_bridges_one_name_but_not_its_sibling(self) -> None:
        nodes = self.build(
            root_text="mod inner;\npub use inner::exported;\n",
            files={"inner.rs": "pub fn exported() {}\npub fn not_exported() {}\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        self.assertTrue(ap.declared_reachable(("inner",), "exported", reachable, bridged, globs))
        self.assertFalse(
            ap.declared_reachable(("inner",), "not_exported", reachable, bridged, globs)
        )

    def test_pub_crate_module_and_pub_crate_use_do_not_bridge(self) -> None:
        nodes = self.build(
            root_text=(
                "pub(crate) mod inner;\n"
                "pub use inner::Exported;\n"
                "pub(crate) use inner::NotExported;\n"
            ),
            files={"inner.rs": "pub struct Exported;\npub struct NotExported;\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        self.assertNotIn(("inner",), reachable)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
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
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        self.assertIn(("inner",), globs)
        self.assertTrue(ap.declared_reachable(("inner",), "a", reachable, bridged, globs))
        self.assertTrue(ap.declared_reachable(("inner",), "b", reachable, bridged, globs))

    def test_impl_block_of_a_reachable_type_counts_wherever_it_sits(self) -> None:
        nodes = self.build(
            root_text="pub mod hex;\nmod extra;\n",
            files={
                "hex.rs": "pub struct Hex;\n",
                "extra.rs": "impl Hex {\n    pub fn helper() {}\n}\n",
            },
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
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


class FlatFileWithSiblingDirectory(FixtureTreeCase):
    """Fix loop 2 finding 4: plan §2.2's own tree is directory modules with flat-file children
    (`hex/impls.cairo`, `board/*.cairo`) — the Rust-side equivalent, a flat file whose own further
    child resolves in a sibling directory named after it (`foo.rs` declares `mod bar;`, real file
    `foo/bar.rs`), used to raise "cannot resolve" outright."""

    def test_flat_parent_resolves_its_own_child_in_a_sibling_directory(self) -> None:
        nodes = self.build(
            root_text="pub mod foo;\n",
            files={
                "foo.rs": "mod bar;\npub use bar::Thing;\n",
                "foo/bar.rs": "pub struct Thing;\n",
            },
        )
        self.assertIn(("foo", "bar"), nodes)
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        self.assertTrue(
            ap.declared_reachable(("foo", "bar"), "Thing", reachable, bridged, globs)
        )

    def test_two_levels_of_flat_parents_each_resolve_their_own_child(self) -> None:
        nodes = self.build(
            root_text="mod a;\n",
            files={
                "a.rs": "mod b;\n",
                "a/b.rs": "mod c;\npub use c::Deep;\n",
                "a/b/c.rs": "pub struct Deep;\n",
            },
        )
        self.assertIn(("a", "b", "c"), nodes)


class UsePathForms(FixtureTreeCase):
    """Fix loop 2 finding 4 (ii): an alias, a `crate::`-prefixed path, a `self::`-prefixed path
    and a nested group (`crate::{A, sub::{B, C}}`, the exact shape the pinned checkout's own
    `direction/edge_direction.rs` uses) all resolve; a glob nested inside a group raises, naming
    the file and the statement."""

    def test_alias_bridges_the_original_name_not_the_alias(self) -> None:
        nodes = self.build(
            root_text="mod inner;\npub use inner::Thing as Alias;\n",
            files={"inner.rs": "pub struct Thing;\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, used = ap.collect_use_statements(nodes, reachable)
        self.assertTrue(ap.declared_reachable(("inner",), "Thing", reachable, bridged, globs))
        self.assertNotIn("Alias", used)  # the alias itself is not a declared item anywhere

    def test_crate_prefixed_path_resolves_from_the_root(self) -> None:
        nodes = self.build(
            root_text="mod inner;\n",
            files={
                "inner.rs": "mod deep;\npub use crate::inner::deep::Thing;\n",
                "inner/deep.rs": "pub struct Thing;\n",
            },
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        # `inner` is not itself reachable (private `mod inner;`), so its own `pub use` (even a
        # `crate::`-absolute one) cannot bridge externally — this asserts the path resolved to
        # the right target module, not that the whole chain becomes publicly reachable.
        target, entries = [], []
        ap.parse_use_tree("crate::inner::deep::Thing", ("inner",), "test", target, entries)
        self.assertEqual([(("inner", "deep"), "Thing", None)], target)

    def test_self_prefixed_path_is_relative_to_the_current_module(self) -> None:
        entries: list = []
        globs: list = []
        ap.parse_use_tree("self::deep::Thing", ("inner",), "test", entries, globs)
        self.assertEqual([(("inner", "deep"), "Thing", None)], entries)

    def test_nested_group_path_resolves_every_leaf(self) -> None:
        # The exact shape `direction/edge_direction.rs` uses:
        # `use crate::{Hex, angles::{DIRECTION_ANGLE_RAD, DIRECTION_ANGLE_DEGREES}};`
        entries: list = []
        globs: list = []
        ap.parse_use_tree(
            "crate::{Hex, angles::{DIRECTION_ANGLE_RAD, DIRECTION_ANGLE_DEGREES}}",
            (), "test", entries, globs,
        )
        self.assertEqual(
            {
                ((), "Hex", None),
                (("angles",), "DIRECTION_ANGLE_RAD", None),
                (("angles",), "DIRECTION_ANGLE_DEGREES", None),
            },
            set(entries),
        )

    def test_glob_inside_a_group_is_a_nested_glob_target(self) -> None:
        # `use a::{b::*, c};` is valid Rust (a nested glob inside a group); the parser supports it
        # through the same recursion a nested named group uses, rather than rejecting it.
        entries: list = []
        globs: list = []
        ap.parse_use_tree("crate::{Hex, inner::*}", (), "test", entries, globs)
        self.assertEqual([((), "Hex", None)], entries)
        self.assertEqual([("inner",)], globs)

    def test_malformed_use_group_raises_naming_the_statement(self) -> None:
        entries: list = []
        globs: list = []
        with self.assertRaises(SystemExit) as ctx:
            # Trailing text after the group's closing brace: not a form `use` allows.
            ap.parse_use_tree("crate::{Hex, Y}extra", (), "src/lib.rs: use ...", entries, globs)
        self.assertIn("src/lib.rs", str(ctx.exception))


class CfgEvaluation(FixtureTreeCase):
    """Fix loop 2 finding 4 (iii): a module gated by an enabled cargo feature is reachable, one
    gated by a disabled or unrecognized feature is not (or raises); adjacency, not proximity, to
    the declaration is what makes a `#[cfg(...)]` apply — an earlier, unrelated module's cfg must
    never leak onto an undecorated later one (the actual bug this fixed: `#[cfg(feature =
    "mesh")]` on `pub mod mesh;` was wrongly read as covering the very next `pub mod orientation;`
    and `pub mod shapes;` too, disabling modules that carry no attribute at all)."""

    def test_enabled_feature_module_is_reachable(self) -> None:
        nodes = self.build(
            root_text='#[cfg(feature = "algorithms")]\npub mod algorithms;\n',
            files={"algorithms.rs": ""},
        )
        self.assertIn(("algorithms",), ap.compute_reachable_modules(nodes))

    def test_disabled_feature_module_is_unreachable_by_default(self) -> None:
        # "serde", not "mesh": mesh is exempted from cfg-reachability by default (it must still be
        # listed as a documentary "modules excluded as a whole" entry per plan §4.4), so a mesh
        # fixture here would pass regardless of whether the general disabled-by-default mechanism
        # works. serde carries no such exemption.
        nodes = self.build(
            root_text='#[cfg(feature = "serde")]\npub mod serde_support;\n',
            files={"serde_support.rs": ""},
        )
        self.assertNotIn(("serde_support",), ap.compute_reachable_modules(nodes))

    def test_disabled_feature_module_is_exempt_when_asked(self) -> None:
        nodes = self.build(
            root_text='#[cfg(feature = "mesh")]\npub mod mesh;\n',
            files={"mesh.rs": ""},
        )
        reachable = ap.compute_reachable_modules(nodes, cfg_exempt=frozenset({("mesh",)}))
        self.assertIn(("mesh",), reachable)

    def test_an_undecorated_declaration_after_a_cfg_gated_one_is_unaffected(self) -> None:
        # The exact bug: adjacency, not a fixed lookback window, decides which declaration a
        # `#[cfg(...)]` belongs to. "serde", not "mesh": see the comment on
        # test_disabled_feature_module_is_unreachable_by_default.
        nodes = self.build(
            root_text=(
                '#[cfg(feature = "serde")]\n'
                "pub mod serde_support;\n"
                "pub mod orientation;\n"
            ),
            files={"serde_support.rs": "", "orientation.rs": ""},
        )
        reachable = ap.compute_reachable_modules(nodes)
        self.assertNotIn(("serde_support",), reachable)
        self.assertIn(("orientation",), reachable)

    def test_cfg_test_module_is_unreachable(self) -> None:
        nodes = self.build(root_text="#[cfg(test)]\nmod tests;\n", files={"tests.rs": ""})
        self.assertNotIn(("tests",), ap.compute_reachable_modules(nodes))

    def test_cfg_any_empty_is_always_false(self) -> None:
        self.assertFalse(ap.evaluate_cfg("any()", "test"))

    def test_cfg_not_negates(self) -> None:
        self.assertTrue(ap.evaluate_cfg('not(feature = "mesh")', "test"))
        self.assertFalse(ap.evaluate_cfg('not(feature = "grid")', "test"))

    def test_unrecognized_cfg_feature_raises(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            self.build(
                root_text='#[cfg(feature = "unknown_future_feature")]\npub mod hidden;\n',
                files={"hidden.rs": "pub struct Hex;\n"},
            )
        self.assertIn("unknown_future_feature", str(ctx.exception))

    def test_unrecognized_cfg_predicate_raises(self) -> None:
        # `target_os = "..."` is not among the predicates this tool recognizes (`feature`, `test`,
        # `any`, `all`, `not`); it must raise, not be silently treated as false.
        with self.assertRaises(SystemExit) as ctx:
            self.build(
                root_text='#[cfg(target_os = "linux")]\npub mod hidden;\n',
                files={"hidden.rs": ""},
            )
        self.assertIn("target_os", str(ctx.exception))

    def test_cfg_any_empty_module_is_unreachable(self) -> None:
        # `any()` alone is recognized (always false); confirm the *module* is gone, matching the
        # audit's own probe (`#[cfg(any())] pub mod hidden { pub struct Hex {} }` must not be
        # treated as public).
        nodes = self.build(root_text='#[cfg(any())]\npub mod hidden;\n', files={"hidden.rs": ""})
        self.assertNotIn(("hidden",), ap.compute_reachable_modules(nodes))


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

    def test_derive_binds_to_the_immediately_following_declaration_only(self) -> None:
        # Fix loop 2 finding 15: a derive must not attach to a *different* type that merely sits
        # within the same lookback window.
        text = ap.mask_comments(
            "#[derive(Default)]\npub struct A;\npub struct B;\n"
        )
        items = ap.scan_declarations(text, "shapes", "shapes.rs", lambda n: True, prefix=True)
        keys = {i.key for i in items}
        self.assertIn(("shapes", "impl", "Default for A"), keys)
        self.assertNotIn(("shapes", "impl", "Default for B"), keys)

    def test_derive_does_not_leak_across_an_intervening_declaration(self) -> None:
        # Same finding: even a *short* gap must not let a derive skip over another declaration.
        text = ap.mask_comments(
            "#[derive(Default)]\npub struct A;\n\npub struct B;\n"
        )
        items = ap.scan_declarations(text, "shapes", "shapes.rs", lambda n: True, prefix=True)
        keys = {i.key for i in items}
        self.assertIn(("shapes", "impl", "Default for A"), keys)
        self.assertNotIn(("shapes", "impl", "Default for B"), keys)

    def test_private_tuple_field_is_not_a_public_field(self) -> None:
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

    def test_free_const_in_an_inline_module_is_found_despite_indentation(self) -> None:
        # Fix loop 2 finding 5: `direction::angles`'s own shape — indented because it sits inside
        # an inline `pub mod angles { ... }`, which the old column-0-anchored FREE_CONST_RE
        # rejected as if it were impl-block content.
        text = ap.mask_comments(
            "    pub const DIRECTION_ANGLE_RAD: f32 = 1.0;\n"
            "    pub const DIRECTION_ANGLE_DEGREES: f32 = 60.0;\n"
        )
        items = ap.scan_module(text, "EdgeDirection", "direction/angles", lambda n: True, set(), False)
        names = {i.name for i in items if i.kind == "const"}
        self.assertEqual({"DIRECTION_ANGLE_RAD", "DIRECTION_ANGLE_DEGREES"}, names)

    def test_free_item_scan_does_not_double_count_an_impl_blocks_own_method(self) -> None:
        text = ap.mask_comments(
            "pub fn free_fn() {}\n"
            "impl Hex {\n    pub fn method() {}\n}\n"
        )
        items = ap.scan_module(text, "Hex", "hex/mod.rs", lambda n: True, {"Hex"}, False)
        names = {i.name for i in items if i.kind == "method"}
        self.assertIn("free_fn", names)
        self.assertEqual(1, sum(1 for i in items if i.kind == "method" and i.name == "method"))


class MultiTypeOwnerScoping(unittest.TestCase):
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
    """Fix loop 1 finding 3, extended by fix loop 2: every `renamed` RULES entry (not just
    COUNTERPARTS) is presence-gated — the first version of fix loop 1's fix only gated entries
    that happened to carry a `replacement`, and none of the real `renamed` rules did."""

    def test_counterparts_entry_is_missing_until_its_cairo_target_exists(self) -> None:
        item = ap.Item("HexSpanExt", "trait", "HexIterExt", "hex/iter.rs")
        cairo_key = ("HexSpanExt", "trait", "HexSpanExt")
        fake_counterparts = {item.key: ("renamed", cairo_key, "test detail")}
        with mock.patch.object(ap, "COUNTERPARTS", fake_counterparts):
            statuses, _ = ap.classify([item], [])
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
        item = ap.Item("HexSpanExt", "trait", "HexIterExt", "hex/iter.rs")
        fake_rule = ap.rule("HexSpanExt", r"trait:HexIterExt", "dropped", "test reason")
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

    def test_every_real_renamed_rule_carries_a_replacement_or_is_interop(self) -> None:
        # Fix loop 2 finding 3's actual bug: 20 real `renamed` rows had no `replacement` at all,
        # so every one of them read `renamed` unconditionally, regardless of Cairo presence.
        # Interop rules (hexx_glam) are the one deliberate exception (see their own comment):
        # their replacement can never resolve true from this crate's own inventory by design.
        for candidate in ap.RULES:
            if candidate.status == "renamed":
                self.assertIsNotNone(
                    candidate.replacement,
                    f"renamed rule {candidate.item.pattern!r} (owner {candidate.owner.pattern!r}) "
                    f"has no replacement to verify presence against",
                )


class ScheduledReleaseCheck(unittest.TestCase):
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

    def test_l_m4_release_check_does_not_raise_unknown_release(self) -> None:
        # D-132's version->milestone table maps 1.x to L-M4 (docs/RELEASING.md,
        # .github/workflows/release-check.yml); nothing in the plan's classification is
        # scheduled there yet, so this reduces to "every non-dropped item is present".
        item = ap.Item("Hex", "struct", "Hex", "hex/mod.rs")
        self.assertEqual(1, ap.check_release([item], [], "L-M4"))
        self.assertEqual(0, ap.check_release([item], [item], "L-M4"))

    def test_absent_mapped_counterpart_scheduled_for_a_release_fails_it(self) -> None:
        item = ap.Item("algorithms", "method", "a_star", "algorithms/pathfinding.rs")
        self.assertEqual("L-M3", ap.milestone_of(item, "missing"))
        self.assertIn(item.key, ap.COUNTERPARTS)
        self.assertEqual(1, ap.check_release([item], [], "L-M3"))

    def test_interop_item_is_scheduled_l_m3_not_l_m2(self) -> None:
        item = ap.Item("Hex", "method", "as_ivec2", "hex/convert.rs")
        self.assertEqual("L-M3", ap.milestone_of(item, "missing"))


class CanonicalMilestoneList(unittest.TestCase):
    def test_l_m1_has_exactly_the_items_plan_section_8_names(self) -> None:
        hex_items = {k for k in ap._L_M1 if k[0] == "Hex"}
        self.assertEqual(15, len(hex_items))
        edge_direction_items = {k for k in ap._L_M1 if k[0] == "EdgeDirection"}
        self.assertEqual(11 + 30, len(edge_direction_items))
        self.assertEqual(30, len(ap._EDGE_DIRECTION_CONSTANTS))
        self.assertEqual(30, len(set(ap._EDGE_DIRECTION_CONSTANTS)))
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


class ExtensionInventory(FixtureTreeCase):
    """Fix loop 2 finding 14: a synthetic `board`-shaped Cairo tree, directory and flat forms,
    with a trait, its members, an impl, a constant, a struct with a field, and an enum with a
    variant — every one of them must show up, scoped `Type.name`."""

    def build_cairo(self, root_text: str, files: dict[str, str]):
        nodes = self.build(root_text, files, root_name="lib.cairo")
        reachable = ap.compute_reachable_modules(nodes, cfg_exempt=frozenset())
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        return nodes, reachable, bridged, globs

    def test_directory_form_extension_module(self) -> None:
        nodes, reachable, bridged, globs = self.build_cairo(
            root_text="pub mod board;\n",
            files={
                "board.cairo": "pub mod map;\n",
                "board/map.cairo": (
                    "pub const MAX_WIDTH: u8 = 15;\n"
                    "#[derive(Copy, Drop)]\n"
                    "pub struct HexMap {\n    pub width: u8,\n}\n"
                    "pub trait HexMapTrait {\n    fn new_empty(width: u8) -> HexMap;\n}\n"
                    "pub impl HexMapImpl of HexMapTrait {\n"
                    "    fn new_empty(width: u8) -> HexMap { HexMap { width } }\n"
                    "}\n"
                ),
            },
        )

        def owner_of(path, name):
            return path[0] if path and path[0] == "board" else None

        items = ap.scan_cairo_tree(nodes, reachable, bridged, globs, owner_of)
        keys = {i.key for i in items}
        self.assertIn(("board", "const", "MAX_WIDTH"), keys)
        self.assertIn(("board", "struct", "HexMap"), keys)
        self.assertIn(("board", "field", "HexMap.width"), keys)
        self.assertIn(("board", "trait", "HexMapTrait"), keys)
        self.assertIn(("board", "method", "HexMap.new_empty"), keys)

    def test_flat_form_extension_module(self) -> None:
        # `board.cairo` itself declares the item (no `board/` directory at all).
        nodes, reachable, bridged, globs = self.build_cairo(
            root_text="pub mod board;\n",
            files={"board.cairo": "pub enum Direction {\n    East,\n    West,\n}\n"},
        )

        def owner_of(path, name):
            return path[0] if path and path[0] == "board" else None

        items = ap.scan_cairo_tree(nodes, reachable, bridged, globs, owner_of)
        keys = {i.key for i in items}
        self.assertIn(("board", "enum", "Direction"), keys)
        self.assertIn(("board", "variant", "Direction.East"), keys)
        self.assertIn(("board", "variant", "Direction.West"), keys)


class RealCheckoutClassification(unittest.TestCase):
    """Fix loop 1 finding 6, fix loop 2 finding 3: the parser run for real on the pinned `hexx`
    0.25.0 checkout. Skipped (not failed) where the checkout is unavailable (local-only, never in
    CI: see `sources/VERSIONS.md`, `.gitignore`)."""

    HEXX_ROOT = Path(__file__).resolve().parents[2] / "sources" / "hexx"

    def setUp(self) -> None:
        if not (self.HEXX_ROOT / "src" / "lib.rs").is_file():
            self.skipTest(f"{self.HEXX_ROOT} not present (local-only checkout, see class docstring)")
        self.hexx = ap.parse_hexx(self.HEXX_ROOT)
        self.statuses, _ = ap.classify(self.hexx, [])
        self.by_key = {i.key: i for i in self.hexx}

    def status_of(self, owner: str, kind: str, name: str) -> str:
        key = (owner, kind, name)
        self.assertIn(key, self.by_key, f"{key} not found by the parser")
        return self.statuses[self.by_key[key]][0]

    def test_bitand_i32_and_mul_f32_are_excluded(self) -> None:
        self.assertEqual("dropped", self.status_of("Hex", "impl", "BitAnd<i32>"))
        self.assertEqual("dropped", self.status_of("Hex", "impl", "Mul<f32>"))

    def test_cached_rings_and_circular_range_are_counterparts(self) -> None:
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

    def test_deref_of_hexorientation_is_discovered_and_dropped(self) -> None:
        self.assertEqual("dropped", self.status_of("HexOrientation", "impl", "Deref"))

    def test_direction_angles_constants_are_discovered_and_dropped(self) -> None:
        for name in ("DIRECTION_ANGLE_OFFSET_RAD", "DIRECTION_ANGLE_OFFSET_DEGREES",
                      "DIRECTION_ANGLE_RAD", "DIRECTION_ANGLE_DEGREES"):
            self.assertEqual("dropped", self.status_of("EdgeDirection", "const", name))

    def test_no_renamed_item_is_falsely_ported_without_its_cairo_target(self) -> None:
        # Fix loop 2 finding 3's own probe: against an *empty* Cairo source, nothing should ever
        # read `ported` or `renamed` — everything is either `dropped` (by design) or `missing`
        # (nothing implemented yet).
        bad = [
            item for item in self.hexx
            if self.statuses[item][0] in ("ported", "renamed")
        ]
        self.assertEqual([], bad)


if __name__ == "__main__":
    unittest.main()
