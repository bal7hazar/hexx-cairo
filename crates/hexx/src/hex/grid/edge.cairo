//! `hex/grid/edge`: `GridEdge`, an edge of the grid given by a hex and an edge direction (`hexx`'s
//! `src/hex/grid/edge.rs`), with `Hex::all_edges`.
//!
//! An edge has two forms, one per hex it separates: `GridEdge { origin: a, direction: d }` and its
//! `flipped()` `GridEdge { origin: a + d, direction: -d }` are the same edge, which `equivalent`
//! says. The compass of the directions is `hexx`'s, verbatim (see `EdgeDirection`).

use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::hex::grid::vertex::GridVertex;
use crate::hex::{Hex, HexTrait};

/// An edge of the hexagonal grid: the hex it starts from and the direction it points towards.
///
/// Mirrors `hexx::GridEdge` (`src/hex/grid/edge.rs:12`).
///
/// #### Panics
///
/// None: the type only holds its two fields.
///
/// #### Deviations
///
/// `Debug` is derived: it prints `GridEdge { origin: Hex { x: 1, y: 2, z: -3 }, direction:
/// EdgeDirection { index: 0, x: 1, y: 0, z: -1 } }`, as `hexx`'s derived `Debug` does. `Hash` and
/// `Serde` are derived as a matter of course (plan §2.3): `Serde` reads the direction through the
/// `Serde` of `EdgeDirection`, which refuses an index above 5. `Default` is not derived, as in
/// `hexx`.
#[derive(Copy, Drop, PartialEq, Debug, Serde, Hash)]
pub struct GridEdge {
    /// The coordinate of the edge.
    pub origin: Hex,
    /// The direction the edge points towards.
    pub direction: EdgeDirection,
}

/// The methods of `impl GridEdge`.
pub trait GridEdgeTrait {
    /// Whether `self` and `other` are the same edge: identical, or one the flipped form of the
    /// other (same origin and direction, or the origin of one is the destination of the other with
    /// the opposite direction).
    ///
    /// Mirrors `GridEdge::equivalent` (`src/hex/grid/edge.rs:23`).
    ///
    /// #### Panics
    ///
    /// When `other.destination()` leaves `i32`, which `hexx` does in a debug build (the second
    /// clause is only evaluated when the first is false).
    ///
    /// #### Deviations
    ///
    /// Takes both edges by value (`GridEdge` is `Copy`), not by reference.
    fn equivalent(self: GridEdge, other: GridEdge) -> bool;

    /// The hex the edge points to: `origin + direction`.
    ///
    /// Mirrors `GridEdge::destination` (`src/hex/grid/edge.rs:31`).
    ///
    /// #### Panics
    ///
    /// When a component of the destination leaves `i32` (`Hex::add_dir`); `hexx` wraps in a
    /// release build and panics in a debug build.
    ///
    /// #### Deviations
    ///
    /// Takes `self` by value, not by reference. Cairo has no `const fn`.
    fn destination(self: GridEdge) -> Hex;

    /// The two vertices making the edge, in clockwise order: the `vertex_ccw` of the direction
    /// first, then its `vertex_cw`, both on the origin.
    ///
    /// Mirrors `GridEdge::vertices` (`src/hex/grid/edge.rs:38`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Takes `self` by value, not by reference. Cairo has no `const fn`.
    fn vertices(self: GridEdge) -> [GridVertex; 2];

    /// The same edge seen from the other hex: the origin becomes the destination and the direction
    /// is inverted.
    ///
    /// Mirrors `GridEdge::flipped` (`src/hex/grid/edge.rs:55`).
    ///
    /// #### Panics
    ///
    /// When the destination leaves `i32` (`destination`).
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn flipped(self: GridEdge) -> GridEdge;

    /// The edge facing the opposite direction, on the same origin.
    ///
    /// Mirrors `GridEdge::const_neg` (`src/hex/grid/edge.rs:65`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`; this is the plain function behind the `-` operator.
    fn const_neg(self: GridEdge) -> GridEdge;

    /// The next edge in clockwise order, on the same origin.
    ///
    /// Mirrors `GridEdge::clockwise` (`src/hex/grid/edge.rs:75`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn clockwise(self: GridEdge) -> GridEdge;

