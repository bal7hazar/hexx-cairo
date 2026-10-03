//! `VertexDirection`: one of the six vertex (diagonal) directions of a hexagon, the mirror of
//! `hexx::VertexDirection` (`src/direction/vertex_direction.rs`).
//!
//! **The compass constants are `hexx`'s, verbatim, and assume a screen with y pointing down**, as
//! those of `EdgeDirection` do (see its module documentation): on the north-up map of the board
//! engine, `POINTY_SOUTH_EAST` (index 1) points north-east and `clockwise` turns
//! *counter-clockwise* (plan §3.2). The names are not changed.
//!
//! Vertex `i` lies between edge `i - 1` and edge `i`: `edge_ccw` is edge `(i + 5) mod 6`, `edge_cw`
//! is edge `i`.
//!
//! `hexx`'s iterator (`iter`, `impl ExactSizeIterator`) is an eager `Span` here: a `Span` is the
//! iterator of Cairo (plan §4.4, "Span" counterparts). The 18 angle functions of `hexx` (`f32`)
//! are excluded (plan §4.4).

use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionIndexTrait};
use crate::hex::{Hex, HexTrait};

/// The number of directions, as a divisor.
const SIX: NonZero<u8> = 6;

/// One of the six vertex directions of a hexagon, an index in `0..=5`.
///
/// Mirrors `hexx::VertexDirection` (`src/direction/vertex_direction.rs:74`), a `struct
/// VertexDirection(u8)`.
///
/// #### Panics
///
/// None: the field is private and every constant, and every result of a method, is in `0..=5`.
///
/// #### Deviations
///
/// Cairo has no tuple structs: the field is named `index`. It stays private so that `index()` is
/// the only reader, as `pub(crate)` is in `hexx` (plan §3.2). `Hash` is derived as a matter of
/// course (plan §2.3). `Debug` is written by hand and prints what `hexx`'s does
/// (`VertexDirection { index: 0, x: 2, y: -1, z: -1 }`, `src/direction/vertex_direction.rs:637`).
/// `Serde` is written by hand: `deserialize` returns `None` for an index above 5, so that a value
/// read from calldata is always one of the six directions (a derived `Serde` would accept any
/// `u8`, and `rotate_cw` and `into_hex` would leave `0..=5`).
#[derive(Copy, Drop, PartialEq, Default, Hash)]
pub struct VertexDirection {
    index: u8,
}

/// `Serde` of `VertexDirection`: one felt, the index, as the derived impl writes it; reading
/// refuses an index above 5. Private, like a derived impl (Cairo finds it all the same).
impl VertexDirectionSerde of Serde<VertexDirection> {
    fn serialize(self: @VertexDirection, ref output: Array<felt252>) {
        Serde::<u8>::serialize(self.index, ref output);
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<VertexDirection> {
        let index: u8 = Serde::<u8>::deserialize(ref serialized)?;
        if index > 5 {
            return None;
        }
        Some(VertexDirection { index })
    }
}

/// `Debug` of `VertexDirection`, as `hexx`'s: `VertexDirection { index: 0, x: 2, y: -1, z: -1 }`.
///
/// Mirrors `impl Debug for VertexDirection` (`src/direction/vertex_direction.rs:637`).
impl VertexDirectionDebug of core::fmt::Debug<VertexDirection> {
    fn fmt(self: @VertexDirection, ref f: core::fmt::Formatter) -> Result<(), core::fmt::Error> {
        let c = (*self).into_hex();
        write!(
            f, "VertexDirection {{ index: {}, x: {}, y: {}, z: {} }}", *self.index, c.x, c.y, c.z(),
        )
    }
}

/// The items of `impl VertexDirection` of milestone L-M2.
pub trait VertexDirectionTrait {
    /// The direction towards `X, -Y, -Z`, index 0.
    ///
    /// Mirrors `VertexDirection::X_NEG_Y_NEG_Z` (`src/direction/vertex_direction.rs:78`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const X_NEG_Y_NEG_Z: VertexDirection;

    /// The direction to (2, -1) or (2, -1, -1), index 0.
    ///
    /// Mirrors `VertexDirection::X` (`src/direction/vertex_direction.rs:80`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const X: VertexDirection;

