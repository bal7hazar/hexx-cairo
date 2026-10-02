//! Hexagonal directions, pointy-top, odd-r offset layout.
//!
//! Index convention (shared with `origami_map`): `i = y * width + x`, bit 0 is printed
//! bottom-right, `+1` is West and `+width` is North. Odd rows are drawn shifted half a tile
//! toward increasing `x` (to the left in the printout).
//!
//! | Direction | even row      | odd row       |
//! |-----------|---------------|---------------|
//! | East      | `i - 1`       | `i - 1`       |
//! | NorthEast | `i + W - 1`   | `i + W`       |
//! | NorthWest | `i + W`       | `i + W + 1`   |
//! | West      | `i + 1`       | `i + 1`       |
//! | SouthWest | `i - W`       | `i - W + 1`   |
//! | SouthEast | `i - W - 1`   | `i - W`       |
//!
//! N-7 (plan §6.8): the index of a direction (`East` 0 to `SouthEast` 5) turns
//! counter-clockwise on the north-up map, `rotate` turns by steps of 60 degrees and `arc` says in
//! which arc of an actor's facing a neighbour stands (`grimworld:docs/design/04-combat.md`
//! § Facing and arcs). `Direction` and the mirror's `EdgeDirection` share their indices: the
//! conversions both ways preserve the index (plan §3.2).

// Internal imports

use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};

// Constants

/// Number of directions.
pub const DIRECTION_COUNT: u8 = 6;
/// Width in bits of a direction in a packed permutation.
pub const DIRECTION_SIZE: NonZero<u32> = 0x10;
/// The number of directions, as a divisor.
const SIX: NonZero<u8> = 6;

/// Types.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub enum Direction {
    East,
    NorthEast,
    NorthWest,
    West,
    SouthWest,
    SouthEast,
}

/// The arc of an actor's facing in which a neighbour stands (plan §6.8, the game's
/// `docs/design/04-combat.md` § Facing and arcs): for a facing `d`, `Front` is `d`, `FrontSide`
/// is `d ± 1`, `RearSide` is `d ± 2` and `Back` is `d + 3`.
///
/// Mirrors nothing in `hexx`: an extension (N-7).
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub enum Arc {
    Front,
    FrontSide,
    RearSide,
    Back,
}

#[generate_trait]
pub impl DirectionImpl of DirectionTrait {
    /// Return the opposite direction.
    /// # Arguments
    /// * `self` - The direction
    /// # Returns
    /// * The opposite direction
    #[inline]
    fn opposite(self: Direction) -> Direction {
        match self {
            Direction::East => Direction::West,
            Direction::NorthEast => Direction::SouthWest,
            Direction::NorthWest => Direction::SouthEast,
            Direction::West => Direction::East,
            Direction::SouthWest => Direction::NorthEast,
            Direction::SouthEast => Direction::NorthWest,
        }
    }

    /// Return the neighbour index without any bound check.
    /// # Arguments
    /// * `self` - The direction
    /// * `position` - The current position, its neighbour must lie in the board
    /// * `width` - The width of the map
    /// * `odd` - Whether the position lies on an odd row
    /// # Returns
    /// * The neighbour position
    #[inline]
    fn next(self: Direction, position: u8, width: u8, odd: bool) -> u8 {
        match self {
            Direction::East => position - 1,
            Direction::NorthEast => if odd {
                position + width
            } else {
                position + width - 1
            },
            Direction::NorthWest => if odd {
                position + width + 1
            } else {
                position + width
            },
            Direction::West => position + 1,
            Direction::SouthWest => if odd {
                position + 1 - width
            } else {
                position - width
            },
            Direction::SouthEast => if odd {
                position - width
            } else {
                position - width - 1
            },
        }
    }

    /// Pop the next direction from a packed permutation (4 bits per direction, first in the
    /// lowest nibble), as returned by `Rng::shuffle6`.
    /// # Arguments
    /// * `directions` - The packed directions
    /// # Returns
    /// * The next direction
    /// # Effects
    /// * The packed directions are updated
    #[inline]
    fn pop_front(ref directions: u32) -> Direction {
        let (rest, index) = DivRem::div_rem(directions, DIRECTION_SIZE);
        directions = rest;
        match index {
            0 => Direction::East,
            1 => Direction::NorthEast,
            2 => Direction::NorthWest,
            3 => Direction::West,
            4 => Direction::SouthWest,
            _ => Direction::SouthEast,
        }
    }