    /// The next edge in counter-clockwise order, on the same origin.
    ///
    /// Mirrors `GridEdge::counter_clockwise` (`src/hex/grid/edge.rs:85`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn counter_clockwise(self: GridEdge) -> GridEdge;

    /// Rotates the edge clockwise by `offset` steps of 60 degrees (`EdgeDirection::rotate_cw`).
    ///
    /// Mirrors `GridEdge::rotate_cw` (`src/hex/grid/edge.rs:95`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn rotate_cw(self: GridEdge, offset: u8) -> GridEdge;

    /// Rotates the edge counter-clockwise by `offset` steps of 60 degrees
    /// (`EdgeDirection::rotate_ccw`).
    ///
    /// Mirrors `GridEdge::rotate_ccw` (`src/hex/grid/edge.rs:104`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn rotate_ccw(self: GridEdge, offset: u8) -> GridEdge;
}

pub impl GridEdgeImpl of GridEdgeTrait {
    fn equivalent(self: GridEdge, other: GridEdge) -> bool {
        (self.origin == other.origin && self.direction == other.direction)
            || (self.origin == other.destination() && self.direction == other.direction.const_neg())
    }

    #[inline]
    fn destination(self: GridEdge) -> Hex {
        self.origin.add_dir(self.direction)
    }

    #[inline]
    fn vertices(self: GridEdge) -> [GridVertex; 2] {
        [
            GridVertex { origin: self.origin, direction: self.direction.vertex_ccw() },
            GridVertex { origin: self.origin, direction: self.direction.vertex_cw() },
        ]
    }

    #[inline]
    fn flipped(self: GridEdge) -> GridEdge {
        GridEdge { origin: self.destination(), direction: self.direction.const_neg() }
    }

    #[inline]
    fn const_neg(self: GridEdge) -> GridEdge {
        GridEdge { origin: self.origin, direction: self.direction.const_neg() }
    }

    #[inline]
    fn clockwise(self: GridEdge) -> GridEdge {
        GridEdge { origin: self.origin, direction: self.direction.clockwise() }
    }

    #[inline]
    fn counter_clockwise(self: GridEdge) -> GridEdge {
        GridEdge { origin: self.origin, direction: self.direction.counter_clockwise() }
    }

    #[inline]
    fn rotate_cw(self: GridEdge, offset: u8) -> GridEdge {
        GridEdge { origin: self.origin, direction: self.direction.rotate_cw(offset) }
    }

    #[inline]
    fn rotate_ccw(self: GridEdge, offset: u8) -> GridEdge {
        GridEdge { origin: self.origin, direction: self.direction.rotate_ccw(offset) }
    }
}

/// The edge opposite to `self`, as the `-` operator.
///
/// Mirrors `impl Neg for GridEdge` (`src/hex/grid/edge.rs:124`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The operator is a trait impl that Cairo resolves from the scope: a consumer imports
/// `GridEdgeNeg` (`use hexx::hex::grid::edge::GridEdgeNeg;`) to write `-edge`.
pub impl GridEdgeNeg of Neg<GridEdge> {
    #[inline]
    fn neg(a: GridEdge) -> GridEdge {
        a.const_neg()
    }
}

/// The edge of the origin hex `ZERO` pointing towards `direction`.
///
/// Mirrors `impl From<EdgeDirection> for GridEdge` (`src/hex/grid/edge.rs:133`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The impl is `Into`, not `From`: Cairo's `From` does not exist in the corelib, `Into` is the
/// conversion trait.
pub impl GridEdgeFromEdgeDirection of Into<EdgeDirection, GridEdge> {
    #[inline]
    fn into(self: EdgeDirection) -> GridEdge {
        GridEdge { origin: HexTrait::ZERO, direction: self }
    }
}

/// The method `Hex::all_edges`, defined in `hex/grid/edge.rs` in `hexx` (an `impl Hex` block of
/// that file); a trait of this module here (D-143).
pub trait HexEdgesTrait {
    /// The six edges of the hex, in `EdgeDirection::ALL_DIRECTIONS` order.
    ///
    /// Mirrors `Hex::all_edges` (`src/hex/grid/edge.rs:116`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// `hexx` maps `ALL_DIRECTIONS` (`[T; 6]::map`); a fixed-size array has no `map` in Cairo, the
    /// six edges are written out.
    fn all_edges(self: Hex) -> [GridEdge; 6];
}