    /// The direction to (2, -1) or (2, -1, -1) (represents "Right" in flat orientation), index 0.
    ///
    /// Mirrors `VertexDirection::FLAT_RIGHT` (`src/direction/vertex_direction.rs:84`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_RIGHT: VertexDirection;

    /// The direction to (2, -1) or (2, -1, -1) (represents "East" in flat orientation), index 0.
    ///
    /// Mirrors `VertexDirection::FLAT_EAST` (`src/direction/vertex_direction.rs:88`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_EAST: VertexDirection;

    /// The direction to (2, -1) or (2, -1, -1) (represents "Top right" in pointy orientation),
    /// index 0.
    ///
    /// Mirrors `VertexDirection::POINTY_TOP_RIGHT` (`src/direction/vertex_direction.rs:92`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_TOP_RIGHT: VertexDirection;

    /// The direction to (2, -1) or (2, -1, -1) (represents "North East" in pointy orientation),
    /// index 0.
    ///
    /// Mirrors `VertexDirection::POINTY_NORTH_EAST` (`src/direction/vertex_direction.rs:96`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_NORTH_EAST: VertexDirection;

    /// The direction towards `X, -Y, Z`, index 5.
    ///
    /// Mirrors `VertexDirection::X_NEG_Y_Z` (`src/direction/vertex_direction.rs:99`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const X_NEG_Y_Z: VertexDirection;

    /// The direction to (1, -2) or (1, -2, 1), index 5.
    ///
    /// Mirrors `VertexDirection::NEG_Y` (`src/direction/vertex_direction.rs:101`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_Y: VertexDirection;

    /// The direction to (1, -2) or (1, -2, 1) (represents "Top Right" in flat orientation), index
    /// 5.
    ///
    /// Mirrors `VertexDirection::FLAT_TOP_RIGHT` (`src/direction/vertex_direction.rs:105`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_TOP_RIGHT: VertexDirection;

    /// The direction to (1, -2) or (1, -2, 1) (represents "North East" in flat orientation), index
    /// 5.
    ///
    /// Mirrors `VertexDirection::FLAT_NORTH_EAST` (`src/direction/vertex_direction.rs:109`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_NORTH_EAST: VertexDirection;

    /// The direction to (1, -2) or (1, -2, 1) (represents "Top" in pointy orientation), index 5.
    ///
    /// Mirrors `VertexDirection::POINTY_TOP` (`src/direction/vertex_direction.rs:113`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_TOP: VertexDirection;

    /// The direction to (1, -2) or (1, -2, 1) (represents "North" in pointy orientation), index 5.
    ///
    /// Mirrors `VertexDirection::POINTY_NORTH` (`src/direction/vertex_direction.rs:117`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_NORTH: VertexDirection;

    /// The direction towards `-X, -Y, Z`, index 4.
    ///
    /// Mirrors `VertexDirection::NEG_X_NEG_Y` (`src/direction/vertex_direction.rs:120`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_X_NEG_Y: VertexDirection;

    /// The direction to (-1, -1) or (-1, -1, 2), index 4.
    ///
    /// Mirrors `VertexDirection::Z` (`src/direction/vertex_direction.rs:122`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const Z: VertexDirection;

    /// The direction to (-1, -1) or (-1, -1, 2) (represents "Top Left" in flat orientation), index
    /// 4.
    ///
    /// Mirrors `VertexDirection::FLAT_TOP_LEFT` (`src/direction/vertex_direction.rs:126`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_TOP_LEFT: VertexDirection;

    /// The direction to (-1, -1) or (-1, -1, 2) (represents "North West" in flat orientation),
    /// index 4.
    ///
    /// Mirrors `VertexDirection::FLAT_NORTH_WEST` (`src/direction/vertex_direction.rs:130`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_NORTH_WEST: VertexDirection;

    /// The direction to (-1, -1) or (-1, -1, 2) (represents "Top Left" in pointy orientation),
    /// index 4.
    ///
    /// Mirrors `VertexDirection::POINTY_TOP_LEFT` (`src/direction/vertex_direction.rs:134`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_TOP_LEFT: VertexDirection;

