//! `hex/grid/vertex`: `GridVertex`, a vertex of the grid given by a hex and a vertex direction
//! (`hexx`'s `src/hex/grid/vertex.rs`), with `Hex::all_vertices`.
//!
//! A vertex is shared by three hexes, so it has three forms; `equivalent` says whether two
//! vertices are the same one. The compass of the directions is `hexx`'s, verbatim (see
//! `VertexDirection`).

use crate::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
use crate::hex::grid::edge::GridEdge;
use crate::hex::{Hex, HexTrait};

/// A vertex of the hexagonal grid: the hex it belongs to and the direction it points towards.
///
/// Mirrors `hexx::GridVertex` (`src/hex/grid/vertex.rs:13`).
///
/// #### Panics
///
/// None: the type only holds its two fields.
///
/// #### Deviations
///
/// `Debug` is derived: it prints `GridVertex { origin: Hex { x: 1, y: 2, z: -3 }, direction:
/// VertexDirection { index: 0, x: 2, y: -1, z: -1 } }`, as `hexx`'s derived `Debug` does. `Hash`
/// and `Serde` are derived as a matter of course (plan §2.3): `Serde` reads the direction through
/// the `Serde` of `VertexDirection`, which refuses an index above 5. `Default` is not derived, as
/// in `hexx`.
#[derive(Copy, Drop, PartialEq, Debug, Serde, Hash)]
pub struct GridVertex {
    /// The coordinate of the vertex.
    pub origin: Hex,
    /// The direction the vertex points towards.
    pub direction: VertexDirection,
}

/// The methods of `impl GridVertex`.
pub trait GridVertexTrait {
    /// Whether `self` and `other` are the same vertex: identical, or the same vertex seen from
    /// one of the two other hexes that share it. The three forms are tried in `hexx`'s order:
    /// identical, then the form on the neighbour `direction_cw` (direction rotated by 2
    /// counter-clockwise), then the form on the neighbour `direction_ccw` (rotated by 2 clockwise).
    ///
    /// Mirrors `GridVertex::equivalent` (`src/hex/grid/vertex.rs:24`).
    ///
    /// #### Panics
    ///
    /// When an origin plus `direction_cw` or `direction_ccw` leaves `i32`: both neighbours are
    /// computed first, as `hexx` does, which panics in a debug build and wraps in a release build.
    ///
    /// #### Deviations
    ///
    /// Takes both vertices by value (`GridVertex` is `Copy`), not by reference. The sums are
    /// `Hex::add_dir`, `hexx`'s `Hex + EdgeDirection`.
    fn equivalent(self: GridVertex, other: GridVertex) -> bool;

    /// The three hexes sharing the vertex, in clockwise order: the origin, then its neighbours in
    /// `edge_ccw` and `edge_cw`.
    ///
    /// Mirrors `GridVertex::coordinates` (`src/hex/grid/vertex.rs:44`).
    ///
    /// #### Panics
    ///
    /// When a component of a neighbour leaves `i32` (`Hex::add_dir`).
    ///
    /// #### Deviations
    ///
    /// Takes `self` by value, not by reference. Cairo has no `const fn`.
    fn coordinates(self: GridVertex) -> [Hex; 3];

    /// The two hexes sharing the vertex besides the origin, in clockwise order: the neighbours in
    /// `edge_ccw` and `edge_cw`.
    ///
    /// Mirrors `GridVertex::destinations` (`src/hex/grid/vertex.rs:54`).
    ///
    /// #### Panics
    ///
    /// When a component of a neighbour leaves `i32` (`Hex::add_dir`).
    ///
    /// #### Deviations
    ///
    /// Takes `self` by value, not by reference. Cairo has no `const fn`.
    fn destinations(self: GridVertex) -> [Hex; 2];

    /// The two edges of the origin that meet at the vertex, in clockwise order: the `edge_ccw` one
    /// first, then the `edge_cw` one.
    ///
    /// Mirrors `GridVertex::side_edges` (`src/hex/grid/vertex.rs:65`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Takes `self` by value, not by reference. Cairo has no `const fn`.
    fn side_edges(self: GridVertex) -> [GridEdge; 2];

    /// The vertex facing the opposite direction, on the same origin.
    ///
    /// Mirrors `GridVertex::const_neg` (`src/hex/grid/vertex.rs:81`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`; this is the plain function behind the `-` operator.
    fn const_neg(self: GridVertex) -> GridVertex;

    /// The next vertex in clockwise order, on the same origin.
    ///
    /// Mirrors `GridVertex::clockwise` (`src/hex/grid/vertex.rs:91`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn clockwise(self: GridVertex) -> GridVertex;

