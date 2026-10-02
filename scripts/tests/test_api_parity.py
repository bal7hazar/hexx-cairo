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


def node_of(raw: str, source: str) -> ap.ModuleNode:
    """A standalone `ModuleNode` from a raw (unmasked) text snippet, for the scan_* unit tests
    that exercise one declaration form in isolation rather than a whole fixture tree — fix loop 3:
    `scan_declarations`/`scan_trait_declarations`/`scan_inherent_impls`/`scan_module`/`scan_impls`
    all take a `ModuleNode` now (cfg-gating a declaration needs the node's own `text_with_strings`
    and `line_offset`, not just its plain masked text)."""
    return ap.ModuleNode(path=(), vis="pub", text=ap.mask_comments(raw), source=source,
                          text_with_strings=ap.mask_comments(raw, mask_strings=False))


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
        self.assertFalse(ap.exported_name(("inner",), "exported", reachable, bridged, globs))
        self.assertFalse(
            ap.exported_name(("inner",), "not_exported", reachable, bridged, globs)
        )

    def test_named_reexport_bridges_one_name_but_not_its_sibling(self) -> None:
        nodes = self.build(
            root_text="mod inner;\npub use inner::exported;\n",
            files={"inner.rs": "pub fn exported() {}\npub fn not_exported() {}\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        self.assertTrue(ap.exported_name(("inner",), "exported", reachable, bridged, globs))
        self.assertFalse(
            ap.exported_name(("inner",), "not_exported", reachable, bridged, globs)
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
        self.assertTrue(ap.exported_name(("inner",), "Exported", reachable, bridged, globs))
        self.assertFalse(
            ap.exported_name(("inner",), "NotExported", reachable, bridged, globs)
        )

    def test_glob_reexport_bridges_every_name(self) -> None:
        nodes = self.build(
            root_text="mod inner;\npub use inner::*;\n",
            files={"inner.rs": "pub fn a() {}\npub fn b() {}\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        self.assertIn(("inner",), globs)
        self.assertTrue(ap.exported_name(("inner",), "a", reachable, bridged, globs))
        self.assertTrue(ap.exported_name(("inner",), "b", reachable, bridged, globs))

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
            if ap.exported_name(("hex",), n, reachable, bridged, globs)
        }
        self.assertEqual({"Hex"}, reachable_types)
        items = ap.scan_inherent_impls(
            nodes[("extra",)], owner="Hex",
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
            ap.exported_name(("foo", "bar"), "Thing", reachable, bridged, globs)
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

    def test_alias_exports_under_the_alias_not_the_original_name(self) -> None:
        # Fix loop 3 finding 16: a declaration reachable only through an aliased re-export is
        # visible under the alias, not its own declared name — matching hexx's `Thing` against a
        # Cairo item found here by the *original* name `Thing` would misclassify it, since `Thing`
        # is not actually part of this tree's public API; only `Alias` is.
        nodes = self.build(
            root_text="mod inner;\npub use inner::Thing as Alias;\n",
            files={"inner.rs": "pub struct Thing;\n"},
        )
        reachable = ap.compute_reachable_modules(nodes)
        bridged, globs, used = ap.collect_use_statements(nodes, reachable)
        self.assertEqual("Alias", ap.exported_name(("inner",), "Thing", reachable, bridged, globs))
        self.assertIn("Alias", used)  # the alias is the identifier the rest of this file writes

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

    def test_super_prefixed_path_resolves_to_the_parent_module(self) -> None:
        # Fix loop 3 finding P2-4: `super::` used to fall through to the plain-relative case, so
        # `super::Thing` written in module `foo::bar` resolved to `foo::bar::super::Thing` — a
        # path that can never match a real declaration — instead of `foo::Thing`.
        entries: list = []
        globs: list = []
        ap.parse_use_tree("super::Thing", ("foo", "bar"), "test", entries, globs)
        self.assertEqual([(("foo",), "Thing", None)], entries)

    def test_double_super_walks_up_two_parent_modules(self) -> None:
        entries: list = []
        globs: list = []
        ap.parse_use_tree("super::super::Thing", ("foo", "bar", "baz"), "test", entries, globs)
        self.assertEqual([(("foo",), "Thing", None)], entries)

    def test_super_at_the_crate_root_raises(self) -> None:
        entries: list = []
        globs: list = []
        with self.assertRaises(SystemExit) as ctx:
            ap.parse_use_tree("super::Thing", (), "src/lib.rs:1", entries, globs)
        self.assertIn("src/lib.rs:1", str(ctx.exception))

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

    def test_target_arch_spirv_is_always_false(self) -> None:
        # `not(target_arch = "spirv")` gates hexx's own `Debug` impls; tools/refgen never builds
        # for a GPU shader target, so this is always true here.
        self.assertFalse(ap.evaluate_cfg('target_arch = "spirv"', "test"))
        self.assertTrue(ap.evaluate_cfg('not(target_arch = "spirv")', "test"))

    def test_unrecognized_target_arch_raises(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            ap.evaluate_cfg('target_arch = "wasm32"', "test")
        self.assertIn("wasm32", str(ctx.exception))

    def test_bevy_platform_feature_is_known_disabled(self) -> None:
        self.assertFalse(ap.evaluate_cfg('feature = "bevy_platform"', "test"))
        self.assertTrue(ap.evaluate_cfg('not(feature = "bevy_platform")', "test"))

    def test_disabled_cfg_declaration_error_names_a_line_not_only_a_file(self) -> None:
        # Fix loop 3 finding P2-4: every unsupported-form error must report `file:line`, not just
        # a file (`scan_declarations` on a struct's own `#[cfg(...)]`, one line down from a
        # padding line so line 1 would be a wrong-but-plausible answer if line tracking were off).
        node = node_of(
            'pub fn padding() {}\n#[cfg(feature = "unknown_future_feature")]\npub struct S;\n',
            "src/lib.rs",
        )
        with self.assertRaises(SystemExit) as ctx:
            ap.scan_declarations(node, "owner", lambda n: n, False)
        self.assertIn("src/lib.rs:3", str(ctx.exception))  # the struct's own line, not the cfg's

    def test_use_statement_cfg_error_names_the_line_it_is_on(self) -> None:
        node = node_of(
            "pub fn f() {}\n\n"  # lines 1-2: padding, so the use is not on line 1
            '#[cfg(feature = "unknown_future_feature")]\n'
            "pub use inner::Thing;\n",
            "src/lib.rs",
        )
        with self.assertRaises(SystemExit) as ctx:
            ap.collect_use_statements({(): node}, {()})
        self.assertIn("src/lib.rs:4", str(ctx.exception))


class PublicFieldsVariantsAndTraitMembers(unittest.TestCase):
    def test_struct_fields_are_items(self) -> None:
        node = node_of("pub struct Hex {\n    pub x: i32,\n    pub y: i32,\n}\n", "hex/mod.rs")
        items = ap.scan_declarations(node, "Hex", name_ok=lambda n: n, prefix=False)
        kinds_names = {(i.kind, i.name) for i in items}
        self.assertEqual({("struct", "Hex"), ("field", "x"), ("field", "y")}, kinds_names)

    def test_enum_variants_are_items(self) -> None:
        node = node_of("pub enum OffsetHexMode {\n    Even,\n    Odd,\n}\n", "conversions.rs")
        items = ap.scan_declarations(node, "conversions", lambda n: n, False)
        kinds_names = {(i.kind, i.name) for i in items}
        self.assertEqual(
            {("enum", "OffsetHexMode"), ("variant", "Even"), ("variant", "Odd")}, kinds_names
        )

    def test_attributed_default_variant_is_still_a_variant(self) -> None:
        node = node_of(
            "pub enum HexOrientation {\n    Pointy,\n    #[default]\n    Flat,\n}\n",
            "orientation.rs",
        )
        items = ap.scan_declarations(node, "HexOrientation", lambda n: n, False)
        names = {i.name for i in items if i.kind == "variant"}
        self.assertEqual({"Pointy", "Flat"}, names)

    def test_derived_default_is_an_impl_item(self) -> None:
        node = node_of(
            "#[derive(Debug, Copy, Clone, PartialEq, Eq, Hash, Default)]\n"
            "pub enum HexOrientation {\n    Pointy,\n    #[default]\n    Flat,\n}\n",
            "orientation.rs",
        )
        items = ap.scan_declarations(node, "HexOrientation", lambda n: n, False)
        self.assertIn(("HexOrientation", "impl", "Default"), {i.key for i in items})

    def test_derive_binds_to_the_immediately_following_declaration_only(self) -> None:
        # Fix loop 2 finding 15: a derive must not attach to a *different* type that merely sits
        # within the same lookback window.
        node = node_of("#[derive(Default)]\npub struct A;\npub struct B;\n", "shapes.rs")
        items = ap.scan_declarations(node, "shapes", lambda n: n, prefix=True)
        keys = {i.key for i in items}
        self.assertIn(("shapes", "impl", "Default for A"), keys)
        self.assertNotIn(("shapes", "impl", "Default for B"), keys)

    def test_derive_does_not_leak_across_an_intervening_declaration(self) -> None:
        # Same finding: even a *short* gap must not let a derive skip over another declaration.
        node = node_of("#[derive(Default)]\npub struct A;\n\npub struct B;\n", "shapes.rs")
        items = ap.scan_declarations(node, "shapes", lambda n: n, prefix=True)
        keys = {i.key for i in items}
        self.assertIn(("shapes", "impl", "Default for A"), keys)
        self.assertNotIn(("shapes", "impl", "Default for B"), keys)

    def test_private_tuple_field_is_not_a_public_field(self) -> None:
        node = node_of("pub struct EdgeDirection(pub(crate) u8);\n", "edge_direction.rs")
        items = ap.scan_declarations(node, "EdgeDirection", lambda n: n, False)
        self.assertEqual([("struct", "EdgeDirection")], [(i.kind, i.name) for i in items])

    def test_reexported_trait_is_scanned_with_its_members(self) -> None:
        node = node_of(
            "pub trait HexIterExt: Iterator {\n"
            "    fn average(&self) -> Hex;\n"
            "    fn center(&self) -> Hex;\n"
            "    fn bounds(&self) -> HexBounds;\n"
            "}\n",
            "hex/iter.rs",
        )
        items = ap.scan_trait_declarations(node, "HexSpanExt", lambda n: n, False)
        names = {(i.kind, i.name) for i in items}
        self.assertIn(("trait", "HexIterExt"), names)
        self.assertIn(("method", "average"), names)
        self.assertIn(("method", "center"), names)
        self.assertIn(("method", "bounds"), names)

    def test_declaration_with_a_disabled_cfg_is_skipped(self) -> None:
        # Fix loop 3 finding P2-4: cfg used to be evaluated for `mod` declarations only.
        node = node_of(
            '#[cfg(feature = "rayon")]\npub struct RayonOnly;\npub struct Kept;\n', "shapes.rs"
        )
        items = ap.scan_declarations(node, "shapes", lambda n: n, False)
        names = {i.name for i in items}
        self.assertNotIn("RayonOnly", names)
        self.assertIn("Kept", names)

    def test_use_statement_with_a_disabled_cfg_bridges_nothing(self) -> None:
        node = node_of(
            '#[cfg(feature = "rayon")]\npub use inner::Thing;\n', "shapes.rs"
        )
        bridged, _globs, used = ap.collect_use_statements({(): node}, {()})
        self.assertEqual({}, bridged)
        self.assertNotIn("Thing", used)

    def test_free_const_in_an_inline_module_is_found_despite_indentation(self) -> None:
        # Fix loop 2 finding 5: `direction::angles`'s own shape — indented because it sits inside
        # an inline `pub mod angles { ... }`, which the old column-0-anchored FREE_CONST_RE
        # rejected as if it were impl-block content.
        node = node_of(
            "    pub const DIRECTION_ANGLE_RAD: f32 = 1.0;\n"
            "    pub const DIRECTION_ANGLE_DEGREES: f32 = 60.0;\n",
            "direction/angles",
        )
        items = ap.scan_module(node, "EdgeDirection", lambda n: n, set(), False)
        names = {i.name for i in items if i.kind == "const"}
        self.assertEqual({"DIRECTION_ANGLE_RAD", "DIRECTION_ANGLE_DEGREES"}, names)

    def test_free_item_scan_does_not_double_count_an_impl_blocks_own_method(self) -> None:
        node = node_of(
            "pub fn free_fn() {}\n"
            "impl Hex {\n    pub fn method() {}\n}\n",
            "hex/mod.rs",
        )
        items = ap.scan_module(node, "Hex", lambda n: n, {"Hex"}, False)
        names = {i.name for i in items if i.kind == "method"}
        self.assertIn("free_fn", names)
        self.assertEqual(1, sum(1 for i in items if i.kind == "method" and i.name == "method"))


class MultiTypeOwnerScoping(unittest.TestCase):
    def test_same_named_methods_of_two_local_types_do_not_collapse(self) -> None:
        node = node_of(
            "pub struct A;\n"
            "pub struct B;\n"
            "impl A {\n    pub fn new() -> A { A }\n}\n"
            "impl B {\n    pub fn new() -> B { B }\n}\n",
            "shapes.rs",
        )
        items = ap.scan_declarations(node, "shapes", lambda n: n, prefix=True)
        reachable_types = {"A", "B"}
        items = list(items) + ap.scan_inherent_impls(node, "shapes", reachable_types, prefix=True)
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

    def test_report_only_never_fails_even_with_missing_items(self) -> None:
        # Fix loop 3 decision P2-13: a pre-release version (0.1.0-rc.N) carries only part of its
        # milestone (plan §9.1) — the gate is informational for it, not enforced.
        item = ap.Item("Hex", "struct", "Hex", "hex/mod.rs")
        self.assertIn(item.key, ap._L_M1)
        self.assertEqual(0, ap.check_release([item], [], "L-M1", report_only=True))

    def test_report_only_still_passes_when_nothing_is_missing(self) -> None:
        item = ap.Item("Hex", "struct", "Hex", "hex/mod.rs")
        self.assertEqual(0, ap.check_release([item], [item], "L-M1", report_only=True))

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

    def test_generate_trait_impl_produces_the_trait_item_too(self) -> None:
        # Fix loop 3 finding P2-14: `#[generate_trait]` synthesizes the trait from the impl; no
        # `pub trait HexMapTrait { ... }` text ever exists for `CAIRO_TRAIT_RE` to match.
        nodes, reachable, bridged, globs = self.build_cairo(
            root_text="pub mod board;\n",
            files={
                "board.cairo": "pub mod map;\n",
                "board/map.cairo": (
                    "#[derive(Copy, Drop)]\n"
                    "pub struct HexMap {\n    pub width: u8,\n}\n"
                    "#[generate_trait]\n"
                    "pub impl HexMapImpl of HexMapTrait {\n"
                    "    fn new(width: u8) -> HexMap { HexMap { width } }\n"
                    "}\n"
                ),
            },
        )

        def owner_of(path, name):
            return path[0] if path and path[0] == "board" else None

        items = ap.scan_cairo_tree(nodes, reachable, bridged, globs, owner_of)
        keys = {i.key for i in items}
        self.assertIn(("board", "trait", "HexMapTrait"), keys)
        self.assertIn(("board", "method", "HexMap.new"), keys)

    def test_plain_impl_of_without_generate_trait_does_not_synthesize_a_trait_item(self) -> None:
        # The trait item only comes from the impl when `#[generate_trait]` is actually there: a
        # plain `pub impl X of Y` implementing a trait declared *elsewhere* (unreachable here)
        # must not manufacture a phantom `Y` row.
        nodes, reachable, bridged, globs = self.build_cairo(
            root_text="pub mod board;\n",
            files={
                "board.cairo": "pub mod map;\n",
                "board/map.cairo": (
                    "pub impl HexMapImpl of HexMapTrait {\n"
                    "    fn new(width: u8) -> u8 { width }\n"
                    "}\n"
                ),
            },
        )

        def owner_of(path, name):
            return path[0] if path and path[0] == "board" else None

        items = ap.scan_cairo_tree(nodes, reachable, bridged, globs, owner_of)
        keys = {i.key for i in items}
        self.assertNotIn(("board", "trait", "HexMapTrait"), keys)
        self.assertIn(("board", "method", "HexMap.new"), keys)

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


class RealOrigamiTakeoverForm(FixtureTreeCase):
    """Fix loop 3 finding P2-14: `#[generate_trait] pub impl HexMapImpl of HexMapTrait { ... }`
    (`origami_hexmap::map`) is the exact Cairo form M1-T1 takes over (plan §2.2: `board/map.cairo`,
    `finders/bfs.cairo`, `generators/caver.cairo`). A real, unmodified copy of
    `sources/origami/crates/hexmap/src` — not a hand-written miniature of the form — placed under
    a fixture tree shaped like the plan must find every one of the 20 public functions of
    `docs/research/LIB-02-hexx-analysis.md` §2.1's own facade table, and `HexMapTrait` itself.
    Nothing else in the real file (the `#[feature("bounded-int-utils")]` internals, the private
    `bounded_int` helper impls, the inline `#[cfg(test)] mod tests { ... }`) raises: decision B's
    bar ("an unsupported form raises, you then support it") is met by construction here, not
    assumed. Skipped (not failed) where the checkout is unavailable: local-only, never in CI (see
    `sources/VERSIONS.md`, `.gitignore`), same as `RealCheckoutClassification` below."""

    ORIGAMI_SRC = (Path(__file__).resolve().parents[2] / "sources" / "origami" / "crates"
                   / "hexmap" / "src")

    # docs/research/LIB-02-hexx-analysis.md §2.1's own table, transcribed name for name.
    FACADE_FUNCTIONS = {
        "new", "new_empty", "new_maze", "new_cave", "new_random_walk", "new_hexagon",
        "open_with_corridor", "open_with_maze", "keep_component", "compute_distribution",
        "search_path", "search_path_weighted", "field_of_movement", "distance_to",
        "hex_distance", "reachable", "range", "ring", "neighbor", "is_walkable",
    }

    def test_generate_trait_form_is_fully_inventoried(self) -> None:
        if not (self.ORIGAMI_SRC / "map.cairo").is_file():
            self.skipTest(f"{self.ORIGAMI_SRC} not present (local-only checkout, see class "
                           f"docstring)")
        nodes = self.build(
            root_text="pub mod board;\npub mod finders;\npub mod generators;\n",
            files={
                "board.cairo": "pub mod map;\n",
                "board/map.cairo": (self.ORIGAMI_SRC / "map.cairo").read_text(),
                "finders.cairo": "pub mod bfs;\n",
                "finders/bfs.cairo": (self.ORIGAMI_SRC / "finders" / "bfs.cairo").read_text(),
                "generators.cairo": "pub mod caver;\n",
                "generators/caver.cairo":
                    (self.ORIGAMI_SRC / "generators" / "caver.cairo").read_text(),
            },
            root_name="lib.cairo",
        )
        reachable = ap.compute_reachable_modules(nodes, cfg_exempt=frozenset())
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)

        def owner_of(path, name):
            return path[0] if path and path[0] in ap.EXTENSION_MODULES else None

        items = ap.scan_cairo_tree(nodes, reachable, bridged, globs, owner_of)
        keys = {i.key for i in items}
        self.assertIn(("board", "trait", "HexMapTrait"), keys)
        found = {
            i.name.split(".", 1)[1] for i in items
            if i.owner == "board" and i.kind == "method" and i.name.startswith("HexMap.")
        }
        missing = self.FACADE_FUNCTIONS - found
        self.assertEqual(set(), missing, f"HexMapTrait functions not inventoried: {sorted(missing)}")


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


class TransitiveReexports(FixtureTreeCase):
    """LIB-04b finding *New 1*: a re-export resolved through a chain (a `pub use` of a `pub use`,
    through private modules), a glob in the chain, and one item exported under two names."""

    STRUCT = "pub struct Hex {\n    pub x: u8,\n}\n"

    def exported(self, root_text: str, files: dict[str, str], path=("inner",), name="Hex"):
        nodes = self.build(root_text, files, root_name="lib.cairo")
        reachable = ap.compute_reachable_modules(nodes, cfg_exempt=frozenset())
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)
        return ap.exported_names(path, name, reachable, bridged, globs), (
            nodes, reachable, bridged, globs)

    def scanned(self, tree) -> set[str]:
        nodes, reachable, bridged, globs = tree
        items = ap.scan_cairo_tree(nodes, reachable, bridged, globs,
                                   lambda path, name: "Hex")
        return {i.name for i in items if i.kind == "struct"}

    def test_chain_of_two_reexports_with_an_alias(self) -> None:
        # the auditor's scenario: `pub use middle::Hex as Other` over `pub use super::inner::Hex`
        names, tree = self.exported(
            "mod inner;\nmod middle;\npub use middle::Hex as Other;\n",
            {"inner.cairo": self.STRUCT, "middle.cairo": "pub use super::inner::Hex;\n"},
        )
        self.assertEqual(["Other"], names)
        self.assertEqual({"Other"}, self.scanned(tree))

    def test_chain_of_three_reexports(self) -> None:
        names, _ = self.exported(
            "mod inner;\nmod a;\nmod b;\npub use b::Hex as Far;\n",
            {"inner.cairo": self.STRUCT, "a.cairo": "pub use super::inner::Hex;\n",
             "b.cairo": "pub use super::a::Hex;\n"},
        )
        self.assertEqual(["Far"], names)

    def test_two_root_exports_of_one_item_keep_both_names(self) -> None:
        names, tree = self.exported(
            "mod inner;\npub use inner::Hex;\npub use inner::Hex as Other;\n",
            {"inner.cairo": self.STRUCT},
        )
        self.assertEqual(["Hex", "Other"], names)
        self.assertEqual({"Hex", "Other"}, self.scanned(tree))

    def test_reachable_module_reexported_under_an_alias_keeps_its_own_name_too(self) -> None:
        names, _ = self.exported(
            "pub mod inner;\npub use inner::Hex as Other;\n", {"inner.cairo": self.STRUCT})
        self.assertEqual(["Hex", "Other"], names)

    def test_glob_in_the_chain(self) -> None:
        names, _ = self.exported(
            "mod inner;\nmod middle;\npub use middle::Hex as Other;\n",
            {"inner.cairo": self.STRUCT, "middle.cairo": "pub use super::inner::*;\n"},
        )
        self.assertEqual(["Other"], names)

    def test_glob_over_a_module_that_holds_a_named_reexport(self) -> None:
        names, _ = self.exported(
            "mod inner;\nmod middle;\npub use middle::*;\n",
            {"inner.cairo": self.STRUCT, "middle.cairo": "pub use super::inner::Hex as Renamed;\n"},
        )
        self.assertEqual(["Renamed"], names)

    def test_glob_chain_exports_the_declaration_under_its_own_name(self) -> None:
        names, _ = self.exported(
            "mod inner;\nmod middle;\npub use middle::*;\n",
            {"inner.cairo": self.STRUCT, "middle.cairo": "pub use super::inner::*;\n"},
        )
        self.assertEqual(["Hex"], names)

    def test_cycle_of_globs_is_legal_and_terminates(self) -> None:
        names, _ = self.exported(
            "mod inner;\nmod a;\nmod b;\npub use a::Hex;\n",
            {"inner.cairo": self.STRUCT, "a.cairo": "pub use super::b::*;\npub use super::inner::*;\n",
             "b.cairo": "pub use super::a::*;\n"},
        )
        self.assertEqual(["Hex"], names)

    def test_cycle_of_named_reexports_raises_with_file_and_line(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            self.exported(
                "mod a;\nmod b;\npub use a::X;\n",
                {"a.cairo": "pub use super::b::X;\n", "b.cairo": "pub use super::a::X;\n"},
            )
        self.assertRegex(str(ctx.exception), r"\.cairo:\d+.*cycle of re-exports")

    def test_reexport_of_a_module_raises_with_file_and_line(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            self.exported("mod inner;\npub use inner as other;\n", {"inner.cairo": self.STRUCT})
        self.assertRegex(str(ctx.exception), r"lib\.cairo:2.*re-exporting a module")

    def test_private_use_does_not_extend_the_chain(self) -> None:
        names, _ = self.exported(
            "mod inner;\nmod middle;\npub use middle::Hex;\n",
            {"inner.cairo": self.STRUCT, "middle.cairo": "use super::inner::Hex;\n"},
        )
        self.assertEqual([], names)


class UseStatementForms(FixtureTreeCase):
    """LIB-04b follow-up 1: the four defects listed in the first report."""

    STRUCT = "pub struct Hex {\n    pub x: u8,\n}\n"

    def collect(self, root_text: str, files: dict[str, str]):
        nodes = self.build(root_text, files, root_name="lib.cairo")
        reachable = ap.compute_reachable_modules(nodes, cfg_exempt=frozenset())
        bridged, globs, used = ap.collect_use_statements(nodes, reachable)
        return nodes, reachable, bridged, globs, used

    def test_restricted_visibility_use_is_recognised_and_never_bridges(self) -> None:
        for vis in ("pub(super)", "pub(crate)", "pub(in crate::inner)", "pub (super)"):
            with self.subTest(vis=vis):
                _n, reachable, bridged, globs, used = self.collect(
                    f"pub mod inner;\n{vis} use inner::Hex as Seen;\n",
                    {"inner.cairo": self.STRUCT})
                self.assertIn("Seen", used)  # was silently skipped for `pub(super)`
                self.assertEqual(["Hex"], ap.exported_names(("inner",), "Hex", reachable, bridged,
                                                            globs))

    def test_use_not_at_the_start_of_a_line_is_seen(self) -> None:
        _n, reachable, bridged, globs, used = self.collect(
            "mod inner;\npub mod api { pub use super::inner::Hex as Shown; }\n"
            "pub fn f() {} pub use inner::Hex as Same;\n",
            {"inner.cairo": self.STRUCT})
        self.assertEqual(["Same", "Shown"],
                         ap.exported_names(("inner",), "Hex", reachable, bridged, globs))
        self.assertLessEqual({"Shown", "Same"}, used)

    def test_use_in_an_inline_module_is_attributed_to_that_module(self) -> None:
        # a private inline module's `pub use` cannot bridge; the same one in a `pub mod` does.
        _n, reachable, bridged, globs, _u = self.collect(
            "mod inner;\nmod hidden {\n    pub use super::inner::Hex as Hidden;\n}\n"
            "pub mod shown {\n    pub use super::inner::Hex as Shown;\n}\n",
            {"inner.cairo": self.STRUCT})
        self.assertEqual(["Shown"],
                         ap.exported_names(("inner",), "Hex", reachable, bridged, globs))

    def test_alias_of_a_type_with_members_raises_with_file_and_line(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            nodes = self.build(
                "mod inner;\npub use inner::Hex as Other;\n",
                {"inner.cairo": self.STRUCT + "pub trait HexTrait {\n    fn f(self: Hex);\n}\n"},
                root_name="lib.cairo")
            reachable = ap.compute_reachable_modules(nodes, cfg_exempt=frozenset())
            bridged, globs, _u = ap.collect_use_statements(nodes, reachable)
            ap.reject_scoped_aliases(nodes, reachable, bridged, globs, cairo=True)
        self.assertRegex(str(ctx.exception), r"inner\.cairo:1.*Hex.*associated items")

    def test_alias_of_a_rust_type_with_an_impl_raises_but_not_without(self) -> None:
        def tree(text: str):
            nodes = self.build("mod inner;\npub use inner::Hex as Other;\n", {"inner.rs": text})
            reachable = ap.compute_reachable_modules(nodes)
            bridged, globs, _u = ap.collect_use_statements(nodes, reachable)
            ap.reject_scoped_aliases(nodes, reachable, bridged, globs, cairo=False)

        tree("pub struct Hex {\n    pub x: i32,\n}\n")  # no members: supported
        with self.assertRaises(SystemExit) as ctx:
            tree("pub struct Hex {\n    pub x: i32,\n}\nimpl Hex {\n    pub fn new() {}\n}\n")
        self.assertIn("inner.rs:1", str(ctx.exception))


class VersionIsPrerelease(unittest.TestCase):
    """LIB-04b finding *New 2*: a pre-release iff the part before any `+` holds a hyphen."""

    def test_versions(self) -> None:
        for version, expected in [
            ("0.1.0", False), ("0.1.0-rc.1", True), ("0.1.0+build-1", False),
            ("1.0.0-rc.1+build-1", True), ("1.0.0+a-b", False), ("1.0.0-", True),
            ("1.0.0+", False), ("1.0.0-rc.1", True),
        ]:
            with self.subTest(version=version):
                self.assertEqual(expected, ap.is_prerelease(version))

    def test_cli_refuses_an_invalid_version(self) -> None:
        for version in ("1.0.0-", "1.0", "v1.0.0", ""):
            with self.subTest(version=version), mock.patch.object(
                sys, "argv", ["api_parity.py", "--is-prerelease", version]
            ):
                with self.assertRaises(SystemExit) as ctx:
                    ap.main()
                self.assertIn("not valid semver", str(ctx.exception))

    def test_cli_prints_true_or_false(self) -> None:
        for version, expected in [("0.1.0+build-1", "false"), ("0.1.0-rc.1", "true")]:
            with self.subTest(version=version), mock.patch.object(
                sys, "argv", ["api_parity.py", "--is-prerelease", version]
            ), mock.patch("builtins.print") as printed:
                self.assertEqual(0, ap.main())
                printed.assert_called_once_with(expected)


class ReleaseReportIsComplete(unittest.TestCase):
    """LIB-04b finding *P2-13*: the whole missing-item list, on the stream the workflow captures."""

    def items(self, count: int) -> list[ap.Item]:
        return [ap.Item("Hex", "method", f"m{i}", "hex/mod.rs") for i in range(count)]

    def run_report(self, report_only: bool):
        import io
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(ap, "milestone_of", return_value="L-M1"), \
                mock.patch.object(ap, "classify",
                                  side_effect=lambda h, c: ({i: ("missing", "") for i in h}, [])), \
                mock.patch.object(sys, "stdout", out), mock.patch.object(sys, "stderr", err):
            code = ap.check_release(self.items(66), [], "L-M1", report_only=report_only)
        return code, out.getvalue(), err.getvalue()

    def test_report_only_prints_all_items_to_stdout(self) -> None:
        code, out, err = self.run_report(report_only=True)
        self.assertEqual(0, code)
        self.assertEqual("", err)
        self.assertEqual(67, len(out.splitlines()))  # heading + 66 items
        self.assertIn("Hex::m65", out)

    def test_enforced_failure_lists_all_items_too(self) -> None:
        code, out, err = self.run_report(report_only=False)
        self.assertEqual(1, code)
        self.assertEqual("", out)
        self.assertEqual(67, len(err.splitlines()))


class CairoImplItemsAndConversionsOwner(FixtureTreeCase):
    """M1-T2 follow-up 1: the Cairo side sees `impl` items (a derived `Default`, a corelib impl
    such as `Not`, `Into<A, B>` as Rust's `From<A> for B`), and the module `conversions` is an
    owner with bare member names. An impl it cannot name raises with file and line."""

    def scan(self, files: dict[str, str], root_text: str = "pub mod orientation;\n"):
        nodes = self.build(root_text, files, root_name="lib.cairo")
        reachable = ap.compute_reachable_modules(nodes, cfg_exempt=frozenset())
        bridged, globs, _used = ap.collect_use_statements(nodes, reachable)

        def owner_of(path, name):
            if path in ap.CAIRO_MODULE_OWNER:
                return ap.CAIRO_MODULE_OWNER[path]
            return name if name in ap.OWNERS else None

        return ap.scan_cairo_tree(nodes, reachable, bridged, globs, owner_of,
                                  bare_owners=frozenset(ap.CAIRO_MODULE_OWNER.values()))

    ORIENTATION = (
        "#[derive(Copy, Drop, Default)]\n"
        "pub enum HexOrientation {\n    Pointy,\n    #[default]\n    Flat,\n}\n"
        "pub impl HexOrientationNot of Not<HexOrientation> {\n"
        "    fn not(a: HexOrientation) -> HexOrientation { a }\n}\n"
    )

    def test_derived_default_and_not_are_impl_items(self) -> None:
        keys = {i.key for i in self.scan({"orientation.cairo": self.ORIENTATION})}
        self.assertIn(("HexOrientation", "impl", "Default"), keys)
        self.assertIn(("HexOrientation", "impl", "Not"), keys)
        self.assertIn(("HexOrientation", "variant", "Flat"), keys)

    def test_a_type_that_does_not_derive_default_has_no_default_item(self) -> None:
        text = "#[derive(Copy, Drop)]\npub enum HexOrientation {\n    Pointy,\n    Flat,\n}\n"
        keys = {i.key for i in self.scan({"orientation.cairo": text})}
        self.assertNotIn(("HexOrientation", "impl", "Default"), keys)

    def test_into_is_from_for_the_target(self) -> None:
        text = ("pub struct EdgeDirection {\n    index: u8,\n}\n"
                "pub impl EdgeDirectionIntoHex of Into<EdgeDirection, Hex> {\n"
                "    fn into(self: EdgeDirection) -> Hex { Hex {} }\n}\n")
        keys = {i.key for i in self.scan({"orientation.cairo": text})}
        self.assertIn(("EdgeDirection", "impl", "From<EdgeDirection> for Hex"), keys)

    def test_binary_operator_impl_carries_the_operand(self) -> None:
        text = ("pub struct Hex {\n    pub x: i32,\n}\n"
                "pub impl HexAdd of Add<Hex> {\n    fn add(lhs: Hex, rhs: Hex) -> Hex { lhs }\n}\n")
        keys = {i.key for i in self.scan({"orientation.cairo": text})}
        self.assertIn(("Hex", "impl", "Add<Hex>"), keys)

    def test_an_impl_of_an_unknown_trait_on_a_mirror_owner_raises_with_file_and_line(self) -> None:
        text = ("pub struct Hex {\n    pub x: i32,\n}\n"
                "pub impl HexFoo of Foo<Hex> {\n    fn foo(a: Hex) -> Hex { a }\n}\n")
        with self.assertRaises(SystemExit) as raised:
            self.scan({"orientation.cairo": text})
        self.assertIn("orientation.cairo:4", str(raised.exception))
        self.assertIn("Foo", str(raised.exception))

    def test_an_impl_on_a_foreign_type_is_not_a_mirror_item(self) -> None:
        text = ("pub impl DirectionIntoU8 of Into<Direction, u8> {\n"
                "    fn into(self: Direction) -> u8 { 0 }\n}\n")
        self.assertEqual([], [i for i in self.scan({"orientation.cairo": text})
                              if i.kind == "impl"])

    def test_conversions_module_is_an_owner_with_bare_names(self) -> None:
        text = ("pub enum OffsetHexMode {\n    Even,\n    Odd,\n}\n"
                "#[generate_trait]\n"
                "pub impl HexConversionsImpl of HexConversionsTrait {\n"
                "    fn to_offset_coordinates(self: Hex) -> i32 { 0 }\n"
                "    fn from_offset_coordinates(o: i32) -> Hex { Hex {} }\n}\n")
        keys = {i.key for i in self.scan({"conversions.cairo": text},
                                         root_text="pub mod conversions;\n")}
        for key in (("conversions", "enum", "OffsetHexMode"), ("conversions", "variant", "Even"),
                    ("conversions", "variant", "Odd"),
                    ("conversions", "method", "to_offset_coordinates"),
                    ("conversions", "method", "from_offset_coordinates")):
            self.assertIn(key, keys)

    def test_a_public_impl_of_an_undeclared_trait_on_a_mirror_owner_raises(self) -> None:
        # The auditor's scenario (M1-T2 audit pass 1, finding 1): `...Trait` is not a licence to
        # skip; nothing declares or generates `CustomTrait`.
        text = ("#[derive(Copy, Drop)]\npub enum HexOrientation {\n    Pointy,\n    Flat,\n}\n"
                "pub impl FooImpl of CustomTrait<HexOrientation> {\n"
                "    fn foo(a: HexOrientation) -> HexOrientation { a }\n}\n")
        with self.assertRaises(SystemExit) as raised:
            self.scan({"orientation.cairo": text})
        self.assertIn("orientation.cairo:6", str(raised.exception))
        self.assertIn("CustomTrait", str(raised.exception))

    def test_a_public_impl_of_a_declared_or_generated_trait_is_not_an_error(self) -> None:
        text = ("pub struct Hex {\n    pub x: i32,\n}\n"
                "pub trait DeclaredTrait<T> {\n    fn a(v: T) -> T;\n}\n"
                "pub impl DeclaredImpl of DeclaredTrait<Hex> {\n    fn a(v: Hex) -> Hex { v }\n}\n"
                "#[generate_trait]\n"
                "pub impl HexImpl of HexTrait {\n    fn b(self: Hex) -> i32 { 0 }\n}\n"
                "pub impl HexOther of HexTrait {\n    fn b(self: Hex) -> i32 { 1 }\n}\n")
        keys = {i.key for i in self.scan({"orientation.cairo": text})}
        self.assertIn(("Hex", "method", "b"), keys)


class CairoModuleOwnersOfL_M2(FixtureTreeCase):
    """M2-T0: the Cairo modules of L-M2 attribute every public declaration to their owner, so a
    trait whose name minus `Trait` is not an owner (`HexRingsTrait`) and a free function (`hex`,
    `shapes::*`) count for it."""

    scan = CairoImplItemsAndConversionsOwner.scan

    def scan_module(self, path: tuple[str, ...], text: str):
        """The items of one module file `path` of a fixture tree that declares exactly it."""
        files = {"/".join(path) + ".cairo": text}
        parents = [path[:i] for i in range(1, len(path))]
        root = "".join(f"pub mod {p[0]};\n" for p in parents[:1]) or f"pub mod {path[0]};\n"
        for depth, parent in enumerate(parents):
            files["/".join(parent) + ".cairo"] = f"pub mod {path[depth + 1]};\n"
        return self.scan(files, root_text=root)

    def test_every_l_m2_module_has_its_owner(self) -> None:
        expected = {
            ("hex",): "Hex", ("hex", "impls"): "Hex", ("hex", "rings"): "Hex",
            ("hex", "swizzle"): "Hex", ("hex", "euclidean"): "Hex", ("hex", "convert"): "Hex",
            ("hex", "iter"): "HexSpanExt", ("hex", "grid", "edge"): "GridEdge",
            ("hex", "grid", "vertex"): "GridVertex", ("bounds",): "HexBounds",
            ("shapes",): "shapes",
        }
        for path, owner in expected.items():
            self.assertEqual(owner, ap.CAIRO_MODULE_OWNER[path], path)
            self.assertIn(owner, ap.OWNERS)

    def test_a_trait_of_hex_rings_counts_for_hex(self) -> None:
        text = ("#[generate_trait]\npub impl HexRingsImpl of HexRingsTrait {\n"
                "    fn ring_count(range: u32) -> u32 { range }\n}\n")
        keys = {i.key for i in self.scan_module(("hex", "rings"), text)}
        self.assertIn(("Hex", "trait", "HexRingsTrait"), keys)
        self.assertIn(("Hex", "method", "ring_count"), keys)

    def test_the_free_function_hex_counts_for_hex(self) -> None:
        text = "pub fn hex(x: i32, y: i32) -> Hex {\n    Hex { x, y }\n}\n"
        keys = {i.key for i in self.scan_module(("hex",), text)}
        self.assertIn(("Hex", "method", "hex"), keys)

    def test_hex_iter_counts_for_hex_span_ext(self) -> None:
        text = ("#[generate_trait]\npub impl HexSpanExtImpl of HexSpanExtTrait {\n"
                "    fn center(self: Span<Hex>) -> Hex { Hex {} }\n}\n")
        keys = {i.key for i in self.scan_module(("hex", "iter"), text)}
        self.assertIn(("HexSpanExt", "method", "center"), keys)

    def test_grid_edge_and_vertex_count_for_their_owners(self) -> None:
        text = ("#[generate_trait]\npub impl EdgeImpl of EdgeTrait {\n"
                "    fn origin(self: GridEdge) -> Hex { Hex {} }\n}\n")
        keys = {i.key for i in self.scan_module(("hex", "grid", "edge"), text)}
        self.assertIn(("GridEdge", "method", "origin"), keys)
        keys = {i.key for i in self.scan_module(("hex", "grid", "vertex"), text)}
        self.assertIn(("GridVertex", "method", "origin"), keys)

    def test_bounds_and_shapes_count_for_their_owners(self) -> None:
        text = ("#[generate_trait]\npub impl BoundsImpl of BoundsTrait {\n"
                "    fn center(self: HexBounds) -> Hex { Hex {} }\n}\n")
        keys = {i.key for i in self.scan_module(("bounds",), text)}
        self.assertIn(("HexBounds", "method", "center"), keys)
        text = "pub fn hexagon(center: Hex, radius: u32) -> u32 {\n    radius\n}\n"
        keys = {i.key for i in self.scan_module(("shapes",), text)}
        self.assertIn(("shapes", "method", "hexagon"), keys)


class RulesOfL_M2(unittest.TestCase):
    """M2-T0: the three rows the generated table moves with a rule (plan §4.4)."""

    def status(self, item: "ap.Item", cairo: list["ap.Item"] | None = None):
        statuses, _ = ap.classify([item], cairo or [])
        return statuses[item]

    def test_hex_shl_is_dropped_like_the_other_shifts(self) -> None:
        status, reason = self.status(ap.Item("Hex", "impl", "Shl", "src/hex/impls.rs"))
        self.assertEqual("dropped", status)
        self.assertIn("no shifts", reason)

    def test_hex_shl_with_a_parameter_is_still_dropped_by_its_own_rule(self) -> None:
        status, reason = self.status(ap.Item("Hex", "impl", "Shl<u8>", "src/hex/impls.rs"))
        self.assertEqual("dropped", status)
        self.assertIn("no shifts", reason)

    def test_hex_lerp_is_dropped_for_its_f32_parameter(self) -> None:
        status, reason = self.status(ap.Item("Hex", "method", "lerp", "src/hex/mod.rs"))
        self.assertEqual("dropped", status)
        self.assertIn("f32", reason)

    def test_direction_way_partial_eq_is_renamed_once_contains_exists(self) -> None:
        item = ap.Item("DirectionWay", "impl", "PartialEq<T>", "src/direction/way.rs")
        self.assertEqual("missing", self.status(item)[0])
        contains = ap.Item("DirectionWay", "method", "contains", "crates/hexx/src/direction/way.cairo")
        status, reason = self.status(item, [contains])
        self.assertEqual("renamed", status)
        self.assertIn("nothing to add", reason)


class RealTreeMirrorOfL_M1(unittest.TestCase):
    """The real `crates/hexx/src` against the committed inventory: after M1-T6 no item of the
    canonical L-M1 list is missing."""

    def test_no_item_of_l_m1_is_missing(self) -> None:
        hexx = ap.load_inventory(ap.OUTPUT)
        statuses, _ = ap.classify(hexx, ap.parse_cairo())
        missing = {i.key for i, (status, _) in statuses.items()
                   if status == "missing" and i.key in ap._L_M1}
        self.assertEqual(set(), missing)


if __name__ == "__main__":
    unittest.main()