    /// The direction to (-1, -1) or (-1, -1, 2) (represents "North West" in pointy orientation),
    /// index 4.
    ///
    /// Mirrors `VertexDirection::POINTY_NORTH_WEST` (`src/direction/vertex_direction.rs:138`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_NORTH_WEST: VertexDirection;

    /// The direction towards `-X, Y, Z`, index 3.
    ///
    /// Mirrors `VertexDirection::NEG_X_Y_Z` (`src/direction/vertex_direction.rs:141`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_X_Y_Z: VertexDirection;

    /// The direction to (-2, 1) or (-2, 1, 1), index 3.
    ///
    /// Mirrors `VertexDirection::NEG_X` (`src/direction/vertex_direction.rs:143`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_X: VertexDirection;

    /// The direction to (-2, 1) or (-2, 1, 1) (represents "Left" in flat orientation), index 3.
    ///
    /// Mirrors `VertexDirection::FLAT_LEFT` (`src/direction/vertex_direction.rs:147`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_LEFT: VertexDirection;

    /// The direction to (-2, 1) or (-2, 1, 1) (represents "West" in flat orientation), index 3.
    ///
    /// Mirrors `VertexDirection::FLAT_WEST` (`src/direction/vertex_direction.rs:151`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_WEST: VertexDirection;

    /// The direction to (-2, 1) or (-2, 1, 1) (represents "Bottom Left" in pointy orientation),
    /// index 3.
    ///
    /// Mirrors `VertexDirection::POINTY_BOTTOM_LEFT` (`src/direction/vertex_direction.rs:155`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_BOTTOM_LEFT: VertexDirection;

    /// The direction to (-2, 1) or (-2, 1, 1) (represents "South West" in pointy orientation),
    /// index 3.
    ///
    /// Mirrors `VertexDirection::POINTY_SOUTH_WEST` (`src/direction/vertex_direction.rs:159`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_SOUTH_WEST: VertexDirection;

    /// The direction towards `-X, Y, -Z`, index 2.
    ///
    /// Mirrors `VertexDirection::NEG_X_Y_NEG_Z` (`src/direction/vertex_direction.rs:162`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_X_Y_NEG_Z: VertexDirection;

    /// The direction to (-1, 2) or (-1, 2, -1), index 2.
    ///
    /// Mirrors `VertexDirection::Y` (`src/direction/vertex_direction.rs:164`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const Y: VertexDirection;

    /// The direction to (-1, 2) or (-1, 2, -1) (represents "Bottom Left" in flat orientation),
    /// index 2.
    ///
    /// Mirrors `VertexDirection::FLAT_BOTTOM_LEFT` (`src/direction/vertex_direction.rs:168`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_BOTTOM_LEFT: VertexDirection;

    /// The direction to (-1, 2) or (-1, 2, -1) (represents "South West" in flat orientation), index
    /// 2.
    ///
    /// Mirrors `VertexDirection::FLAT_SOUTH_WEST` (`src/direction/vertex_direction.rs:172`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_SOUTH_WEST: VertexDirection;

    /// The direction to (-1, 2) or (-1, 2, -1) (represents "Bottom " in pointy orientation), index
    /// 2.
    ///
    /// Mirrors `VertexDirection::POINTY_BOTTOM` (`src/direction/vertex_direction.rs:176`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_BOTTOM: VertexDirection;

    /// The direction to (-1, 2) or (-1, 2, -1) (represents "South" in pointy orientation), index 2.
    ///
    /// Mirrors `VertexDirection::POINTY_SOUTH` (`src/direction/vertex_direction.rs:180`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_SOUTH: VertexDirection;

    /// The direction towards `X, Y, -Z`, index 1.
    ///
    /// Mirrors `VertexDirection::X_Y` (`src/direction/vertex_direction.rs:183`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const X_Y: VertexDirection;

    /// The direction to (1, 1) or (1, 1, -2), index 1.
    ///
    /// Mirrors `VertexDirection::NEG_Z` (`src/direction/vertex_direction.rs:185`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_Z: VertexDirection;

