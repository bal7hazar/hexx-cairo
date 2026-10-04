//! `EdgeDirection`: one of the six edge directions of a hexagon, the mirror of
//! `hexx::EdgeDirection` (`src/direction/edge_direction.rs`).
//!
//! **The compass constants are `hexx`'s, verbatim, and assume a screen with y pointing down.** On
//! the north-up map of the board engine, `POINTY_SOUTH_EAST` (index 1) is the *north-east*
//! neighbour and `clockwise` turns *counter-clockwise* (plan §3.2, LIB-02 §3.1). The names are
//! not changed. The board keeps its own `Direction` (`East` ... `SouthEast`, north up) with the
//! same indices:
//!
//! | Index | `EdgeDirection` (y down)                                               | `Direction`
//! (north up) |
//! |-------|------------------------------------------------------------------------|------------------------|
//! | 0     | `X`, `POINTY_EAST`, `POINTY_RIGHT`, `FLAT_SOUTH_EAST`, `FLAT_BOTTOM_RIGHT`   | `East`
//! |
//! | 1     | `Y`, `POINTY_SOUTH_EAST`, `POINTY_BOTTOM_RIGHT`, `FLAT_SOUTH`, `FLAT_BOTTOM` |
//! `NorthEast` |
//! | 2     | `NEG_X_Y`, `POINTY_SOUTH_WEST`, `POINTY_BOTTOM_LEFT`, `FLAT_SOUTH_WEST`,
//! `FLAT_BOTTOM_LEFT` | `NorthWest` |
//! | 3     | `NEG_X`, `POINTY_WEST`, `POINTY_LEFT`, `FLAT_NORTH_WEST`, `FLAT_TOP_LEFT`    | `West`
//! |
//! | 4     | `NEG_Y`, `POINTY_NORTH_WEST`, `POINTY_TOP_LEFT`, `FLAT_NORTH`, `FLAT_TOP`    |
//! `SouthWest` |
//! | 5     | `X_NEG_Y`, `POINTY_NORTH_EAST`, `POINTY_TOP_RIGHT`, `FLAT_NORTH_EAST`,
//! `FLAT_TOP_RIGHT` | `SouthEast` |
//!
//! `hexx`'s iterator (`iter`, `impl ExactSizeIterator`) is an eager `Span` here: a `Span` is the
//! iterator of Cairo (plan §4.4, "Span" counterparts).

use core::fmt::{Debug, Error, Formatter};
use crate::direction::vertex_direction::{VertexDirection, VertexDirectionIndexTrait};
use crate::hex::{Hex, HexTrait};

/// The number of directions, as a divisor.
const SIX: NonZero<u8> = 6;

/// One of the six edge directions of a hexagon, an index in `0..=5`.
///
/// Mirrors `hexx::EdgeDirection` (`src/direction/edge_direction.rs:75`), a `struct
/// EdgeDirection(u8)`.
///
/// #### Panics
///
/// None: the field is private and every constant, and every result of a method, is in `0..=5`.
///
/// #### Deviations
///
/// Cairo has no tuple structs: the field is named `index`. It stays private so that `index()` is
/// the only reader, as `pub(crate)` is in `hexx` (plan §3.2). `Default` (index 0) and `Hash` are
/// derived, as in `hexx` (`src/direction/edge_direction.rs:68-69`). `Debug` is written by hand and
/// prints what `hexx`'s does (`EdgeDirection { index: 0, x: 1, y: 0, z: -1 }`,
/// `src/direction/edge_direction.rs:635`). `Serde` is written by hand: `deserialize` returns `None`
/// for an index above 5, so that a value read from calldata is always one of the six directions. A
/// derived `Serde` would accept any `u8`, as `hexx`'s `serde` derive does (feature `serde`);
/// `into_hex` would then panic on its table of six entries, and `rotate_cw` could return an index
/// outside `0..=5`.
#[derive(Copy, Drop, PartialEq, Default, Hash)]
pub struct EdgeDirection {
    index: u8,
}