    /// Rotate by `steps` steps of 60 degrees, counter-clockwise on the north-up map: the
    /// direction of index `(index + steps) mod 6`.
    /// # Arguments
    /// * `self` - The direction
    /// * `steps` - The number of steps, any `u8` (`rotate(3)` is `opposite`)
    /// # Returns
    /// * The rotated direction
    ///
    /// Mirrors nothing in `hexx`: an extension (N-7), the board's counterpart of
    /// `EdgeDirection::rotate_cw`, which is the same rotation on the mirror type.
    #[inline]
    fn rotate(self: Direction, steps: u8) -> Direction {
        // [Compute] steps mod 6, then a sum in 0..=10 wrapped once
        let (_, steps) = DivRem::div_rem(steps, SIX);
        let index: u8 = self.into();
        let sum = index + steps;
        DirectionIndexTrait::from_index(
            if sum >= DIRECTION_COUNT {
                sum - DIRECTION_COUNT
            } else {
                sum
            },
        )
    }

    /// The arc of `facing` in which the neighbour in direction `self` stands: `Front` when
    /// `(index(self) − index(facing)) mod 6` is 0, `FrontSide` for 1 and 5, `RearSide` for 2 and
    /// 4, `Back` for 3.
    /// # Arguments
    /// * `self` - The direction from the actor to the neighbour
    /// * `facing` - The facing of the actor
    /// # Returns
    /// * The arc
    ///
    /// Mirrors nothing in `hexx`: an extension (N-7).
    #[inline]
    fn arc(self: Direction, facing: Direction) -> Arc {
        // [Compute] index + 6 - facing, in 1..=11, never below zero: one arm per value
        let index: u8 = self.into();
        let facing: u8 = facing.into();
        match index + DIRECTION_COUNT - facing {
            0 => Arc::Front,
            1 => Arc::FrontSide,
            2 => Arc::RearSide,
            3 => Arc::Back,
            4 => Arc::RearSide,
            5 => Arc::FrontSide,
            6 => Arc::Front,
            7 => Arc::FrontSide,
            8 => Arc::RearSide,
            9 => Arc::Back,
            10 => Arc::RearSide,
            _ => Arc::FrontSide,
        }
    }
}

/// The direction of an index, private: the indices it receives are in `0..=5`.
#[generate_trait]
impl DirectionIndexImpl of DirectionIndexTrait {
    #[inline]
    fn from_index(index: u8) -> Direction {
        match index {
            0 => Direction::East,
            1 => Direction::NorthEast,
            2 => Direction::NorthWest,
            3 => Direction::West,
            4 => Direction::SouthWest,
            _ => Direction::SouthEast,
        }
    }
}

/// The mirror's direction of the same index (plan §3.2): `East` is `EdgeDirection::X`, index 0.
///
/// Mirrors nothing in `hexx`: an extension (N-7).
pub impl DirectionIntoEdgeDirection of Into<Direction, EdgeDirection> {
    #[inline]
    fn into(self: Direction) -> EdgeDirection {
        match self {
            Direction::East => EdgeDirectionTrait::X,
            Direction::NorthEast => EdgeDirectionTrait::Y,
            Direction::NorthWest => EdgeDirectionTrait::NEG_X_Y,
            Direction::West => EdgeDirectionTrait::NEG_X,
            Direction::SouthWest => EdgeDirectionTrait::NEG_Y,
            Direction::SouthEast => EdgeDirectionTrait::X_NEG_Y,
        }
    }
}

/// The board's direction of the same index (plan §3.2): `EdgeDirection::X`, index 0, is `East`.
///
/// Mirrors nothing in `hexx`: an extension (N-7).
pub impl EdgeDirectionIntoDirection of Into<EdgeDirection, Direction> {
    #[inline]
    fn into(self: EdgeDirection) -> Direction {
        DirectionIndexTrait::from_index(self.index())
    }
}

pub impl DirectionIntoU8 of Into<Direction, u8> {
    #[inline]
    fn into(self: Direction) -> u8 {
        match self {
            Direction::East => 0,
            Direction::NorthEast => 1,
            Direction::NorthWest => 2,
            Direction::West => 3,
            Direction::SouthWest => 4,
            Direction::SouthEast => 5,
        }
    }
}

