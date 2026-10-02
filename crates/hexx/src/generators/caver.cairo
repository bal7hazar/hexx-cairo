//! Cave generator: synchronous bit-sliced cellular automaton (lot L4).
//!
//! The whole board is one generation: the 6 neighbour planes are field shifts of the grid, a
//! carry-save adder counts them bit-sliced, and the rule is two set operations. Rule `B4/S2`: a
//! wall with at least 4 floor neighbours becomes floor, a floor with at least 2 stays floor.
//!
//! N-1 (plan §6.2), `generate_with_margins` and `smooth`: the same automaton on a board whose
//! ring holds tiles (the margins copied from the neighbouring chunks) and whose rows have the
//! global parity of the chunk. Some tiles are frozen, the ring always and the held tiles of
//! `smooth`: they keep their value, and their part of the six neighbour planes is computed once
//! (`CaverInternal::freeze`). A generation then builds the planes of the free tiles as `generate`
//! does, adds the frozen part to each and masks the rule by the free tiles
//! (`CaverInternal::step_frozen`).

// Core imports

use core::felt252_div;
use core::poseidon::hades_permutation;

// Internal imports

use hexx::board::asserter::Asserter;
use hexx::board::asserter::{MAX_SIZE, errors as asserter};
use hexx::board::bits::Bits;
use hexx::board::layout::{Layout, LayoutTrait};
use hexx::finders::bfs::BfsInternal;

// Constants

/// 1/2 in the field.
const INV_2: felt252 = 0x400000000000008800000000000000000000000000000000000000000000001;
/// Largest board of the single-limb path.
const SMALL_SIZE: u8 = 128;

/// Errors module.
pub mod errors {
    pub const CAVER_POSITION_NOT_FLOOR: felt252 = 'Caver: position not floor';
    pub const CAVER_DIMENSIONS_TOO_LARGE: felt252 = 'Caver: dimensions too large';
}

/// Shift constants of the neighbour planes.
#[derive(Copy, Drop)]
struct Shifts {
    /// 2^(W-1)
    up_even: felt252,
    /// 2^W
    up_odd: felt252,
    /// 2^(W+1)
    up_wide: felt252,
    /// 2^-(W+1)
    down_even: felt252,
    /// 2^-W
    down_odd: felt252,
    /// 2^-(W-1)
    down_wide: felt252,
}

/// Constants of a board with margins (plan §6.2), by the global parity of its rows.
#[derive(Copy, Drop)]
struct Margins {
    /// Whether local row 0 is a global odd row.
    odd: bool,
    /// Bits of the whole board, `2^(W*H) - 1`.
    board: felt252,
    /// Bits of the interior.
    interior: felt252,
    /// Bits of the four corners.
    corners: felt252,
    /// Bits of row 0, `2^W - 1`: they lie in the low limb.
    bottom: u128,
    /// Bits of the globally even rows, without column 0.
    evens: u256,
    /// Bits of the globally odd rows, without column `W - 1`.
    odds: u256,
    /// The shift constants.
    shifts: Shifts,
}

/// The frozen tiles of a board and their part of the six neighbour planes, constant over the
/// generations.
#[derive(Copy, Drop)]
struct Frozen {
    /// The frozen tiles at their value: the ring, and the held tiles of `smooth`.
    tiles: felt252,
    /// Their part of the plane of the East neighbours, `i - 1`.
    east: felt252,
    /// Of the West neighbours, `i + 1`.
    west: felt252,
    /// Of the northern neighbours at `i + W`.
    north: felt252,
    /// Of the other northern neighbours, `i + W - 1` or `i + W + 1` by row parity.
    north_other: felt252,
    /// Of the southern neighbours at `i - W`.
    south: felt252,
    /// Of the other southern neighbours, `i - W - 1` or `i - W + 1` by row parity.
    south_other: felt252,
}

#[generate_trait]
pub impl Caver of CaverTrait {
    /// Generate a cave.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `order` - The number of generations
    /// * `seed` - The seed
    /// # Returns
    /// * The generated grid
    fn generate(width: u8, height: u8, order: u8, seed: felt252) -> felt252 {
        // [Check] Dimensions
        Asserter::assert_valid_dimension(width, height);
        // [Compute] Initial fill: half of the interior
        if order == 0 {
            let interior = LayoutTrait::interior(width, height);
            return Bits::to_felt(CaverInternal::fill(interior, seed));
        }
        let (layout, interior) = LayoutTrait::with_interior(width, height);
        let grid = CaverInternal::fill(interior, seed);
        // [Compute] Generations
        if width * height <= SMALL_SIZE {
            CaverInternal::evolve_small(@layout, grid.low, order)
        } else {
            CaverInternal::evolve(@layout, grid, order)
        }
    }

    /// Keep the floor tiles connected to a position: the flood fill of `Bfs::reachable`, one
    /// dilation per layer on the frontier only (see `GAS.md`, P1).
    /// # Arguments
    /// * `grid` - The grid, interior tiles only
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `from` - The position, a floor tile
    /// # Returns
    /// * The connected component of `from`
    /// # Panics
    /// * If `from` is not floor, or the dimensions are invalid
    fn keep_component(grid: felt252, width: u8, height: u8, from: u8) -> felt252 {
        // [Check] Start is floor
        let open: u256 = grid.into();
        assert(Bits::get(open, from), errors::CAVER_POSITION_NOT_FLOOR);
        // [Return] Flood fill, the grid has no open edge tile
        Asserter::assert_valid_dimension(width, height);
        BfsInternal::component(open, width, height, from)
    }

    /// Generate a cave given its margins (plan §6.2, N-1): the ring tiles of `fixed` take their
    /// value from `values` (the sides that face an already generated neighbour), every other tile
    /// is drawn from the seed as `generate` draws the interior, then the automaton runs `order`
    /// generations on the interior with the ring frozen, each row with its global parity.
    ///
    /// The four corners are always wall (D-134): a corner is never drawn, and a corner of
    /// `values` is cleared like every bit of `values` outside `fixed` and the ring, not refused.
    /// With the whole ring fixed to wall and `odd = false`, the result is `generate`'s.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `order` - The number of generations
    /// * `seed` - The seed
    /// * `fixed` - The ring tiles whose value is given, masked to the ring
    /// * `values` - Their values, masked to `fixed`
    /// * `odd` - Whether local row 0 is a global odd row
    /// # Returns
    /// * The generated grid
    /// # Panics
    /// * `'Asserter: invalid dimension'` when `W < 3` or `H < 3`
    /// * `'Caver: dimensions too large'` when `W * (H + 1) + 1 > 251`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §6.2, N-1).
    fn generate_with_margins(
        width: u8, height: u8, order: u8, seed: felt252, fixed: felt252, values: felt252, odd: bool,
    ) -> felt252 {
        // [Check] Dimensions
        CaverAssert::assert_margins(width, height);
        // [Compute] The given tiles: the fixed tiles of the ring, corners excluded
        let margins = CaverInternal::margins(width, height, odd);
        let sides = margins.board - margins.interior - margins.corners;
        let given = Bits::and(fixed.into(), sides.into());
        let kept = Bits::to_felt(Bits::and(values.into(), given));
        // [Compute] Initial fill: every tile but the given ones and the corners, as `fill` draws
        let (noise, _, _) = hades_permutation(seed, 0, 2);
        let drawn = margins.board - margins.corners - Bits::to_felt(given);
        let fill = Bits::and(noise.into(), drawn.into());
        if order == 0 {
            return Bits::to_felt(fill) + kept;
        }
        // [Compute] Generations on the interior, the ring frozen
        let free: u256 = margins.interior.into();
        let grid = Bits::and(fill, free);
        let frozen = Bits::to_felt(fill) - Bits::to_felt(grid) + kept;
        CaverInternal::evolve_frozen(@margins, frozen, free, grid, order)
    }

    /// Run `order` generations of the automaton on an existing grid (plan §6.2, N-1): the ring
    /// and the tiles of `held` keep their value (D-28), each row has its global parity.
    /// # Arguments
    /// * `grid` - The grid, without bits at or above `W * H`
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `order` - The number of generations
    /// * `held` - The tiles that keep their value, any tiles; the ring is always held
    /// * `odd` - Whether local row 0 is a global odd row
    /// # Returns
    /// * The grid after `order` generations
    /// # Panics
    /// * `'Asserter: invalid dimension'` when `W < 3` or `H < 3`
    /// * `'Caver: dimensions too large'` when `W * (H + 1) + 1 > 251`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §6.2, N-1).
    fn smooth(
        grid: felt252, width: u8, height: u8, order: u8, held: felt252, odd: bool,
    ) -> felt252 {
        // [Check] Dimensions
        CaverAssert::assert_margins(width, height);
        if order == 0 {
            return grid;
        }
        // [Compute] The free tiles: the interior minus the held tiles
        let margins = CaverInternal::margins(width, height, odd);
        let interior: u256 = margins.interior.into();
        let held = Bits::and(held.into(), interior);
        let free = u256 { low: interior.low - held.low, high: interior.high - held.high };
        // [Compute] Generations on the free tiles
        let free_grid = Bits::and(grid.into(), free);
        let frozen = grid - Bits::to_felt(free_grid);
        CaverInternal::evolve_frozen(@margins, frozen, free, free_grid, order)
    }
}

/// Checks of the generator.
#[generate_trait]
impl CaverAssert of CaverAssertTrait {
    /// Assert that a board can hold margins: `W, H >= 3`, and `W * (H + 1) + 1 <= 251` so that
    /// every neighbour plane of a live ring stays below 2^251 (plan §6.2, D-30).
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// # Panics
    /// * `'Asserter: invalid dimension'` when `W < 3` or `H < 3`
    /// * `'Caver: dimensions too large'` when `W * (H + 1) + 1 > 251`
    #[inline]
    fn assert_margins(width: u8, height: u8) {
        assert(width > 2, asserter::ASSERTER_INVALID_DIMENSION);
        assert(height > 2, asserter::ASSERTER_INVALID_DIMENSION);
        let size: u16 = width.into() * (height.into() + 1) + 1;
        assert(size <= MAX_SIZE, errors::CAVER_DIMENSIONS_TOO_LARGE);
    }
}

