//! Hex geometry: axial coordinates and grid distance.
//!
//! Odd-r offset to axial: `q = x - floor(y / 2)`, `r = y`. The distance is
//! `max(|dq|, |dr|, |dq + dr|)`: exact on an obstacle-free board, admissible and consistent as a
//! unit-cost heuristic.
//!
//! The same distance on the global coordinates of a location, with no board
//! (`distance_between`), the chunk of a tile (`chunk_of`), and the conversions between a tile
//! and the mirror's `Hex` (plan §3.5): the tile `(x, y)` is the `hexx` coordinate
//! `Hex::from_offset_coordinates([-x, y], OffsetHexMode::Even, HexOrientation::Pointy)`, that is
//! `Hex { x: -x - ceil(y / 2), y }`, so that index 0 is `Hex::ZERO` and the indices of
//! `Direction` and `EdgeDirection` coincide. `to_axial` keeps its own frame (it does not negate
//! `x`): its results are those of 1.8.0.

// Core imports

#[feature("bounded-int-utils")]
use core::internal::bounded_int::{
    AddHelper, BoundedInt, ConstrainHelper, DivRemHelper, SubHelper, UnitInt, add, constrain,
    div_rem, sub, upcast,
};

// Internal imports

use hexx::board::layout::LayoutTrait;
use hexx::hex::{Hex, HexTrait};

// Constants

/// 2, as a divisor.
const TWO: NonZero<u8> = 2;
/// The side of a chunk, `assembly::CHUNK` (D-120), as a divisor.
const CHUNK: NonZero<u8> = 15;

// The ranges of `distance_between` (`bounded_int`: no overflow check; the compiler checks each
// declared range against its operands)

/// `⌊y / 2⌋` and `y mod 2`.
impl Half of DivRemHelper<u8, UnitInt<2>> {
    type DivT = BoundedInt<0, 127>;
    type RemT = BoundedInt<0, 1>;
}

/// `x + ⌊y' / 2⌋`, one side of `dq`.
impl Side of AddHelper<u8, BoundedInt<0, 127>> {
    type Result = BoundedInt<0, 382>;
}

/// `dq`, the difference of both sides.
impl DeltaQ of SubHelper<BoundedInt<0, 382>, BoundedInt<0, 382>> {
    type Result = BoundedInt<-382, 382>;
}

/// `dr = y2 − y1`.
impl DeltaR of SubHelper<u8, u8> {
    type Result = BoundedInt<-255, 255>;
}

/// The sign of `dq`.
impl SignQ of ConstrainHelper<BoundedInt<-382, 382>, 0> {
    type LowT = BoundedInt<-382, -1>;
    type HighT = BoundedInt<0, 382>;
}

/// The sign of `dr`.
impl SignR of ConstrainHelper<BoundedInt<-255, 255>, 0> {
    type LowT = BoundedInt<-255, -1>;
    type HighT = BoundedInt<0, 255>;
}

/// `|dq|` of a negative `dq`.
impl NegQ of SubHelper<UnitInt<0>, BoundedInt<-382, -1>> {
    type Result = BoundedInt<1, 382>;
}

/// `|dr|` of a negative `dr`.
impl NegR of SubHelper<UnitInt<0>, BoundedInt<-255, -1>> {
    type Result = BoundedInt<1, 255>;
}

/// `dq + dr`, both non-negative.
impl SumHigh of AddHelper<BoundedInt<0, 382>, BoundedInt<0, 255>> {
    type Result = BoundedInt<0, 637>;
}

/// `dq + dr`, both negative.
impl SumLow of AddHelper<BoundedInt<-382, -1>, BoundedInt<-255, -1>> {
    type Result = BoundedInt<-637, -2>;
}

/// `|dq + dr|` of a negative sum.
impl NegSum of SubHelper<UnitInt<0>, BoundedInt<-637, -2>> {
    type Result = BoundedInt<2, 637>;
}

