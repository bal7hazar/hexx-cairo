//! Board layout: masks, neighbour expansion and coordinates.
//!
//! Pointy-top, odd-r offset, row-major: `i = y * width + x`, see `types::direction`.
//!
//! Border invariant: a bitmap that is expanded only holds interior tiles
//! (`1 <= x <= W - 2`, `1 <= y <= H - 2`) and `W * H <= 251`. Then every neighbour shift is an
//! exact field multiplication (no wrap-around, no dropped bit, no overflow) and only the set
//! operations need the bitwise builtin.

// Core imports

use core::felt252_div;

// Internal imports

use hexx::board::bits::{Bits, TWO_POW_128};
use hexx::board::direction::Direction;

// Constants

/// 1/2 in the field.
const INV_2: felt252 = 0x400000000000008800000000000000000000000000000000000000000000001;
/// 2, as a divisor.
const TWO: NonZero<u8> = 2;
/// The 6 directions, in `Direction` order.
const DIRECTIONS: [Direction; 6] = [
    Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
    Direction::SouthWest, Direction::SouthEast,
];

/// Per-map constants of the neighbour expansion, computed once per call.
#[derive(Copy, Drop)]
pub struct Layout {
    pub width: u8,
    pub height: u8,
    /// Bits of the even rows.
    pub even: u256,
    /// 2^(W-1): up shift of the even rows.
    pub up_even: felt252,
    /// 2^W: up shift of the odd rows.
    pub up_odd: felt252,
    /// 2^-(W+1): down shift of the even rows.
    pub down_even: felt252,
    /// 2^-W: down shift of the odd rows.
    pub down_odd: felt252,
}

/// Constants of the hex dilation (`Layout::dilation`): the 4 values the layer loops carry.
#[derive(Copy, Drop)]
pub struct Dilation {
    /// Bits of the even rows, low limb.
    pub even_low: u128,
    /// Bits of the even rows, high limb.
    pub even_high: u128,
    /// 2^(W-1): up shift of the even rows (the odd rows shift by twice as much).
    pub up: felt252,
    /// 2^-(W+1): down shift of the even rows (the odd rows shift by twice as much).
    pub down: felt252,
}

#[generate_trait]
pub impl LayoutImpl of LayoutTrait {
    /// Compute the layout constants of a map.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// # Returns
    /// * The layout
    #[inline]
    fn new(width: u8, height: u8) -> Layout {
        let up_odd = Bits::pow(width);
        let down_odd = Bits::inv(width);
        Layout {
            width,
            height,
            even: Self::even(width, height).into(),
            up_even: up_odd * INV_2,
            up_odd,
            down_even: down_odd * INV_2,
            down_odd,
        }
    }

    /// Bits of the whole board, `2^(W*H) - 1`.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// # Returns
    /// * The board mask
    #[inline]
    fn board(width: u8, height: u8) -> felt252 {
        Bits::pow(width * height) - 1
    }

    /// Bits of the even rows, `ROW * (2^(2W * ceil(H/2)) - 1) / (2^(2W) - 1)`.
    /// The field division is exact because the divisor divides the numerator.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// # Returns
    /// * The even rows mask
    #[inline]
    fn even(width: u8, height: u8) -> felt252 {
        let row = Bits::pow(width);
        let size = width * height;
        // [Compute] 2^(2W * ceil(H/2)), may exceed the field: exact anyway, the quotient fits
        let top = if height % 2 == 0 {
            Bits::pow(size)
        } else {
            Bits::pow(size) * row
        };
        let pair = row * row - 1;
        felt252_div((row - 1) * (top - 1), pair.try_into().unwrap())
    }

    /// Bits of the interior, `(2^(W-1) - 2) * 2^W * (2^(W*(H-2)) - 1) / (2^W - 1)`.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// # Returns
    /// * The interior mask
    #[inline]
    fn interior(width: u8, height: u8) -> felt252 {
        let row = Bits::pow(width);
        let inner = row * INV_2 - 2;
        let rows = Bits::pow(width * (height - 2)) - 1;
        felt252_div(inner * row * rows, (row - 1).try_into().unwrap())
    }