#[generate_trait]
impl CaverInternal of CaverInternalTrait {
    /// Random initial fill, each interior tile is floor with probability 1/2.
    /// # Arguments
    /// * `interior` - The interior mask
    /// * `seed` - The seed
    /// # Returns
    /// * The initial grid, interior tiles only
    #[inline]
    fn fill(interior: felt252, seed: felt252) -> u256 {
        let (noise, _, _) = core::poseidon::hades_permutation(seed, 0, 2);
        Bits::and(noise.into(), interior.into())
    }

    /// Run `order` generations of the automaton on a grid of interior tiles.
    /// # Arguments
    /// * `layout` - The layout
    /// * `grid` - The grid, interior tiles only
    /// * `order` - The number of generations, `0` returns the grid
    /// # Returns
    /// * The grid after `order` generations
    fn evolve(layout: @Layout, grid: u256, order: u8) -> felt252 {
        let layout = *layout;
        let shifts = Self::shifts(@layout);
        let mut felt = Bits::to_felt(grid);
        let mut grid = grid;
        let mut order = order;
        while order != 0 {
            order -= 1;
            grid = Self::step(@shifts, layout.even, grid, felt);
            felt = Bits::to_felt(grid);
        }
        felt
    }

    /// `evolve` for boards of at most 128 bits, on a single limb.
    /// # Arguments
    /// * `layout` - The layout, `W * H <= 128`
    /// * `grid` - The grid, interior tiles only
    /// * `order` - The number of generations, `0` returns the grid
    /// # Returns
    /// * The grid after `order` generations
    fn evolve_small(layout: @Layout, grid: u128, order: u8) -> felt252 {
        let layout = *layout;
        let shifts = Self::shifts(@layout);
        let mut felt: felt252 = grid.into();
        let mut grid = grid;
        let mut order = order;
        while order != 0 {
            order -= 1;
            grid = Self::step_small(@shifts, layout.even.low, grid, felt);
            felt = grid.into();
        }
        felt
    }

    /// Shift constants of the neighbour planes.
    #[inline]
    fn shifts(layout: @Layout) -> Shifts {
        let layout = *layout;
        Shifts {
            up_even: layout.up_even,
            up_odd: layout.up_odd,
            up_wide: layout.up_odd + layout.up_odd,
            down_even: layout.down_even,
            down_odd: layout.down_odd,
            down_wide: layout.down_odd + layout.down_odd,
        }
    }

    /// One generation on the whole board.
    /// # Arguments
    /// * `shifts` - The shift constants
    /// * `even` - The even rows mask
    /// * `grid` - The grid, interior tiles only
    /// * `felt` - The same grid as a felt
    /// # Returns
    /// * The next grid, interior tiles only
    #[inline]
    fn step(shifts: @Shifts, even: u256, grid: u256, felt: felt252) -> u256 {
        let shifts = *shifts;
        // [Compute] Split by row parity
        let (low, _, _) = Bits::bitwise(grid.low, even.low);
        let (high, _, _) = Bits::bitwise(grid.high, even.high);
        let grid_even = Bits::to_felt(u256 { low, high });
        let grid_odd = felt - grid_even;
        // [Compute] Neighbour planes: bit i of a plane is the grid at one neighbour of i
        let east: u256 = (felt + felt).into();
        let west: u256 = (felt * INV_2).into();
        let north: u256 = (felt * shifts.down_odd).into();
        let north_other: u256 = (grid_odd * shifts.down_wide + grid_even * shifts.down_even).into();
        let south: u256 = (felt * shifts.up_odd).into();
        let south_other: u256 = (grid_odd * shifts.up_wide + grid_even * shifts.up_even).into();
        // [Compute] Rule, per limb
        let low = Self::rule(
            grid.low, east.low, west.low, north.low, north_other.low, south.low, south_other.low,
        );
        let high = Self::rule(
            grid.high,
            east.high,
            west.high,
            north.high,
            north_other.high,
            south.high,
            south_other.high,
        );
        // [Return] Next grid
        u256 { low, high }
    }

    /// One generation on a single limb, `W * H <= 128`.
    /// # Arguments
    /// * `shifts` - The shift constants
    /// * `even` - The even rows mask
    /// * `grid` - The grid, interior tiles only
    /// * `felt` - The same grid as a felt
    /// # Returns
    /// * The next grid, interior tiles only
    #[inline]
    fn step_small(shifts: @Shifts, even: u128, grid: u128, felt: felt252) -> u128 {
        let shifts = *shifts;
        let (grid_even, _, _) = Bits::bitwise(grid, even);
        let grid_even: felt252 = grid_even.into();
        let grid_odd = felt - grid_even;
        Self::rule(
            grid,
            (felt + felt).try_into().unwrap(),
            (felt * INV_2).try_into().unwrap(),
            (felt * shifts.down_odd).try_into().unwrap(),
            (grid_odd * shifts.down_wide + grid_even * shifts.down_even).try_into().unwrap(),
            (felt * shifts.up_odd).try_into().unwrap(),
            (grid_odd * shifts.up_wide + grid_even * shifts.up_even).try_into().unwrap(),
        )
    }

    /// Rule `B4/S2` on one limb of the 6 neighbour planes: `b2 | (grid & b1)`, where
    /// `count = 4 * b2 + 2 * b1 + b0` (`b0` is not needed). Born tiles are interior: a border tile
    /// has at most 3 interior neighbours.
    /// 9 builtin applications, carries as additions of disjoint bitmaps.
    /// # Returns
    /// * The next limb
    #[inline(always)]
    fn rule(grid: u128, a: u128, b: u128, c: u128, d: u128, e: u128, f: u128) -> u128 {
        // [Compute] Full adders on (a, b, c) and (d, e, f)
        let (ab, x, _) = Bits::bitwise(a, b);
        let (xc, s1, _) = Bits::bitwise(x, c);
        let (de, y, _) = Bits::bitwise(d, e);
        let (yf, s2, _) = Bits::bitwise(y, f);
        // [Compute] Half adder on the sums: weight-2 carry
        let (c3, _, _) = Bits::bitwise(s1, s2);
        // [Compute] Full adder on the weight-2 carries
        let (c12, x12, _) = Bits::bitwise(ab + xc, de + yf);
        let (x3, b1, _) = Bits::bitwise(x12, c3);
        // [Return] Born with 4+, survive with 2+
        let (survive, _, _) = Bits::bitwise(grid, b1);
        let (_, _, next) = Bits::bitwise(c12 + x3, survive);
        next
    }

    /// The constants of a board with margins, from three table lookups and one exact division.
    ///
    /// Column 0 on the local even rows is `(2^(2W * ceil(H/2)) - 1) / (2^(2W) - 1)`, exact as in
    /// `LayoutTrait::even`; on the local odd rows it is that column one row up, without the bit
    /// that leaves the board when `H` is odd. Every mask is the product of one of them, or of
    /// both, by the pattern of a row.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map, `W * (H + 1) + 1 <= 251`
    /// * `odd` - Whether local row 0 is a global odd row
    /// # Returns
    /// * The constants
    #[inline]
    fn margins(width: u8, height: u8, odd: bool) -> Margins {
        let row = Bits::pow(width);
        let down = Bits::inv(width);
        let board = Bits::pow(width * height);
        let up_even = row * INV_2;
        // [Compute] Column 0 on the local even rows and on the local odd rows
        let pair: NonZero<felt252> = (row * row - 1).try_into().unwrap();
        let (first, second) = if height % 2 == 0 {
            let first = felt252_div(board - 1, pair);
            (first, first * row)
        } else {
            let first = felt252_div(board * row - 1, pair);
            (first, (first - 1) * down)
        };
        // [Compute] Tile `(0, H - 1)`, then column 0 on the globally even and odd rows
        let top = board * down;
        let (even, other) = if odd {
            (second, first)
        } else {
            (first, second)
        };
        Margins {
            odd,
            board: board - 1,
            interior: (first + second - 1 - top) * (up_even - 2),
            corners: (1 + up_even) * (1 + top),
            bottom: (row - 1).try_into().unwrap(),
            evens: (even * (row - 2)).into(),
            odds: (other * (up_even - 1)).into(),
            shifts: Shifts {
                up_even,
                up_odd: row,
                up_wide: row + row,
                down_even: down * INV_2,
                down_odd: down,
                down_wide: down + down,
            },
        }
    }

    /// The part of the six neighbour planes that comes from the frozen tiles.
    ///
    /// Every plane is a field product of the tiles by a power of two, exact and without a carry:
    /// * a tile that would wrap around a column edge in the two parity-dependent planes is
    ///   cleared first (column `W - 1` on the globally odd rows, column 0 on the globally even
    ///   ones: `Margins::odds`, `Margins::evens`); its true neighbour there lies outside the
    ///   board. The tiles left reach their true neighbour, so no two of them, frozen or free,
    ///   reach the same bit, and the planes add up without a carry (the audit's case `(14, 11)`,
    ///   `(1, 12)`, `(1, 13)` on 15 x 15);
    /// * row 0 is cleared before the three downward products (West, and both northern planes):
    ///   its tiles have no northern destination, and their West destinations are ring tiles.
    ///   With column 0 cleared on the globally even rows, no bit is left below the largest
    ///   divisor, `2^(W+1)`;
    /// * the upward products stay below `2^(W * (H + 1) + 1) <= 2^251` (`assert_margins`).
    /// The other wrap-arounds (East of column `W - 1`, West of column 0) land on ring tiles,
    /// whose bits no plane specifies: the rule is masked by the free tiles.
    /// # Arguments
    /// * `margins` - The constants
    /// * `tiles` - The frozen tiles at their value: the ring, and any interior tile
    /// # Returns
    /// * The frozen tiles and their planes
    #[inline]
    fn freeze(margins: @Margins, tiles: felt252) -> Frozen {
        let margins = *margins;
        let shifts = margins.shifts;
        // [Compute] Split by global row parity, without the tiles that wrap
        let wide: u256 = tiles.into();
        let even = Bits::and(wide, margins.evens);
        let odd = Bits::and(wide, margins.odds);
        let up_even = Bits::to_felt(even);
        let up_odd = Bits::to_felt(odd);
        // [Compute] Without row 0 for the downward planes: it lies in one parity
        let (bottom, _, _) = Bits::bitwise(wide.low, margins.bottom);
        let down = tiles - bottom.into();
        let (down_even, down_odd) = if margins.odd {
            let (bottom, _, _) = Bits::bitwise(odd.low, margins.bottom);
            (up_even, up_odd - bottom.into())
        } else {
            let (bottom, _, _) = Bits::bitwise(even.low, margins.bottom);
            (up_even - bottom.into(), up_odd)
        };
        Frozen {
            tiles,
            east: tiles + tiles,
            west: down * INV_2,
            north: down * shifts.down_odd,
            north_other: down_odd * shifts.down_wide + down_even * shifts.down_even,
            south: tiles * shifts.up_odd,
            south_other: up_odd * shifts.up_wide + up_even * shifts.up_even,
        }
    }