    /// The next vertex in counter-clockwise order, on the same origin.
    ///
    /// Mirrors `GridVertex::counter_clockwise` (`src/hex/grid/vertex.rs:101`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn counter_clockwise(self: GridVertex) -> GridVertex;

    /// Rotates the vertex clockwise by `offset` steps of 60 degrees
    /// (`VertexDirection::rotate_cw`).
    ///
    /// Mirrors `GridVertex::rotate_cw` (`src/hex/grid/vertex.rs:111`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn rotate_cw(self: GridVertex, offset: u8) -> GridVertex;

    /// Rotates the vertex counter-clockwise by `offset` steps of 60 degrees
    /// (`VertexDirection::rotate_ccw`).
    ///
    /// Mirrors `GridVertex::rotate_ccw` (`src/hex/grid/vertex.rs:120`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`.
    fn rotate_ccw(self: GridVertex, offset: u8) -> GridVertex;
}

pub impl GridVertexImpl of GridVertexTrait {
    fn equivalent(self: GridVertex, other: GridVertex) -> bool {
        let cw = GridVertex {
            origin: self.origin.add_dir(self.direction.direction_cw()),
            direction: self.direction.rotate_ccw(2),
        };
        let ccw = GridVertex {
            origin: self.origin.add_dir(self.direction.direction_ccw()),
            direction: self.direction.rotate_cw(2),
        };
        // identical
        (self.origin == other.origin && self.direction == other.direction)
            || (cw.origin == other.origin && cw.direction == other.direction)
            || (ccw.origin == other.origin && ccw.direction == other.direction)
    }

    #[inline]
    fn coordinates(self: GridVertex) -> [Hex; 3] {
        [
            self.origin, self.origin.add_dir(self.direction.edge_ccw()),
            self.origin.add_dir(self.direction.edge_cw()),
        ]
    }

    #[inline]
    fn destinations(self: GridVertex) -> [Hex; 2] {
        [
            self.origin.add_dir(self.direction.edge_ccw()),
            self.origin.add_dir(self.direction.edge_cw()),
        ]
    }

    #[inline]
    fn side_edges(self: GridVertex) -> [GridEdge; 2] {
        [
            GridEdge { origin: self.origin, direction: self.direction.edge_ccw() },
            GridEdge { origin: self.origin, direction: self.direction.edge_cw() },
        ]
    }

    #[inline]
    fn const_neg(self: GridVertex) -> GridVertex {
        GridVertex { origin: self.origin, direction: self.direction.const_neg() }
    }

    #[inline]
    fn clockwise(self: GridVertex) -> GridVertex {
        GridVertex { origin: self.origin, direction: self.direction.clockwise() }
    }

    #[inline]
    fn counter_clockwise(self: GridVertex) -> GridVertex {
        GridVertex { origin: self.origin, direction: self.direction.counter_clockwise() }
    }

    #[inline]
    fn rotate_cw(self: GridVertex, offset: u8) -> GridVertex {
        GridVertex { origin: self.origin, direction: self.direction.rotate_cw(offset) }
    }

    #[inline]
    fn rotate_ccw(self: GridVertex, offset: u8) -> GridVertex {
        GridVertex { origin: self.origin, direction: self.direction.rotate_ccw(offset) }
    }
}

/// The vertex opposite to `self`, as the `-` operator.
///
/// Mirrors `impl Neg for GridVertex` (`src/hex/grid/vertex.rs:140`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The operator is a trait impl that Cairo resolves from the scope: a consumer imports
/// `GridVertexNeg` (`use hexx::hex::grid::vertex::GridVertexNeg;`) to write `-vertex`.
pub impl GridVertexNeg of Neg<GridVertex> {
    #[inline]
    fn neg(a: GridVertex) -> GridVertex {
        a.const_neg()
    }
}

/// The vertex of the origin hex `ZERO` pointing towards `direction`.
///
/// Mirrors `impl From<VertexDirection> for GridVertex` (`src/hex/grid/vertex.rs:149`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The impl is `Into`, not `From`: Cairo's `From` does not exist in the corelib, `Into` is the
/// conversion trait.
pub impl GridVertexFromVertexDirection of Into<VertexDirection, GridVertex> {
    #[inline]
    fn into(self: VertexDirection) -> GridVertex {
        GridVertex { origin: HexTrait::ZERO, direction: self }
    }
}

