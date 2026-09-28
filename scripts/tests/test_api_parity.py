#!/usr/bin/env python3
"""Unit tests of scripts/api_parity.py (AC-3): effective visibility, re-exports, public fields
and variants, public trait members, and the precedence of COUNTERPARTS over the exclusion rules.

Run: python3 -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import api_parity as ap  # noqa: E402


class EffectiveVisibilityAndReexports(unittest.TestCase):
    """plan §4.2: a `pub` item in a private (or `pub(crate)`) module is not part of the public
    API unless a `pub use` re-export bridges it — the mechanism `PRIVATE_MODULES` and
    `scan_trait` implement for `hex::iter` (`HexIterExt` re-exported, `ExactSizeHexIterator`
    is not) and `direction::way` (`DirectionWay` re-exported, `Way` is not)."""

    SNIPPET = """
        pub trait HexIterExt: Iterator {
            fn average(&self) -> Hex;
            fn center(&self) -> Hex;
            fn bounds(&self) -> HexBounds;
        }

        impl<I: Iterator<Item = Hex>> HexIterExt for I {}

        pub struct ExactSizeHexIterator<I> {
            iter: I,
        }

        impl<I> ExactSizeIterator for ExactSizeHexIterator<I> where I: Iterator {}
    """

    def test_reexported_trait_is_scanned_with_its_members(self) -> None:
        text = ap.mask_comments(self.SNIPPET)
        items = ap.scan_trait(text, "HexSpanExt", "hex/iter.rs", {"HexIterExt"})
        names = {(i.kind, i.name) for i in items}
        self.assertIn(("trait", "HexIterExt"), names)
        self.assertIn(("method", "average"), names)
        self.assertIn(("method", "center"), names)
        self.assertIn(("method", "bounds"), names)

    def test_non_reexported_item_of_the_same_private_module_is_not_scanned(self) -> None:
        text = ap.mask_comments(self.SNIPPET)
        # ExactSizeHexIterator is `pub` in the source but never named in a `pub use`: the
        # production PRIVATE_MODULES entry for hex/iter.rs only lists "HexIterExt", exactly
        # because it is the only re-exported name (src/hex/mod.rs: `pub use iter::HexIterExt;`
        # vs `pub(crate) use iter::ExactSizeHexIterator;`).
        items = ap.scan_trait(text, "HexSpanExt", "hex/iter.rs", {"HexIterExt"})
        names = {i.name for i in items}
        self.assertNotIn("ExactSizeHexIterator", names)

    def test_directionway_reexported_way_trait_is_not(self) -> None:
        snippet = """
            pub enum DirectionWay<T> {
                Single(T),
                Tie([T; 2]),
            }

            pub trait Way: Copy {
                fn ccw(self) -> Self;
                fn cw(self) -> Self;
            }

            impl<T> DirectionWay<T> {
                pub fn unwrap(self) -> T { loop {} }
                pub fn contains(&self, dir: &T) -> bool { loop {} }
                pub fn map<U>(self, f: impl FnMut(T) -> U) -> DirectionWay<U> { loop {} }
            }

            impl Way for EdgeDirection {
                fn ccw(self) -> Self { self }
                fn cw(self) -> Self { self }
            }
        """
        text = ap.mask_comments(snippet)
        struct_items = ap.scan_struct_enum(text, "DirectionWay", "direction/way.rs", {"DirectionWay"})
        impl_items = ap.scan_impls_for_targets(text, "DirectionWay", "direction/way.rs", {"DirectionWay"})
        names = {i.name for i in struct_items + impl_items}
        self.assertIn("Single", names)
        self.assertIn("Tie", names)
        self.assertIn("unwrap", names)
        self.assertIn("contains", names)
        self.assertIn("map", names)
        # Way and its impl on EdgeDirection are in a `pub(crate) mod`, never re-exported: not
        # reachable from outside the crate, so not part of the public API.
        self.assertNotIn("ccw", names)
        self.assertNotIn("cw", names)


class PublicFieldsAndVariants(unittest.TestCase):
    def test_struct_fields_are_items(self) -> None:
        text = ap.mask_comments("pub struct Hex {\n    pub x: i32,\n    pub y: i32,\n}\n")
        items = ap.scan_struct_enum(text, "Hex", "hex/mod.rs", allowed=None)
        kinds_names = {(i.kind, i.name) for i in items}
        self.assertEqual({("struct", "Hex"), ("field", "x"), ("field", "y")}, kinds_names)

    def test_enum_variants_are_items(self) -> None:
        text = ap.mask_comments("pub enum OffsetHexMode {\n    Even,\n    Odd,\n}\n")
        items = ap.scan_struct_enum(text, "conversions", "conversions.rs", allowed=None)
        kinds_names = {(i.kind, i.name) for i in items}
        self.assertEqual(
            {("enum", "OffsetHexMode"), ("variant", "Even"), ("variant", "Odd")}, kinds_names
        )

    def test_private_tuple_field_is_not_a_public_field(self) -> None:
        # `pub struct EdgeDirection(pub(crate) u8);`: the field is pub(crate), not pub — the
        # regex `pub\s+(?!\()` must not match `pub(crate)`.
        text = ap.mask_comments("pub struct EdgeDirection(pub(crate) u8);\n")
        items = ap.scan_struct_enum(text, "EdgeDirection", "direction/edge_direction.rs", allowed=None)
        self.assertEqual([("struct", "EdgeDirection")], [(i.kind, i.name) for i in items])


class CounterpartsPrecedence(unittest.TestCase):
    """plan §4.2, audit finding 13: COUNTERPARTS wins over the broad RULES — the first version of
    the plan let a broad rule classify a counterpart's signature, hiding incomplete parity."""

    def test_counterparts_entry_wins_over_a_matching_exclusion_rule(self) -> None:
        item = ap.Item("algorithms", "method", "range_fov", "algorithms/fov.rs")
        fake_rule = ap.rule("algorithms", r"method:range_fov", "dropped",
                             "test: would wrongly exclude range_fov as if it took a callback")
        fake_counterparts = {item.key: ("ported", "range_fov", "test: real counterpart detail")}
        with mock.patch.object(ap, "RULES", (fake_rule,)), \
             mock.patch.object(ap, "COUNTERPARTS", fake_counterparts):
            statuses, _ = ap.classify([item], [])
        status, detail = statuses[item]
        self.assertEqual("ported", status)
        self.assertIn("real counterpart detail", detail)

    def test_without_a_counterparts_entry_the_rule_applies(self) -> None:
        item = ap.Item("algorithms", "method", "range_fov", "algorithms/fov.rs")
        fake_rule = ap.rule("algorithms", r"method:range_fov", "dropped", "test reason")
        with mock.patch.object(ap, "RULES", (fake_rule,)), mock.patch.object(ap, "COUNTERPARTS", {}):
            statuses, _ = ap.classify([item], [])
        self.assertEqual(("dropped", "test reason"), statuses[item])


class ScheduledReleaseCheck(unittest.TestCase):
    """AC-3: "an item scheduled for a release and absent fails the check of that release"."""

    def test_missing_item_scheduled_at_or_before_the_release_fails(self) -> None:
        item = ap.Item("Hex", "struct", "Hex", "hex/mod.rs")
        self.assertIn(item.key, ap._L_M1)
        code = ap.check_release([item], [], "L-M1")
        self.assertEqual(1, code)

    def test_present_item_passes(self) -> None:
        item = ap.Item("Hex", "struct", "Hex", "hex/mod.rs")
        code = ap.check_release([item], [item], "L-M1")
        self.assertEqual(0, code)

    def test_item_scheduled_after_the_release_does_not_block_it(self) -> None:
        # Any L-M2-tagged item (not in _L_M1) on an owner other than "algorithms" (L-M3): still
        # missing, but not due until L-M2, so an L-M1 check must not fail on it.
        item = ap.Item("Hex", "method", "range", "hex/mod.rs")
        self.assertNotIn(item.key, ap._L_M1)
        code = ap.check_release([item], [], "L-M1")
        self.assertEqual(0, code)


if __name__ == "__main__":
    unittest.main()