    /// The direction to (1, 1) or (1, 1, -2) (represents "Bottom Right" in flat orientation), index
    /// 1.
    ///
    /// Mirrors `VertexDirection::FLAT_BOTTOM_RIGHT` (`src/direction/vertex_direction.rs:189`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_BOTTOM_RIGHT: VertexDirection;

    /// The direction to (1, 1) or (1, 1, -2) (represents "South East" in flat orientation), index
    /// 1.
    ///
    /// Mirrors `VertexDirection::FLAT_SOUTH_EAST` (`src/direction/vertex_direction.rs:193`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_SOUTH_EAST: VertexDirection;

    /// The direction to (1, 1) or (1, 1, -2) (represents "Bottom Right" in pointy orientation),
    /// index 1.
    ///
    /// Mirrors `VertexDirection::POINTY_BOTTOM_RIGHT` (`src/direction/vertex_direction.rs:197`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_BOTTOM_RIGHT: VertexDirection;

    /// The direction to (1, 1) or (1, 1, -2) (represents "South East" in pointy orientation), index
    /// 1.
    ///
    /// Mirrors `VertexDirection::POINTY_SOUTH_EAST` (`src/direction/vertex_direction.rs:201`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_SOUTH_EAST: VertexDirection;

    /// All six directions, in index order, matching `Hex::DIAGONAL_COORDS`.
    ///
    /// Mirrors `VertexDirection::ALL_DIRECTIONS` (`src/direction/vertex_direction.rs:221`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const ALL_DIRECTIONS: [VertexDirection; 6];

    /// The six directions as a `Span`, in index order.
    ///
    /// Mirrors `VertexDirection::iter` (`src/direction/vertex_direction.rs:225`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// `hexx` returns an `impl ExactSizeIterator`; a `Span` is the iterator of Cairo (plan §4.4).
    fn iter() -> Span<VertexDirection>;

    /// The index of the direction, in `0..=5`.
    ///
    /// Mirrors `VertexDirection::index` (`src/direction/vertex_direction.rs:232`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn index(self: VertexDirection) -> u8;

    /// The coordinates of the diagonal neighbour: `Hex::DIAGONAL_COORDS[index]`.
    ///
    /// Mirrors `VertexDirection::into_hex` (`src/direction/vertex_direction.rs:239`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn into_hex(self: VertexDirection) -> Hex;

    /// The opposite direction: `(index + 3) mod 6`.
    ///
    /// Mirrors `VertexDirection::const_neg` (`src/direction/vertex_direction.rs:253`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`; this is the plain function behind the `-` operator.
    fn const_neg(self: VertexDirection) -> VertexDirection;

    /// The next direction in `hexx`'s sense: `(index + 1) mod 6`. On a north-up map this turns
    /// counter-clockwise (see the module documentation).
    ///
    /// Mirrors `VertexDirection::clockwise` (`src/direction/vertex_direction.rs:268`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn clockwise(self: VertexDirection) -> VertexDirection;

    /// The previous direction in `hexx`'s sense: `(index + 5) mod 6`.
    ///
    /// Mirrors `VertexDirection::counter_clockwise` (`src/direction/vertex_direction.rs:286`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn counter_clockwise(self: VertexDirection) -> VertexDirection;

    /// Rotates `offset` steps of 60 degrees in the sense of `counter_clockwise`:
    /// `(index + 6 - offset mod 6) mod 6`.
    ///
    /// Mirrors `VertexDirection::rotate_ccw` (`src/direction/vertex_direction.rs:300`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// None.
    fn rotate_ccw(self: VertexDirection, offset: u8) -> VertexDirection;

    /// Rotates `offset` steps of 60 degrees in the sense of `clockwise`:
    /// `(index + offset mod 6) mod 6`.
    ///
    /// Mirrors `VertexDirection::rotate_cw` (`src/direction/vertex_direction.rs:314`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// None.
    fn rotate_cw(self: VertexDirection, offset: u8) -> VertexDirection;

    /// The edge direction counter-clockwise of the vertex: the edge `(index + 5) mod 6`.
    ///
    /// Mirrors `VertexDirection::direction_ccw` (`src/direction/vertex_direction.rs:573`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn direction_ccw(self: VertexDirection) -> EdgeDirection;