    /// The six neighbour planes of a grid given as its free tiles and the planes of its frozen
    /// tiles: bit `i` of a plane is the grid at one neighbour of `i`, for every interior tile
    /// `i`. The bits of the ring tiles are unspecified.
    ///
    /// The free tiles are interior tiles: their planes are those of `step`, exact under the
    /// border invariant. A frozen and a free tile never reach the same bit of a plane
    /// (`freeze`), so each sum is a union.
    /// # Arguments
    /// * `margins` - The constants
    /// * `frozen` - The planes of the frozen tiles
    /// * `grid` - The free tiles of the grid, interior tiles only
    /// * `felt` - The same as a felt
    /// # Returns
    /// * The planes East, West, North (`i + W`), other North, South (`i - W`), other South
    #[inline(always)]
    fn planes(
        margins: @Margins, frozen: @Frozen, grid: u256, felt: felt252,
    ) -> (u256, u256, u256, u256, u256, u256) {
        let margins = *margins;
        let shifts = margins.shifts;
        let frozen = *frozen;
        // [Compute] Split by global row parity: no free tile lies on column 0
        let (low, _, _) = Bits::bitwise(grid.low, margins.evens.low);
        let (high, _, _) = Bits::bitwise(grid.high, margins.evens.high);
        let grid_even = Bits::to_felt(u256 { low, high });
        let grid_odd = felt - grid_even;
        // [Return] Planes of the free tiles, plus those of the frozen tiles
        (
            (felt + felt + frozen.east).into(),
            (felt * INV_2 + frozen.west).into(),
            (felt * shifts.down_odd + frozen.north).into(),
            (grid_odd * shifts.down_wide + grid_even * shifts.down_even + frozen.north_other)
                .into(),
            (felt * shifts.up_odd + frozen.south).into(),
            (grid_odd * shifts.up_wide + grid_even * shifts.up_even + frozen.south_other).into(),
        )
    }

    /// One generation on the free tiles of a board with frozen tiles.
    /// # Arguments
    /// * `margins` - The constants
    /// * `frozen` - The planes of the frozen tiles
    /// * `free` - The tiles that evolve, interior tiles only
    /// * `grid` - The free tiles of the grid
    /// * `felt` - The same as a felt
    /// # Returns
    /// * The free tiles of the next grid
    #[inline]
    fn step_frozen(
        margins: @Margins, frozen: @Frozen, free: u256, grid: u256, felt: felt252,
    ) -> u256 {
        let (east, west, north, north_other, south, south_other) = Self::planes(
            margins, frozen, grid, felt,
        );
        // [Compute] Rule, per limb: a free tile survives on its own value; a frozen tile, or a
        // bit outside the board, is never born
        let low = Self::rule(
            grid.low, east.low, west.low, north.low, north_other.low, south.low, south_other.low,
        );
        let high = Self::rule(
            grid.high,
            east.high,
            west.high,
            north.high,
            north_other.high,
            south.high,
            south_other.high,
        );
        let (low, _, _) = Bits::bitwise(low, free.low);
        let (high, _, _) = Bits::bitwise(high, free.high);
        // [Return] Next free tiles
        u256 { low, high }
    }

    /// Run `order` generations of the automaton on a board with frozen tiles.
    /// # Arguments
    /// * `margins` - The constants
    /// * `frozen` - The frozen tiles at their value: the ring, and any interior tile
    /// * `free` - The tiles that evolve: interior tiles, none of them frozen
    /// * `grid` - The free tiles of the grid
    /// * `order` - The number of generations, `0` returns the grid
    /// # Returns
    /// * The whole grid after `order` generations
    fn evolve_frozen(
        margins: @Margins, frozen: felt252, free: u256, grid: u256, order: u8,
    ) -> felt252 {
        let frozen = Self::freeze(margins, frozen);
        let mut felt = Bits::to_felt(grid);
        let mut grid = grid;
        let mut order = order;
        while order != 0 {
            order -= 1;
            grid = Self::step_frozen(margins, @frozen, free, grid, felt);
            felt = Bits::to_felt(grid);
        }
        felt + frozen.tiles
    }
}

#[cfg(test)]
mod tests {
    // Core imports

    use core::poseidon::hades_permutation;

    // Internal imports

    use hexx::board::bits::Bits;
    use hexx::board::direction::Direction;
    use hexx::board::layout::LayoutTrait;
    use hexx::board::seams::{SeamTrait, Side};
    use hexx::tests::bench_caver::{fill_half, keep_component_dilation, reference};
    use hexx::tests::fixtures::{UNREACHABLE_17X14, UNREACHABLE_17X14_FAR_FROM};

    // Local imports

    use super::Caver;
    use super::CaverInternal;

    // Constants

    const SEED: felt252 = 'CAVE';

    /// Invariants of a generated cave: interior only, deterministic, equal to the scalar
    /// reference automaton (B4/S2) run on the same initial fill.
    fn check_generate(width: u8, height: u8) {
        let interior: u256 = LayoutTrait::interior(width, height).into();
        let mut seed: felt252 = 0;
        while seed != 4 {
            let fill = fill_half(width, height, seed);
            let mut order: u8 = 0;
            while order != 5 {
                let grid = Caver::generate(width, height, order, seed);
                let open: u256 = grid.into();
                assert!(open & interior == open, "border ring must stay closed");
                assert!(grid == Caver::generate(width, height, order, seed));
                assert!(grid == reference(fill, width, height, order, 4, 2));
                order += 1;
            }
            seed += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 142913)]
    fn test_caver_generate_17x14() {
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        //  0 0 1 1 1 0 0 1 0 0 0 0 0 0 1 0 0
        // 0 1 1 1 1 1 1 1 1 0 0 0 0 0 1 1 0
        //  0 1 1 1 1 1 1 1 1 0 1 1 1 1 1 0 0
        // 0 1 1 1 1 1 1 1 1 0 0 1 1 1 0 0 0
        //  0 1 1 1 1 1 0 0 0 0 1 1 1 0 0 0 0
        // 0 0 1 1 1 1 0 0 0 1 1 1 1 1 0 0 0
        //  0 1 1 1 1 1 0 0 0 1 1 1 1 1 1 1 0
        // 0 1 1 1 1 1 1 0 0 1 1 1 1 1 1 1 0
        //  0 1 1 1 1 1 1 0 1 1 1 1 1 1 1 1 0
        // 0 0 1 1 1 1 1 0 0 1 0 0 1 1 1 0 0
        //  0 0 1 1 1 1 1 1 1 1 0 1 1 1 0 0 0
        // 0 0 0 0 1 1 1 1 1 1 0 0 1 0 0 0 0
        //  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        let grid = Caver::generate(17, 14, 3, SEED);
        assert!(grid == 0x72047f833fdf1fe70f8703c7c3e3f9f9fcfdfe3e4e1fee03f200000);
    }

    #[test]
    #[available_gas(l2_gas: 143018)]
    fn test_caver_generate_19x13() {
        //  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 0 1 1 0 0 1 1 1 1 1 0 0 0 0 1 0 0 0
        //  0 1 1 1 1 1 1 1 1 1 1 1 0 0 1 1 1 0 0
        // 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0
        //  0 1 1 1 1 1 1 1 1 1 0 0 1 1 1 0 0 0 0
        // 0 0 1 1 1 0 0 1 1 1 1 0 0 1 1 0 0 0 0
        //  0 1 1 1 1 0 0 0 1 1 1 0 0 1 1 1 1 0 0
        // 0 0 1 1 1 1 1 0 1 1 1 1 0 1 1 1 1 0 0
        //  0 0 1 1 1 1 1 1 1 1 1 0 0 1 1 1 1 0 0
        // 0 0 0 1 1 1 1 1 1 1 1 0 0 1 1 1 1 0 0
        //  0 0 1 1 0 0 1 1 1 1 1 0 0 0 1 1 0 0 0
        // 0 0 0 0 0 0 0 0 1 1 1 1 0 0 0 1 1 0 0
        //  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        let grid = Caver::generate(19, 13, 3, SEED);
        assert!(grid == 0x33e10ffe70ffff3fe7039e60f1cf0fbde1ff3c1fe7867c6003c600000);
    }

    #[test]
    #[available_gas(l2_gas: 78737)]
    fn test_caver_generate_7x7() {
        //  0 0 0 0 0 0 0
        // 0 0 0 0 0 0 0
        //  0 0 0 0 0 0 0
        // 0 0 1 1 0 0 0
        //  0 1 1 0 0 0 0
        // 0 0 0 0 0 0 0
        //  0 0 0 0 0 0 0
        let grid = Caver::generate(7, 7, 3, SEED);
        assert!(grid == 0x30c0000);
    }

    #[test]
    #[available_gas(l2_gas: 33290)]
    fn test_caver_generate_order_zero() {
        // Initial fill, about half of the interior
        let grid = Caver::generate(17, 14, 0, SEED);
        assert!(grid == 0x534e7d202fd79ea60b2882c2c35799e8d42b1a665d1c2603f640000);
        assert!(grid == fill_half(17, 14, SEED));
    }

    #[test]
    #[available_gas(l2_gas: 7261267)]
    fn test_caver_generate_3x3() {
        // A single interior tile: never has a floor neighbour
        assert!(Caver::generate(3, 3, 0, 2) == 0x10);
        assert!(Caver::generate(3, 3, 1, 2) == 0);
        check_generate(3, 3);
    }