    /// Bits of the hexagon of radius `radius` centred in its `(2R+3) x (2R+3)` board, whose
    /// outer ring is left as wall. With `W * H <= 251`, the largest radius is 6 (15x15).
    /// # Arguments
    /// * `radius` - The radius of the hexagon
    /// # Returns
    /// * The hexagon mask
    fn hexagon(radius: u8) -> felt252 {
        let width = 2 * radius + 3;
        let center = radius + 1;
        let half = center / 2;
        let mut mask: felt252 = 0;
        let mut y: u8 = 1;
        while y != width - 1 {
            // [Compute] Row extent: x_min = cx - R + max(0, cy - y) + y/2 - cy/2
            let (start, length) = if y < center {
                (1 + center - y + y / 2 - half, 2 * radius + 1 - (center - y))
            } else {
                (1 + y / 2 - half, 2 * radius + 1 - (y - center))
            };
            mask += (Bits::pow(length) - 1) * Bits::pow(y * width + start);
            y += 1;
        }
        mask
    }

    /// The layout and the interior mask, from 3 shared table lookups (`new` and `interior`
    /// computed together).
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// # Returns
    /// * The layout and the interior mask
    #[inline]
    fn with_interior(width: u8, height: u8) -> (Layout, felt252) {
        let row = Bits::pow(width);
        let inv_row = Bits::inv(width);
        let board = Bits::pow(width * height);
        let up_even = row * INV_2;
        let down_even = inv_row * INV_2;
        // [Compute] Even rows, ROW * (2^(2W * ceil(H/2)) - 1) / (2^(2W) - 1)
        let top = if height % 2 == 0 {
            board
        } else {
            board * row
        };
        let even = felt252_div((row - 1) * (top - 1), (row * row - 1).try_into().unwrap());
        // [Compute] Interior, (2^(W-1) - 2) * 2^W * (2^(W*(H-2)) - 1) / (2^W - 1)
        let rows = board * inv_row * inv_row - 1;
        let interior = felt252_div((up_even - 2) * row * rows, (row - 1).try_into().unwrap());
        let layout = Layout {
            width, height, even: even.into(), up_even, up_odd: row, down_even, down_odd: inv_row,
        };
        (layout, interior)
    }

    /// Hex dilation: the frontier and all its neighbours (design section 2.2).
    /// 10 applications of the bitwise builtin, 4 felt-to-`u256` conversions, all shifts are field
    /// products (see `Dilation::dilate`).
    /// # Arguments
    /// * `self` - The layout
    /// * `frontier` - The frontier, interior tiles only (border invariant)
    /// # Returns
    /// * The frontier and its neighbours
    #[inline]
    fn expand(self: @Layout, frontier: u256) -> u256 {
        let dilation = self.dilation();
        let (low, high) = dilation.dilate(frontier.low, frontier.high, Bits::to_felt(frontier));
        u256 { low, high }
    }

    /// Hex dilation for boards of at most 128 bits (`W * H <= 128`): the same formulation on a
    /// single `u128` limb, about half the cost of `expand` (see `GAS.md`).
    /// # Arguments
    /// * `self` - The layout
    /// * `frontier` - The frontier, interior tiles only (border invariant)
    /// # Returns
    /// * The frontier and its neighbours
    #[inline]
    fn expand_small(self: @Layout, frontier: u128) -> u128 {
        self.dilation().expand_small(frontier)
    }

    /// The constants of the dilation, for the layer loops.
    /// # Arguments
    /// * `self` - The layout
    /// # Returns
    /// * The 4 constants
    #[inline(always)]
    fn dilation(self: @Layout) -> Dilation {
        let layout = *self;
        Dilation {
            even_low: layout.even.low,
            even_high: layout.even.high,
            up: layout.up_even,
            down: layout.down_even,
        }
    }