pub impl HexEdgesImpl of HexEdgesTrait {
    fn all_edges(self: Hex) -> [GridEdge; 6] {
        let [d0, d1, d2, d3, d4, d5] = EdgeDirectionTrait::ALL_DIRECTIONS;
        [
            GridEdge { origin: self, direction: d0 }, GridEdge { origin: self, direction: d1 },
            GridEdge { origin: self, direction: d2 }, GridEdge { origin: self, direction: d3 },
            GridEdge { origin: self, direction: d4 }, GridEdge { origin: self, direction: d5 },
        ]
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::direction::vertex_direction::VertexDirectionTrait;
    use crate::hex::grid::vertex::GridVertexTrait;
    use crate::hex::{Hex, HexTrait};
    use super::{GridEdge, GridEdgeNeg, GridEdgeTrait, HexEdgesTrait};

    /// The plain definitions the optimised methods are tested against.
    #[generate_trait]
    impl GridEdgeOracleImpl of GridEdgeOracleTrait {
        /// The hex and its six neighbours, the hex first.
        fn hexes_around(h: Hex) -> Array<Hex> {
            let [n0, n1, n2, n3, n4, n5] = h.all_neighbors();
            array![h, n0, n1, n2, n3, n4, n5]
        }

        /// The 6 x 7 edges that the hex and its six neighbours carry.
        fn edges_around(h: Hex) -> Array<GridEdge> {
            let mut edges = array![];
            let mut hexes = Self::hexes_around(h).span();
            while let Some(around) = hexes.pop_front() {
                let mut own = (*around).all_edges().span();
                while let Some(e) = own.pop_front() {
                    edges.append(*e);
                }
            }
            edges
        }

        /// The geometric definition of the equivalence: two edges are the same when they separate
        /// the same two hexes, `{origin, destination}` as a set.
        fn separate_the_same_hexes(a: GridEdge, b: GridEdge) -> bool {
            let (a0, a1) = (a.origin, a.origin.add_dir(a.direction));
            let (b0, b1) = (b.origin, b.origin.add_dir(b.direction));
            (a0 == b0 && a1 == b1) || (a0 == b1 && a1 == b0)
        }

        /// `equivalent` against the definition on every ordered pair of `edges_around(h)`;
        /// returns the number of equivalent pairs.
        fn check_equivalent_around(h: Hex) -> u32 {
            let edges = Self::edges_around(h);
            assert!(edges.len() == 42);
            let mut count: u32 = 0;
            let mut outer = edges.span();
            while let Some(a) = outer.pop_front() {
                let mut inner = edges.span();
                while let Some(b) = inner.pop_front() {
                    let expected = Self::separate_the_same_hexes(*a, *b);
                    assert!((*a).equivalent(*b) == expected);
                    if expected {
                        count += 1;
                    }
                }
            }
            count
        }
    }

    /// `equivalent` against its geometric definition on every pair of the 6 x 7 edges around the
    /// origin: 42 edges are equivalent to themselves, and 24 of them (the 6 spokes and the 18
    /// edges between two ring hexes or a ring hex and the centre, seen from both sides) have their
    /// flipped form among the 42 as well: 66 ordered pairs.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_equivalent_oracle_at_the_origin() {
        assert!(GridEdgeOracleTrait::check_equivalent_around(HexTrait::ZERO) == 66);
    }

