//! `algorithms::fov`: `range_fov` and `directional_fov` of `hexx` (`src/algorithms/fov.rs`), on
//! a `HexMap`.
//!
//! One walk per hex of the ring: the accumulators of the line with the game's tie rule (plan
//! §6.6, those of `HexTrait::line_to` and `LineInternal::walk`), from the start towards the ring
//! hex, on the board, stopped at the first tile off the board or a wall. The walk tracks the tile
//! index, its column and its row, so that a line leaving the board stops there instead of being
//! refused (`LineTrait::line` is `None` for such a line, D-27).

// Internal imports

use crate::board::asserter::Asserter;
use crate::board::bits::Bits;
use crate::board::direction::Direction;
use crate::board::map::HexMap;
use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::direction::vertex_direction::VertexDirection;
use crate::direction::way::DirectionWayTrait;
use crate::hex::HexTrait;

// Constants

/// The six sides of a ring, as `Hex` moves: the ring of radius `r` starts at `(−r, r)` and walks
/// `r` steps along each move in turn.
const SIDES: [(i32, i32); 6] = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];

/// The tiles of the board visible from `from` up to `range`: walls and the edge of the board block
/// the sight.
///
/// A free function: it mirrors the free function of `hexx` at the same path
/// (`hexx::algorithms::range_fov`), and the mirror keeps `hexx`'s names and paths (principle 8),
/// as `a_star` does (D-143's written reason).
///
/// For every hex `t` of the ring of radius `range` around the `Hex` of `from` (the whole ring,
/// `6 × range` hexes, on the board or not; the start itself for `range` 0), the line from the
/// start to `t` with the game's tie rule, both ends included, is cut before its first tile that is
/// off the board or a wall (`hexx`'s `take_while(!blocking)`, `fov.rs:32`, with `blocking(h) = h
/// off the board or a wall`). The result is the union of those prefixes. So the start is in it
/// unless it is a wall, and a wall never is.
///
/// Mirrors `hexx::algorithms::range_fov` (`src/algorithms/fov.rs:29`).
///
/// #### Panics
///
/// * If `from` is outside the board (`'Asserter: position not inside'`, no counterpart in
/// `hexx`).
///
/// #### Deviations
///
/// * The lines carry the game's tie rule (plan §6.6: at an exact tie, the lower tile index), as
/// `LineTrait::line` and `line_of_sight`, where `hexx`'s `line_to` rounds `f32`
/// (`src/hex/mod.rs:903`): the two may differ at a tie. `docs/deviations/fov_ties.md` lists every
/// input of the golden vectors where they do, with its tie.
/// * No `blocking` closure: the blocking set is the walls of the map and every hex off the board.
/// * The result is a bitmap of tile indices, `hexx`'s a `HashSet<Hex>`.
/// * `range` is a `u8`, `hexx`'s a `u32`.
/// * A tile of the result lies on a line to a ring hex, with no blocking tile before it on that
/// line; it is not necessarily visible on its own line from `from` (`LineTrait::line_of_sight`),
/// as in `hexx`.
pub fn range_fov(map: HexMap, from: u8, range: u8) -> felt252 {
    Fov::fov(map, from, range, Option::None)
}

/// The tiles of the board visible from `from` up to `range`, in the 120° cone facing `direction`:
/// walls and the edge of the board block the sight.
///
/// A free function: it mirrors the free function of `hexx` at the same path
/// (`hexx::algorithms::directional_fov`), and the mirror keeps `hexx`'s names and paths
/// (principle 8), as `a_star` does (D-143's written reason).
///
/// As `range_fov`, over the ring hexes `t` whose `diagonal_way_to` from the start contains one
/// of the two vertex directions of `direction` (`direction.vertex_directions()`, `fov.rs:67-73`;
/// a `Tie` way counts when either of its directions matches, as `hexx`'s `PartialEq<T>` of
/// `DirectionWay`, `src/direction/way.rs:42-46`).
///
/// Mirrors `hexx::algorithms::directional_fov` (`src/algorithms/fov.rs:61`).
///
/// #### Panics
///
/// * If `from` is outside the board (`'Asserter: position not inside'`, no counterpart in
/// `hexx`).
///
/// #### Deviations
///
/// * Those of `range_fov`: the game's tie rule on the lines, the walls and the edge of the board
/// as the blocking set, a bitmap of tile indices, `range` a `u8`.
pub fn directional_fov(map: HexMap, from: u8, range: u8, direction: EdgeDirection) -> felt252 {
    Fov::fov(map, from, range, Option::Some(direction))
}