/// `Serde` of `EdgeDirection`: one felt, the index, as the derived impl writes it; reading refuses
/// an index above 5. Private, like a derived impl (Cairo finds it all the same).
impl EdgeDirectionSerde of Serde<EdgeDirection> {
    fn serialize(self: @EdgeDirection, ref output: Array<felt252>) {
        Serde::<u8>::serialize(self.index, ref output);
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<EdgeDirection> {
        let index: u8 = Serde::<u8>::deserialize(ref serialized)?;
        if index > 5 {
            return None;
        }
        Some(EdgeDirection { index })
    }
}

/// The items of `impl EdgeDirection` of milestones L-M1 and L-M2.
pub trait EdgeDirectionTrait {
    /// The direction towards `(1, -1)`, index 5.
    ///
    /// Mirrors `EdgeDirection::X_NEG_Y` (`src/direction/edge_direction.rs:79`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const X_NEG_Y: EdgeDirection;

    /// The direction towards `(1, -1)`, index 5: `FLAT_TOP_RIGHT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_TOP_RIGHT` (`src/direction/edge_direction.rs:83`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_TOP_RIGHT: EdgeDirection;

    /// The direction towards `(1, -1)`, index 5: `FLAT_NORTH_EAST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_NORTH_EAST` (`src/direction/edge_direction.rs:87`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_NORTH_EAST: EdgeDirection;

    /// The direction towards `(1, -1)`, index 5: `POINTY_TOP_RIGHT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_TOP_RIGHT` (`src/direction/edge_direction.rs:91`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_TOP_RIGHT: EdgeDirection;

    /// The direction towards `(1, -1)`, index 5: `POINTY_NORTH_EAST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_NORTH_EAST` (`src/direction/edge_direction.rs:95`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_NORTH_EAST: EdgeDirection;

    /// The direction towards `(0, -1)`, index 4.
    ///
    /// Mirrors `EdgeDirection::NEG_Y` (`src/direction/edge_direction.rs:98`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_Y: EdgeDirection;

    /// The direction towards `(0, -1)`, index 4: `FLAT_TOP`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_TOP` (`src/direction/edge_direction.rs:102`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_TOP: EdgeDirection;

    /// The direction towards `(0, -1)`, index 4: `FLAT_NORTH`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_NORTH` (`src/direction/edge_direction.rs:106`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_NORTH: EdgeDirection;

    /// The direction towards `(0, -1)`, index 4: `POINTY_TOP_LEFT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_TOP_LEFT` (`src/direction/edge_direction.rs:110`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_TOP_LEFT: EdgeDirection;

    /// The direction towards `(0, -1)`, index 4: `POINTY_NORTH_WEST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_NORTH_WEST` (`src/direction/edge_direction.rs:114`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_NORTH_WEST: EdgeDirection;

    /// The direction towards `(-1, 0)`, index 3.
    ///
    /// Mirrors `EdgeDirection::NEG_X` (`src/direction/edge_direction.rs:117`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_X: EdgeDirection;

    /// The direction towards `(-1, 0)`, index 3: `FLAT_TOP_LEFT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_TOP_LEFT` (`src/direction/edge_direction.rs:121`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_TOP_LEFT: EdgeDirection;

    /// The direction towards `(-1, 0)`, index 3: `FLAT_NORTH_WEST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_NORTH_WEST` (`src/direction/edge_direction.rs:125`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_NORTH_WEST: EdgeDirection;

    /// The direction towards `(-1, 0)`, index 3: `POINTY_LEFT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_LEFT` (`src/direction/edge_direction.rs:129`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_LEFT: EdgeDirection;

    /// The direction towards `(-1, 0)`, index 3: `POINTY_WEST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_WEST` (`src/direction/edge_direction.rs:133`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_WEST: EdgeDirection;

    /// The direction towards `(-1, 1)`, index 2.
    ///
    /// Mirrors `EdgeDirection::NEG_X_Y` (`src/direction/edge_direction.rs:136`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_X_Y: EdgeDirection;

    /// The direction towards `(-1, 1)`, index 2: `FLAT_BOTTOM_LEFT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_BOTTOM_LEFT` (`src/direction/edge_direction.rs:140`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_BOTTOM_LEFT: EdgeDirection;

    /// The direction towards `(-1, 1)`, index 2: `FLAT_SOUTH_WEST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_SOUTH_WEST` (`src/direction/edge_direction.rs:144`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_SOUTH_WEST: EdgeDirection;

