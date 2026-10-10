//! `algorithms::fov`: `range_fov` and `directional_fov` of `hexx` (`src/algorithms/fov.rs`), on
//! a `HexMap`.
//!
//! One line per hex of the ring, with the game's tie rule (plan §6.6). Two paths give the same
//! result:
//!
//! - the **table path** serves the width 15 and a range of at most 6 (the game's sight): when the
//!   ring hex lies on the board, `LineTrait::line` to it (its table path), and when neither that
//!   line nor the ring hex holds a wall, the whole line is seen at once;
//! - the **walk** serves every other line: the accumulators of the line (those of
//!   `HexTrait::line_to` and `LineInternal::walk`), from the start towards the ring hex, tile by
//!   tile on the board, stopped at the first tile off the board or a wall. The walk tracks the
//!   tile index, its column and its row, so that a line leaving the board stops there instead of
//!   being refused (`LineTrait::line` is `None` for such a line, D-27).
//!
//! The ring is taken side by side: the hex `j` of a side lies at `(±mx, ±my)` from the start
//! with fixed signs and magnitudes `r`, `j` or `r − j` (`SIDES`). With a facing, a side lies in
//! the cone when its middle does (a `diagonal_way_to` wedge is a cone from the start), and its
//! first hex, a corner, when the side before does as well (a tie of both wedges).

// Internal imports

use crate::board::asserter::Asserter;
use crate::board::bits::Bits;
use crate::board::direction::Direction;
use crate::board::line::LineTrait;
use crate::board::map::HexMap;
use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::direction::vertex_direction::VertexDirection;
use crate::direction::way::DirectionWayTrait;
use crate::hex::HexTrait;

// Constants

/// The six sides of the ring of radius `r`, from `(−r, r)` counter-clockwise: the hex `j` of a
/// side (`0..r`, from its first corner) lies at `(±mx, ±my)` from the start, `(east, kind of
/// mx, north, kind of my)`: `x > 0` to the east, `y > 0` to the north, a magnitude `r` (`R`),
/// `j` (`J`) or `r − j` (`RJ`). In `Hex` coordinates the sides run `(−r + j, r)`,
/// `(j, r − j)`, `(r, −j)`, `(r − j, −r)`, `(−j, −r + j)`, `(−r, j)`.
const SIDES: [(bool, u8, bool, u8); 6] = [
    (false, RJ, true, R), (true, J, true, RJ), (true, R, false, J), (true, RJ, false, R),
    (false, J, false, RJ), (false, R, true, J),
];
/// The kinds of a magnitude of `SIDES`.
const R: u8 = 0;
const J: u8 = 1;
const RJ: u8 = 2;
/// The middle of each side on the ring of radius 2, in `Hex` coordinates from the start.
const MIDDLES: [(i32, i32); 6] = [(-1, 2), (1, 1), (2, -1), (1, -2), (-1, -1), (-2, 1)];
/// The width and the largest range of the table path of `LineTrait::line`.
const TABLE_WIDTH: u8 = 15;
const TABLE_RADIUS: u8 = 6;

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

/// A tile of a walk: its index, column, row and the parity of its row.
#[derive(Copy, Drop)]
struct Tile {
    index: u8,
    column: u8,
    row: u8,
    odd: bool,
}