    /// The same away from the origin, with negative and positive components.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_equivalent_oracle_elsewhere() {
        assert!(GridEdgeOracleTrait::check_equivalent_around(HexTrait::new(-7, 12)) == 66);
        assert!(GridEdgeOracleTrait::check_equivalent_around(HexTrait::new(30, -17)) == 66);
    }

    /// The flipped edge is the same edge, flipping twice gives the edge back, the destination of
    /// the flipped edge is the origin.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_flipped() {
        let mut edges = GridEdgeOracleTrait::edges_around(HexTrait::new(-4, 9)).span();
        while let Some(e) = edges.pop_front() {
            let e = *e;
            let f = e.flipped();
            assert!(f.destination() == e.origin);
            assert!(f.origin == e.destination());
            assert!(f.flipped() == e);
            assert!(e.equivalent(f) && f.equivalent(e));
            assert!(f == GridEdge { origin: e.destination(), direction: e.direction.const_neg() });
        }
    }

    /// `-edge` is `const_neg`, and negating twice gives the edge back, the origin is unchanged.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_neg() {
        let mut edges = HexTrait::new(2, 2).all_edges().span();
        while let Some(e) = edges.pop_front() {
            let e = *e;
            assert!(-e == e.const_neg());
            assert!(-(-e) == e);
            assert!((-e).origin == e.origin);
            assert!((-e).direction == e.direction.const_neg());
        }
    }

    /// The rotations by `offset` are `offset` steps of `clockwise` and `counter_clockwise`, on the
    /// same origin, for the offsets `0..=12` (more than two turns).
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_rotations_are_repeated_steps() {
        let mut edges = HexTrait::new(-3, 5).all_edges().span();
        while let Some(e) = edges.pop_front() {
            let e = *e;
            let mut cw = e;
            let mut ccw = e;
            let mut offset: u8 = 0;
            while offset <= 12 {
                assert!(e.rotate_cw(offset) == cw);
                assert!(e.rotate_ccw(offset) == ccw);
                assert!(cw.origin == e.origin && ccw.origin == e.origin);
                cw = cw.clockwise();
                ccw = ccw.counter_clockwise();
                offset += 1;
            }
            assert!(e.clockwise().counter_clockwise() == e);
        }
    }

    /// The two vertices of an edge are its two ends, in clockwise order: both on the origin, and
    /// the edge is a side of each: the clockwise side of the counter-clockwise vertex, the
    /// counter-clockwise side of the clockwise vertex.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_vertices_are_its_ends() {
        let mut edges = HexTrait::new(6, -1).all_edges().span();
        while let Some(e) = edges.pop_front() {
            let e = *e;
            let [ccw, cw] = e.vertices();
            assert!(ccw.origin == e.origin && cw.origin == e.origin);
            let [_, side_cw] = ccw.side_edges();
            let [side_ccw, _] = cw.side_edges();
            assert(side_cw == e, 'ccw vertex, cw side');
            assert(side_ccw == e, 'cw vertex, ccw side');
        }
    }

    /// `Into<EdgeDirection, GridEdge>`: the edge of the origin `ZERO`.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_from_edge_direction() {
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            let g: GridEdge = d.into();
            assert!(g == GridEdge { origin: HexTrait::ZERO, direction: d });
        }
    }

    /// `all_edges` is the six directions, in `ALL_DIRECTIONS` order, on the same origin.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_all_edges() {
        let h = HexTrait::new(8, -3);
        let mut edges = h.all_edges().span();
        let mut all = EdgeDirectionTrait::iter();
        while let Some(e) = edges.pop_front() {
            let d = *all.pop_front().unwrap();
            assert!(*e == GridEdge { origin: h, direction: d });
        }
        assert!(all.is_empty());
    }

    /// `Serde` round trip of the derived impl.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_edge_serde_round_trip() {
        let e = GridEdge { origin: HexTrait::new(-5, 4), direction: EdgeDirectionTrait::NEG_X };
        let mut output = array![];
        Serde::serialize(@e, ref output);
        let mut serialized = output.span();
        let back: Option<GridEdge> = Serde::deserialize(ref serialized);
        assert!(back == Some(e));
        assert!(serialized.len() == 0);
    }

    /// A destination that leaves `i32` panics (`hexx` does in a debug build).
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    #[should_panic]
    fn test_grid_edge_destination_overflow_panics() {
        GridEdge { origin: HexTrait::new(0x7fffffff, 0), direction: EdgeDirectionTrait::X }
            .destination();
    }

    /// The panic of `equivalent`'s second clause, only evaluated when the first is false.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    #[should_panic]
    fn test_grid_edge_equivalent_overflow_panics() {
        let a = GridEdge { origin: HexTrait::ZERO, direction: EdgeDirectionTrait::X };
        let b = GridEdge { origin: HexTrait::new(0x7fffffff, 0), direction: EdgeDirectionTrait::X };
        a.equivalent(b);
    }

    // Benchmarks of M2-T7 (LIB-06), 17 repetitions of the six edges of a hex per test (102 calls),
    // operands as `src/tests/bench_mirror.cairo`: per call = (test - baseline) / 102. Targets (`L`,
    // `U = ceil(1.25 L)`, plan §7 has none for L-M2), derived from the L-M1 measurements of
    // `bench_mirror` (`i32` operation or comparison 1,030, `add_dir` 4,341, direction rotation by
    // one 1,868, by `n` 2,217, `const_neg` 1,785) and written before the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `destination` | 4,341 | 5,427 |
    // | `flipped` | 4,341 + 1,785 = 6,126 | 7,658 |
    // | `equivalent` (second clause) | 4,341 + 1,785 + 4 comparisons = 10,246 | 12,808 |
    // | `vertices` | 2 x 1,868 = 3,736 | 4,670 |
    // | `rotate_cw`, `rotate_ccw` (255 steps) | 2,217 | 2,772 |
    // | `const_neg` | 1,785 | 2,232 |
    // | `clockwise`, `counter_clockwise` | 1,868 | 2,335 |
    // | `Hex::all_edges` | 6 x 1,030 = 6,180 | 7,725 |
    //
    // `equivalent` is measured on the pairs (edge, its flipped form); `all_edges` on 102 calls.

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_baseline() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.direction.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_baseline_hex() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                let y: i32 = item.direction.index().into();
                acc = acc ^ y.try_into().unwrap_or(0) ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_destination() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.destination().y.try_into().unwrap_or(0) ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_flipped() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.flipped().origin.y.try_into().unwrap_or(0) ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_baseline_pairs() {
        let h = HexTrait::new(3, -2);
        let edges = h.all_edges();
        let mut items = array![];
        let mut others = array![];
        let mut src = edges.span();
        while let Some(e) = src.pop_front() {
            items.append(*e);
            others.append((*e).flipped());
        }
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut k: usize = 0;
            while k != 6 {
                let a = *items.span().at(k);
                let b = *others.span().at(k);
                if a.direction.index() < 6 && b.direction.index() < 6 {
                    acc = acc ^ 1;
                }
                acc = acc ^ offset;
                k += 1;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_equivalent() {
        let h = HexTrait::new(3, -2);
        let edges = h.all_edges();
        let mut items = array![];
        let mut others = array![];
        let mut src = edges.span();
        while let Some(e) = src.pop_front() {
            items.append(*e);
            others.append((*e).flipped());
        }
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut k: usize = 0;
            while k != 6 {
                let a = *items.span().at(k);
                let b = *others.span().at(k);
                if a.equivalent(b) {
                    acc = acc ^ 1;
                }
                acc = acc ^ offset;
                k += 1;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_vertices() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                let [a, b] = item.vertices();
                acc = acc ^ a.direction.index() ^ b.direction.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_rotate_cw() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.rotate_cw(offset).direction.index();
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_rotate_ccw() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.rotate_ccw(offset).direction.index();
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_const_neg() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.const_neg().direction.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_clockwise() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.clockwise().direction.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_counter_clockwise() {
        let h = HexTrait::new(3, -2);
        let items = h.all_edges();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                acc = acc ^ item.counter_clockwise().direction.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_baseline_all() {
        let h = HexTrait::new(3, -2);
        let mut acc: u8 = 0;
        let mut k: u8 = 0;
        while k != 102 {
            let edges = [h, h, h, h, h, h];
            let [_, _, c, _, _, _] = edges;
            acc = acc ^ c.y.try_into().unwrap_or(0) ^ k;
            k += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_edge_all_edges() {
        let h = HexTrait::new(3, -2);
        let mut acc: u8 = 0;
        let mut k: u8 = 0;
        while k != 102 {
            let edges = h.all_edges();
            let [_, _, c, _, _, _] = edges;
            acc = acc ^ c.direction.index() ^ k;
            k += 1;
        }
        assert!(acc != 200);
    }
}