    /// The direction towards `(-1, 1)`, index 2: `POINTY_BOTTOM_LEFT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_BOTTOM_LEFT` (`src/direction/edge_direction.rs:148`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_BOTTOM_LEFT: EdgeDirection;

    /// The direction towards `(-1, 1)`, index 2: `POINTY_SOUTH_WEST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_SOUTH_WEST` (`src/direction/edge_direction.rs:152`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_SOUTH_WEST: EdgeDirection;

    /// The direction towards `(0, 1)`, index 1.
    ///
    /// Mirrors `EdgeDirection::Y` (`src/direction/edge_direction.rs:155`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const Y: EdgeDirection;

    /// The direction towards `(0, 1)`, index 1: `FLAT_BOTTOM`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_BOTTOM` (`src/direction/edge_direction.rs:159`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_BOTTOM: EdgeDirection;

    /// The direction towards `(0, 1)`, index 1: `FLAT_SOUTH`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_SOUTH` (`src/direction/edge_direction.rs:163`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_SOUTH: EdgeDirection;

    /// The direction towards `(0, 1)`, index 1: `POINTY_BOTTOM_RIGHT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_BOTTOM_RIGHT` (`src/direction/edge_direction.rs:167`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_BOTTOM_RIGHT: EdgeDirection;

    /// The direction towards `(0, 1)`, index 1: `POINTY_SOUTH_EAST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_SOUTH_EAST` (`src/direction/edge_direction.rs:171`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_SOUTH_EAST: EdgeDirection;

    /// The direction towards `(1, 0)`, index 0.
    ///
    /// Mirrors `EdgeDirection::X` (`src/direction/edge_direction.rs:174`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const X: EdgeDirection;

    /// The direction towards `(1, 0)`, index 0: `FLAT_BOTTOM_RIGHT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_BOTTOM_RIGHT` (`src/direction/edge_direction.rs:178`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_BOTTOM_RIGHT: EdgeDirection;

    /// The direction towards `(1, 0)`, index 0: `FLAT_SOUTH_EAST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::FLAT_SOUTH_EAST` (`src/direction/edge_direction.rs:182`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const FLAT_SOUTH_EAST: EdgeDirection;

    /// The direction towards `(1, 0)`, index 0: `POINTY_RIGHT`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_RIGHT` (`src/direction/edge_direction.rs:186`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_RIGHT: EdgeDirection;

    /// The direction towards `(1, 0)`, index 0: `POINTY_EAST`, a compass alias.
    ///
    /// Mirrors `EdgeDirection::POINTY_EAST` (`src/direction/edge_direction.rs:190`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const POINTY_EAST: EdgeDirection;

    /// All six directions, in index order, matching `Hex::NEIGHBORS_COORDS`.
    ///
    /// Mirrors `EdgeDirection::ALL_DIRECTIONS` (`src/direction/edge_direction.rs:208`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const ALL_DIRECTIONS: [EdgeDirection; 6];

    /// The six directions as a `Span`, in index order.
    ///
    /// Mirrors `EdgeDirection::iter` (`src/direction/edge_direction.rs:212`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// `hexx` returns an `impl ExactSizeIterator`; a `Span` is the iterator of Cairo (plan §4.4).
    fn iter() -> Span<EdgeDirection>;

    /// The index of the direction, in `0..=5`.
    ///
    /// Mirrors `EdgeDirection::index` (`src/direction/edge_direction.rs:219`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn index(self: EdgeDirection) -> u8;

    /// The neighbour coordinates of the direction: `Hex::NEIGHBORS_COORDS[index]`.
    ///
    /// Mirrors `EdgeDirection::into_hex` (`src/direction/edge_direction.rs:226`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn into_hex(self: EdgeDirection) -> Hex;

    /// The opposite direction: `(index + 3) mod 6`.
    ///
    /// Mirrors `EdgeDirection::const_neg` (`src/direction/edge_direction.rs:243`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Cairo has no `const fn`; this is the plain function behind the `-` operator of L-M2.
    fn const_neg(self: EdgeDirection) -> EdgeDirection;

    /// The next direction in `hexx`'s sense: `(index + 1) mod 6`. On a north-up map this turns
    /// counter-clockwise (see the module documentation).
    ///
    /// Mirrors `EdgeDirection::clockwise` (`src/direction/edge_direction.rs:261`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn clockwise(self: EdgeDirection) -> EdgeDirection;