    #[test]
    #[available_gas(l2_gas: 106000564)]
    fn test_caver_generate_invariants_7x7() {
        check_generate(7, 7);
    }

    #[test]
    #[available_gas(l2_gas: 334979598)]
    fn test_caver_generate_invariants_11x11() {
        check_generate(11, 11);
    }

    #[test]
    #[available_gas(l2_gas: 745176094)]
    fn test_caver_generate_invariants_17x14() {
        check_generate(17, 14);
    }

    #[test]
    #[available_gas(l2_gas: 773859522)]
    fn test_caver_generate_invariants_19x13() {
        check_generate(19, 13);
    }

    #[test]
    #[available_gas(l2_gas: 335543374)]
    fn test_caver_generate_invariants_83x3() {
        check_generate(83, 3);
    }

    #[test]
    #[available_gas(l2_gas: 358995481)]
    fn test_caver_generate_invariants_3x83() {
        check_generate(3, 83);
    }

    #[test]
    #[available_gas(l2_gas: 760756383)]
    fn test_caver_generate_invariants_25x10() {
        check_generate(25, 10);
    }

    #[test]
    #[available_gas(l2_gas: 346253784)]
    fn test_caver_generate_invariants_16x8() {
        // 128 bits: largest board of the single-limb path
        check_generate(16, 8);
    }