    /// The edge direction counter-clockwise of the vertex: the edge `(index + 5) mod 6`.
    ///
    /// Mirrors `VertexDirection::edge_ccw` (`src/direction/vertex_direction.rs:588`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn edge_ccw(self: VertexDirection) -> EdgeDirection;

    /// The edge direction clockwise of the vertex: the edge `index`.
    ///
    /// Mirrors `VertexDirection::direction_cw` (`src/direction/vertex_direction.rs:603`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn direction_cw(self: VertexDirection) -> EdgeDirection;

    /// The edge direction clockwise of the vertex: the edge `index`.
    ///
    /// Mirrors `VertexDirection::edge_cw` (`src/direction/vertex_direction.rs:618`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn edge_cw(self: VertexDirection) -> EdgeDirection;

    /// The two adjacent edge directions, `[edge_ccw, edge_cw]`.
    ///
    /// Mirrors `VertexDirection::edge_directions` (`src/direction/vertex_direction.rs:625`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// `hexx` returns `[EdgeDirection; 2]`; so does this port (a fixed-size array).
    fn edge_directions(self: VertexDirection) -> [EdgeDirection; 2];
}

pub impl VertexDirectionImpl of VertexDirectionTrait {
    const X_NEG_Y_NEG_Z: VertexDirection = VertexDirection { index: 0 };
    const X: VertexDirection = VertexDirection { index: 0 };
    const FLAT_RIGHT: VertexDirection = VertexDirection { index: 0 };
    const FLAT_EAST: VertexDirection = VertexDirection { index: 0 };
    const POINTY_TOP_RIGHT: VertexDirection = VertexDirection { index: 0 };
    const POINTY_NORTH_EAST: VertexDirection = VertexDirection { index: 0 };
    const X_NEG_Y_Z: VertexDirection = VertexDirection { index: 5 };
    const NEG_Y: VertexDirection = VertexDirection { index: 5 };
    const FLAT_TOP_RIGHT: VertexDirection = VertexDirection { index: 5 };
    const FLAT_NORTH_EAST: VertexDirection = VertexDirection { index: 5 };
    const POINTY_TOP: VertexDirection = VertexDirection { index: 5 };
    const POINTY_NORTH: VertexDirection = VertexDirection { index: 5 };
    const NEG_X_NEG_Y: VertexDirection = VertexDirection { index: 4 };
    const Z: VertexDirection = VertexDirection { index: 4 };
    const FLAT_TOP_LEFT: VertexDirection = VertexDirection { index: 4 };
    const FLAT_NORTH_WEST: VertexDirection = VertexDirection { index: 4 };
    const POINTY_TOP_LEFT: VertexDirection = VertexDirection { index: 4 };
    const POINTY_NORTH_WEST: VertexDirection = VertexDirection { index: 4 };
    const NEG_X_Y_Z: VertexDirection = VertexDirection { index: 3 };
    const NEG_X: VertexDirection = VertexDirection { index: 3 };
    const FLAT_LEFT: VertexDirection = VertexDirection { index: 3 };
    const FLAT_WEST: VertexDirection = VertexDirection { index: 3 };
    const POINTY_BOTTOM_LEFT: VertexDirection = VertexDirection { index: 3 };
    const POINTY_SOUTH_WEST: VertexDirection = VertexDirection { index: 3 };
    const NEG_X_Y_NEG_Z: VertexDirection = VertexDirection { index: 2 };
    const Y: VertexDirection = VertexDirection { index: 2 };
    const FLAT_BOTTOM_LEFT: VertexDirection = VertexDirection { index: 2 };
    const FLAT_SOUTH_WEST: VertexDirection = VertexDirection { index: 2 };
    const POINTY_BOTTOM: VertexDirection = VertexDirection { index: 2 };
    const POINTY_SOUTH: VertexDirection = VertexDirection { index: 2 };
    const X_Y: VertexDirection = VertexDirection { index: 1 };
    const NEG_Z: VertexDirection = VertexDirection { index: 1 };
    const FLAT_BOTTOM_RIGHT: VertexDirection = VertexDirection { index: 1 };
    const FLAT_SOUTH_EAST: VertexDirection = VertexDirection { index: 1 };
    const POINTY_BOTTOM_RIGHT: VertexDirection = VertexDirection { index: 1 };
    const POINTY_SOUTH_EAST: VertexDirection = VertexDirection { index: 1 };