/// What every line of one field of view shares.
#[derive(Copy, Drop)]
struct Sight {
    map: HexMap,
    board: Board,
    start: Tile,
    /// `column + ⌈row / 2⌉` of the start: the ring hex `(x, y)` from it lies at the column
    /// `base − x − ⌈(row + y) / 2⌉`.
    base: felt252,
    range: u8,
    /// Whether the lines take the table path of `LineTrait::line` first.
    table: bool,
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
        let vertices = match facing {
            Option::Some(direction) => Option::Some(direction.vertex_directions()),
            Option::None => Option::None,
        };
        // [Return] Range 0: the ring is the start
        let start_bit = Bits::pow(from);
        if range == 0 {
            return if Self::faces(vertices, 0, 0) {
                start_bit
            } else {
                0
            };
        }
        // [Compute] The ring, side by side, each side `range` hexes from its first corner; with a
        // facing, a side takes the wedge of its middle, its corner that of the side before as
        // well (a tie between both)
        let (row, column) = DivRem::div_rem(from, map.width.try_into().unwrap());
        let (half, odd) = DivRem::div_rem(row, 2);
        let sight = Sight {
            map,
            board,
            start: Tile { index: from, column, row, odd: odd == 1 },
            base: column.into() + half.into() + odd.into(),
            range,
            table: map.width == TABLE_WIDTH && range <= TABLE_RADIUS,
        };
        let sight = BoxTrait::new(sight);
        let cone = Self::cone(vertices);
        let mut seen: (u128, u128) = (0, 0);
        let mut side: u32 = 0;
        for (east, kind_x, north, kind_y) in SIDES.span() {
            let (inside, before) = (*cone[side], *cone[(side + 5) % 6]);
            let side_ = (*east, *kind_x, *north, *kind_y);
            if inside {
                Self::side(sight, side_, 0, range.into(), ref seen);
            } else if before {
                Self::side(sight, side_, 0, 1, ref seen);
            }
            side += 1;
        }
        // [Return] The prefixes and the start
        let (low, high) = seen;
        Bits::to_felt(u256 { low, high }) + start_bit
    }

    /// Whether each side of the ring lies in the cone, by its middle on the ring of radius 2
    /// (a `diagonal_way_to` wedge is a cone from the start, the same at every radius).
    fn cone(vertices: Option<[VertexDirection; 2]>) -> Span<bool> {
        if vertices.is_none() {
            return [true, true, true, true, true, true].span();
        }
        let mut cone: Array<bool> = array![];
        for (x, y) in MIDDLES.span() {
            cone.append(Self::faces(vertices, *x, *y));
        }
        cone.span()
    }

    /// Whether the hex at `(x, y)` from the start lies in the cone, always without a facing.
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

    /// The lines to the hexes `first..last` of a side (`j`, from its corner).
    fn side(
        sight: Box<Sight>,
        side: (bool, u8, bool, u8),
        first: u16,
        last: u16,
        ref seen: (u128, u128),
    ) {
        let (east, kind_x, north, kind_y) = side;
        let (range, table) = {
            let sight = sight.unbox();
            (sight.range.into(), sight.table)
        };
        let mut j = first;
        while j != last {
            let mx = Self::magnitude(kind_x, range, j);
            let my = Self::magnitude(kind_y, range, j);
            if !(table && Self::clear(sight, east, mx, north, my, ref seen)) {
                Self::walk(sight, east, mx, north, my, ref seen);
            }
            j += 1;
        }
    }

    /// `r`, `j` or `r − j` by the kind of a side.
    #[inline(always)]
    fn magnitude(kind: u8, range: u16, j: u16) -> u16 {
        if kind == R {
            range
        } else if kind == J {
            j
        } else {
            range - j
        }
    }

    /// The table path: when the ring hex `(±mx, ±my)` from the start lies on the board and no
    /// tile of `LineTrait::line` to it, nor itself, is a wall, adds them to `seen`.
    /// # Returns
    /// * `false` when the line must be walked: the hex off the board, the line leaving it, or a
    ///   wall on it
    #[inline(always)]
    fn clear(
        sight: Box<Sight>, east: bool, mx: u16, north: bool, my: u16, ref seen: (u128, u128),
    ) -> bool {
        let sight = sight.unbox();
        // [Check] The ring hex on the board: its row, then its column
        let row: felt252 = sight.start.row.into();
        let my_felt: felt252 = my.into();
        let target_row: u8 = match (if north {
            row + my_felt
        } else {
            row - my_felt
        }).try_into() {
            Option::Some(target_row) => target_row,
            Option::None => { return false; },
        };
        let board = sight.board;
        if target_row > board.last_row {
            return false;
        }
        let (half, odd) = DivRem::div_rem(target_row, 2);
        let mx_felt: felt252 = mx.into();
        let shift = if east {
            -mx_felt
        } else {
            mx_felt
        };
        let target_column: u8 = match (sight.base + shift - half.into() - odd.into()).try_into() {
            Option::Some(target_column) => target_column,
            Option::None => { return false; },
        };
        if target_column > board.last_column {
            return false;
        }
        let to = target_row * board.width + target_column;
        // [Check] The line on the board, every tile walkable
        let between = match sight.map.line(sight.start.index, to) {
            Option::Some(between) => between,
            Option::None => { return false; },
        };
        let line: u256 = (between + Bits::pow(to)).into();
        if line.low & board.low != line.low || line.high & board.high != line.high {
            return false;
        }
        let (low, high) = seen;
        seen = (low | line.low, high | line.high);
        true
    }

    /// Walks the line from the start to the ring hex `(±mx, ±my)` from it (`range` steps),
    /// adding each tile to `seen` until one is off the board or a wall. The start is not added.
    fn walk(sight: Box<Sight>, east: bool, mx: u16, north: bool, my: u16, ref seen: (u128, u128)) {
        let sight = sight.unbox();
        // [Compute] The moves: `x` grows to the east, `y` to the north
        let n: u16 = sight.range.into();
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
        let board = @sight.board;
        let mut tile = sight.start;
        let (mut low, mut high) = seen;
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
                break;
            }
            let (in_high, bit) = Self::bit(tile.index);
            if in_high {
                if *board.high & bit == 0 {
                    break;
                }
                high = high | bit;
            } else {
                if *board.low & bit == 0 {
                    break;
                }
                low = low | bit;
            }
            step += 1;
        }
        seen = (low, high);
    }

    /// Moves one tile in a direction (the offsets of `board::direction`), `false` when the tile
    /// leaves the board.
    #[inline(always)]
    fn advance(ref tile: Tile, board: @Board, direction: Direction) -> bool {
        let (width, last_column, last_row) = (*board.width, *board.last_column, *board.last_row);
        match direction {
            Direction::East => {
                if tile.column == 0 {
                    return false;
                }
                tile.column -= 1;
                tile.index -= 1;
                return true;
            },
            Direction::West => {
                if tile.column == last_column {
                    return false;
                }
                tile.column += 1;
                tile.index += 1;
                return true;
            },
            Direction::NorthEast => {
                if tile.row == last_row {
                    return false;
                }
                if tile.odd {
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
                if tile.odd {
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
                if tile.odd {
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
                if tile.odd {
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
        tile.odd = !tile.odd;
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

#[cfg(test)]
mod tests {
    // Internal imports

    use crate::board::bits::Bits;
    use crate::board::geometry::Geometry;
    use crate::board::hexagon::HexagonTrait;
    use crate::board::layout::LayoutTrait;
    use crate::board::line::LineTrait;
    use crate::board::map::{HexMap, HexMapTrait};
    use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
    use crate::direction::way::DirectionWayTrait;
    use crate::hex::HexTrait;
    use crate::hex::rings::HexRingsTrait;
    use crate::tests::fixtures::SERPENTINE_15X16;

    // Local imports

    use super::{Fov, SIDES, directional_fov, range_fov};

    // Constants

    /// Every tile of 15 × 16 walkable: 2^240 − 1.
    const OPEN_15X16: felt252 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    /// Every tile of 7 × 7 walkable: 2^49 − 1.
    const OPEN_7X7: felt252 = 0x1ffffffffffff;
    /// The window of the game.
    const WIDTH: u8 = 15;
    const HEIGHT: u8 = 16;

    // Oracles

    #[generate_trait]
    impl Oracle of OracleTrait {
        /// `range_fov` by the plain definition, when every hex of the ring lies on the board: for
        /// every ring hex `t`, the tiles of `LineTrait::line(from, t)` plus both ends, taken in
        /// the order of their distance from `from` (the one tile of the line in each
        /// `hexagon_ring(from, k)`), cut at the first wall. A line that leaves the board
        /// (`None`, R-N5-1) is taken from the mirror's `line_to` instead, cut at its first hex
        /// off the board or a wall.
        fn fov(map: HexMap, from: u8, range: u8) -> felt252 {
            let grid: u256 = map.grid.into();
            if !Bits::get(grid, from) {
                return 0;
            }
            let mut rings: Array<u256> = array![Bits::pow(from).into()];
            let mut k: u8 = 1;
            while k <= range {
                rings.append(map.hexagon_ring(from, k).into());
                k += 1;
            }
            let center = Geometry::index_to_hex(map.width, from);
            let mut result: u256 = Bits::pow(from).into();
            for target in center.ring(range.into()) {
                let to = Geometry::hex_to_index(map.width, map.height, *target).unwrap();
                match map.line(from, to) {
                    Option::Some(between) => {
                        let line: u256 = (between + Bits::pow(from) + Bits::pow(to)).into();
                        let mut k: u32 = 1;
                        while k <= range.into() {
                            let tile = Bits::and(line, *rings[k]);
                            if Bits::and(tile, grid) == 0 {
                                break;
                            }
                            result = Bits::or(result, tile);
                            k += 1;
                        }
                    },
                    Option::None => {
                        for hex in center.line_to(*target) {
                            match Geometry::hex_to_index(map.width, map.height, *hex) {
                                Option::Some(position) => {
                                    if !Bits::get(grid, position) {
                                        break;
                                    }
                                    result = Bits::or(result, Bits::pow(position).into());
                                },
                                Option::None => { break; },
                            }
                        }
                    },
                }
            }
            Bits::to_felt(result)
        }

        /// The ring of `range` around the origin by the moves of `hexx`'s ring (`Hex` moves from
        /// `(−r, r)`, `r` steps along each), as `(side, j, x, y)`.
        fn ring(range: i32) -> Array<(u32, u16, i32, i32)> {
            let moves: [(i32, i32); 6] = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];
            let mut hexes = array![];
            let (mut x, mut y) = (-range, range);
            let mut side: u32 = 0;
            for (dx, dy) in moves.span() {
                let mut j: i32 = 0;
                while j != range {
                    hexes.append((side, j.try_into().unwrap(), x, y));
                    x += *dx;
                    y += *dy;
                    j += 1;
                }
                side += 1;
            }
            hexes
        }

        /// Whether every hex of the ring of `range` around `from` lies on the board.
        fn ring_inside(map: HexMap, from: u8, range: u8) -> bool {
            let center = Geometry::index_to_hex(map.width, from);
            for hex in center.ring(range.into()) {
                if Geometry::hex_to_index(map.width, map.height, *hex).is_none() {
                    return false;
                }
            }
            true
        }

        /// Whether `a ⊆ b`.
        fn within(a: felt252, b: felt252) -> bool {
            let a: u256 = a.into();
            Bits::and(a, b.into()) == a
        }

        /// The next state of a 64-bit linear congruential generator (Knuth's MMIX constants).
        fn next(state: u64) -> u64 {
            let product: u128 = state.into() * 6364136223846793005 + 1442695040888963407;
            (product % 0x10000000000000000).try_into().unwrap()
        }

        /// A seeded cave: each tile walkable with probability 2/3.
        fn cave(width: u8, height: u8, seed: u64) -> felt252 {
            let size: u16 = width.into() * height.into();
            let mut state = seed;
            let mut grid: felt252 = 0;
            let mut position: u16 = 0;
            while position != size {
                state = Self::next(state);
                if (state / 0x100000000) % 3 != 0 {
                    grid += Bits::pow(position.try_into().unwrap());
                }
                position += 1;
            }
            grid
        }

        /// The `EdgeDirection` of index 0.
        fn first() -> EdgeDirection {
            *EdgeDirectionTrait::ALL_DIRECTIONS.span()[0]
        }

        /// A map with no seed.
        fn map(width: u8, height: u8, grid: felt252) -> HexMap {
            HexMap { width, height, grid, seed: 0 }
        }
    }

    #[generate_trait]
    impl Check of CheckTrait {
        /// `range_fov` against `Oracle::fov` on the starts `first..last`, at every range whose
        /// ring lies on the board, up to `most`.
        fn oracle(map: HexMap, first: u16, last: u16, most: u8) {
            let mut from = first;
            while from != last {
                let position: u8 = from.try_into().unwrap();
                let mut range: u8 = 0;
                while range <= most && Oracle::ring_inside(map, position, range) {
                    let expected = Oracle::fov(map, position, range);
                    assert!(range_fov(map, position, range) == expected, "{} {}", position, range);
                    range += 1;
                }
                from += 1;
            }
        }

        /// The properties of one start and range: the field lies in the hexagon and the
        /// walkable tiles; a wall added (a seeded walkable tile other than the start) adds no
        /// tile; each directional field lies in the field, and the six cover it.
        fn property(map: HexMap, position: u8, range: u8, ref state: u64) {
            let size: u16 = map.width.into() * map.height.into();
            let fov = range_fov(map, position, range);
            let area: u256 = map.hexagon(position, range).into();
            let area = Bits::to_felt(Bits::and(area, map.grid.into()));
            assert!(Oracle::within(fov, area), "hexagon {} {}", position, range);
            // A wall added
            state = Oracle::next(state);
            let wall: u8 = ((state / 0x100000000) % size.into()).try_into().unwrap();
            if wall != position && map.is_walkable(wall) {
                let mut walled = map;
                walled.grid -= Bits::pow(wall);
                let less = range_fov(walled, position, range);
                assert!(Oracle::within(less, fov), "wall {} {} {}", position, range, wall);
            }
            // The cones
            let mut union: u256 = 0;
            for direction in EdgeDirectionTrait::ALL_DIRECTIONS.span() {
                let cone = directional_fov(map, position, range, *direction);
                assert!(Oracle::within(cone, fov), "cone {} {}", position, range);
                union = Bits::or(union, cone.into());
            }
            assert!(Bits::to_felt(union) == fov, "union {} {}", position, range);
        }

        /// The properties on the starts `first..last`, at `ranges`.
        fn near(map: HexMap, first: u16, last: u16, ranges: Span<u8>, seed: u64) {
            let mut state = seed;
            let mut from = first;
            while from != last {
                for range in ranges {
                    Self::property(map, from.try_into().unwrap(), *range, ref state);
                }
                from += 1;
            }
        }

        /// The properties on `count` seeded starts, each at a seeded range of `3..=16`.
        fn seeded(map: HexMap, count: u32, seed: u64) {
            let size: u64 = map.width.into() * map.height.into();
            let mut state = seed;
            let mut index: u32 = 0;
            while index != count {
                state = Oracle::next(state);
                let position: u8 = ((state / 0x100000000) % size).try_into().unwrap();
                let range: u8 = (3 + (state / 0x10000000000) % 14).try_into().unwrap();
                Self::property(map, position, range, ref state);
                index += 1;
            }
        }
    }

    // Regression cases

    /// A wall at the start sees nothing, whatever the range.
    #[test]
    #[available_gas(l2_gas: 31342)]
    fn test_fov_from_wall() {
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16 - Bits::pow(112));
        assert!(range_fov(map, 112, 0) == 0);
        assert!(range_fov(map, 112, 6) == 0);
        assert!(directional_fov(map, 112, 6, Oracle::first()) == 0);
    }

    /// Range 0 is the start alone.
    #[test]
    #[available_gas(l2_gas: 24104)]
    fn test_fov_range_zero() {
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        assert!(range_fov(map, 112, 0) == Bits::pow(112));
        assert!(range_fov(map, 0, 0) == 1);
    }

    /// Decision 1 (b) of the brief: on the empty window, from `(2, 7)` at range 6, the tile
    /// `(1, 7)` lies only on lines to ring hexes off the board (column ≤ −4): it is seen, as in
    /// `hexx` with `blocking = off the board or a wall`.
    #[test]
    #[available_gas(l2_gas: 1894318)]
    fn test_fov_whole_ring() {
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        let from = LayoutTrait::index(WIDTH, 2, 7);
        let seen = LayoutTrait::index(WIDTH, 1, 7);
        assert!(Bits::get(range_fov(map, from, 6).into(), seen));
    }

    /// A wall is never seen, and blocks the tiles behind it on its lines: on the empty window
    /// from `(7, 7)`, the wall `(6, 7)` (one step East) hides `(5, 7)`, `(4, 7)` (the only lines
    /// to them pass through it).
    #[test]
    #[available_gas(l2_gas: 1318130)]
    fn test_fov_wall_hides() {
        let wall = LayoutTrait::index(WIDTH, 6, 7);
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16 - Bits::pow(wall));
        let fov: u256 = range_fov(map, LayoutTrait::index(WIDTH, 7, 7), 6).into();
        assert!(!Bits::get(fov, wall));
        assert!(!Bits::get(fov, LayoutTrait::index(WIDTH, 5, 7)));
        assert!(!Bits::get(fov, LayoutTrait::index(WIDTH, 4, 7)));
        assert!(Bits::get(fov, LayoutTrait::index(WIDTH, 8, 7)));
    }

    /// On the empty window the sight from `(7, 7)` is the whole hexagon of radius 6.
    #[test]
    #[available_gas(l2_gas: 1179030)]
    fn test_fov_open_sight() {
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        let from = LayoutTrait::index(WIDTH, 7, 7);
        assert!(range_fov(map, from, 6) == map.hexagon(from, 6));
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: position not inside')]
    fn test_fov_revert_outside() {
        range_fov(Oracle::map(WIDTH, HEIGHT, OPEN_15X16), 240, 1);
    }

    #[test]
    #[available_gas(l2_gas: 8096)]
    #[should_panic(expected: 'Asserter: position not inside')]
    fn test_directional_fov_revert_outside() {
        directional_fov(Oracle::map(WIDTH, HEIGHT, OPEN_15X16), 240, 1, Oracle::first());
    }

    // `range_fov` against the oracle, every start, every range whose ring lies on the board
    // (each board in two halves of its starts, under the step limit of a test)

    #[test]
    #[available_gas(l2_gas: 474692424)]
    fn test_fov_oracle_open_15x16_0() {
        Check::oracle(Oracle::map(WIDTH, HEIGHT, OPEN_15X16), 0, 120, 16);
    }

    #[test]
    #[available_gas(l2_gas: 478962679)]
    fn test_fov_oracle_open_15x16_1() {
        Check::oracle(Oracle::map(WIDTH, HEIGHT, OPEN_15X16), 120, 240, 16);
    }

    #[test]
    #[available_gas(l2_gas: 257221586)]
    fn test_fov_oracle_serpentine_15x16_0() {
        Check::oracle(Oracle::map(WIDTH, HEIGHT, SERPENTINE_15X16), 0, 120, 16);
    }

    #[test]
    #[available_gas(l2_gas: 299902447)]
    fn test_fov_oracle_serpentine_15x16_1() {
        Check::oracle(Oracle::map(WIDTH, HEIGHT, SERPENTINE_15X16), 120, 240, 16);
    }

    #[test]
    #[available_gas(l2_gas: 336943900)]
    fn test_fov_oracle_cave_a_15x16_0() {
        Check::oracle(
            Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave a')), 0, 120, 16,
        );
    }

    #[test]
    #[available_gas(l2_gas: 390337453)]
    fn test_fov_oracle_cave_a_15x16_1() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave a'));
        Check::oracle(map, 120, 240, 16);
    }

    #[test]
    #[available_gas(l2_gas: 356790617)]
    fn test_fov_oracle_cave_b_15x16_0() {
        Check::oracle(
            Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave b')), 0, 120, 16,
        );
    }

    #[test]
    #[available_gas(l2_gas: 384264097)]
    fn test_fov_oracle_cave_b_15x16_1() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave b'));
        Check::oracle(map, 120, 240, 16);
    }

    #[test]
    #[available_gas(l2_gas: 102907096)]
    fn test_fov_oracle_7x7() {
        Check::oracle(Oracle::map(7, 7, OPEN_7X7), 0, 49, 3);
        Check::oracle(Oracle::map(7, 7, Oracle::cave(7, 7, 'cave 7')), 0, 49, 3);
    }

    // Properties: every start at ranges `0..=2`, and seeded starts at ranges `3..=16` (the whole
    // domain, every start at every range of `0..=16`, is beyond the step limit of a test)

    #[test]
    #[available_gas(l2_gas: 678998311)]
    fn test_fov_properties_open_15x16_near_0() {
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        Check::near(map, 0, 120, [0, 1, 2].span(), 'open');
    }

    #[test]
    #[available_gas(l2_gas: 695814611)]
    fn test_fov_properties_open_15x16_near_1() {
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        Check::near(map, 120, 240, [0, 1, 2].span(), 'open');
    }

    #[test]
    #[available_gas(l2_gas: 575664382)]
    fn test_fov_properties_open_15x16_seeded() {
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        Check::seeded(map, 16, 'open');
    }

    #[test]
    #[available_gas(l2_gas: 319967111)]
    fn test_fov_properties_serpentine_15x16_near_0() {
        let map = Oracle::map(WIDTH, HEIGHT, SERPENTINE_15X16);
        Check::near(map, 0, 120, [0, 1, 2].span(), 'serpent');
    }

    #[test]
    #[available_gas(l2_gas: 322663914)]
    fn test_fov_properties_serpentine_15x16_near_1() {
        let map = Oracle::map(WIDTH, HEIGHT, SERPENTINE_15X16);
        Check::near(map, 120, 240, [0, 1, 2].span(), 'serpent');
    }

    #[test]
    #[available_gas(l2_gas: 78711397)]
    fn test_fov_properties_serpentine_15x16_seeded() {
        let map = Oracle::map(WIDTH, HEIGHT, SERPENTINE_15X16);
        Check::seeded(map, 24, 'serpent');
    }

    #[test]
    #[available_gas(l2_gas: 523494735)]
    fn test_fov_properties_cave_a_15x16_near_0() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave a'));
        Check::near(map, 0, 120, [0, 1, 2].span(), 'cave a');
    }

    #[test]
    #[available_gas(l2_gas: 534566700)]
    fn test_fov_properties_cave_a_15x16_near_1() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave a'));
        Check::near(map, 120, 240, [0, 1, 2].span(), 'cave a');
    }

    #[test]
    #[available_gas(l2_gas: 264893911)]
    fn test_fov_properties_cave_a_15x16_seeded() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave a'));
        Check::seeded(map, 24, 'cave a');
    }

    #[test]
    #[available_gas(l2_gas: 514036988)]
    fn test_fov_properties_cave_b_15x16_near_0() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave b'));
        Check::near(map, 0, 120, [0, 1, 2].span(), 'cave b');
    }

    #[test]
    #[available_gas(l2_gas: 500246931)]
    fn test_fov_properties_cave_b_15x16_near_1() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave b'));
        Check::near(map, 120, 240, [0, 1, 2].span(), 'cave b');
    }

    #[test]
    #[available_gas(l2_gas: 179703641)]
    fn test_fov_properties_cave_b_15x16_seeded() {
        let map = Oracle::map(WIDTH, HEIGHT, Oracle::cave(WIDTH, HEIGHT, 'cave b'));
        Check::seeded(map, 24, 'cave b');
    }

    #[test]
    #[available_gas(l2_gas: 613083428)]
    fn test_fov_properties_open_7x7_near() {
        Check::near(Oracle::map(7, 7, OPEN_7X7), 0, 49, [0, 1, 2, 3].span(), 'open 7');
    }

    #[test]
    #[available_gas(l2_gas: 405801219)]
    fn test_fov_properties_cave_7x7_near() {
        let map = Oracle::map(7, 7, Oracle::cave(7, 7, 'cave 7'));
        Check::near(map, 0, 49, [0, 1, 2, 3].span(), 'cave 7');
    }

    #[test]
    #[available_gas(l2_gas: 577603437)]
    fn test_fov_properties_7x7_seeded() {
        Check::seeded(Oracle::map(7, 7, OPEN_7X7), 24, 'open 7');
        Check::seeded(Oracle::map(7, 7, Oracle::cave(7, 7, 'cave 7')), 24, 'cave 7');
    }

    // Benchmarks: the difference between a test that calls twice and one that calls once, the
    // method of `bench_assembly`.

    #[derive(Copy, Drop)]
    struct Bench {
        /// The sight: the empty window from `(7, 7)` and `(7, 8)`, range 6, every ring hex on
        /// the board.
        sight: [u8; 2],
        /// Next to the ring, range 15: from `(1, 7)` and `(13, 8)`, most lines leave the board.
        edge: [u8; 2],
    }

    #[generate_trait]
    impl Inputs of InputsTrait {
        /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
        #[inline(never)]
        fn get() -> Bench {
            Bench { sight: [112, 127], edge: [106, 133] }
        }
    }

    /// `range_fov` on the sight. The target is the brief's (sketch (A)): `L = 173,822 + 36 × 6 ×
    /// 9,557 = 2,238,134`. The design kept takes, for each of the 36 ring hexes, the table path
    /// of `LineTrait::line` and one wall test (`line_of_sight`'s table path, 17,706 in
    /// `gas/hexx.snap`) after the ring hex's index (`Geometry::hex_to_index`, 5,370): `L = 36 ×
    /// 23,076 = 830,736`, derived after the first measurement of the design (see the report of
    /// M3-T2). The walk alone (sketch (A)) measured 4,339,009.
    #[test]
    #[available_gas(l2_gas: 1182400)]
    #[inline(never)]
    fn bench_range_fov_sight_once() {
        let [from, _] = Inputs::get().sight;
        assert!(range_fov(Oracle::map(WIDTH, HEIGHT, OPEN_15X16), from, 6) != 0);
    }

    #[test]
    #[available_gas(l2_gas: 2359970)]
    #[inline(never)]
    fn bench_range_fov_sight_twice() {
        let [from, other] = Inputs::get().sight;
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        assert!(range_fov(map, from, 6) != 0);
        assert!(range_fov(map, other, 6) != 0);
    }

    /// `directional_fov` on the sight, `EdgeDirection` 0. The target is the brief's (sketch
    /// (A)): `L = 1,605,392`. The design kept: 6 `diagonal_way_to` (the middles of the sides, at
    /// most 19,059 each) and the 13 lines of the cone as in `range_fov`: `L = 6 × 19,059 + 13 ×
    /// 23,076 = 414,342`, derived after the first measurement of the design.
    #[test]
    #[available_gas(l2_gas: 586172)]
    #[inline(never)]
    fn bench_directional_fov_sight_once() {
        let [from, _] = Inputs::get().sight;
        let direction = Oracle::first();
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        assert!(directional_fov(map, from, 6, direction) != 0);
    }

    #[test]
    #[available_gas(l2_gas: 1164165)]
    #[inline(never)]
    fn bench_directional_fov_sight_twice() {
        let [from, other] = Inputs::get().sight;
        let direction = Oracle::first();
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        assert!(directional_fov(map, from, 6, direction) != 0);
        assert!(directional_fov(map, other, 6, direction) != 0);
    }

    /// `SIDES` gives every hex of the ring, signs and magnitudes, at ranges `1..=16`, and they
    /// are the hexes of the mirror's `HexRingsTrait::ring`.
    #[test]
    #[available_gas(l2_gas: 153939524)]
    fn test_fov_sides() {
        let mut range: i32 = 1;
        while range != 17 {
            let r: u16 = range.try_into().unwrap();
            let hexes = Oracle::ring(range);
            let mirror = HexTrait::ZERO.ring(range.try_into().unwrap());
            assert!(hexes.len() == mirror.len());
            for (side, j, x, y) in hexes.span() {
                let (east, kind_x, north, kind_y) = *SIDES.span()[*side];
                let (mx, my) = (Fov::magnitude(kind_x, r, *j), Fov::magnitude(kind_y, r, *j));
                let (mx, my): (i32, i32) = (mx.into(), my.into());
                assert!(*x == if east {
                    mx
                } else {
                    -mx
                }, "x {} {} {}", range, side, j);
                assert!(*y == if north {
                    my
                } else {
                    -my
                }, "y {} {} {}", range, side, j);
                let mut found = false;
                for hex in mirror {
                    if *hex == HexTrait::new(*x, *y) {
                        found = true;
                    }
                }
                assert!(found, "ring {} {} {}", range, x, y);
            }
            range += 1;
        }
    }

    /// The cone side by side (`Fov::cone`: a side takes the wedge of its middle, its first hex
    /// that of the side before as well) equals the plain filter of `hexx`, `diagonal_way_to` of
    /// every ring hex, for the six `EdgeDirection`s at ranges `1..=16`.
    #[test]
    #[available_gas(l2_gas: 130548821)]
    fn test_directional_fov_cone() {
        for direction in EdgeDirectionTrait::ALL_DIRECTIONS.span() {
            let vertices = Option::Some((*direction).vertex_directions());
            let cone = Fov::cone(vertices);
            let mut range: i32 = 1;
            while range != 17 {
                for (side, j, x, y) in Oracle::ring(range) {
                    let sided = *cone[side] || (j == 0 && *cone[(side + 5) % 6]);
                    assert!(sided == Fov::faces(vertices, x, y), "{} {} {}", range, x, y);
                }
                range += 1;
            }
        }
    }

    /// The number of ring hexes of the cone of `EdgeDirection` 0 at range 6.
    #[test]
    #[available_gas(l2_gas: 818843)]
    fn test_directional_fov_cone_size() {
        let [a, b] = Oracle::first().vertex_directions();
        let mut count: u32 = 0;
        for hex in HexTrait::ZERO.ring(6) {
            let way = HexTrait::ZERO.diagonal_way_to(*hex);
            if way.contains(@a) || way.contains(@b) {
                count += 1;
            }
        }
        assert!(count == 13, "{}", count);
    }

    /// `range_fov` next to the ring at range 15, no target.
    #[test]
    #[available_gas(l2_gas: 12560921)]
    #[inline(never)]
    fn bench_range_fov_edge_once() {
        let [from, _] = Inputs::get().edge;
        assert!(range_fov(Oracle::map(WIDTH, HEIGHT, OPEN_15X16), from, 15) != 0);
    }

    #[test]
    #[available_gas(l2_gas: 25045642)]
    #[inline(never)]
    fn bench_range_fov_edge_twice() {
        let [from, other] = Inputs::get().edge;
        let map = Oracle::map(WIDTH, HEIGHT, OPEN_15X16);
        assert!(range_fov(map, from, 15) != 0);
        assert!(range_fov(map, other, 15) != 0);
    }

    /// `range_fov` at the end of the domain, range 255 from `(7, 7)`, once, no target.
    #[test]
    #[available_gas(l2_gas: 245117961)]
    #[inline(never)]
    fn bench_range_fov_far_once() {
        let [from, _] = Inputs::get().sight;
        assert!(range_fov(Oracle::map(WIDTH, HEIGHT, OPEN_15X16), from, 255) != 0);
    }
}