    /// Board neighbours of a tile, one direction at a time: the neighbourhood of an edge
    /// endpoint, which has no exact field mask (edge-endpoint helper of `Bfs` and `Dial`).
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `position` - The tile
    /// # Returns
    /// * The bits of its neighbours
    fn edge_neighbors(width: u8, height: u8, position: u8) -> felt252 {
        let mut around: felt252 = 0;
        for direction in DIRECTIONS.span() {
            if let Option::Some(next) = Self::neighbor(width, height, position, *direction) {
                around += Bits::pow(next);
            }
        }
        around
    }

    /// First neighbour of a tile in a set, directions in `Direction` order: the predecessor of
    /// an edge target in the last layer of a search (edge-endpoint helper of `Bfs` and `Dial`).
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `position` - The tile
    /// * `set` - The set
    /// # Returns
    /// * The first neighbour in the set, `None` if there is none
    fn neighbor_in(width: u8, height: u8, position: u8, set: u256) -> Option<u8> {
        for direction in DIRECTIONS.span() {
            if let Option::Some(next) = Self::neighbor(width, height, position, *direction) {
                if Bits::get(set, next) {
                    return Option::Some(next);
                }
            }
        }
        Option::None
    }

    /// The 6 neighbour bits of an interior position.
    /// `2^i * M_parity` with `M` the field sum of the 6 relative offsets, exact because every
    /// neighbour of an interior tile lies in the board.
    /// # Arguments
    /// * `self` - The layout
    /// * `position` - The position, an interior tile
    /// # Returns
    /// * The neighbour mask
    #[inline]
    fn neighbor_mask(self: @Layout, position: u8) -> felt252 {
        let layout = *self;
        let (_, odd) = Self::parity(layout.width, position);
        let offsets = if odd {
            // {-1, +1, +W, +W+1, -W, -W+1}
            INV_2 + 2 + 3 * (layout.up_odd + layout.down_odd)
        } else {
            // {-1, +1, +W-1, +W, -W-1, -W}
            INV_2 + 2 + 3 * (layout.up_even + layout.down_even)
        };
        Bits::pow(position) * offsets
    }

    /// Position of the coordinates.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `x` - The column
    /// * `y` - The row
    /// # Returns
    /// * The position
    #[inline]
    fn index(width: u8, x: u8, y: u8) -> u8 {
        y * width + x
    }

    /// Coordinates of a position.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `position` - The position
    /// # Returns
    /// * The column and the row
    #[inline]
    fn coords(width: u8, position: u8) -> (u8, u8) {
        let (y, x) = DivRem::div_rem(position, width.try_into().unwrap());
        (x, y)
    }

    /// Column and row parity of a position, one division by `2W`.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `position` - The position
    /// # Returns
    /// * The column and whether the row is odd
    #[inline]
    fn parity(width: u8, position: u8) -> (u8, bool) {
        let (_, rem) = DivRem::div_rem(position, (2 * width).try_into().unwrap());
        if rem < width {
            (rem, false)
        } else {
            (rem - width, true)
        }
    }

    /// Neighbour of a position, `None` if it falls outside the board.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `position` - The position
    /// * `direction` - The direction
    /// # Returns
    /// * The neighbour position if it lies in the board
    fn neighbor(width: u8, height: u8, position: u8, direction: Direction) -> Option<u8> {
        let (y, x) = DivRem::div_rem(position, width.try_into().unwrap());
        let odd = y % 2 == 1;
        match direction {
            Direction::East => if x == 0 {
                None
            } else {
                Some(position - 1)
            },
            Direction::West => if x == width - 1 {
                None
            } else {
                Some(position + 1)
            },
            Direction::NorthEast => if y == height - 1 {
                None
            } else if odd {
                Some(position + width)
            } else if x == 0 {
                None
            } else {
                Some(position + width - 1)
            },
            Direction::NorthWest => if y == height - 1 {
                None
            } else if !odd {
                Some(position + width)
            } else if x == width - 1 {
                None
            } else {
                Some(position + width + 1)
            },
            Direction::SouthEast => if y == 0 {
                None
            } else if odd {
                Some(position - width)
            } else if x == 0 {
                None
            } else {
                Some(position - width - 1)
            },
            Direction::SouthWest => if y == 0 {
                None
            } else if !odd {
                Some(position - width)
            } else if x == width - 1 {
                None
            } else {
                Some(position + 1 - width)
            },
        }
    }