    const ALL_DIRECTIONS: [VertexDirection; 6] = [
        VertexDirection { index: 0 }, VertexDirection { index: 1 }, VertexDirection { index: 2 },
        VertexDirection { index: 3 }, VertexDirection { index: 4 }, VertexDirection { index: 5 },
    ];

    #[inline]
    fn iter() -> Span<VertexDirection> {
        let all = Self::ALL_DIRECTIONS;
        all.span()
    }

    #[inline]
    fn index(self: VertexDirection) -> u8 {
        self.index
    }

    #[inline]
    fn into_hex(self: VertexDirection) -> Hex {
        let diagonal = HexTrait::DIAGONAL_COORDS;
        *diagonal.span().at(self.index.into())
    }

    #[inline]
    fn const_neg(self: VertexDirection) -> VertexDirection {
        VertexDirection { index: VertexDirectionStepsTrait::wrap(self.index + 3) }
    }

    #[inline]
    fn clockwise(self: VertexDirection) -> VertexDirection {
        VertexDirection { index: VertexDirectionStepsTrait::wrap(self.index + 1) }
    }

    #[inline]
    fn counter_clockwise(self: VertexDirection) -> VertexDirection {
        VertexDirection { index: VertexDirectionStepsTrait::wrap(self.index + 5) }
    }

    fn rotate_ccw(self: VertexDirection, offset: u8) -> VertexDirection {
        let steps = VertexDirectionStepsTrait::steps(offset);
        VertexDirection { index: VertexDirectionStepsTrait::wrap(self.index + 6 - steps) }
    }

    fn rotate_cw(self: VertexDirection, offset: u8) -> VertexDirection {
        let steps = VertexDirectionStepsTrait::steps(offset);
        VertexDirection { index: VertexDirectionStepsTrait::wrap(self.index + steps) }
    }

    #[inline]
    fn direction_ccw(self: VertexDirection) -> EdgeDirection {
        self.edge_ccw()
    }

    #[inline]
    fn edge_ccw(self: VertexDirection) -> EdgeDirection {
        EdgeDirectionIndexTrait::from_index(VertexDirectionStepsTrait::wrap(self.index + 5))
    }

    #[inline]
    fn direction_cw(self: VertexDirection) -> EdgeDirection {
        self.edge_cw()
    }

    #[inline]
    fn edge_cw(self: VertexDirection) -> EdgeDirection {
        EdgeDirectionIndexTrait::from_index(self.index)
    }

    #[inline]
    fn edge_directions(self: VertexDirection) -> [EdgeDirection; 2] {
        [self.edge_ccw(), self.edge_cw()]
    }
}

/// The index arithmetic of the rotations, private: `sum mod 6` for `sum` in `0..=11`, and
/// `offset mod 6`, which is the only division of the type.
#[generate_trait]
impl VertexDirectionStepsImpl of VertexDirectionStepsTrait {
    #[inline]
    fn wrap(sum: u8) -> u8 {
        if sum >= 6 {
            sum - 6
        } else {
            sum
        }
    }