    /// The previous direction in `hexx`'s sense: `(index + 5) mod 6`.
    ///
    /// Mirrors `EdgeDirection::counter_clockwise` (`src/direction/edge_direction.rs:279`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn counter_clockwise(self: EdgeDirection) -> EdgeDirection;

    /// Rotates `offset` steps of 60 degrees in the sense of `counter_clockwise`:
    /// `(index + 6 - offset mod 6) mod 6`.
    ///
    /// Mirrors `EdgeDirection::rotate_ccw` (`src/direction/edge_direction.rs:296`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// None.
    fn rotate_ccw(self: EdgeDirection, offset: u8) -> EdgeDirection;

    /// Rotates `offset` steps of 60 degrees in the sense of `clockwise`:
    /// `(index + offset mod 6) mod 6`.
    ///
    /// Mirrors `EdgeDirection::rotate_cw` (`src/direction/edge_direction.rs:313`).
    ///
    /// #### Panics
    ///
    /// None: every `offset` in `0..=255` is defined.
    ///
    /// #### Deviations
    ///
    /// None.
    fn rotate_cw(self: EdgeDirection, offset: u8) -> EdgeDirection;

    /// The vertex direction counter-clockwise of the edge, `vertex_ccw`: the vertex `index`.
    ///
    /// Mirrors `EdgeDirection::diagonal_ccw` (`src/direction/edge_direction.rs:571`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn diagonal_ccw(self: EdgeDirection) -> VertexDirection;

    /// The vertex direction counter-clockwise of the edge: the vertex `index`.
    ///
    /// Mirrors `EdgeDirection::vertex_ccw` (`src/direction/edge_direction.rs:586`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn vertex_ccw(self: EdgeDirection) -> VertexDirection;

    /// The vertex direction clockwise of the edge, `vertex_cw`: the vertex `(index + 1) mod 6`.
    ///
    /// Mirrors `EdgeDirection::diagonal_cw` (`src/direction/edge_direction.rs:601`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn diagonal_cw(self: EdgeDirection) -> VertexDirection;

    /// The vertex direction clockwise of the edge: the vertex `(index + 1) mod 6`.
    ///
    /// Mirrors `EdgeDirection::vertex_cw` (`src/direction/edge_direction.rs:616`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn vertex_cw(self: EdgeDirection) -> VertexDirection;

    /// The two adjacent vertex directions, `[vertex_ccw, vertex_cw]`.
    ///
    /// Mirrors `EdgeDirection::vertex_directions` (`src/direction/edge_direction.rs:623`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn vertex_directions(self: EdgeDirection) -> [VertexDirection; 2];
}

pub impl EdgeDirectionImpl of EdgeDirectionTrait {
    const X_NEG_Y: EdgeDirection = EdgeDirection { index: 5 };
    const FLAT_TOP_RIGHT: EdgeDirection = EdgeDirection { index: 5 };
    const FLAT_NORTH_EAST: EdgeDirection = EdgeDirection { index: 5 };
    const POINTY_TOP_RIGHT: EdgeDirection = EdgeDirection { index: 5 };
    const POINTY_NORTH_EAST: EdgeDirection = EdgeDirection { index: 5 };
    const NEG_Y: EdgeDirection = EdgeDirection { index: 4 };
    const FLAT_TOP: EdgeDirection = EdgeDirection { index: 4 };
    const FLAT_NORTH: EdgeDirection = EdgeDirection { index: 4 };
    const POINTY_TOP_LEFT: EdgeDirection = EdgeDirection { index: 4 };
    const POINTY_NORTH_WEST: EdgeDirection = EdgeDirection { index: 4 };
    const NEG_X: EdgeDirection = EdgeDirection { index: 3 };
    const FLAT_TOP_LEFT: EdgeDirection = EdgeDirection { index: 3 };
    const FLAT_NORTH_WEST: EdgeDirection = EdgeDirection { index: 3 };
    const POINTY_LEFT: EdgeDirection = EdgeDirection { index: 3 };
    const POINTY_WEST: EdgeDirection = EdgeDirection { index: 3 };
    const NEG_X_Y: EdgeDirection = EdgeDirection { index: 2 };
    const FLAT_BOTTOM_LEFT: EdgeDirection = EdgeDirection { index: 2 };
    const FLAT_SOUTH_WEST: EdgeDirection = EdgeDirection { index: 2 };
    const POINTY_BOTTOM_LEFT: EdgeDirection = EdgeDirection { index: 2 };
    const POINTY_SOUTH_WEST: EdgeDirection = EdgeDirection { index: 2 };
    const Y: EdgeDirection = EdgeDirection { index: 1 };
    const FLAT_BOTTOM: EdgeDirection = EdgeDirection { index: 1 };
    const FLAT_SOUTH: EdgeDirection = EdgeDirection { index: 1 };
    const POINTY_BOTTOM_RIGHT: EdgeDirection = EdgeDirection { index: 1 };
    const POINTY_SOUTH_EAST: EdgeDirection = EdgeDirection { index: 1 };
    const X: EdgeDirection = EdgeDirection { index: 0 };
    const FLAT_BOTTOM_RIGHT: EdgeDirection = EdgeDirection { index: 0 };
    const FLAT_SOUTH_EAST: EdgeDirection = EdgeDirection { index: 0 };
    const POINTY_RIGHT: EdgeDirection = EdgeDirection { index: 0 };
    const POINTY_EAST: EdgeDirection = EdgeDirection { index: 0 };
    const ALL_DIRECTIONS: [EdgeDirection; 6] = [
        EdgeDirection { index: 0 }, EdgeDirection { index: 1 }, EdgeDirection { index: 2 },
        EdgeDirection { index: 3 }, EdgeDirection { index: 4 }, EdgeDirection { index: 5 },
    ];