#[generate_trait]
pub impl Geometry of GeometryTrait {
    /// Axial coordinates of a position.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `position` - The position
    /// # Returns
    /// * The axial coordinates `(q, r)`
    #[inline]
    fn to_axial(width: u8, position: u8) -> (i16, i16) {
        let (x, y) = LayoutTrait::coords(width, position);
        let q: i16 = x.into() - (y / 2).into();
        (q, y.into())
    }

    /// Grid distance between two positions.
    /// Measured cheaper than a single division by `2W` per position (see `GAS.md`).
    /// # Arguments
    /// * `width` - The width of the map
    /// * `from` - The first position
    /// * `to` - The second position
    /// # Returns
    /// * The number of steps between both positions on an empty board
    #[inline]
    fn distance(width: u8, from: u8, to: u8) -> u8 {
        let (x_from, y_from) = LayoutTrait::coords(width, from);
        let (x_to, y_to) = LayoutTrait::coords(width, to);
        // [Compute] dq = (x2 - x1) - (y2/2 - y1/2), without negative intermediates
        let lhs = x_to + y_from / 2;
        let rhs = x_from + y_to / 2;
        let (dq, dq_negative) = if lhs >= rhs {
            (lhs - rhs, false)
        } else {
            (rhs - lhs, true)
        };
        let (dr, dr_negative) = if y_to >= y_from {
            (y_to - y_from, false)
        } else {
            (y_from - y_to, true)
        };
        // [Return] Same signs: |dq| + |dr|, opposite signs: max(|dq|, |dr|)
        if dq_negative == dr_negative {
            dq + dr
        } else if dq > dr {
            dq
        } else {
            dr
        }
    }