    #[inline]
    fn steps(offset: u8) -> u8 {
        let (_, steps) = DivRem::div_rem(offset, SIX);
        steps
    }
}

/// The vertex direction of an index in `0..=5`, for the edge direction's `vertex_*` methods:
/// `pub(crate)`, the field being private. Outside the parity table and the public documentation
/// template (`pub(crate)` in `hexx`: `VertexDirection(pub(crate) u8)`). The caller guarantees
/// `index <= 5`.
#[generate_trait]
pub(crate) impl VertexDirectionIndexImpl of VertexDirectionIndexTrait {
    #[inline]
    fn from_index(index: u8) -> VertexDirection {
        VertexDirection { index }
    }
}

/// The coordinates of the diagonal neighbour.
///
/// Mirrors `impl From<VertexDirection> for Hex` (`src/direction/vertex_direction.rs:630`): Cairo
/// writes it `Into<VertexDirection, Hex>`.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The impl is `Into`, not `From`: Cairo's `From` does not exist in the corelib, `Into` is the
/// conversion trait.
pub impl VertexDirectionIntoHex of Into<VertexDirection, Hex> {
    #[inline]
    fn into(self: VertexDirection) -> Hex {
        self.into_hex()
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::hex::HexTrait;
    use super::{VertexDirection, VertexDirectionTrait};

    /// The oracle of the rotations, on every index and every count of `u8`: the index arithmetic
    /// written plainly, `(i + n) % 6` and `(i + 258 - n) % 6` (258 = 43 * 6, `n <= 255`).
    #[test]
    #[available_gas(l2_gas: 19399758)]
    fn test_vertex_direction_rotation_oracle() {
        let all = VertexDirectionTrait::iter();
        let mut i: u16 = 0;
        while i < 6 {
            let d = *all.at(i.into());
            let mut n: u16 = 0;
            while n < 256 {
                let offset: u8 = n.try_into().unwrap();
                let cw: u16 = (i + n) % 6;
                let ccw: u16 = (i + 258 - n) % 6;
                assert(d.rotate_cw(offset).index().into() == cw, 'rotate_cw');
                assert(d.rotate_ccw(offset).index().into() == ccw, 'rotate_ccw');
                n += 1;
            }
            i += 1;
        }
    }

    /// The one-step rotations and the opposite, against the same plain arithmetic.
    #[test]
    #[available_gas(l2_gas: 132668)]
    fn test_vertex_direction_steps_oracle() {
        let all = VertexDirectionTrait::iter();
        let mut i: u8 = 0;
        while i < 6 {
            let d = *all.at(i.into());
            assert(d.clockwise().index() == (i + 1) % 6, 'clockwise');
            assert(d.counter_clockwise().index() == (i + 5) % 6, 'counter_clockwise');
            assert(d.const_neg().index() == (i + 3) % 6, 'const_neg');
            assert(d.clockwise().counter_clockwise() == d, 'cw then ccw');
            assert(d.const_neg().const_neg() == d, 'const_neg twice');
            i += 1;
        }
    }

    /// The five names of each index (`src/direction/vertex_direction.rs:78-201`), as the
    /// table of the module documentation.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_vertex_direction_compass_aliases() {
        // Index 0 .. 5, in `ALL_DIRECTIONS` order: the first name of each group.
        assert(VertexDirectionTrait::X_NEG_Y_NEG_Z == VertexDirectionTrait::POINTY_NORTH_EAST, '0');
        assert(VertexDirectionTrait::X_Y == VertexDirectionTrait::POINTY_SOUTH_EAST, '1');
        assert(VertexDirectionTrait::NEG_X_Y_NEG_Z == VertexDirectionTrait::POINTY_SOUTH, '2');
        assert(VertexDirectionTrait::NEG_X_Y_Z == VertexDirectionTrait::POINTY_SOUTH_WEST, '3');
        assert(VertexDirectionTrait::NEG_X_NEG_Y == VertexDirectionTrait::POINTY_NORTH_WEST, '4');
        assert(VertexDirectionTrait::X_NEG_Y_Z == VertexDirectionTrait::POINTY_NORTH, '5');
    }

    /// A diagonal is the sum of the two neighbours it lies between: vertex `i` is edge `i - 1`
    /// plus edge `i` (the oracle of `into_hex`, from `EdgeDirection`).
    #[test]
    #[available_gas(l2_gas: 77973)]
    fn test_vertex_direction_into_hex_is_the_sum_of_its_edges() {
        let all = VertexDirectionTrait::iter();
        let mut i: u8 = 0;
        while i < 6 {
            let d = *all.at(i.into());
            let sum = d.edge_ccw().into_hex().const_add(d.edge_cw().into_hex());
            assert(d.into_hex() == sum, 'into_hex');
            i += 1;
        }
    }