    /// Direction from a position to an adjacent one, through their coordinates: `Some(d)` if and
    /// only if `neighbor(width, height, from, d) == Some(to)`.
    /// # Arguments
    /// * `width` - The width of the map, not zero
    /// * `height` - The height of the map
    /// * `from` - The position
    /// * `to` - The other position
    /// # Returns
    /// * The direction, `None` when either position lies outside the board or the two are not
    ///   neighbours (the last tile of a row and the first of the next are not)
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §6.1).
    fn neighbor_direction(width: u8, height: u8, from: u8, to: u8) -> Option<Direction> {
        // [Check] Both positions in the board: a row below the height
        let divisor: NonZero<u8> = width.try_into().unwrap();
        let (y_from, x_from) = DivRem::div_rem(from, divisor);
        let (y_to, x_to) = DivRem::div_rem(to, divisor);
        if y_from >= height || y_to >= height {
            return None;
        }
        // [Compute] Same row: East is x - 1, West is x + 1
        if y_to == y_from {
            return if x_to + 1 == x_from {
                Some(Direction::East)
            } else if x_to == x_from + 1 {
                Some(Direction::West)
            } else {
                None
            };
        }
        let north = y_to == y_from + 1;
        if !north && y_from != y_to + 1 {
            return None;
        }
        // [Compute] Row above or below: the East neighbour is x - 1 on an even row and x on an
        // odd one, the West neighbour one more; with `t = x_to + 1 - odd`, East is `t == x`
        let (_, odd) = DivRem::div_rem(y_from, TWO);
        let t = x_to + 1 - odd;
        if t == x_from {
            Some(if north {
                Direction::NorthEast
            } else {
                Direction::SouthEast
            })
        } else if t == x_from + 1 {
            Some(if north {
                Direction::NorthWest
            } else {
                Direction::SouthWest
            })
        } else {
            None
        }
    }
}

#[generate_trait]
pub impl DilationImpl of DilationTrait {
    /// Hex dilation on the limbs of a frontier also given as a felt (lot L1). With the West pairs
    /// `P` split by row parity, the up neighbours are `Pe * 2^(W-1) + Po * 2^W`, that is
    /// `(2P - Pe) * 2^(W-1)`, and the down neighbours `(2P - Pe) * 2^-(W+1)`: one product each.
    /// # Arguments
    /// * `self` - The constants
    /// * `low` - The low limb of the frontier, interior tiles only (border invariant)
    /// * `high` - The high limb of the frontier
    /// * `felt` - The frontier as a felt
    /// # Returns
    /// * The limbs of the frontier and its neighbours
    #[inline(always)]
    fn dilate(self: @Dilation, low: u128, high: u128, felt: felt252) -> (u128, u128) {
        let dilation = *self;
        // [Compute] Frontier and its West neighbours, then split by row parity
        let double: u256 = (felt + felt).into();
        let (_, _, pairs_low) = Bits::bitwise(low, double.low);
        let (_, _, pairs_high) = Bits::bitwise(high, double.high);
        let (even_low, _, _) = Bits::bitwise(pairs_low, dilation.even_low);
        let (even_high, _, _) = Bits::bitwise(pairs_high, dilation.even_high);
        let pairs: felt252 = pairs_low.into() + pairs_high.into() * TWO_POW_128;
        let even: felt252 = even_low.into() + even_high.into() * TWO_POW_128;
        let rows = pairs + pairs - even;
        // [Compute] NE/NW, SE/SW and East neighbours
        let up: u256 = (rows * dilation.up).into();
        let down: u256 = (rows * dilation.down).into();
        let east: u256 = (felt * INV_2).into();
        // [Return] Union
        let (_, _, side_low) = Bits::bitwise(pairs_low, east.low);
        let (_, _, side_high) = Bits::bitwise(pairs_high, east.high);
        let (_, _, vertical_low) = Bits::bitwise(up.low, down.low);
        let (_, _, vertical_high) = Bits::bitwise(up.high, down.high);
        let (_, _, low) = Bits::bitwise(side_low, vertical_low);
        let (_, _, high) = Bits::bitwise(side_high, vertical_high);
        (low, high)
    }