    /// Grid distance between two tiles of a location, on their global coordinates (odd-r, no
    /// board): the cube distance of `(q, r) = (x − ⌊y/2⌋, y)`, which equals `hex_distance` on
    /// any board that holds both tiles.
    /// # Arguments
    /// * `x1` - The column of the first tile
    /// * `y1` - The row of the first tile
    /// * `x2` - The column of the second tile
    /// * `y2` - The row of the second tile
    /// # Returns
    /// * The number of steps between both tiles, at most 383 (`(0, 0)` to `(255, 255)`)
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §6.1), the formula of `distance` on bounded
    /// integers (no overflow check, 4,220 against 7,220 on `u16`, M1-T3).
    #[inline]
    #[feature("bounded-int-utils")]
    fn distance_between(x1: u8, y1: u8, x2: u8, y2: u8) -> u16 {
        // [Compute] dq = (x2 + y1/2) - (x1 + y2/2) and dr = y2 - y1, on bounded ranges
        let (h1, _) = div_rem::<_, _, Half>(y1, 2);
        let (h2, _) = div_rem::<_, _, Half>(y2, 2);
        let dq = sub::<_, _, DeltaQ>(add::<_, _, Side>(x2, h1), add::<_, _, Side>(x1, h2));
        let dr = sub::<_, _, DeltaR>(y2, y1);
        // [Return] Same signs: |dq + dr|, opposite signs: max(|dq|, |dr|)
        match constrain::<_, 0, SignQ>(dq) {
            Ok(dq) => match constrain::<_, 0, SignR>(dr) {
                Ok(dr) => upcast(sub::<_, _, NegSum>(0, add::<_, _, SumLow>(dq, dr))),
                Err(dr) => {
                    let dq: u16 = upcast(sub::<_, _, NegQ>(0, dq));
                    let dr: u16 = upcast(dr);
                    if dq > dr {
                        dq
                    } else {
                        dr
                    }
                },
            },
            Err(dq) => match constrain::<_, 0, SignR>(dr) {
                Ok(dr) => {
                    let dq: u16 = upcast(dq);
                    let dr: u16 = upcast(sub::<_, _, NegR>(0, dr));
                    if dq > dr {
                        dq
                    } else {
                        dr
                    }
                },
                Err(dr) => upcast(add::<_, _, SumHigh>(dq, dr)),
            },
        }
    }

    /// The chunk of a tile of a location, `(x / 15, y / 15)` (the chunks are 15 × 15, D-120).
    /// It does not place a window (see `assembly::origin`).
    /// # Arguments
    /// * `x` - The global column of the tile
    /// * `y` - The global row of the tile
    /// # Returns
    /// * The column and the row of its chunk, each in `0..=17`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §6.1).
    #[inline]
    fn chunk_of(x: u8, y: u8) -> (u8, u8) {
        let (cx, _) = DivRem::div_rem(x, CHUNK);
        let (cy, _) = DivRem::div_rem(y, CHUNK);
        (cx, cy)
    }

    /// The mirror's `Hex` of a tile: `Hex { x: -x - ceil(y / 2), y }` (plan §3.5).
    /// # Arguments
    /// * `x` - The column of the tile
    /// * `y` - The row of the tile
    /// # Returns
    /// * The `Hex`, equal to `Hex::from_offset_coordinates([-x, y], Even, Pointy)`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §3.5).
    #[inline]
    fn to_hex(x: u8, y: u8) -> Hex {
        // [Compute] -(x + ceil(y / 2)) in the field, in -383..=0: always an `i32`
        let (half, odd) = DivRem::div_rem(y, TWO);
        let sum: felt252 = x.into() + half.into() + odd.into();
        HexTrait::new((-sum).try_into().unwrap(), y.into())
    }

    /// The tile of a `Hex`, the inverse of `to_hex`.
    /// # Arguments
    /// * `hex` - The `Hex`, any
    /// # Returns
    /// * The column and the row, `None` when either leaves `0..=255`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §3.5).
    #[inline]
    fn from_hex(hex: Hex) -> Option<(u8, u8)> {
        // [Check] The row
        let y: u8 = hex.y.try_into()?;
        // [Compute] -(hex.x + ceil(y / 2)) in the field: no `i32` operation, so no overflow
        let (half, odd) = DivRem::div_rem(y, TWO);
        let sum: felt252 = hex.x.into() + half.into() + odd.into();
        let x: u8 = (-sum).try_into()?;
        Some((x, y))
    }

    /// The mirror's `Hex` of a board position: `to_hex` of its coordinates.
    /// # Arguments
    /// * `width` - The width of the map, not zero
    /// * `position` - The position
    /// # Returns
    /// * The `Hex`; position 0 is `Hex::ZERO`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §3.5).
    #[inline]
    fn index_to_hex(width: u8, position: u8) -> Hex {
        let (x, y) = LayoutTrait::coords(width, position);
        Self::to_hex(x, y)
    }

    /// The board position of a `Hex`, the inverse of `index_to_hex` on the board.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map, with `width * height <= 256`
    /// * `hex` - The `Hex`, any
    /// # Returns
    /// * The position, `None` when the tile lies outside the board
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §3.5).
    #[inline]
    fn hex_to_index(width: u8, height: u8, hex: Hex) -> Option<u8> {
        let (x, y) = Self::from_hex(hex)?;
        if x >= width || y >= height {
            return None;
        }
        Some(LayoutTrait::index(width, x, y))
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use hexx::board::direction::Direction;
    use hexx::board::layout::LayoutTrait;
    use hexx::conversions::{HexConversionsTrait, OffsetHexMode};
    use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
    use hexx::hex::{Hex, HexTrait};
    use hexx::orientation::HexOrientation;
    use super::Geometry;

    /// The six directions, in index order.
    const DIRECTIONS: [Direction; 6] = [
        Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
        Direction::SouthWest, Direction::SouthEast,
    ];
    /// The boards of the plan (§5.4 fixture dimensions, the window 15 × 16 of D-120, its
    /// transpose) and the largest valid ones.
    const BOARDS: [(u8, u8); 12] = [
        (3, 3), (83, 3), (3, 83), (7, 7), (17, 14), (19, 13), (25, 10), (15, 15), (15, 16),
        (16, 15), (251, 1), (1, 251),
    ];
    /// The seeded pairs of location coordinates.
    const PAIRS: u32 = 512;

    // Oracles

    #[generate_trait]
    impl Oracle of OracleTrait {
        /// The cube distance on `i32`: `max(|dq|, |dr|, |dq + dr|)` with `q = x − ⌊y/2⌋`.
        fn distance(x1: u8, y1: u8, x2: u8, y2: u8) -> u16 {
            let q1: i32 = x1.into() - (y1 / 2).into();
            let q2: i32 = x2.into() - (y2 / 2).into();
            let dq = q2 - q1;
            let dr: i32 = y2.into() - y1.into();
            let s = dq + dr;
            let dq = if dq < 0 {
                -dq
            } else {
                dq
            };
            let dr = if dr < 0 {
                -dr
            } else {
                dr
            };
            let s = if s < 0 {
                -s
            } else {
                s
            };
            let max = if dq > dr {
                dq
            } else {
                dr
            };
            let max = if s > max {
                s
            } else {
                max
            };
            max.try_into().unwrap()
        }

        /// The formula of plan §3.5 through the mirror: `from_offset_coordinates([-x, y], Even,
        /// Pointy)`.
        fn to_hex(x: u8, y: u8) -> Hex {
            let column: i32 = x.into();
            HexConversionsTrait::from_offset_coordinates(
                [-column, y.into()], OffsetHexMode::Even, HexOrientation::Pointy,
            )
        }

        /// The next state of a 64-bit linear congruential generator (Knuth's MMIX constants).
        fn next(state: u64) -> u64 {
            let product: u128 = state.into() * 6364136223846793005 + 1442695040888963407;
            (product % 0x10000000000000000).try_into().unwrap()
        }

        /// A byte of a state.
        fn byte(state: u64, shift: u64) -> u8 {
            ((state / shift) % 256).try_into().unwrap()
        }
    }

    // Benchmarks: the inputs of both calls, opaque to the compiler

    #[derive(Copy, Drop)]
    struct Bench {
        /// `(x1, y1, x2, y2)`: `(0, 0)`–`(255, 255)`, the worst case of `distance_between`, 383.
        first: (u8, u8, u8, u8),
        /// The same shape, the other way round.
        second: (u8, u8, u8, u8),
        /// Tiles: `(255, 255)`, `(254, 253)`.
        tiles: [(u8, u8); 2],
        /// Their `Hex`.
        hexes: [Hex; 2],
        /// The window's width and height, and two of its positions.
        board: (u8, u8),
        positions: [u8; 2],
        /// The `Hex` of both positions.
        board_hexes: [Hex; 2],
    }

    #[generate_trait]
    impl Inputs of InputsTrait {
        /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
        #[inline(never)]
        fn get() -> Bench {
            Bench {
                first: (0, 0, 255, 255),
                second: (255, 255, 0, 0),
                tiles: [(255, 255), (254, 253)],
                hexes: [Hex { x: -383, y: 255 }, Hex { x: -381, y: 253 }],
                board: (15, 16),
                positions: [239, 224],
                board_hexes: [Hex { x: -22, y: 15 }, Hex { x: -21, y: 14 }],
            }
        }
    }

    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_geometry_to_axial() {
        // (x, y) = (3, 5) on width 7: q = 3 - 2 = 1
        let (q, r) = Geometry::to_axial(7, 5 * 7 + 3);
        assert!(q == 1);
        assert!(r == 5);
        // (0, 4): q = -2
        let (q, r) = Geometry::to_axial(7, 4 * 7);
        assert!(q == -2);
        assert!(r == 4);
    }

    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_geometry_distance_design_checks() {
        // (x, 0) -> (x - 1, 1) is 1 step
        assert!(Geometry::distance(7, 3, 7 + 2) == 1);
        // (0, 0) -> (0, 2) is 2 steps
        assert!(Geometry::distance(7, 0, 14) == 2);
        // Symmetric and zero on the diagonal
        assert!(Geometry::distance(7, 7 + 2, 3) == 1);
        assert!(Geometry::distance(7, 24, 24) == 0);
        // Same row
        assert!(Geometry::distance(7, 7, 13) == 6);
    }

    // distance_between

    /// R-D1 (audit pass 1, finding 10; pass 3, finding 31).
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_geometry_distance_between_regression() {
        assert!(Geometry::distance_between(255, 0, 0, 255) == 382);
        assert!(Geometry::distance_between(0, 0, 255, 255) == 383);
        assert!(Geometry::distance_between(255, 255, 0, 0) == 383);
        assert!(Geometry::distance_between(0, 255, 255, 0) == 382);
        assert!(Geometry::distance_between(0, 0, 0, 0) == 0);
        assert!(Geometry::distance_between(0, 0, 255, 0) == 255);
    }

    /// Every pair of a 7 × 7, placed at three global origins of even row (the board and the
    /// location are then the same odd-r grid): `distance` of the board, the cube distance and the
    /// `Hex` distance through `to_hex`.
    #[test]
    #[available_gas(l2_gas: 135468039)]
    fn test_geometry_distance_between_7x7() {
        let origins: [(u8, u8); 3] = [(0, 0), (120, 90), (248, 248)];
        for (ox, oy) in origins.span() {
            let (ox, oy) = (*ox, *oy);
            let mut from: u8 = 0;
            while from != 49 {
                let (x1, y1) = LayoutTrait::coords(7, from);
                let mut to: u8 = 0;
                while to != 49 {
                    let (x2, y2) = LayoutTrait::coords(7, to);
                    let distance = Geometry::distance_between(ox + x1, oy + y1, ox + x2, oy + y2);
                    let expected: u16 = Geometry::distance(7, from, to).into();
                    assert!(distance == expected, "{} -> {} at ({}, {})", from, to, ox, oy);
                    to += 1;
                }
                from += 1;
            }
        }
    }

    /// 512 seeded pairs of location coordinates, over the whole `u8` domain: the cube distance on
    /// `i32` and the `Hex` distance through `to_hex`; the distance is symmetric.
    #[test]
    #[available_gas(l2_gas: 29074122)]
    fn test_geometry_distance_between_seeded() {
        let mut state: u64 = 'pairs';
        let mut index: u32 = 0;
        while index != PAIRS {
            state = Oracle::next(state);
            let (x1, y1) = (Oracle::byte(state, 0x100000000), Oracle::byte(state, 0x10000000000));
            let (x2, y2) = (
                Oracle::byte(state, 0x1000000000000), Oracle::byte(state, 0x100000000000000),
            );
            let distance = Geometry::distance_between(x1, y1, x2, y2);
            assert!(distance == Oracle::distance(x1, y1, x2, y2));
            assert!(distance == Geometry::distance_between(x2, y2, x1, y1));
            let through: u32 = Geometry::to_hex(x1, y1)
                .unsigned_distance_to(Geometry::to_hex(x2, y2));
            assert!(distance.into() == through);
            index += 1;
        }
    }

    /// Every row `y1` of `u8` against the edge rows `y2` (0, 1, 127, 128, 254, 255), both ways,
    /// with the extreme columns: every sign of `dq` and `dr` and every end of their ranges, against
    /// the cube distance on `i32`.
    #[test]
    #[available_gas(l2_gas: 159948212)]
    fn test_geometry_distance_between_rows() {
        let edges: [u8; 6] = [0, 1, 127, 128, 254, 255];
        let columns: [(u8, u8); 4] = [(0, 0), (0, 255), (255, 0), (128, 127)];
        let mut v: u16 = 0;
        while v != 256 {
            let y1: u8 = v.try_into().unwrap();
            for y2 in edges.span() {
                for (x1, x2) in columns.span() {
                    let (x1, y2, x2) = (*x1, *y2, *x2);
                    let expected = Oracle::distance(x1, y1, x2, y2);
                    assert!(Geometry::distance_between(x1, y1, x2, y2) == expected);
                    assert!(Geometry::distance_between(x2, y2, x1, y1) == expected);
                }
            }
            v += 1;
        }
    }

    // chunk_of

    /// Every column and every row of `u8`: `15 · c <= v < 15 · (c + 1)`.
    #[test]
    #[available_gas(l2_gas: 2533860)]
    fn test_geometry_chunk_of() {
        let mut v: u16 = 0;
        while v != 256 {
            let x: u8 = v.try_into().unwrap();
            let y: u8 = 255 - x;
            let (cx, cy) = Geometry::chunk_of(x, y);
            let (cx, cy): (u16, u16) = (cx.into(), cy.into());
            assert!(15 * cx <= v && v < 15 * cx + 15);
            let w: u16 = y.into();
            assert!(15 * cy <= w && w < 15 * cy + 15);
            v += 1;
        }
        assert!(Geometry::chunk_of(255, 255) == (17, 17));
        assert!(Geometry::chunk_of(14, 15) == (0, 1));
    }

    // to_hex, from_hex

    /// Every row with the columns 0, 1, 127, 128, 254, 255, and every column with the rows 0, 1,
    /// 254, 255: `to_hex` equals the formula of §3.5 and `from_hex` inverts it.
    #[test]
    #[available_gas(l2_gas: 58619096)]
    fn test_geometry_to_hex_from_hex() {
        let edges: [u8; 6] = [0, 1, 127, 128, 254, 255];
        let mut v: u16 = 0;
        while v != 256 {
            let free: u8 = v.try_into().unwrap();
            for edge in edges.span() {
                for (x, y) in array![(*edge, free), (free, *edge)] {
                    let hex = Geometry::to_hex(x, y);
                    assert!(hex == Oracle::to_hex(x, y), "({}, {})", x, y);
                    assert!(Geometry::from_hex(hex) == Some((x, y)));
                }
            }
            v += 1;
        }
        // Index 0 is the origin; (255, 255) is the most negative column
        assert!(Geometry::to_hex(0, 0) == HexTrait::ZERO);
        assert!(Geometry::to_hex(255, 255) == Hex { x: -383, y: 255 });
    }

    /// `from_hex` is `None` as soon as the column or the row leaves `0..=255`, and never panics.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_geometry_from_hex_outside() {
        let max: i32 = 0x7fffffff;
        let min: i32 = -0x7fffffff - 1;
        // The row
        assert!(Geometry::from_hex(Hex { x: 0, y: -1 }).is_none());
        assert!(Geometry::from_hex(Hex { x: -128, y: 256 }).is_none());
        assert!(Geometry::from_hex(Hex { x: 0, y: max }).is_none());
        assert!(Geometry::from_hex(Hex { x: 0, y: min }).is_none());
        // The column: x = -hex.x - ceil(y / 2) is -1 or 256
        assert!(Geometry::from_hex(Hex { x: 1, y: 0 }).is_none());
        assert!(Geometry::from_hex(Hex { x: 0, y: 1 }).is_none());
        assert!(Geometry::from_hex(Hex { x: -256, y: 0 }).is_none());
        assert!(Geometry::from_hex(Hex { x: -384, y: 255 }).is_none());
        assert!(Geometry::from_hex(Hex { x: max, y: 0 }).is_none());
        assert!(Geometry::from_hex(Hex { x: min, y: 0 }).is_none());
        assert!(Geometry::from_hex(Hex { x: min, y: 255 }).is_none());
        assert!(Geometry::from_hex(Hex { x: max, y: max }).is_none());
        // Just inside
        assert!(Geometry::from_hex(Hex { x: -255, y: 0 }) == Some((255, 0)));
        assert!(Geometry::from_hex(Hex { x: -1, y: 1 }) == Some((0, 1)));
        assert!(Geometry::from_hex(Hex { x: -128, y: 255 }) == Some((0, 255)));
    }

    /// Every row of `u8`, each with the `Hex` columns at both ends of `0..=255` and just beyond
    /// them, and at the ends of `i32`: `Some` exactly inside, `None` outside, never a panic.
    #[test]
    #[available_gas(l2_gas: 9310613)]
    fn test_geometry_from_hex_rows() {
        let max: i32 = 0x7fffffff;
        let min: i32 = -0x7fffffff - 1;
        let mut v: u16 = 0;
        while v != 256 {
            let y: u8 = v.try_into().unwrap();
            let row: i32 = y.into();
            // The Hex column of the tile column 0 is -ceil(y / 2)
            let zero = Oracle::to_hex(0, y).x;
            assert!(Geometry::from_hex(Hex { x: zero, y: row }) == Some((0, y)));
            assert!(Geometry::from_hex(Hex { x: zero - 255, y: row }) == Some((255, y)));
            assert!(Geometry::from_hex(Hex { x: zero + 1, y: row }).is_none());
            assert!(Geometry::from_hex(Hex { x: zero - 256, y: row }).is_none());
            assert!(Geometry::from_hex(Hex { x: max, y: row }).is_none());
            assert!(Geometry::from_hex(Hex { x: min, y: row }).is_none());
            v += 1;
        }
    }

    // index_to_hex, hex_to_index

    /// Every tile of the boards of the plan: the round trip, the formula of §3.5, and a `Hex`
    /// just beyond each side of the board is `None`.
    #[test]
    #[available_gas(l2_gas: 62630663)]
    fn test_geometry_index_to_hex_round_trip() {
        for (width, height) in BOARDS.span() {
            let (width, height) = (*width, *height);
            let size: u16 = width.into() * height.into();
            let mut position: u16 = 0;
            while position != size {
                let position_u8: u8 = position.try_into().unwrap();
                let hex = Geometry::index_to_hex(width, position_u8);
                assert!(Geometry::hex_to_index(width, height, hex) == Some(position_u8));
                let (x, y) = LayoutTrait::coords(width, position_u8);
                assert!(hex == Oracle::to_hex(x, y));
                position += 1;
            }
            // Beyond the West and the North sides, and below the first row
            let mut y: u8 = 0;
            while y != height {
                assert!(Geometry::hex_to_index(width, height, Oracle::to_hex(width, y)).is_none());
                y += 1;
            }
            let mut x: u8 = 0;
            while x != width {
                let beyond = Oracle::to_hex(x, height);
                assert!(Geometry::hex_to_index(width, height, beyond).is_none());
                let below = Oracle::to_hex(x, 0).const_sub(Hex { x: 0, y: 1 });
                assert!(Geometry::hex_to_index(width, height, below).is_none());
                x += 1;
            }
        }
    }

    /// The directions coincide (plan §3.5): on every tile of a 7 × 7 and of the window 15 × 16,
    /// the `Hex` of the board neighbour in `Direction` `d` is the `Hex` of the tile plus the
    /// neighbour coordinates of `EdgeDirection` `d`.
    #[test]
    #[available_gas(l2_gas: 38544419)]
    fn test_geometry_index_to_hex_directions() {
        let boards: [(u8, u8); 2] = [(7, 7), (15, 16)];
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            let mut position: u8 = 0;
            while position != width * height {
                let hex = Geometry::index_to_hex(width, position);
                for direction in DIRECTIONS.span() {
                    let direction = *direction;
                    if let Some(next) = LayoutTrait::neighbor(width, height, position, direction) {
                        let edge: EdgeDirection = direction.into();
                        let step = edge.into_hex();
                        let expected = Hex { x: hex.x + step.x, y: hex.y + step.y };
                        assert!(Geometry::index_to_hex(width, next) == expected);
                        assert!(Geometry::hex_to_index(width, height, expected) == Some(next));
                    }
                }
                position += 1;
            }
        }
        // East of index 0 is `EdgeDirection::X` of `Hex::ZERO`
        assert!(Geometry::index_to_hex(7, 0) == HexTrait::ZERO);
        let x: EdgeDirection = EdgeDirectionTrait::X;
        assert!(Geometry::hex_to_index(7, 7, x.into_hex()).is_none());
    }

    // Benchmarks, on the worst case of each function: the difference between a test that calls
    // twice and one that calls once, the method of `bench_assembly`.

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 13829)]
    fn bench_geometry_distance_between_once() {
        let bench = Inputs::get();
        let (x1, y1, x2, y2) = bench.first;
        assert!(Geometry::distance_between(x1, y1, x2, y2) == 383);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 18260)]
    fn bench_geometry_distance_between_twice() {
        let bench = Inputs::get();
        let (x1, y1, x2, y2) = bench.first;
        assert!(Geometry::distance_between(x1, y1, x2, y2) == 383);
        let (x1, y1, x2, y2) = bench.second;
        assert!(Geometry::distance_between(x1, y1, x2, y2) == 383);
    }

    /// `hex_distance` of the engine on the window, beside `distance_between` (the game's hot path,
    /// the brief's report): the same method, the far corners of 15 × 16.
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 15278)]
    fn bench_geometry_distance_once() {
        let bench = Inputs::get();
        let [first, _] = bench.positions;
        assert!(Geometry::distance(15, 0, first) == 22);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 20570)]
    fn bench_geometry_distance_twice() {
        let bench = Inputs::get();
        let [first, second] = bench.positions;
        assert!(Geometry::distance(15, 0, first) == 22);
        assert!(Geometry::distance(15, 0, second) == 21);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 13052)]
    fn bench_geometry_chunk_of_once() {
        let bench = Inputs::get();
        let [(x, y), _] = bench.tiles;
        assert!(Geometry::chunk_of(x, y) == (17, 17));
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 16223)]
    fn bench_geometry_chunk_of_twice() {
        let bench = Inputs::get();
        let [(x, y), (u, v)] = bench.tiles;
        assert!(Geometry::chunk_of(x, y) == (17, 17));
        assert!(Geometry::chunk_of(u, v) == (16, 16));
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 12768)]
    fn bench_geometry_to_hex_once() {
        let bench = Inputs::get();
        let [(x, y), _] = bench.tiles;
        let [first, _] = bench.hexes;
        assert!(Geometry::to_hex(x, y) == first);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 15656)]
    fn bench_geometry_to_hex_twice() {
        let bench = Inputs::get();
        let [(x, y), (u, v)] = bench.tiles;
        let [first, second] = bench.hexes;
        assert!(Geometry::to_hex(x, y) == first);
        assert!(Geometry::to_hex(u, v) == second);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 13755)]
    fn bench_geometry_from_hex_once() {
        let bench = Inputs::get();
        let [first, _] = bench.hexes;
        assert!(Geometry::from_hex(first) == Some((255, 255)));
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 17787)]
    fn bench_geometry_from_hex_twice() {
        let bench = Inputs::get();
        let [first, second] = bench.hexes;
        assert!(Geometry::from_hex(first) == Some((255, 255)));
        assert!(Geometry::from_hex(second) == Some((254, 253)));
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 13829)]
    fn bench_geometry_index_to_hex_once() {
        let bench = Inputs::get();
        let (width, _) = bench.board;
        let [position, _] = bench.positions;
        let [first, _] = bench.board_hexes;
        assert!(Geometry::index_to_hex(width, position) == first);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 17777)]
    fn bench_geometry_index_to_hex_twice() {
        let bench = Inputs::get();
        let (width, _) = bench.board;
        let [position, other] = bench.positions;
        let [first, second] = bench.board_hexes;
        assert!(Geometry::index_to_hex(width, position) == first);
        assert!(Geometry::index_to_hex(width, other) == second);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 15519)]
    fn bench_geometry_hex_to_index_once() {
        let bench = Inputs::get();
        let (width, height) = bench.board;
        let [first, _] = bench.board_hexes;
        assert!(Geometry::hex_to_index(width, height, first) == Some(239));
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 21158)]
    fn bench_geometry_hex_to_index_twice() {
        let bench = Inputs::get();
        let (width, height) = bench.board;
        let [first, second] = bench.board_hexes;
        assert!(Geometry::hex_to_index(width, height, first) == Some(239));
        assert!(Geometry::hex_to_index(width, height, second) == Some(224));
    }
}