/// The method `Hex::all_vertices`, defined in `hex/grid/vertex.rs` in `hexx` (an `impl Hex` block
/// of that file); a trait of this module here (D-143).
pub trait HexVerticesTrait {
    /// The six vertices of the hex, in `VertexDirection::ALL_DIRECTIONS` order.
    ///
    /// Mirrors `Hex::all_vertices` (`src/hex/grid/vertex.rs:132`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// `hexx` maps `ALL_DIRECTIONS` (`[T; 6]::map`); a fixed-size array has no `map` in Cairo, the
    /// six vertices are written out.
    fn all_vertices(self: Hex) -> [GridVertex; 6];
}

pub impl HexVerticesImpl of HexVerticesTrait {
    fn all_vertices(self: Hex) -> [GridVertex; 6] {
        let [d0, d1, d2, d3, d4, d5] = VertexDirectionTrait::ALL_DIRECTIONS;
        [
            GridVertex { origin: self, direction: d0 }, GridVertex { origin: self, direction: d1 },
            GridVertex { origin: self, direction: d2 }, GridVertex { origin: self, direction: d3 },
            GridVertex { origin: self, direction: d4 }, GridVertex { origin: self, direction: d5 },
        ]
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::direction::vertex_direction::VertexDirectionTrait;
    use crate::hex::grid::edge::GridEdgeTrait;
    use crate::hex::{Hex, HexTrait};
    use super::{GridVertex, GridVertexNeg, GridVertexTrait, HexVerticesTrait};

    /// The plain definitions the optimised methods are tested against.
    #[generate_trait]
    impl GridVertexOracleImpl of GridVertexOracleTrait {
        /// The hex and its six neighbours, the hex first.
        fn hexes_around(h: Hex) -> Array<Hex> {
            let [n0, n1, n2, n3, n4, n5] = h.all_neighbors();
            array![h, n0, n1, n2, n3, n4, n5]
        }

        /// The 6 x 7 vertices that the hex and its six neighbours carry.
        fn vertices_around(h: Hex) -> Array<GridVertex> {
            let mut vertices = array![];
            let mut hexes = Self::hexes_around(h).span();
            while let Some(around) = hexes.pop_front() {
                let mut own = (*around).all_vertices().span();
                while let Some(v) = own.pop_front() {
                    vertices.append(*v);
                }
            }
            vertices
        }

        fn contains(set: [Hex; 3], h: Hex) -> bool {
            let [a, b, c] = set;
            h == a || h == b || h == c
        }

        /// The geometric definition of the equivalence: two vertices are the same when the three
        /// hexes they touch are the same set.
        fn touch_the_same_hexes(a: GridVertex, b: GridVertex) -> bool {
            let (ca, cb) = (a.coordinates(), b.coordinates());
            let [a0, a1, a2] = ca;
            let [b0, b1, b2] = cb;
            Self::contains(cb, a0)
                && Self::contains(cb, a1)
                && Self::contains(cb, a2)
                && Self::contains(ca, b0)
                && Self::contains(ca, b1)
                && Self::contains(ca, b2)
        }

        /// `equivalent` against the definition on every ordered pair of `vertices_around(h)`;
        /// returns the number of equivalent pairs.
        fn check_equivalent_around(h: Hex) -> u32 {
            let vertices = Self::vertices_around(h);
            assert!(vertices.len() == 42);
            let mut count: u32 = 0;
            let mut outer = vertices.span();
            while let Some(a) = outer.pop_front() {
                let mut inner = vertices.span();
                while let Some(b) = inner.pop_front() {
                    let expected = Self::touch_the_same_hexes(*a, *b);
                    assert!((*a).equivalent(*b) == expected);
                    if expected {
                        count += 1;
                    }
                }
            }
            count
        }
    }

    /// `equivalent` against its geometric definition on every pair of the 6 x 7 vertices around
    /// the origin. A vertex has three forms; of the 42, the 18 around the centre have all three
    /// among the 42 (6 classes of 3), 12 have two (6 classes of 2) and 12 have one: the ordered
    /// pairs are 6 x 9 + 6 x 4 + 12 = 90.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_equivalent_oracle_at_the_origin() {
        assert!(GridVertexOracleTrait::check_equivalent_around(HexTrait::ZERO) == 90);
    }