    /// `dilate` for boards of at most 128 bits: every shift fits the limb.
    /// # Arguments
    /// * `self` - The constants
    /// * `frontier` - The frontier, interior tiles only (border invariant)
    /// # Returns
    /// * The frontier and its neighbours
    #[inline(always)]
    fn expand_small(self: @Dilation, frontier: u128) -> u128 {
        let dilation = *self;
        let (_, _, pairs) = Bits::bitwise(frontier, frontier + frontier);
        let (even, _, _) = Bits::bitwise(pairs, dilation.even_low);
        let pairs_felt: felt252 = pairs.into();
        let rows = pairs_felt + pairs_felt - even.into();
        let up: u128 = (rows * dilation.up).try_into().unwrap();
        let down: u128 = (rows * dilation.down).try_into().unwrap();
        let east: u128 = (frontier.into() * INV_2).try_into().unwrap();
        let (_, _, side) = Bits::bitwise(pairs, east);
        let (_, _, vertical) = Bits::bitwise(up, down);
        let (_, _, next) = Bits::bitwise(side, vertical);
        next
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use super::{DIRECTIONS, Direction, LayoutTrait};

    /// Pairs of a board per seeded test.
    const PAIRS: u32 = 512;

    // Oracles

    #[generate_trait]
    impl Oracle of OracleTrait {
        /// `neighbor_direction` by its definition: the first direction whose `neighbor` is `to`,
        /// `None` when there is none or when either position lies outside the board.
        fn neighbor_direction(width: u8, height: u8, from: u8, to: u8) -> Option<Direction> {
            let size: u16 = width.into() * height.into();
            if from.into() >= size || to.into() >= size {
                return None;
            }
            for direction in DIRECTIONS.span() {
                if LayoutTrait::neighbor(width, height, from, *direction) == Some(to) {
                    return Some(*direction);
                }
            }
            None
        }

        /// The next state of a 64-bit linear congruential generator (Knuth's MMIX constants).
        fn next(state: u64) -> u64 {
            let product: u128 = state.into() * 6364136223846793005 + 1442695040888963407;
            (product % 0x10000000000000000).try_into().unwrap()
        }
    }

    // neighbor_direction

    /// R-D2 and R-D4 on the window 15 × 16.
    #[test]
    #[available_gas(l2_gas: 14406)]
    fn test_layout_neighbor_direction_regression() {
        // R-D2: the last tile of row 0 and the first of row 1 are not neighbours
        assert!(LayoutTrait::neighbor_direction(15, 16, 14, 15).is_none());
        // R-D4
        assert!(LayoutTrait::neighbor_direction(15, 16, 0, 1) == Some(Direction::West));
        assert!(LayoutTrait::neighbor_direction(15, 16, 0, 14).is_none());
        // Outside the board, and a tile is not its own neighbour
        assert!(LayoutTrait::neighbor_direction(15, 16, 240, 225).is_none());
        assert!(LayoutTrait::neighbor_direction(15, 16, 225, 240).is_none());
        assert!(LayoutTrait::neighbor_direction(15, 16, 255, 254).is_none());
        assert!(LayoutTrait::neighbor_direction(15, 16, 17, 17).is_none());
    }

    /// R-D3: every position and every direction of 15 × 16; `neighbor(from, d) = Some(to)`
    /// gives `neighbor_direction(from, to) = Some(d)` (a boundary asserts nothing).
    #[test]
    #[available_gas(l2_gas: 28054730)]
    fn test_layout_neighbor_direction_window() {
        let mut from: u8 = 0;
        while from != 240 {
            for direction in DIRECTIONS.span() {
                if let Some(to) = LayoutTrait::neighbor(15, 16, from, *direction) {
                    assert!(LayoutTrait::neighbor_direction(15, 16, from, to) == Some(*direction));
                }
            }
            from += 1;
        }
    }

    /// Every pair of positions of a 7 × 7 and of an 8 × 5 (even width), `to` up to one row
    /// beyond the board, against the definition.
    #[test]
    #[available_gas(l2_gas: 297619445)]
    fn test_layout_neighbor_direction_pairs() {
        let boards: [(u8, u8); 2] = [(7, 7), (8, 5)];
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            let end = width * (height + 1);
            let mut from: u8 = 0;
            while from != end {
                let mut to: u8 = 0;
                while to != end {
                    assert!(
                        LayoutTrait::neighbor_direction(
                            width, height, from, to,
                        ) == Oracle::neighbor_direction(width, height, from, to),
                        "{} x {}: {} -> {}",
                        width,
                        height,
                        from,
                        to,
                    );
                    to += 1;
                }
                from += 1;
            }
        }
    }