/// The board as the walk reads it.
#[derive(Copy, Drop)]
struct Board {
    width: u8,
    /// `W − 1` and `H − 1`.
    last_column: u8,
    last_row: u8,
    /// The limbs of the grid, `1` walkable.
    low: u128,
    high: u128,
}

/// A tile of a walk: its index, column and row.
#[derive(Copy, Drop)]
struct Tile {
    index: u8,
    column: u8,
    row: u8,
}

#[generate_trait]
impl Fov of FovTrait {
    /// The field of view, every ring hex or those of the cone of `facing`.
    fn fov(map: HexMap, from: u8, range: u8, facing: Option<EdgeDirection>) -> felt252 {
        // [Check] The start inside the board
        Asserter::assert_inside(map.width, map.height, from);
        let grid: u256 = map.grid.into();
        let board = Board {
            width: map.width,
            last_column: map.width - 1,
            last_row: map.height - 1,
            low: grid.low,
            high: grid.high,
        };
        // [Check] A wall at the start blocks every line
        if !Self::walkable(@board, from) {
            return 0;
        }
        let (row, column) = DivRem::div_rem(from, map.width.try_into().unwrap());
        let start = Tile { index: from, column, row };
        let vertices = match facing {
            Option::Some(direction) => Option::Some(direction.vertex_directions()),
            Option::None => Option::None,
        };
        // [Compute] The ring, side by side from `(−r, r)`; the start alone for range 0
        let mut seen: (u128, u128) = (0, 0);
        let mut any = false;
        if range == 0 {
            if Self::faces(vertices, 0, 0) {
                any = true;
            }
        } else {
            let radius: i32 = range.into();
            let (mut x, mut y) = (-radius, radius);
            for (dx, dy) in SIDES.span() {
                let mut j: u8 = 0;
                while j != range {
                    if Self::faces(vertices, x, y) {
                        any = true;
                        Self::walk(@board, start, range, x, y, ref seen);
                    }
                    x += *dx;
                    y += *dy;
                    j += 1;
                }
            }
        }
        // [Return] The prefixes, and the start when a line was walked
        let (low, high) = seen;
        let mut result = Bits::to_felt(u256 { low, high });
        if any {
            result += Bits::pow(from);
        }
        result
    }

    /// Whether the ring hex at `(x, y)` from the start lies in the cone, always without a facing.
    #[inline]
    fn faces(vertices: Option<[VertexDirection; 2]>, x: i32, y: i32) -> bool {
        match vertices {
            Option::Some(pair) => {
                let [a, b] = pair;
                let way = HexTrait::ZERO.diagonal_way_to(HexTrait::new(x, y));
                way.contains(@a) || way.contains(@b)
            },
            Option::None => true,
        }
    }