    #[inline]
    fn iter() -> Span<EdgeDirection> {
        let all = Self::ALL_DIRECTIONS;
        all.span()
    }

    #[inline]
    fn index(self: EdgeDirection) -> u8 {
        self.index
    }

    #[inline]
    fn into_hex(self: EdgeDirection) -> Hex {
        let neighbors = HexTrait::NEIGHBORS_COORDS;
        *neighbors.span().at(self.index.into())
    }

    #[inline]
    fn const_neg(self: EdgeDirection) -> EdgeDirection {
        EdgeDirection { index: EdgeDirectionStepsTrait::wrap(self.index + 3) }
    }

    #[inline]
    fn clockwise(self: EdgeDirection) -> EdgeDirection {
        EdgeDirection { index: EdgeDirectionStepsTrait::wrap(self.index + 1) }
    }

    #[inline]
    fn counter_clockwise(self: EdgeDirection) -> EdgeDirection {
        EdgeDirection { index: EdgeDirectionStepsTrait::wrap(self.index + 5) }
    }

    fn rotate_ccw(self: EdgeDirection, offset: u8) -> EdgeDirection {
        let steps = EdgeDirectionStepsTrait::steps(offset);
        EdgeDirection { index: EdgeDirectionStepsTrait::wrap(self.index + 6 - steps) }
    }

    fn rotate_cw(self: EdgeDirection, offset: u8) -> EdgeDirection {
        let steps = EdgeDirectionStepsTrait::steps(offset);
        EdgeDirection { index: EdgeDirectionStepsTrait::wrap(self.index + steps) }
    }

    #[inline]
    fn diagonal_ccw(self: EdgeDirection) -> VertexDirection {
        self.vertex_ccw()
    }

    #[inline]
    fn vertex_ccw(self: EdgeDirection) -> VertexDirection {
        VertexDirectionIndexTrait::from_index(self.index)
    }

    #[inline]
    fn diagonal_cw(self: EdgeDirection) -> VertexDirection {
        self.vertex_cw()
    }

    #[inline]
    fn vertex_cw(self: EdgeDirection) -> VertexDirection {
        VertexDirectionIndexTrait::from_index(EdgeDirectionStepsTrait::wrap(self.index + 1))
    }