    /// 512 seeded pairs on each of 17 × 14, 19 × 13, and the wide boards 85 × 3, 127 × 2, 128
    /// × 1 and 251 × 1 (every `u8` as a position, `2W` above 255), half of them within two rows
    /// of each other, against the definition.
    #[test]
    #[available_gas(l2_gas: 223028883)]
    fn test_layout_neighbor_direction_seeded() {
        let boards: [(u8, u8); 6] = [(17, 14), (19, 13), (85, 3), (127, 2), (128, 1), (251, 1)];
        let mut state: u64 = 'neighbor';
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            let mut index: u32 = 0;
            while index != PAIRS {
                state = Oracle::next(state);
                let from: u8 = ((state / 0x100000000) % 256).try_into().unwrap();
                let to: u8 = if index % 2 == 0 {
                    ((state / 0x10000000000) % 256).try_into().unwrap()
                } else {
                    // Within two rows: from - 2W - 2 + (0..4W+4), clamped to u8
                    let span: u64 = 4 * width.into() + 5;
                    let offset: u64 = (state / 0x10000000000) % span;
                    let target: u64 = from.into() + offset;
                    let back: u64 = 2 * width.into() + 2;
                    if target < back {
                        0
                    } else if target - back > 255 {
                        255
                    } else {
                        (target - back).try_into().unwrap()
                    }
                };
                assert!(
                    LayoutTrait::neighbor_direction(
                        width, height, from, to,
                    ) == Oracle::neighbor_direction(width, height, from, to),
                );
                index += 1;
            }
        }
    }

    // Benchmarks: the worst case, an odd row and a non-adjacent pair one row above (the
    // longest branch); the difference between two calls and one, the method of `bench_assembly`.

    #[derive(Copy, Drop)]
    struct Bench {
        /// `(x, y) = (5, 1)` to `(12, 2)`, then `(7, 1)` to `(0, 2)`, on 15 × 16.
        pairs: [(u8, u8); 2],
    }

    #[generate_trait]
    impl Inputs of InputsTrait {
        /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
        #[inline(never)]
        fn get() -> Bench {
            Bench { pairs: [(20, 42), (22, 30)] }
        }
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 26124)]
    fn bench_layout_neighbor_direction_once() {
        let bench = Inputs::get();
        let [(from, to), _] = bench.pairs;
        assert!(LayoutTrait::neighbor_direction(15, 16, from, to).is_none());
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 36246)]
    fn bench_layout_neighbor_direction_twice() {
        let bench = Inputs::get();
        let [(from, to), (other, next)] = bench.pairs;
        assert!(LayoutTrait::neighbor_direction(15, 16, from, to).is_none());
        assert!(LayoutTrait::neighbor_direction(15, 16, other, next).is_none());
    }
}