    #[test]
    #[available_gas(l2_gas: 277730)]
    fn test_caver_generate_seeds_differ() {
        assert!(Caver::generate(17, 14, 3, 1) != Caver::generate(17, 14, 3, 2));
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: invalid dimension')]
    fn test_caver_generate_revert_too_small() {
        Caver::generate(2, 17, 3, SEED);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: invalid dimension')]
    fn test_caver_generate_revert_too_large() {
        Caver::generate(16, 16, 3, SEED);
    }

    #[test]
    #[available_gas(l2_gas: 585630)]
    fn test_caver_keep_component_split() {
        // Left half (x = 1..7) of the board split by the wall column x = 8
        let mut expected: felt252 = 0;
        let mut y: u8 = 1;
        while y != 13 {
            expected += 0xfe * Bits::pow(17 * y);
            y += 1;
        }
        let component = Caver::keep_component(
            UNREACHABLE_17X14, 17, 14, UNREACHABLE_17X14_FAR_FROM,
        );
        assert!(component == expected);
        let other = Caver::keep_component(UNREACHABLE_17X14, 17, 14, 219);
        assert!(component + other == UNREACHABLE_17X14);
    }

    #[test]
    #[available_gas(l2_gas: 24905291)]
    fn test_caver_keep_component_closed() {
        // The component is a subset of the cave, closed under dilation, and holds the start
        let layout = LayoutTrait::new(17, 14);
        let mut seed: felt252 = 1;
        while seed != 9 {
            let cave = Caver::generate(17, 14, 3, seed);
            let open: u256 = cave.into();
            let mut position: u8 = 18;
            while position < 220 {
                if Bits::get(open, position) {
                    let component: u256 = Caver::keep_component(cave, 17, 14, position).into();
                    assert!(component & open == component);
                    assert!(layout.expand(component) & open == component);
                    assert!(Bits::get(component, position));
                    let felt = Bits::to_felt(component);
                    assert!(felt == keep_component_dilation(cave, 17, 14, position));
                }
                position += 29;
            }
            seed += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 113516)]
    fn test_caver_keep_component_single() {
        // 7x7 cave: one component of 4 tiles
        let cave = Caver::generate(7, 7, 3, SEED);
        assert!(Caver::keep_component(cave, 7, 7, 18) == cave);
    }

    #[test]
    #[available_gas(l2_gas: 36147)]
    #[should_panic(expected: 'Caver: position not floor')]
    fn test_caver_keep_component_revert_wall() {
        Caver::keep_component(UNREACHABLE_17X14, 17, 14, 25);
    }

    // N-1 (plan §6.2): `generate_with_margins` and `smooth`

    /// The six directions, in `Direction` order.
    const DIRECTIONS: [Direction; 6] = [
        Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
        Direction::SouthWest, Direction::SouthEast,
    ];
    /// 2, as a divisor.
    const TWO: NonZero<u128> = 2;
    /// The boards of the oracles beyond those run on 64 seeds.
    const OTHERS: [(u8, u8); 8] = [
        (8, 6), (11, 11), (14, 15), (15, 14), (25, 9), (50, 4), (3, 82), (62, 3),
    ];
    /// The oracles compare the generations 0 to `ORDERS`.
    const ORDERS: u8 = 3;
    /// The ring of 15 x 15.
    const RING_15X15: felt252 = 0x1fffe000c00180030006000c00180030006000c00180030006000ffff;
    /// A pattern for the values of the sides: two tiles in three open, on every bit.
    const PATTERN: felt252 = 0x6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db;
    /// The interior tiles `(10, 12)` and `(11, 12)` of 15 x 15, and the ring tile `(0, 0)`.
    const R_N1_1: felt252 = 0xc00000000000000000000000000000000000000000000001;

    // Oracles

    #[generate_trait]
    impl Oracle of OracleTrait {
        /// The neighbour of a tile from the neighbour table of `board::direction`, read with the
        /// global parity of its row (local row `y` is globally odd iff `y` is odd XOR `odd`), on
        /// signed coordinates; `None` outside the board.
        fn neighbor(
            width: u8, height: u8, position: u8, direction: Direction, odd: bool,
        ) -> Option<u8> {
            let (x, y): (i32, i32) = ((position % width).into(), (position / width).into());
            let shifted = ((position / width) % 2 == 1) != odd;
            let (dx, dy): (i32, i32) = match direction {
                Direction::East => (-1, 0),
                Direction::NorthEast => if shifted {
                    (0, 1)
                } else {
                    (-1, 1)
                },
                Direction::NorthWest => if shifted {
                    (1, 1)
                } else {
                    (0, 1)
                },
                Direction::West => (1, 0),
                Direction::SouthWest => if shifted {
                    (1, -1)
                } else {
                    (0, -1)
                },
                Direction::SouthEast => if shifted {
                    (0, -1)
                } else {
                    (-1, -1)
                },
            };
            let (w, h): (i32, i32) = (width.into(), height.into());
            let (nx, ny) = (x + dx, y + dy);
            if nx < 0 || nx >= w || ny < 0 || ny >= h {
                return None;
            }
            Some((ny * w + nx).try_into().unwrap())
        }

        /// The six neighbours of every tile, in `Direction` order. A neighbour outside the board
        /// is the index `W * H`: the tiles of `tiles` end with a wall there.
        fn neighbors(width: u8, height: u8, odd: bool) -> Array<[u8; 6]> {
            let size = width * height;
            let [east, north_east, north_west, west, south_west, south_east] = DIRECTIONS;
            let mut table = array![];
            let mut position: u8 = 0;
            while position != size {
                table
                    .append(
                        [
                            Self::neighbor(width, height, position, east, odd).unwrap_or(size),
                            Self::neighbor(width, height, position, north_east, odd)
                                .unwrap_or(size),
                            Self::neighbor(width, height, position, north_west, odd)
                                .unwrap_or(size),
                            Self::neighbor(width, height, position, west, odd).unwrap_or(size),
                            Self::neighbor(width, height, position, south_west, odd)
                                .unwrap_or(size),
                            Self::neighbor(width, height, position, south_east, odd)
                                .unwrap_or(size),
                        ],
                    );
                position += 1;
            }
            table
        }

        /// The `count` lowest bits of a value, lowest first, one felt per tile (1 is floor),
        /// then a wall: the tile that stands for every neighbour outside the board.
        fn tiles(value: felt252, count: u8) -> Array<felt252> {
            let value: u256 = value.into();
            let mut tiles = array![];
            let mut limb = value.low;
            let mut index: u8 = 0;
            while index != count {
                if index == 128 {
                    limb = value.high;
                }
                let (rest, bit) = DivRem::div_rem(limb, TWO);
                tiles.append(bit.into());
                limb = rest;
                index += 1;
            }
            tiles.append(0);
            tiles
        }

        /// The bitmap of the first `count` tiles.
        fn pack(tiles: @Array<felt252>, count: u8) -> felt252 {
            let mut grid = 0;
            let mut index: u32 = count.into();
            while index != 0 {
                index -= 1;
                grid = grid + grid + *tiles.at(index);
            }
            grid
        }

        /// The ring, tile by tile: the first and last column and row.
        fn ring(width: u8, height: u8) -> Array<bool> {
            let mut ring = array![];
            let mut position: u8 = 0;
            while position != width * height {
                let (x, y) = (position % width, position / width);
                ring.append(x == 0 || y == 0 || x == width - 1 || y == height - 1);
                position += 1;
            }
            ring
        }

        /// The four corners.
        fn corners(width: u8, height: u8) -> felt252 {
            let size = width * height;
            1 + Bits::pow(width - 1) + Bits::pow(size - width) + Bits::pow(size - 1)
        }

        /// One generation of the scalar automaton B4/S2 (the `reference` of `bench_caver` with
        /// frozen tiles and the global parity): a frozen tile keeps its value; a wall with at
        /// least 4 floor neighbours becomes floor, a floor with at least 2 stays floor.
        /// # Arguments
        /// * `tiles` - The tiles, then the wall beyond the board
        /// * `frozen` - Whether each tile is frozen
        /// * `neighbors` - The six neighbours of each tile
        fn step(
            tiles: @Array<felt252>, frozen: @Array<bool>, neighbors: @Array<[u8; 6]>,
        ) -> Array<felt252> {
            let mut next = array![];
            let mut position = 0;
            while position != frozen.len() {
                let alive = *tiles.at(position);
                if *frozen.at(position) {
                    next.append(alive);
                } else {
                    let [a, b, c, d, e, f] = *neighbors.at(position);
                    let count: u8 = (*tiles.at(a.into())
                        + *tiles.at(b.into())
                        + *tiles.at(c.into())
                        + *tiles.at(d.into())
                        + *tiles.at(e.into())
                        + *tiles.at(f.into()))
                        .try_into()
                        .unwrap();
                    let floor = if alive == 1 {
                        count >= 2
                    } else {
                        count >= 4
                    };
                    next.append(if floor {
                        1
                    } else {
                        0
                    });
                }
                position += 1;
            }
            next.append(0);
            next
        }

        /// The initial grid of `generate_with_margins` by its definition, tile by tile: a corner
        /// is wall (D-134), a fixed ring tile has its value, any other tile is the bit of the
        /// noise that `CaverInternal::fill` reads.
        fn fill(
            width: u8, height: u8, seed: felt252, fixed: felt252, values: felt252,
        ) -> Array<felt252> {
            let (noise, _, _) = hades_permutation(seed, 0, 2);
            let noise = Self::tiles(noise, width * height);
            let fixed: u256 = fixed.into();
            let values: u256 = values.into();
            let mut fill = array![];
            let mut y: u8 = 0;
            while y != height {
                let row = y == 0 || y == height - 1;
                let mut x: u8 = 0;
                while x != width {
                    let column = x == 0 || x == width - 1;
                    let position = y * width + x;
                    fill
                        .append(
                            if column && row {
                                0
                            } else if (column || row) && Bits::get(fixed, position) {
                                if Bits::get(values, position) {
                                    1
                                } else {
                                    0
                                }
                            } else {
                                *noise.at(position.into())
                            },
                        );
                    x += 1;
                }
                y += 1;
            }
            fill.append(0);
            fill
        }

        /// `generate_with_margins` against the scalar automaton on one board and one parity:
        /// two extreme rings (every side given open, every side given wall), then `seeds` seeds
        /// with, in turn, no side fixed, every side fixed, random fixed tiles and two opposite
        /// sides fixed, the values random; the generations 0 to `ORDERS`. On every case: the
        /// corners are wall (D-134), the fixed tiles have their value and the free ring tiles
        /// are the fill's, whatever the order.
        fn check_margins(width: u8, height: u8, odd: bool, seeds: u8) {
            let size = width * height;
            let board = LayoutTrait::board(width, height);
            let interior = LayoutTrait::interior(width, height);
            let corners: u256 = Self::corners(width, height).into();
            let ring: u256 = (board - interior).into();
            let sides = ring - corners;
            let frozen = Self::ring(width, height);
            let neighbors = Self::neighbors(width, height, odd);
            let mut cases: Array<(felt252, felt252, felt252)> = array![
                ('open', board, board), ('wall', board, 0),
            ];
            let mut seed: u8 = 0;
            while seed != seeds {
                let (a, b, _) = hades_permutation(seed.into(), 'margins', 2);
                let fixed = match seed % 4 {
                    0 => 0,
                    1 => board,
                    2 => a,
                    _ => if (seed / 4) % 2 == 0 {
                        SeamTrait::side(width, height, Side::East)
                            + SeamTrait::side(width, height, Side::West)
                    } else {
                        SeamTrait::side(width, height, Side::South)
                            + SeamTrait::side(width, height, Side::North)
                    },
                };
                cases.append((seed.into(), fixed, b));
                seed += 1;
            }
            for (seed, fixed, values) in cases.span() {
                let (seed, fixed, values) = (*seed, *fixed, *values);
                let given = Bits::and(fixed.into(), sides);
                let drawn = sides - given;
                let (noise, _, _) = hades_permutation(seed, 0, 2);
                let mut expected = Self::fill(width, height, seed, fixed, values);
                let mut order: u8 = 0;
                loop {
                    let grid = Caver::generate_with_margins(
                        width, height, order, seed, fixed, values, odd,
                    );
                    assert!(
                        grid == Self::pack(@expected, size),
                        "{} x {}, odd {}, seed {}, order {}",
                        width,
                        height,
                        odd,
                        seed,
                        order,
                    );
                    let wide: u256 = grid.into();
                    assert!(Bits::and(wide, corners) == 0, "corner");
                    assert!(Bits::and(wide, given) == Bits::and(values.into(), given), "fixed");
                    assert!(Bits::and(wide, drawn) == Bits::and(noise.into(), drawn), "free");
                    if order == ORDERS {
                        break;
                    }
                    expected = Self::step(@expected, @frozen, @neighbors);
                    order += 1;
                }
            }
        }

        /// `smooth` against the scalar automaton on one board and one parity: the full board,
        /// the ring alone and the interior alone, with nothing held; then `seeds` seeded grids
        /// of density 1/2 with, in turn, nothing held, random tiles held and few tiles held; the
        /// generations 0 to `ORDERS`. On every case the ring and the held tiles keep their value.
        fn check_smooth(width: u8, height: u8, odd: bool, seeds: u8) {
            let size = width * height;
            let board = LayoutTrait::board(width, height);
            let interior = LayoutTrait::interior(width, height);
            let border: u256 = (board - interior).into();
            let ring = Self::ring(width, height);
            let neighbors = Self::neighbors(width, height, odd);
            let mut cases: Array<(felt252, felt252)> = array![
                (board, 0), (board - interior, 0), (interior, 0),
            ];
            let mut seed: u8 = 0;
            while seed != seeds {
                let (a, b, c) = hades_permutation(seed.into(), 'smooth', 2);
                let grid = Bits::to_felt(Bits::and(a.into(), board.into()));
                let held = match seed % 3 {
                    0 => 0,
                    1 => b,
                    _ => Bits::to_felt(Bits::and(b.into(), c.into())),
                };
                cases.append((grid, held));
                seed += 1;
            }
            for (grid, held) in cases.span() {
                let (grid, held) = (*grid, *held);
                // [Compute] The frozen tiles: the ring and the held tiles
                let tiles = Self::tiles(held, size);
                let mut frozen = array![];
                let mut position = 0;
                while position != ring.len() {
                    frozen.append(*ring.at(position) || *tiles.at(position) == 1);
                    position += 1;
                }
                let kept = Bits::or(border, Bits::and(held.into(), board.into()));
                let mut expected = Self::tiles(grid, size);
                let mut order: u8 = 0;
                loop {
                    let next = Caver::smooth(grid, width, height, order, held, odd);
                    assert!(
                        next == Self::pack(@expected, size),
                        "{} x {}, odd {}, grid {}, held {}, order {}",
                        width,
                        height,
                        odd,
                        grid,
                        held,
                        order,
                    );
                    assert!(Bits::and(next.into(), kept) == Bits::and(grid.into(), kept), "held");
                    if order == ORDERS {
                        break;
                    }
                    expected = Self::step(@expected, @frozen, @neighbors);
                    order += 1;
                }
            }
        }

        /// For every interior tile, its bit and its six neighbours in the order of the planes of
        /// `CaverInternal::planes`: East, West, the northern neighbour at `i + W` (North-West on
        /// a globally even row, North-East on a globally odd one), the other northern one, the
        /// southern neighbour at `i - W` (South-West on an even row, South-East on an odd one),
        /// the other southern one.
        fn plane_neighbors(width: u8, height: u8, odd: bool) -> Array<(felt252, [u8; 6])> {
            let mut table = array![];
            let mut y: u8 = 1;
            while y != height - 1 {
                let [east, west, north, north_other, south, south_other] = if (y % 2 == 1) != odd {
                    [
                        Direction::East, Direction::West, Direction::NorthEast,
                        Direction::NorthWest, Direction::SouthEast, Direction::SouthWest,
                    ]
                } else {
                    [
                        Direction::East, Direction::West, Direction::NorthWest,
                        Direction::NorthEast, Direction::SouthWest, Direction::SouthEast,
                    ]
                };
                let mut x: u8 = 1;
                while x != width - 1 {
                    let position = y * width + x;
                    table
                        .append(
                            (
                                Bits::pow(position),
                                [
                                    Self::neighbor(width, height, position, east, odd).unwrap(),
                                    Self::neighbor(width, height, position, west, odd).unwrap(),
                                    Self::neighbor(width, height, position, north, odd).unwrap(),
                                    Self::neighbor(width, height, position, north_other, odd)
                                        .unwrap(),
                                    Self::neighbor(width, height, position, south, odd).unwrap(),
                                    Self::neighbor(width, height, position, south_other, odd)
                                        .unwrap(),
                                ],
                            ),
                        );
                    x += 1;
                }
                y += 1;
            }
            table
        }

        /// The six planes by their definition, on the interior tiles: bit `i` of a plane is the
        /// grid at the neighbour of `i`.
        fn expected_planes(
            tiles: @Array<felt252>, table: @Array<(felt252, [u8; 6])>,
        ) -> Array<felt252> {
            let (mut east, mut west, mut north) = (0, 0, 0);
            let (mut north_other, mut south, mut south_other) = (0, 0, 0);
            for (power, around) in table.span() {
                let power = *power;
                let [a, b, c, d, e, f] = *around;
                east += power * *tiles.at(a.into());
                west += power * *tiles.at(b.into());
                north += power * *tiles.at(c.into());
                north_other += power * *tiles.at(d.into());
                south += power * *tiles.at(e.into());
                south_other += power * *tiles.at(f.into());
            }
            array![east, west, north, north_other, south, south_other]
        }

        /// The six planes of the implementation for a grid whose ring and `held` tiles are
        /// frozen, restricted to the interior: the preparation of `smooth`, then
        /// `CaverInternal::freeze` and `CaverInternal::planes`.
        fn planes(
            width: u8, height: u8, grid: felt252, held: felt252, odd: bool,
        ) -> Array<felt252> {
            let margins = CaverInternal::margins(width, height, odd);
            let interior: u256 = margins.interior.into();
            let held = Bits::and(held.into(), interior);
            let free = interior - held;
            let free_grid = Bits::and(grid.into(), free);
            let frozen = CaverInternal::freeze(@margins, grid - Bits::to_felt(free_grid));
            let (east, west, north, north_other, south, south_other) = CaverInternal::planes(
                @margins, @frozen, free_grid, Bits::to_felt(free_grid),
            );
            array![
                Bits::to_felt(Bits::and(east, interior)), Bits::to_felt(Bits::and(west, interior)),
                Bits::to_felt(Bits::and(north, interior)),
                Bits::to_felt(Bits::and(north_other, interior)),
                Bits::to_felt(Bits::and(south, interior)),
                Bits::to_felt(Bits::and(south_other, interior)),
            ]
        }

        /// The planes of the implementation against their definition on every interior tile of
        /// one board and one parity: on the full board, free then held, where every product is
        /// the largest; then on `grids` seeded grids of density 1/2 and 1/4 in turn, the ring
        /// included; on half of them, random interior tiles are held (frozen). From 64 grids
        /// on, every tile is floor in one seeded grid at least.
        fn check_planes(width: u8, height: u8, odd: bool, grids: u32) {
            let size = width * height;
            let full = LayoutTrait::board(width, height);
            let board: u256 = full.into();
            let table = Self::plane_neighbors(width, height, odd);
            let expected = Self::expected_planes(@Self::tiles(full, size), @table);
            assert!(Self::planes(width, height, full, 0, odd) == expected, "full");
            assert!(Self::planes(width, height, full, full, odd) == expected, "full, held");
            let mut seen: u256 = 0;
            let mut index: u32 = 0;
            while index != grids {
                let (a, b, c) = hades_permutation(index.into(), 'planes', 2);
                let grid = if index % 2 == 0 {
                    Bits::and(a.into(), board)
                } else {
                    Bits::and(Bits::and(a.into(), b.into()), board)
                };
                let held = if index % 4 < 2 {
                    0
                } else {
                    c
                };
                seen = Bits::or(seen, grid);
                let grid = Bits::to_felt(grid);
                let planes = Self::planes(width, height, grid, held, odd);
                let expected = Self::expected_planes(@Self::tiles(grid, size), @table);
                assert!(planes == expected, "{} x {}, odd {}, grid {}", width, height, odd, index);
                index += 1;
            }
            assert!(grids < 64 || seen == board, "coverage");
        }
    }

    // The oracles themselves

    /// The neighbours with the global parity against `LayoutTrait::neighbor`: equal on an even
    /// chunk; on an odd chunk, equal to the neighbours of the tile one row up on a board one row
    /// taller at each end, whose local parity is then the chunk's global one.
    #[test]
    #[available_gas(l2_gas: 98213336)]
    fn test_caver_oracle_neighbor() {
        let boards: [(u8, u8); 4] = [(15, 15), (7, 7), (8, 6), (3, 3)];
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            let mut position: u8 = 0;
            while position != width * height {
                for direction in DIRECTIONS.span() {
                    let direction = *direction;
                    assert!(
                        Oracle::neighbor(
                            width, height, position, direction, false,
                        ) == LayoutTrait::neighbor(width, height, position, direction),
                    );
                    let expected =
                        match LayoutTrait::neighbor(
                            width, height + 2, position + width, direction,
                        ) {
                        Some(next) => if next < width || next >= width * (height + 1) {
                            None
                        } else {
                            Some(next - width)
                        },
                        None => None,
                    };
                    assert!(Oracle::neighbor(width, height, position, direction, true) == expected);
                }
                position += 1;
            }
        }
    }

    /// The scalar automaton with the ring frozen and `odd = false` is the `reference` of
    /// `bench_caver`, the oracle of `generate`, generation after generation.
    #[test]
    #[available_gas(l2_gas: 244067572)]
    fn test_caver_oracle_reference() {
        let boards: [(u8, u8); 4] = [(15, 15), (11, 11), (8, 6), (3, 3)];
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            let size = width * height;
            let frozen = Oracle::ring(width, height);
            let neighbors = Oracle::neighbors(width, height, false);
            let mut seed: felt252 = 0;
            while seed != 2 {
                let mut expected = fill_half(width, height, seed);
                let mut tiles = Oracle::tiles(expected, size);
                let mut order: u8 = 0;
                while order != 3 {
                    expected =
                        hexx::tests::bench_caver::reference_step(expected, width, height, 4, 2);
                    tiles = Oracle::step(@tiles, @frozen, @neighbors);
                    assert!(Oracle::pack(@tiles, size) == expected);
                    order += 1;
                }
                seed += 1;
            }
        }
    }