    /// The links between the two types: `vertex_ccw` / `edge_cw` and `vertex_cw` / `edge_ccw` are
    /// each other's inverse, and `edge_directions` / `vertex_directions` list `[ccw, cw]`.
    #[test]
    #[available_gas(l2_gas: 105158)]
    fn test_vertex_direction_links_with_edge_direction() {
        let all = VertexDirectionTrait::iter();
        let mut i: u8 = 0;
        while i < 6 {
            let v = *all.at(i.into());
            assert(v.edge_cw().vertex_ccw() == v, 'edge_cw then vertex_ccw');
            assert(v.edge_ccw().vertex_cw() == v, 'edge_ccw then vertex_cw');
            assert(v.edge_cw() == v.direction_cw(), 'direction_cw');
            assert(v.edge_ccw() == v.direction_ccw(), 'direction_ccw');
            let [a, b] = v.edge_directions();
            assert(a == v.edge_ccw() && b == v.edge_cw(), 'edge_directions');
            i += 1;
        }
    }

    // `Serde`: a value read from calldata is always one of the six directions.

    #[test]
    #[available_gas(l2_gas: 46295)]
    fn test_vertex_direction_serde_round_trip() {
        let all = VertexDirectionTrait::iter();
        let mut i: u8 = 0;
        while i < 6 {
            let d = *all.at(i.into());
            let mut output = array![];
            Serde::serialize(@d, ref output);
            let mut serialized = output.span();
            let back: Option<VertexDirection> = Serde::deserialize(ref serialized);
            assert(back == Some(d), 'round trip');
            assert(serialized.len() == 0, 'consumed');
            i += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 999086)]
    fn test_vertex_direction_serde_refuses_an_index_above_five() {
        let mut index: u8 = 6;
        loop {
            let mut serialized = array![index.into()].span();
            let back: Option<VertexDirection> = Serde::deserialize(ref serialized);
            assert(back.is_none(), 'accepted');
            if index == 255 {
                break;
            }
            index += 1;
        }
    }

    // Benchmarks of M2-T1 (LIB-06), 17 repetitions of the six directions per test (102 calls),
    // operands as `src/tests/bench_mirror.cairo`: per call = (test − baseline) / 102. Targets
    // (`L`, `U = ceil(1.25 L)`, plan §7 has none for L-M2), derived from the L-M1 measurements
    // of `bench_mirror` (`into_hex` 1,411, `counter_clockwise` 1,868, `rotate_ccw` at 255 steps
    // 2,217) and written before the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `into_hex` | 1,411 | 1,764 |
    // | `const_neg`, `clockwise`, `counter_clockwise`, `direction_cw`, `direction_ccw`, `edge_cw`,
    // `edge_ccw` | 1,868 | 2,335 |
    // | `rotate_cw`, `rotate_ccw` (255 steps) | 2,217 | 2,772 |
    // | `edge_directions` | 3,736 (two `edge_*`) | 4,670 |

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_vertex_direction_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 521605)]
    fn bench_vertex_direction_baseline_into_hex() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let y: i32 = d.index().into();
                acc = acc ^ y.try_into().unwrap_or(0);
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 658693)]
    fn bench_vertex_direction_into_hex() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.into_hex().y.try_into().unwrap_or(0);
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 729564)]
    fn bench_vertex_direction_const_neg() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.const_neg().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 691722)]
    fn bench_vertex_direction_clockwise() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.clockwise().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 738489)]
    fn bench_vertex_direction_counter_clockwise() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.counter_clockwise().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 715550)]
    fn bench_vertex_direction_rotate_cw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.rotate_cw(offset).index();
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 771137)]
    fn bench_vertex_direction_rotate_ccw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.rotate_ccw(offset).index();
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    /// The baseline of the functions that return an `EdgeDirection`: its `index` is read.
    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_vertex_direction_edge_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_vertex_direction_edge_cw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.edge_cw().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 738489)]
    fn bench_vertex_direction_edge_ccw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.edge_ccw().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 833058)]
    fn bench_vertex_direction_edge_directions() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let [a, b] = d.edge_directions();
                acc = acc ^ a.index() ^ b.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }
}