    /// The same away from the origin, with negative and positive components.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_equivalent_oracle_elsewhere() {
        assert!(GridVertexOracleTrait::check_equivalent_around(HexTrait::new(-7, 12)) == 90);
        assert!(GridVertexOracleTrait::check_equivalent_around(HexTrait::new(30, -17)) == 90);
    }

    /// `coordinates` is the origin then `destinations`, the three hexes are pairwise adjacent.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_coordinates_and_destinations() {
        let mut vertices = HexTrait::new(-4, 9).all_vertices().span();
        while let Some(v) = vertices.pop_front() {
            let v = *v;
            let [c0, c1, c2] = v.coordinates();
            let [d1, d2] = v.destinations();
            assert!(c0 == v.origin && c1 == d1 && c2 == d2);
            assert!(c0.distance_to(c1) == 1 && c1.distance_to(c2) == 1 && c2.distance_to(c0) == 1);
        }
    }

    /// The side edges are the edges of the origin that meet at the vertex, and the vertex is the
    /// end of each of them: the clockwise vertex of the counter-clockwise side, the
    /// counter-clockwise vertex of the clockwise side.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_side_edges_end_at_the_vertex() {
        let mut vertices = HexTrait::new(6, -1).all_vertices().span();
        while let Some(v) = vertices.pop_front() {
            let v = *v;
            let [side_ccw, side_cw] = v.side_edges();
            assert!(side_ccw.origin == v.origin && side_cw.origin == v.origin);
            let [_, end] = side_ccw.vertices();
            assert(end == v, 'ccw side ends at v');
            let [start, _] = side_cw.vertices();
            assert(start == v, 'cw side starts at v');
        }
    }

    /// `-vertex` is `const_neg`, and negating twice gives the vertex back, the origin is unchanged.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_neg() {
        let mut vertices = HexTrait::new(2, 2).all_vertices().span();
        while let Some(v) = vertices.pop_front() {
            let v = *v;
            assert!(-v == v.const_neg());
            assert!(-(-v) == v);
            assert!((-v).origin == v.origin);
            assert!((-v).direction == v.direction.const_neg());
        }
    }

    /// The rotations by `offset` are `offset` steps of `clockwise` and `counter_clockwise`, on the
    /// same origin, for the offsets `0..=12` (more than two turns).
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_rotations_are_repeated_steps() {
        let mut vertices = HexTrait::new(-3, 5).all_vertices().span();
        while let Some(v) = vertices.pop_front() {
            let v = *v;
            let mut cw = v;
            let mut ccw = v;
            let mut offset: u8 = 0;
            while offset <= 12 {
                assert!(v.rotate_cw(offset) == cw);
                assert!(v.rotate_ccw(offset) == ccw);
                assert!(cw.origin == v.origin && ccw.origin == v.origin);
                cw = cw.clockwise();
                ccw = ccw.counter_clockwise();
                offset += 1;
            }
            assert!(v.clockwise().counter_clockwise() == v);
        }
    }

    /// `Into<VertexDirection, GridVertex>`: the vertex of the origin `ZERO`.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_from_vertex_direction() {
        let mut all = VertexDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            let g: GridVertex = d.into();
            assert!(g == GridVertex { origin: HexTrait::ZERO, direction: d });
        }
    }

    /// `all_vertices` is the six directions, in `ALL_DIRECTIONS` order, on the same origin.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_all_vertices() {
        let h = HexTrait::new(8, -3);
        let mut vertices = h.all_vertices().span();
        let mut all = VertexDirectionTrait::iter();
        while let Some(v) = vertices.pop_front() {
            let d = *all.pop_front().unwrap();
            assert!(*v == GridVertex { origin: h, direction: d });
        }
        assert!(all.is_empty());
    }

    /// `Serde` round trip of the derived impl.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_grid_vertex_serde_round_trip() {
        let v = GridVertex {
            origin: HexTrait::new(-5, 4), direction: VertexDirectionTrait::POINTY_SOUTH,
        };
        let mut output = array![];
        Serde::serialize(@v, ref output);
        let mut serialized = output.span();
        let back: Option<GridVertex> = Serde::deserialize(ref serialized);
        assert!(back == Some(v));
        assert!(serialized.len() == 0);
    }

    /// A neighbour that leaves `i32` panics in `coordinates` (`hexx` does in a debug build).
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    #[should_panic]
    fn test_grid_vertex_coordinates_overflow_panics() {
        GridVertex {
            origin: HexTrait::new(0x7fffffff, 0),
            direction: VertexDirectionTrait::POINTY_NORTH_EAST,
        }
            .coordinates();
    }

    /// `equivalent` computes both neighbours first, as `hexx` does: it panics on an origin whose
    /// neighbour leaves `i32` even when the vertices are identical.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    #[should_panic]
    fn test_grid_vertex_equivalent_overflow_panics() {
        let v = GridVertex {
            origin: HexTrait::new(0x7fffffff, 0),
            direction: VertexDirectionTrait::POINTY_NORTH_EAST,
        };
        v.equivalent(v);
    }

    // Benchmarks of M2-T7 (LIB-06), 17 repetitions of the six vertices of a hex per test (102
    // calls), operands as `src/tests/bench_mirror.cairo`: per call = (test - baseline) / 102.
    // Targets (`L`, `U = ceil(1.25 L)`, plan §7 has none for L-M2), derived from the L-M1
    // measurements of `bench_mirror` (`i32` operation or comparison 1,030, `add_dir` 4,341,
    // direction rotation by one 1,868, by `n` 2,217, `const_neg` 1,785) and written before the
    // first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `coordinates`, `destinations` | 2 x (4,341 + 1,868) = 12,418 | 15,523 |
    // | `side_edges` | 2 x 1,868 = 3,736 | 4,670 |
    // | `equivalent` (third clause) | 2 x (4,341 + 1,868 + 2,217) + 6 comparisons = 23,032 | 28,790
    // |
    // | `rotate_cw`, `rotate_ccw` (255 steps) | 2,217 | 2,772 |
    // | `const_neg` | 1,785 | 2,232 |
    // | `clockwise`, `counter_clockwise` | 1,868 | 2,335 |
    // | `Hex::all_vertices` | 6 x 1,030 = 6,180 | 7,725 |
    //
    // `equivalent` is measured on the pairs (vertex, its form on the `direction_ccw` neighbour);
    // `all_vertices` on 102 calls.

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_vertex_baseline() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
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
    fn bench_grid_vertex_baseline_hex2() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                let y: i32 = item.direction.index().into();
                let x: i32 = item.direction.index().into();
                acc = acc ^ y.try_into().unwrap_or(0) ^ x.try_into().unwrap_or(0) ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_vertex_coordinates() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                let [_, b, c] = item.coordinates();
                acc = acc ^ b.y.try_into().unwrap_or(0) ^ c.y.try_into().unwrap_or(0) ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_vertex_destinations() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                let [b, c] = item.destinations();
                acc = acc ^ b.y.try_into().unwrap_or(0) ^ c.y.try_into().unwrap_or(0) ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_vertex_side_edges() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = items.span();
            while let Some(item) = all.pop_front() {
                let item = *item;
                let [a, b] = item.side_edges();
                acc = acc ^ a.direction.index() ^ b.direction.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_vertex_baseline_pairs() {
        let h = HexTrait::new(3, -2);
        let vertices = h.all_vertices();
        let mut items = array![];
        let mut others = array![];
        let mut src = vertices.span();
        while let Some(v) = src.pop_front() {
            let v = *v;
            items.append(v);
            others
                .append(
                    GridVertex {
                        origin: v.origin.add_dir(v.direction.direction_ccw()),
                        direction: v.direction.rotate_cw(2),
                    },
                );
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
    fn bench_grid_vertex_equivalent() {
        let h = HexTrait::new(3, -2);
        let vertices = h.all_vertices();
        let mut items = array![];
        let mut others = array![];
        let mut src = vertices.span();
        while let Some(v) = src.pop_front() {
            let v = *v;
            items.append(v);
            others
                .append(
                    GridVertex {
                        origin: v.origin.add_dir(v.direction.direction_ccw()),
                        direction: v.direction.rotate_cw(2),
                    },
                );
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
    fn bench_grid_vertex_rotate_cw() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
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
    fn bench_grid_vertex_rotate_ccw() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
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
    fn bench_grid_vertex_const_neg() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
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
    fn bench_grid_vertex_clockwise() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
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
    fn bench_grid_vertex_counter_clockwise() {
        let h = HexTrait::new(3, -2);
        let items = h.all_vertices();
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
    fn bench_grid_vertex_baseline_all() {
        let h = HexTrait::new(3, -2);
        let mut acc: u8 = 0;
        let mut k: u8 = 0;
        while k != 102 {
            let vertices = [h, h, h, h, h, h];
            let [_, _, c, _, _, _] = vertices;
            acc = acc ^ c.y.try_into().unwrap_or(0) ^ k;
            k += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_grid_vertex_all_vertices() {
        let h = HexTrait::new(3, -2);
        let mut acc: u8 = 0;
        let mut k: u8 = 0;
        while k != 102 {
            let vertices = h.all_vertices();
            let [_, _, c, _, _, _] = vertices;
            acc = acc ^ c.direction.index() ^ k;
            k += 1;
        }
        assert!(acc != 200);
    }
}