pub impl U8TryIntoDirection of TryInto<u8, Direction> {
    #[inline]
    fn try_into(self: u8) -> Option<Direction> {
        match self {
            0 => Some(Direction::East),
            1 => Some(Direction::NorthEast),
            2 => Some(Direction::NorthWest),
            3 => Some(Direction::West),
            4 => Some(Direction::SouthWest),
            5 => Some(Direction::SouthEast),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use hexx::board::direction::Arc;
    use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
    use super::{Direction, DirectionTrait};

    const WIDTH: u8 = 7;
    /// The six directions, in index order.
    const ALL: [Direction; 6] = [
        Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
        Direction::SouthWest, Direction::SouthEast,
    ];
    /// Repetitions of the six directions in a benchmark: 102 calls.
    const REPS: u8 = 17;

    // Oracles

    #[generate_trait]
    impl Oracle of OracleTrait {
        /// `rotate` by its definition: the index `(index + steps) mod 6`, on `u16`, no reduction
        /// first.
        fn rotate(direction: Direction, steps: u8) -> u8 {
            let index: u8 = direction.into();
            let sum: u16 = index.into() + steps.into();
            (sum % 6).try_into().unwrap()
        }

        /// `arc` by the angle between the two directions: the signed difference of the indices,
        /// brought into `0..=5`, then the smaller of the two ways round (0 to 3 steps of 60
        /// degrees).
        fn arc(direction: Direction, facing: Direction) -> Arc {
            let index: u8 = direction.into();
            let facing: u8 = facing.into();
            let difference: i16 = index.into() - facing.into();
            let turn = if difference < 0 {
                difference + 6
            } else {
                difference
            };
            let angle = if turn > 3 {
                6 - turn
            } else {
                turn
            };
            if angle == 0 {
                Arc::Front
            } else if angle == 1 {
                Arc::FrontSide
            } else if angle == 2 {
                Arc::RearSide
            } else {
                Arc::Back
            }
        }

        /// The direction of a benchmark's repetition, `rep mod 6`: a span lookup, charged to
        /// both `arc` benchmarks.
        fn direction_of(rep: u8) -> Direction {
            *ALL.span().at((rep % 6).into())
        }
    }

    // N-7: rotate

    /// Every direction and every `steps` of `u8` against the definition, the mirror's `rotate_cw`
    /// and `rotate(3) == opposite`.
    #[test]
    #[available_gas(l2_gas: 21911400)]
    fn test_direction_rotate_oracle() {
        for direction in ALL.span() {
            let direction = *direction;
            let edge: EdgeDirection = direction.into();
            let mut steps: u16 = 0;
            while steps != 256 {
                let steps_u8: u8 = steps.try_into().unwrap();
                let rotated = direction.rotate(steps_u8);
                let index: u8 = rotated.into();
                assert!(index == Oracle::rotate(direction, steps_u8));
                let mirror: Direction = edge.rotate_cw(steps_u8).into();
                assert!(mirror == rotated);
                steps += 1;
            }
            assert!(direction.rotate(3) == direction.opposite());
            assert!(direction.rotate(0) == direction);
        }
    }

    /// R-N7-1 (audit pass 1, finding 10): 255 mod 6 = 3, no panic.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_direction_rotate_regression() {
        assert!(Direction::SouthEast.rotate(255) == Direction::NorthWest);
        assert!(Direction::SouthEast.rotate(255) == Direction::SouthEast.rotate(3));
        let edge: EdgeDirection = Direction::SouthEast.into();
        assert!(edge.index() == 5);
        assert!(edge.rotate_cw(255).index() == 2);
        // One step is `next` counter-clockwise on the map: East, NorthEast, ..., SouthEast, East
        assert!(Direction::East.rotate(1) == Direction::NorthEast);
        assert!(Direction::SouthEast.rotate(1) == Direction::East);
        assert!(Direction::East.rotate(5) == Direction::SouthEast);
    }

    // N-7: arc

    /// The 36 pairs against the angle between the directions.
    #[test]
    #[available_gas(l2_gas: 478023)]
    fn test_direction_arc_oracle() {
        for direction in ALL.span() {
            for facing in ALL.span() {
                assert!(direction.arc(*facing) == Oracle::arc(*direction, *facing));
            }
        }
    }

    /// The arcs of the game (`design/04-combat.md`): front `d`, front-side `d ± 1`, rear-side
    /// `d ± 2`, back `d + 3`, for every facing `d`.
    #[test]
    #[available_gas(l2_gas: 251255)]
    fn test_direction_arc_game() {
        for facing in ALL.span() {
            let facing = *facing;
            assert!(facing.arc(facing) == Arc::Front);
            assert!(facing.rotate(1).arc(facing) == Arc::FrontSide);
            assert!(facing.rotate(5).arc(facing) == Arc::FrontSide);
            assert!(facing.rotate(2).arc(facing) == Arc::RearSide);
            assert!(facing.rotate(4).arc(facing) == Arc::RearSide);
            assert!(facing.rotate(3).arc(facing) == Arc::Back);
            assert!(facing.opposite().arc(facing) == Arc::Back);
        }
    }

    /// R-N7-2: the difference wraps to 5 for `(SouthEast, East)`.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_direction_arc_regression() {
        assert!(Direction::East.arc(Direction::West) == Arc::Back);
        assert!(Direction::East.arc(Direction::NorthEast) == Arc::FrontSide);
        assert!(Direction::SouthEast.arc(Direction::East) == Arc::FrontSide);
    }