    /// Walks the line from `start` to the ring hex at `(x, y)` from it (`range` steps), adding
    /// each tile to `seen` until one is off the board or a wall. The start is not added.
    fn walk(board: @Board, start: Tile, range: u8, x: i32, y: i32, ref seen: (u128, u128)) {
        // [Compute] The moves: `x` grows to the east, `y` to the north
        let n: u16 = range.into();
        let (east, mx): (bool, u16) = if x > 0 {
            (true, x.try_into().unwrap())
        } else {
            (false, (-x).try_into().unwrap())
        };
        let (north, my): (bool, u16) = if y > 0 {
            (true, y.try_into().unwrap())
        } else {
            (false, (-y).try_into().unwrap())
        };
        let (horizontal, vertical, both) = (
            if east {
                Direction::East
            } else {
                Direction::West
            },
            if north {
                Direction::NorthEast
            } else {
                Direction::SouthWest
            },
            if east {
                Direction::SouthEast
            } else {
                Direction::NorthWest
            },
        );
        // [Compute] The accumulators of `line_to`: `x` ties toward the larger `x`, `y` toward the
        // smaller `y` (a tie rounds a magnitude down when its start is `N − 1`)
        let (mut ex, mut ey) = (if east {
            n
        } else {
            n - 1
        }, if north {
            n - 1
        } else {
            n
        });
        let (ix, iy) = (2 * mx, 2 * my);
        let (tx, ty) = (2 * n - ix, 2 * n - iy);
        let mut tile = start;
        let mut step: u16 = 0;
        while step != n {
            let moved_x = if ex >= tx {
                ex -= tx;
                true
            } else {
                ex += ix;
                false
            };
            let moved_y = if ey >= ty {
                ey -= ty;
                true
            } else {
                ey += iy;
                false
            };
            let direction = if !moved_y {
                horizontal
            } else if moved_x {
                both
            } else {
                vertical
            };
            // [Check] The tile on the board, then walkable
            if !Self::advance(ref tile, board, direction) {
                return;
            }
            let (high, bit) = Self::bit(tile.index);
            let (low_seen, high_seen) = seen;
            if high {
                if *board.high & bit == 0 {
                    return;
                }
                seen = (low_seen, high_seen | bit);
            } else {
                if *board.low & bit == 0 {
                    return;
                }
                seen = (low_seen | bit, high_seen);
            }
            step += 1;
        }
    }

    /// Moves one tile in a direction (the offsets of `board::direction`), `false` when the tile
    /// leaves the board.
    #[inline(always)]
    fn advance(ref tile: Tile, board: @Board, direction: Direction) -> bool {
        let (width, last_column, last_row) = (*board.width, *board.last_column, *board.last_row);
        let odd = tile.row % 2 == 1;
        match direction {
            Direction::East => {
                if tile.column == 0 {
                    return false;
                }
                tile.column -= 1;
                tile.index -= 1;
            },
            Direction::West => {
                if tile.column == last_column {
                    return false;
                }
                tile.column += 1;
                tile.index += 1;
            },
            Direction::NorthEast => {
                if tile.row == last_row {
                    return false;
                }
                if odd {
                    tile.index += width;
                } else {
                    if tile.column == 0 {
                        return false;
                    }
                    tile.column -= 1;
                    tile.index += width - 1;
                }
                tile.row += 1;
            },
            Direction::NorthWest => {
                if tile.row == last_row {
                    return false;
                }
                if odd {
                    if tile.column == last_column {
                        return false;
                    }
                    tile.column += 1;
                    tile.index += width + 1;
                } else {
                    tile.index += width;
                }
                tile.row += 1;
            },
            Direction::SouthWest => {
                if tile.row == 0 {
                    return false;
                }
                if odd {
                    if tile.column == last_column {
                        return false;
                    }
                    tile.column += 1;
                    tile.index -= width - 1;
                } else {
                    tile.index -= width;
                }
                tile.row -= 1;
            },
            Direction::SouthEast => {
                if tile.row == 0 {
                    return false;
                }
                if odd {
                    tile.index -= width;
                } else {
                    if tile.column == 0 {
                        return false;
                    }
                    tile.column -= 1;
                    tile.index -= width + 1;
                }
                tile.row -= 1;
            },
        }
        true
    }

    /// The limb of a position (`true` for the high one) and its bit in that limb.
    #[inline(always)]
    fn bit(index: u8) -> (bool, u128) {
        if index < 128 {
            (false, Bits::pow(index).try_into().unwrap())
        } else {
            (true, Bits::pow(index - 128).try_into().unwrap())
        }
    }

    /// Whether a position inside the board is walkable.
    #[inline(always)]
    fn walkable(board: @Board, index: u8) -> bool {
        let (high, bit) = Self::bit(index);
        if high {
            *board.high & bit != 0
        } else {
            *board.low & bit != 0
        }
    }
}