    #[inline]
    fn vertex_directions(self: EdgeDirection) -> [VertexDirection; 2] {
        [self.vertex_ccw(), self.vertex_cw()]
    }
}

/// The index arithmetic of the rotations, private: `sum mod 6` for `sum` in `0..=11`, and
/// `offset mod 6`, which is the only division of the type.
#[generate_trait]
impl EdgeDirectionStepsImpl of EdgeDirectionStepsTrait {
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

/// The edge direction of an index in `0..=5`, for the vertex direction's `edge_*` methods:
/// `pub(crate)`, the field being private. Outside the parity table and the public documentation
/// template (`pub(crate)` in `hexx`: `EdgeDirection(pub(crate) u8)`). The caller guarantees
/// `index <= 5`.
#[generate_trait]
pub(crate) impl EdgeDirectionIndexImpl of EdgeDirectionIndexTrait {
    #[inline]
    fn from_index(index: u8) -> EdgeDirection {
        EdgeDirection { index }
    }
}

/// `Debug` of `EdgeDirection`, as `hexx`'s: `EdgeDirection { index: 0, x: 1, y: 0, z: -1 }`.
///
/// Mirrors `impl Debug for EdgeDirection` (`src/direction/edge_direction.rs:635`).
pub impl EdgeDirectionDebug of Debug<EdgeDirection> {
    fn fmt(self: @EdgeDirection, ref f: Formatter) -> Result<(), Error> {
        let c = (*self).into_hex();
        write!(
            f, "EdgeDirection {{ index: {}, x: {}, y: {}, z: {} }}", *self.index, c.x, c.y, c.z(),
        )
    }
}

/// The neighbour coordinates of the direction.
///
/// Mirrors `impl From<EdgeDirection> for Hex` (`src/direction/edge_direction.rs:628`): Cairo
/// writes it `Into<EdgeDirection, Hex>`.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The impl is `Into`, not `From`: Cairo's `From` does not exist in the corelib, `Into` is the
/// conversion trait.
pub impl EdgeDirectionIntoHex of Into<EdgeDirection, Hex> {
    #[inline]
    fn into(self: EdgeDirection) -> Hex {
        self.into_hex()
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::vertex_direction::VertexDirectionTrait;
    use super::EdgeDirectionTrait;

    /// The links to the vertex directions, against the index arithmetic written plainly: the
    /// vertex counter-clockwise of edge `i` is vertex `i`, the one clockwise of it is `(i + 1) %
    /// 6`.
    #[test]
    #[available_gas(l2_gas: 130589)]
    fn test_edge_direction_links_with_vertex_direction() {
        let all = EdgeDirectionTrait::iter();
        let vertices = VertexDirectionTrait::iter();
        let mut i: u8 = 0;
        while i < 6 {
            let e = *all.at(i.into());
            assert(e.vertex_ccw() == *vertices.at(i.into()), 'vertex_ccw');
            assert(e.diagonal_ccw() == *vertices.at(i.into()), 'diagonal_ccw');
            assert(e.vertex_cw() == *vertices.at(((i + 1) % 6).into()), 'vertex_cw');
            assert(e.diagonal_cw() == *vertices.at(((i + 1) % 6).into()), 'diagonal_cw');
            let [a, b] = e.vertex_directions();
            assert(a == e.vertex_ccw() && b == e.vertex_cw(), 'vertex_directions');
            // The vertex of an edge leads back to the edge on the right side.
            assert(e.vertex_ccw().edge_cw() == e, 'vertex_ccw then edge_cw');
            assert(e.vertex_cw().edge_ccw() == e, 'vertex_cw then edge_ccw');
            i += 1;
        }
    }

    // Benchmarks of M2-T1 (LIB-06), as `vertex_direction`'s: 17 repetitions of the six directions,
    // per call = (test − `bench_edge_direction_vertex_baseline`) / 102. Targets (`L`,
    // `U = ceil(1.25 L)`), from `counter_clockwise` 1,868 of the L-M1 measurements, written before
    // the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `diagonal_cw`, `diagonal_ccw`, `vertex_cw`, `vertex_ccw` | 1,868 | 2,335 |
    // | `vertex_directions` | 3,736 (two `vertex_*`) | 4,670 |

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_edge_direction_vertex_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 691722)]
    fn bench_edge_direction_vertex_cw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.vertex_cw().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_edge_direction_vertex_ccw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.vertex_ccw().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 691722)]
    fn bench_edge_direction_diagonal_cw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.diagonal_cw().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_edge_direction_diagonal_ccw() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc = acc ^ d.diagonal_ccw().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 786291)]
    fn bench_edge_direction_vertex_directions() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let [a, b] = d.vertex_directions();
                acc = acc ^ a.index() ^ b.index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }
}