    // N-7: the conversions with `EdgeDirection`

    /// The index is preserved both ways, and both round trips are the identity.
    #[test]
    #[available_gas(l2_gas: 62360)]
    fn test_direction_into_edge_direction() {
        for direction in ALL.span() {
            let direction = *direction;
            let index: u8 = direction.into();
            let edge: EdgeDirection = direction.into();
            assert!(edge.index() == index);
            let back: Direction = edge.into();
            assert!(back == direction);
        }
        for edge in EdgeDirectionTrait::iter() {
            let edge = *edge;
            let direction: Direction = edge.into();
            let index: u8 = direction.into();
            assert!(index == edge.index());
            let back: EdgeDirection = direction.into();
            assert!(back == edge);
        }
        // The compass names of the mirror on the north-up map (plan §3.2)
        let north_east: EdgeDirection = Direction::NorthEast.into();
        assert!(north_east == EdgeDirectionTrait::POINTY_SOUTH_EAST);
        let east: Direction = EdgeDirectionTrait::POINTY_EAST.into();
        assert!(east == Direction::East);
    }

    // Benchmarks of N-7: 102 calls each, the six directions 17 times. Per-call cost =
    // (test - baseline) / 102, see `GAS.md`.

    /// The loop, the accumulator and the index of each direction.
    #[test]
    #[available_gas(l2_gas: 588370)]
    fn bench_direction_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != REPS {
            let steps: u8 = 255 - rep;
            for direction in ALL.span() {
                let index: u8 = (*direction).into();
                acc = acc ^ index ^ steps;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    /// `bench_direction_baseline` with the indices read from a span of `u8` instead of converted
    /// from the directions: the difference between both is the cost of `Into<Direction, u8>`,
    /// one `match`, and the baseline of the conversions with `EdgeDirection`.
    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_direction_baseline_index() {
        let indices: [u8; 6] = [0, 1, 2, 3, 4, 5];
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != REPS {
            let steps: u8 = 255 - rep;
            for index in indices.span() {
                acc = acc ^ *index ^ steps;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    /// `steps` from 255 down to 239: the reduction modulo 6 always runs, the sum wraps.
    #[test]
    #[available_gas(l2_gas: 865490)]
    fn bench_direction_rotate() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != REPS {
            let steps: u8 = 255 - rep;
            for direction in ALL.span() {
                let index: u8 = (*direction).rotate(steps).into();
                acc = acc ^ index;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    /// The facing turns with the repetition: every pair of directions is met.
    #[test]
    #[available_gas(l2_gas: 798605)]
    fn bench_direction_arc() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        let mut facing = Direction::SouthEast;
        while rep != REPS {
            for direction in ALL.span() {
                let arc: u8 = match (*direction).arc(facing) {
                    Arc::Front => 0,
                    Arc::FrontSide => 1,
                    Arc::RearSide => 2,
                    Arc::Back => 3,
                };
                acc = acc ^ arc;
            }
            facing = Oracle::direction_of(rep);
            rep += 1;
        }
        assert!(acc != 200);
    }

    /// The baseline of `arc`: the same loop and the same facing, the arc replaced by the index.
    #[test]
    #[available_gas(l2_gas: 665199)]
    fn bench_direction_arc_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        let mut facing = Direction::SouthEast;
        while rep != REPS {
            for direction in ALL.span() {
                let index: u8 = (*direction).into();
                let facing_index: u8 = facing.into();
                acc = acc ^ index ^ facing_index;
            }
            facing = Oracle::direction_of(rep);
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 588370)]
    fn bench_direction_into_edge_direction() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != REPS {
            let steps: u8 = 255 - rep;
            for direction in ALL.span() {
                let edge: EdgeDirection = (*direction).into();
                acc = acc ^ edge.index() ^ steps;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    /// The baseline is `EdgeDirection`'s own: the loop over `iter` and the index.
    #[test]
    #[available_gas(l2_gas: 638350)]
    fn bench_edge_direction_into_direction() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != REPS {
            let steps: u8 = 255 - rep;
            for edge in EdgeDirectionTrait::iter() {
                let direction: Direction = (*edge).into();
                let index: u8 = direction.into();
                acc = acc ^ index ^ steps;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    /// The baseline of `bench_edge_direction_into_direction`.
    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_edge_direction_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != REPS {
            let steps: u8 = 255 - rep;
            for edge in EdgeDirectionTrait::iter() {
                acc = acc ^ (*edge).index() ^ steps;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 50295)]
    fn test_direction_opposite() {
        let mut index: u8 = 0;
        while index != 6 {
            let direction: Direction = index.try_into().unwrap();
            assert!(direction.opposite().opposite() == direction);
            assert!(direction.opposite() != direction);
            let opposite: u8 = direction.opposite().into();
            assert!(opposite == (index + 3) % 6);
            index += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 22890)]
    fn test_direction_round_trip() {
        let mut index: u8 = 0;
        while index != 6 {
            let direction: Direction = index.try_into().unwrap();
            let back: u8 = direction.into();
            assert!(back == index);
            index += 1;
        }
        let none: Option<Direction> = 6_u8.try_into();
        assert!(none.is_none());
    }

    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_direction_next_even_row() {
        // (3, 2) = 17
        let position = 2 * WIDTH + 3;
        assert!(Direction::East.next(position, WIDTH, false) == 2 * WIDTH + 2);
        assert!(Direction::West.next(position, WIDTH, false) == 2 * WIDTH + 4);
        assert!(Direction::NorthEast.next(position, WIDTH, false) == 3 * WIDTH + 2);
        assert!(Direction::NorthWest.next(position, WIDTH, false) == 3 * WIDTH + 3);
        assert!(Direction::SouthEast.next(position, WIDTH, false) == 1 * WIDTH + 2);
        assert!(Direction::SouthWest.next(position, WIDTH, false) == 1 * WIDTH + 3);
    }

    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_direction_next_odd_row() {
        // (3, 3) = 24
        let position = 3 * WIDTH + 3;
        assert!(Direction::East.next(position, WIDTH, true) == 3 * WIDTH + 2);
        assert!(Direction::West.next(position, WIDTH, true) == 3 * WIDTH + 4);
        assert!(Direction::NorthEast.next(position, WIDTH, true) == 4 * WIDTH + 3);
        assert!(Direction::NorthWest.next(position, WIDTH, true) == 4 * WIDTH + 4);
        assert!(Direction::SouthEast.next(position, WIDTH, true) == 2 * WIDTH + 3);
        assert!(Direction::SouthWest.next(position, WIDTH, true) == 2 * WIDTH + 4);
    }

    #[test]
    #[available_gas(l2_gas: 41055)]
    fn test_direction_next_opposite_round_trip() {
        let mut index: u8 = 0;
        while index != 6 {
            let direction: Direction = index.try_into().unwrap();
            // Even row start, the neighbour of a vertical move lies on an odd row
            let position = 2 * WIDTH + 3;
            let vertical = index == 1 || index == 2 || index == 4 || index == 5;
            let next = direction.next(position, WIDTH, false);
            assert!(direction.opposite().next(next, WIDTH, vertical) == position);
            index += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_direction_pop_front() {
        let mut directions: u32 = 0x501234;
        assert!(DirectionTrait::pop_front(ref directions) == Direction::SouthWest);
        assert!(DirectionTrait::pop_front(ref directions) == Direction::West);
        assert!(DirectionTrait::pop_front(ref directions) == Direction::NorthWest);
        assert!(DirectionTrait::pop_front(ref directions) == Direction::NorthEast);
        assert!(DirectionTrait::pop_front(ref directions) == Direction::East);
        assert!(DirectionTrait::pop_front(ref directions) == Direction::SouthEast);
        assert!(directions == 0);
    }
}