    /// The constants of `CaverInternal::margins` against their definitions, tile by tile, on
    /// the boards of the oracles and both parities.
    #[test]
    #[available_gas(l2_gas: 34315229)]
    fn test_caver_margins_masks() {
        let boards: [(u8, u8); 15] = [
            (3, 3), (3, 4), (4, 3), (4, 4), (5, 5), (7, 7), (8, 6), (11, 11), (14, 15), (15, 14),
            (15, 15), (25, 9), (50, 4), (3, 82), (62, 3),
        ];
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            for odd in [false, true].span() {
                let odd = *odd;
                let margins = CaverInternal::margins(width, height, odd);
                let (mut evens, mut odds, mut bottom) = (0, 0, 0);
                let mut position: u8 = 0;
                while position != width * height {
                    let (x, y) = (position % width, position / width);
                    let power = Bits::pow(position);
                    if (y % 2 == 1) != odd {
                        if x != width - 1 {
                            odds += power;
                        }
                    } else if x != 0 {
                        evens += power;
                    }
                    if y == 0 {
                        bottom += power;
                    }
                    position += 1;
                }
                assert!(margins.odd == odd);
                assert!(margins.board == LayoutTrait::board(width, height));
                assert!(margins.interior == LayoutTrait::interior(width, height));
                assert!(margins.corners == Oracle::corners(width, height));
                let low: felt252 = margins.bottom.into();
                assert!(low == bottom);
                assert!(margins.evens == evens.into(), "{} x {}, odd {}", width, height, odd);
                assert!(margins.odds == odds.into(), "{} x {}, odd {}", width, height, odd);
                let layout = LayoutTrait::new(width, height);
                assert!(margins.shifts.up_even == layout.up_even);
                assert!(margins.shifts.up_odd == layout.up_odd);
                assert!(margins.shifts.up_wide == 2 * layout.up_odd);
                assert!(margins.shifts.down_even == layout.down_even);
                assert!(margins.shifts.down_odd == layout.down_odd);
                assert!(margins.shifts.down_wide == 2 * layout.down_odd);
            }
        }
    }

    // Oracle (1): the scalar automaton with frozen tiles and the global parity, on boards from
    // 3 x 3 to 15 x 15, both parities, 64 seeds: the smallest boards of each parity of width and
    // height, 7 x 7 and the chunk, 15 x 15. Other boards follow with two seeds. A test runs
    // 10 million steps at most: the boards and the parities are split over several tests.

    #[test]
    #[available_gas(l2_gas: 412082503)]
    fn test_caver_margins_oracle_small() {
        let boards: [(u8, u8); 4] = [(3, 3), (3, 4), (4, 3), (7, 7)];
        for (width, height) in boards.span() {
            Oracle::check_margins(*width, *height, false, 64);
        }
    }

    #[test]
    #[available_gas(l2_gas: 411885418)]
    fn test_caver_margins_oracle_small_odd() {
        let boards: [(u8, u8); 4] = [(3, 3), (3, 4), (4, 3), (7, 7)];
        for (width, height) in boards.span() {
            Oracle::check_margins(*width, *height, true, 64);
        }
    }

    #[test]
    #[available_gas(l2_gas: 917976564)]
    fn test_caver_margins_oracle_15x15() {
        Oracle::check_margins(15, 15, false, 64);
    }

    #[test]
    #[available_gas(l2_gas: 917911884)]
    fn test_caver_margins_oracle_15x15_odd() {
        Oracle::check_margins(15, 15, true, 64);
    }

    /// Two seeds each, after the extreme cases: even widths and heights (8 x 6, and next to the
    /// chunk 14 x 15 and 15 x 14), 11 x 11, and the boards at the edge of the domain (`W * (H + 1)
    /// + 1` is 251 for 25 x 9 and 50 x 4, 250 for 3 x 82 and 249 for 62 x 3), where the upward
    /// planes are the largest.
    #[test]
    #[available_gas(l2_gas: 467890931)]
    fn test_caver_margins_oracle_others() {
        for (width, height) in OTHERS.span() {
            Oracle::check_margins(*width, *height, false, 2);
        }
    }

    #[test]
    #[available_gas(l2_gas: 467870393)]
    fn test_caver_margins_oracle_others_odd() {
        for (width, height) in OTHERS.span() {
            Oracle::check_margins(*width, *height, true, 2);
        }
    }

    #[test]
    #[available_gas(l2_gas: 363032801)]
    fn test_caver_smooth_oracle_small() {
        let boards: [(u8, u8); 4] = [(3, 3), (3, 4), (4, 3), (7, 7)];
        for (width, height) in boards.span() {
            Oracle::check_smooth(*width, *height, false, 64);
        }
    }

    #[test]
    #[available_gas(l2_gas: 362875721)]
    fn test_caver_smooth_oracle_small_odd() {
        let boards: [(u8, u8); 4] = [(3, 3), (3, 4), (4, 3), (7, 7)];
        for (width, height) in boards.span() {
            Oracle::check_smooth(*width, *height, true, 64);
        }
    }

    #[test]
    #[available_gas(l2_gas: 827381884)]
    fn test_caver_smooth_oracle_15x15() {
        Oracle::check_smooth(15, 15, false, 64);
    }

    #[test]
    #[available_gas(l2_gas: 827352694)]
    fn test_caver_smooth_oracle_15x15_odd() {
        Oracle::check_smooth(15, 15, true, 64);
    }

    #[test]
    #[available_gas(l2_gas: 516509052)]
    fn test_caver_smooth_oracle_others() {
        for (width, height) in OTHERS.span() {
            Oracle::check_smooth(*width, *height, false, 2);
        }
    }

    #[test]
    #[available_gas(l2_gas: 516474444)]
    fn test_caver_smooth_oracle_others_odd() {
        for (width, height) in OTHERS.span() {
            Oracle::check_smooth(*width, *height, true, 2);
        }
    }

    /// Beyond the generations of the game: 12 generations on 15 x 15, two seeds, both
    /// parities, both functions, every side given at random.
    #[test]
    #[available_gas(l2_gas: 309273792)]
    fn test_caver_margins_oracle_deep() {
        let board = LayoutTrait::board(15, 15);
        let frozen = Oracle::ring(15, 15);
        for odd in [false, true].span() {
            let odd = *odd;
            let neighbors = Oracle::neighbors(15, 15, odd);
            let mut seed: felt252 = 0;
            while seed != 2 {
                let (values, grid, _) = hades_permutation(seed, 'deep', 2);
                let grid = Bits::to_felt(Bits::and(grid.into(), board.into()));
                let mut generated = Oracle::fill(15, 15, seed, board, values);
                let mut smoothed = Oracle::tiles(grid, 225);
                let mut order: u8 = 0;
                while order != 12 {
                    generated = Oracle::step(@generated, @frozen, @neighbors);
                    smoothed = Oracle::step(@smoothed, @frozen, @neighbors);
                    order += 1;
                }
                assert!(
                    Caver::generate_with_margins(
                        15, 15, 12, seed, board, values, odd,
                    ) == Oracle::pack(@generated, 225),
                );
                assert!(Caver::smooth(grid, 15, 15, 12, 0, odd) == Oracle::pack(@smoothed, 225));
                seed += 1;
            }
        }
    }

    // Oracle (2): equality with `generate` when the whole ring is fixed to wall

    /// R-N1-4: 15 x 15, order 3, 64 seeds.
    #[test]
    #[available_gas(l2_gas: 20033709)]
    fn test_caver_r_n1_4_equals_generate() {
        let mut seed: felt252 = 0;
        while seed != 64 {
            assert!(
                Caver::generate_with_margins(
                    15, 15, 3, seed, RING_15X15, 0, false,
                ) == Caver::generate(15, 15, 3, seed),
            );
            seed += 1;
        }
    }

    /// R-N1-7: 15 x 15, order 255, the domain-wide worst case, 4 seeds.
    #[test]
    #[available_gas(l2_gas: 81050897)]
    fn test_caver_r_n1_7_equals_generate_order_255() {
        let mut seed: felt252 = 0;
        while seed != 4 {
            assert!(
                Caver::generate_with_margins(
                    15, 15, 255, seed, RING_15X15, 0, false,
                ) == Caver::generate(15, 15, 255, seed),
            );
            seed += 1;
        }
    }

    /// The same on the other boards, single-limb sizes of `generate` included, orders 0 to 4,
    /// with every bit of `fixed` set and `values` holding interior tiles and corners only (both
    /// masked): the ring is wall.
    #[test]
    #[available_gas(l2_gas: 41987211)]
    fn test_caver_margins_equals_generate() {
        let boards: [(u8, u8); 10] = [
            (3, 3), (4, 4), (7, 7), (11, 11), (16, 7), (14, 15), (25, 9), (50, 4), (3, 82), (62, 3),
        ];
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            let board = LayoutTrait::board(width, height);
            let values = LayoutTrait::interior(width, height) + Oracle::corners(width, height);
            let mut seed: felt252 = 0;
            while seed != 4 {
                let mut order: u8 = 0;
                while order != 5 {
                    assert!(
                        Caver::generate_with_margins(
                            width, height, order, seed, board, values, false,
                        ) == Caver::generate(width, height, order, seed),
                        "{} x {}, seed {}, order {}",
                        width,
                        height,
                        seed,
                        order,
                    );
                    order += 1;
                }
                seed += 1;
            }
        }
    }

    // Oracle (4): the six planes on the interior destinations, 256 seeded grids

    #[test]
    #[available_gas(l2_gas: 635348587)]
    fn test_caver_planes_15x15() {
        Oracle::check_planes(15, 15, false, 256);
    }

    #[test]
    #[available_gas(l2_gas: 635348482)]
    fn test_caver_planes_15x15_odd() {
        Oracle::check_planes(15, 15, true, 256);
    }

    #[test]
    #[available_gas(l2_gas: 264868689)]
    fn test_caver_planes_7x7() {
        Oracle::check_planes(7, 7, false, 256);
        Oracle::check_planes(7, 7, true, 256);
    }

    /// The same on the other boards, the edge of the domain included, 8 seeded grids each.
    #[test]
    #[available_gas(l2_gas: 393145041)]
    fn test_caver_planes_others() {
        for (width, height) in OTHERS.span() {
            Oracle::check_planes(*width, *height, false, 8);
            Oracle::check_planes(*width, *height, true, 8);
        }
    }

    // Regression cases (plan §6.2)

    /// R-N1-1: 15 x 15, `odd = false`, `(10, 12)` and `(11, 12)` have one live neighbour each
    /// and die; the held ring tile `(0, 0)` stays.
    #[test]
    #[available_gas(l2_gas: 92585)]
    fn test_caver_r_n1_1_west_plane() {
        assert!(R_N1_1 == 1 + Bits::pow(190) + Bits::pow(191));
        assert!(Caver::smooth(R_N1_1, 15, 15, 1, RING_15X15, false) == 1);
    }

    /// R-N1-2: 15 x 15, `odd = true`, the single live tile `(7, 6)`: local row 6 is globally
    /// odd, so the tile is the southern neighbour of `(7, 7)` and `(8, 7)`, not of `(6, 7)`;
    /// the same when the tile is held, a frozen tile.
    #[test]
    #[available_gas(l2_gas: 150050)]
    fn test_caver_r_n1_2_odd_parity() {
        let tile = Bits::pow(6 * 15 + 7);
        for held in [0, tile].span() {
            let planes = Oracle::planes(15, 15, tile, *held, true);
            assert!(*planes[4] == Bits::pow(7 * 15 + 7));
            assert!(*planes[5] == Bits::pow(7 * 15 + 8));
        }
    }

    /// R-N1-3: 15 x 15, `odd = false`, `(14, 11)`, `(1, 12)` and `(1, 13)`: the two operands of
    /// the other southern plane would meet on `(0, 13)` and carry into `(1, 13)`; `(1, 12)` and
    /// `(1, 13)` have one live neighbour each and die, the held ring tile `(14, 11)` stays.
    #[test]
    #[available_gas(l2_gas: 161019)]
    fn test_caver_r_n1_3_no_carry() {
        let ring = Bits::pow(11 * 15 + 14);
        let grid = ring + Bits::pow(12 * 15 + 1) + Bits::pow(13 * 15 + 1);
        assert!(Caver::smooth(grid, 15, 15, 1, RING_15X15, false) == ring);
        let planes = Oracle::planes(15, 15, grid, 0, false);
        assert!(!Bits::get((*planes[5]).into(), 13 * 15 + 1));
    }

    /// R-N1-5 (D-30): 17 x 14 gives `W * (H + 1) + 1 = 256` and is refused.
    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Caver: dimensions too large')]
    fn test_caver_r_n1_5_revert_too_large() {
        Caver::generate_with_margins(17, 14, 3, SEED, 0, 0, false);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Caver: dimensions too large')]
    fn test_caver_smooth_revert_too_large() {
        Caver::smooth(0, 17, 14, 3, 0, false);
    }

    /// The first board beyond the domain next to 25 x 9: `25 * 11 + 1 = 276`.
    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Caver: dimensions too large')]
    fn test_caver_margins_revert_25x10() {
        Caver::generate_with_margins(25, 10, 3, SEED, 0, 0, false);
    }

    /// Dimensions whose product overflows a `u8`.
    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Caver: dimensions too large')]
    fn test_caver_margins_revert_u8_overflow() {
        Caver::generate_with_margins(255, 255, 3, SEED, 0, 0, false);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: invalid dimension')]
    fn test_caver_margins_revert_too_narrow() {
        Caver::generate_with_margins(2, 15, 3, SEED, 0, 0, false);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: invalid dimension')]
    fn test_caver_smooth_revert_too_low() {
        Caver::smooth(0, 15, 2, 3, 0, true);
    }

    /// R-N1-6: 15 x 15, `odd = false`, the single live ring tile `(1, 0)`: it stays, and on the
    /// interior it is the southern neighbour (`i - W`) of `(1, 1)` and nothing else.
    #[test]
    #[available_gas(l2_gas: 163893)]
    fn test_caver_r_n1_6_ring_source() {
        assert!(Caver::smooth(2, 15, 15, 1, RING_15X15, false) == 2);
        let planes = Oracle::planes(15, 15, 2, 0, false);
        assert!(planes == array![0, 0, 0, 0, Bits::pow(16), 0]);
    }

    /// D-134: a corner given open in `values`, or drawn open by the seed, is wall; the corners
    /// of `values` are cleared, not refused.
    #[test]
    #[available_gas(l2_gas: 17714708)]
    fn test_caver_margins_d134_corners() {
        let corners = Oracle::corners(15, 15);
        let mut seed: felt252 = 0;
        while seed != 16 {
            for odd in [false, true].span() {
                // Every side given open, corners included in `fixed` and `values`
                let open = Caver::generate_with_margins(
                    15, 15, 3, seed, RING_15X15, RING_15X15, *odd,
                );
                assert!(Bits::and(open.into(), RING_15X15.into()) == (RING_15X15 - corners).into());
                // Only the corners given, open: the rest of the ring is drawn
                let drawn = Caver::generate_with_margins(15, 15, 3, seed, corners, corners, *odd);
                assert!(drawn == Caver::generate_with_margins(15, 15, 3, seed, 0, 0, *odd));
                assert!(Bits::and(drawn.into(), corners.into()) == 0);
            }
            seed += 1;
        }
    }

    /// The stream of `generate_with_margins` is API from 0.1.0: one seed per parity, no side
    /// fixed and every side fixed (to `PATTERN`), 15 x 15, order 3. Each pinned grid is also
    /// the scalar automaton's.
    #[test]
    #[available_gas(l2_gas: 122514771)]
    fn test_caver_margins_stream() {
        let frozen = Oracle::ring(15, 15);
        // No side fixed, `odd = false`
        //  0 0 1 0 1 0 1 0 1 0 0 1 1 0 0
        // 0 0 1 1 1 0 1 1 1 1 1 1 1 1 0
        //  0 1 1 0 0 0 1 1 1 1 1 1 1 1 1
        // 1 1 1 0 0 0 1 1 1 1 1 1 1 1 1
        //  0 1 1 0 0 1 1 1 0 0 1 1 1 1 0
        // 1 1 1 1 1 0 0 0 0 0 1 1 1 1 0
        //  0 1 1 1 1 0 0 0 0 1 1 1 1 0 0
        // 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0
        //  1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
        // 0 1 1 1 1 1 1 1 1 1 1 1 1 1 0
        //  0 0 1 1 1 1 1 1 1 1 1 1 1 1 0
        // 0 0 0 1 1 1 1 1 1 1 0 0 1 1 0
        //  0 0 1 1 1 1 1 1 1 0 0 0 0 0 0
        // 1 1 1 1 1 1 1 1 1 0 0 0 0 0 1
        //  0 1 1 0 1 0 0 0 1 0 0 1 0 1 0
        let grid = Caver::generate_with_margins(15, 15, 3, SEED, 0, 0, false);
        assert!(grid == 0x5530eff31ffe3fece7be0f3c3cfffdfffdfff1ffe1fcc7f03fe0b44a);
        let mut tiles = Oracle::fill(15, 15, SEED, 0, 0);
        let neighbors = Oracle::neighbors(15, 15, false);
        for _ in 0..3_u8 {
            tiles = Oracle::step(@tiles, @frozen, @neighbors);
        }
        assert!(grid == Oracle::pack(@tiles, 225));
        // No side fixed, `odd = true`
        //  0 0 1 0 1 0 1 0 1 0 0 1 1 0 0
        // 0 0 1 1 1 1 1 1 1 1 1 1 1 1 0
        //  0 1 0 0 0 0 1 1 1 1 1 1 1 1 1
        // 1 1 0 0 0 1 1 1 1 1 1 1 1 1 1
        //  0 1 1 0 0 0 1 1 0 0 1 1 1 1 0
        // 1 1 1 1 0 0 1 0 0 0 1 1 1 0 0
        //  0 1 1 1 1 0 0 0 0 0 1 1 1 0 0
        // 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0
        //  1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
        // 0 1 1 1 1 1 1 1 1 1 0 1 1 1 0
        //  0 0 1 1 1 1 1 1 1 1 0 0 1 1 0
        // 0 0 1 1 1 1 1 1 1 0 0 1 1 1 0
        //  0 0 1 1 1 1 1 1 1 0 0 0 0 0 0
        // 1 1 1 1 1 1 1 1 1 0 0 0 0 0 1
        //  0 1 1 0 1 0 0 0 1 0 0 1 0 1 0
        let grid = Caver::generate_with_margins(15, 15, 3, SEED, 0, 0, true);
        assert!(grid == 0x5530fff21ffc7fec67bc8e3c1cfff9fffdff71fe63f9c7f03fe0b44a);
        let mut tiles = Oracle::fill(15, 15, SEED, 0, 0);
        let neighbors = Oracle::neighbors(15, 15, true);
        for _ in 0..3_u8 {
            tiles = Oracle::step(@tiles, @frozen, @neighbors);
        }
        assert!(grid == Oracle::pack(@tiles, 225));
        // Every side fixed, `odd = false`
        //  0 1 1 0 1 1 0 1 1 0 1 1 0 1 0
        // 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1
        //  0 1 1 0 0 1 1 1 1 1 1 1 1 1 1
        // 0 1 1 0 0 0 1 1 1 1 1 1 1 1 1
        //  0 1 1 0 0 1 1 1 0 0 1 1 1 1 1
        // 0 1 1 1 1 0 0 0 0 0 1 1 1 1 1
        //  0 1 1 1 1 0 0 0 0 1 1 1 1 1 1
        // 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1
        //  0 1 1 1 1 1 1 1 1 1 1 1 1 1 1
        // 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1
        //  0 0 1 1 1 1 1 1 1 1 1 1 1 1 1
        // 0 0 0 1 1 1 1 1 1 1 0 0 1 1 1
        //  0 0 1 1 1 1 1 1 1 0 0 0 0 1 1
        // 0 1 1 1 1 1 1 1 1 0 0 1 0 0 1
        //  0 1 1 0 1 1 0 1 1 0 1 1 0 1 0
        let grid = Caver::generate_with_margins(15, 15, 3, SEED, RING_15X15, PATTERN, false);
        assert!(grid == 0xdb68fffb3ff63fece7de0fbc3f3ffefffcfff9fff1fce7f0dfe4b6da);
        let mut tiles = Oracle::fill(15, 15, SEED, RING_15X15, PATTERN);
        let neighbors = Oracle::neighbors(15, 15, false);
        for _ in 0..3_u8 {
            tiles = Oracle::step(@tiles, @frozen, @neighbors);
        }
        assert!(grid == Oracle::pack(@tiles, 225));
        // Every side fixed, `odd = true`
        //  0 1 1 0 1 1 0 1 1 0 1 1 0 1 0
        // 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1
        //  0 0 0 0 0 0 1 1 1 1 1 1 1 1 1
        // 0 1 0 0 0 1 1 1 1 1 1 1 1 1 1
        //  0 1 1 0 0 0 1 1 0 0 1 1 1 1 1
        // 0 1 1 1 0 0 1 0 0 0 1 1 1 1 1
        //  0 0 1 1 1 0 0 0 0 0 1 1 1 1 1
        // 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1
        //  0 1 1 1 1 1 1 1 1 1 1 1 1 1 1
        // 0 1 1 1 1 1 1 1 1 1 0 1 1 1 1
        //  0 0 1 1 1 1 1 1 1 1 0 0 1 1 1
        // 0 0 1 1 1 1 1 1 1 0 0 1 1 1 1
        //  0 0 1 1 1 1 1 1 1 0 0 0 0 0 1
        // 0 1 1 1 1 1 1 1 1 0 0 0 0 0 1
        //  0 1 1 0 1 1 0 1 1 0 1 1 0 1 0
        let grid = Caver::generate_with_margins(15, 15, 3, SEED, RING_15X15, PATTERN, true);
        assert!(grid == 0xdb69fff81ff47fec67dc8f9c1f7ffefffdff79fe73f9e7f05fe0b6da);
        let mut tiles = Oracle::fill(15, 15, SEED, RING_15X15, PATTERN);
        let neighbors = Oracle::neighbors(15, 15, true);
        for _ in 0..3_u8 {
            tiles = Oracle::step(@tiles, @frozen, @neighbors);
        }
        assert!(grid == Oracle::pack(@tiles, 225));
    }

    // `LayoutTrait::new_odd`, first used by the chunks of N-1 (review of M1-T7, note 3)

    /// `expand` (and `expand_small` on the single-limb board) of a `new_odd` layout against the
    /// scalar neighbours with the global parity, on every interior tile of 15 x 15 and 7 x 7;
    /// the same on a `new` layout with `odd = false`.
    #[test]
    #[available_gas(l2_gas: 52524602)]
    fn test_caver_layout_new_odd_expand() {
        let boards: [(u8, u8); 2] = [(15, 15), (7, 7)];
        for (width, height) in boards.span() {
            let (width, height) = (*width, *height);
            for odd in [true, false].span() {
                let odd = *odd;
                let layout = if odd {
                    LayoutTrait::new_odd(width, height)
                } else {
                    LayoutTrait::new(width, height)
                };
                let mut y: u8 = 1;
                while y != height - 1 {
                    let mut x: u8 = 1;
                    while x != width - 1 {
                        let position = y * width + x;
                        let tile = Bits::pow(position);
                        let mut expected = tile;
                        for direction in DIRECTIONS.span() {
                            let next = Oracle::neighbor(width, height, position, *direction, odd);
                            expected += Bits::pow(next.unwrap());
                        }
                        let expected: u256 = expected.into();
                        assert!(layout.expand(tile.into()) == expected, "{} x {}", width, height);
                        if width * height <= 128 {
                            let tile: u128 = tile.try_into().unwrap();
                            assert!(layout.expand_small(tile) == expected.low);
                        }
                        x += 1;
                    }
                    y += 1;
                }
            }
        }
    }

    // Benchmarks (plan §6.2, "Worst case"): 15 x 15, the four sides fixed, `odd = true`, every
    // side tile open so that every plane has bits in both limbs. A generation performs the same
    // operations whatever the tiles. `order = 5` gives the cost of a generation, `(order 5 -
    // order 1) / 4`, as `bench_caver` does for `generate`; `twice - once` gives a call.

    #[derive(Copy, Drop)]
    struct Bench {
        width: u8,
        height: u8,
        seeds: [felt252; 2],
        fixed: felt252,
        values: felt252,
        odd: bool,
    }

    #[generate_trait]
    impl Inputs of InputsTrait {
        /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
        #[inline(never)]
        fn get() -> Bench {
            Bench {
                width: 15,
                height: 15,
                seeds: ['CAVE', 'CAVER'],
                fixed: RING_15X15,
                values: RING_15X15,
                odd: true,
            }
        }

        /// A generation count, opaque as well.
        #[inline(never)]
        fn order(order: u8) -> u8 {
            order
        }

        /// `generate_with_margins` on the inputs, with one of the two seeds.
        #[inline(never)]
        fn run(order: u8, second: bool) -> felt252 {
            let bench = Self::get();
            let [seed, other] = bench.seeds;
            let seed = if second {
                other
            } else {
                seed
            };
            Caver::generate_with_margins(
                bench.width,
                bench.height,
                Self::order(order),
                seed,
                bench.fixed,
                bench.values,
                bench.odd,
            )
        }
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 47995)]
    fn bench_caver_generate_with_margins_15x15_order_0() {
        assert!(Inputs::run(0, false) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 111551)]
    fn bench_caver_generate_with_margins_15x15_order_1() {
        assert!(Inputs::run(1, false) != 0);
    }

    /// The game's generation of a chunk.
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 194871)]
    fn bench_caver_generate_with_margins_15x15_order_3() {
        assert!(Inputs::run(3, false) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 380932)]
    fn bench_caver_generate_with_margins_15x15_order_3_twice() {
        assert!(Inputs::run(3, false) != 0);
        assert!(Inputs::run(3, true) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 278191)]
    fn bench_caver_generate_with_margins_15x15_order_5() {
        assert!(Inputs::run(5, false) != 0);
    }

    /// The domain-wide worst case.
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 10693141)]
    fn bench_caver_generate_with_margins_15x15_order_255() {
        assert!(Inputs::run(255, false) != 0);
    }
}
