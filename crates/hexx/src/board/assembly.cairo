//! N-3: the assembly of the window of the tick (plan §6.4, decided by D-120).
//!
//! The window is a board of 15 columns × 16 rows (240 tiles, one felt), assembled at each tick
//! from the chunks of 15 × 15 it overlaps and never stored: 16 rows always span two rows of
//! chunks, and 15 columns one or two columns of chunks, so the input is 2 or 4 chunks. Its origin
//! is on an even global row, so that the window is the same hex grid as the location (odd-r,
//! `window-parity-check.md` §1); the adventurer stands on local column 7, row 7 (global row
//! odd) or 8 (global row even).
//!
//! The chunk of the origin is `(cx, cy)`; with `+x` West and `+y` North (the convention of the
//! board), its neighbours in the window are `(cx + 1, cy)` to the West, `(cx, cy + 1)` to the
//! North and `(cx + 1, cy + 1)` to the North-West.
//!
//! No loop. The window and the chunks share the width 15, so a rectangle of a chunk moves into
//! the window by one shift of the whole felt: per chunk and layer, one AND with a rectangle (the
//! product of two band tables, `board::tables`) and one field product by a power of two, exact
//! because the rectangle clears every bit the shift would drop or push beyond the window.
//!
//! A chunk that the window overlaps may be void (beyond the edge of the location, or outside a
//! zone's outline, D-134): it is passed as `Option::None` and assembled as wall, without a read.
//! The window is never clamped.

// Core imports

#[feature("bounded-int-utils")]
use core::internal::bounded_int::{
    AddHelper, BoundedInt, ConstrainHelper, DivRemHelper, MulHelper, SubHelper, UnitInt, add,
    constrain, div_rem, mul, sub, upcast,
};

// Internal imports

use hexx::board::bits::Bits;
use hexx::board::map::{HexMap, HexMapTrait};
use hexx::board::tables::{COL_FROM, COL_TO, ROW_FROM_15, ROW_TO_15};

// Constants

/// The side of a chunk.
pub const CHUNK: u8 = 15;
/// The width of the window, the chunk's.
pub const WIDTH: u8 = 15;
/// The height of the window.
pub const HEIGHT: u8 = 16;
/// 2^15: one row of the window and of a chunk.
const ROW: felt252 = 0x8000;
/// The tiles of a chunk, 15 · 15.
const TILES: u8 = 225;
/// The interior of the window, `LayoutTrait::interior(15, 16)`, as limbs.
const INTERIOR: u256 = u256 {
    low: 0xfe7ffcfff9fff3ffe7ffcfff9fff0000, high: 0xfff9fff3ffe7ffcfff9fff3f,
};

/// `x + 8`, `y + 7 + (y mod 2)`: a location coordinate moved by one chunk, `15 + (x − 7)`.
type Moved = BoundedInt<7, 263>;
/// A signed global coordinate less the origin's, for any `Origin` (its fields are public).
type Delta = BoundedInt<-2160, 2175>;
/// A non-negative `Delta`.
type Ahead = BoundedInt<0, 2175>;

/// `x + 8`.
impl MoveColumn of AddHelper<u8, UnitInt<8>> {
    type Result = BoundedInt<8, 263>;
}

/// `y + (y mod 2)`.
impl RoundRow of AddHelper<u8, BoundedInt<0, 1>> {
    type Result = BoundedInt<0, 256>;
}

/// `y + (y mod 2) + 7`.
impl MoveRow of AddHelper<BoundedInt<0, 256>, UnitInt<7>> {
    type Result = BoundedInt<7, 263>;
}

/// `y mod 2`.
impl Parity of DivRemHelper<u8, UnitInt<2>> {
    type DivT = BoundedInt<0, 127>;
    type RemT = BoundedInt<0, 1>;
}

/// The Euclidean split of a moved coordinate: `15·(c + 1) + o`.
impl SplitMoved of DivRemHelper<Moved, UnitInt<15>> {
    type DivT = BoundedInt<0, 17>;
    type RemT = BoundedInt<0, 14>;
}

/// `c = (c + 1) − 1`.
impl ChunkIndex of SubHelper<BoundedInt<0, 17>, UnitInt<1>> {
    type Result = BoundedInt<-1, 16>;
}

/// `15·c` for any `i8`.
impl ChunkStart of MulHelper<i8, UnitInt<15>> {
    type Result = BoundedInt<-1920, 1905>;
}

/// `15·c + o` for any `i8` and `u8`.
impl OriginStart of AddHelper<BoundedInt<-1920, 1905>, u8> {
    type Result = BoundedInt<-1920, 2160>;
}

/// `x − (15·c + o)`.
impl Difference of SubHelper<u8, BoundedInt<-1920, 2160>> {
    type Result = Delta;
}

/// The sign of a `Delta`.
impl Sign of ConstrainHelper<Delta, 0> {
    type LowT = BoundedInt<-2160, -1>;
    type HighT = Ahead;
}

/// Inside the 15 columns of the window.
impl InColumns of ConstrainHelper<Ahead, 15> {
    type LowT = BoundedInt<0, 14>;
    type HighT = BoundedInt<15, 2175>;
}

/// Inside the 16 rows of the window.
impl InRows of ConstrainHelper<Ahead, 16> {
    type LowT = BoundedInt<0, 15>;
    type HighT = BoundedInt<16, 2175>;
}

/// `15·dy`.
impl RowStart of MulHelper<BoundedInt<0, 15>, UnitInt<15>> {
    type Result = BoundedInt<0, 225>;
}

/// `15·dy + dx`.
impl TileIndex of AddHelper<BoundedInt<0, 225>, BoundedInt<0, 14>> {
    type Result = BoundedInt<0, 239>;
}

/// Errors module.
pub mod errors {
    pub const ASSEMBLY_ODD_ORIGIN: felt252 = 'Assembly: odd origin';
    pub const ASSEMBLY_INVALID_OFFSET: felt252 = 'Assembly: invalid offset';
}

/// The origin of a window: the chunk `(cx, cy)` that holds it and the offset `(ox, oy)` in that
/// chunk, so that the global origin is `(15·cx + ox, 15·cy + oy)` (Euclidean: the origin may lie
/// before the first tile of the location, at `cx = -1` or `cy = -1`).
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct Origin {
    /// The column of the chunk, in `-1..=16` for the tiles of a location.
    pub cx: i8,
    /// The row of the chunk, in `-1..=16` for the tiles of a location.
    pub cy: i8,
    /// The column of the origin in its chunk, in `0..15`.
    pub ox: u8,
    /// The row of the origin in its chunk, in `0..15`.
    pub oy: u8,
}

/// The rectangles of the four chunks at one offset, and the two shifts, shared by the layers.
#[derive(Copy, Drop)]
struct Masks {
    /// Whether the window spans two columns of chunks (`ox != 0`).
    split: bool,
    /// Columns `[ox, 15)`, rows `[oy, 15)` of the chunk `(cx, cy)`.
    origin: u256,
    /// Columns `[0, ox)`, rows `[oy, 15)` of the chunk `(cx + 1, cy)`.
    west: u256,
    /// Columns `[ox, 15)`, rows `[0, oy + 1)` of the chunk `(cx, cy + 1)`.
    north: u256,
    /// Columns `[0, ox)`, rows `[0, oy + 1)` of the chunk `(cx + 1, cy + 1)`.
    north_west: u256,
    /// `2^-(15·oy + ox)`: the lower row of chunks into the window.
    down: felt252,
    /// `2^(225 − 15·oy − ox)`: the upper row of chunks into the window.
    up: felt252,
}

#[generate_trait]
pub impl AssemblyImpl of AssemblyTrait {
    /// The origin of the window of an adventurer at global `(x, y)`: `(x − 7, y − 7)` when `y`
    /// is odd, `(x − 7, y − 8)` when `y` is even, so that the origin row is always even.
    /// # Arguments
    /// * `x` - The column of the adventurer in the location
    /// * `y` - The row of the adventurer in the location
    /// # Returns
    /// * The chunk and the offset of the origin, Euclidean (never an odd origin)
    #[feature("bounded-int-utils")]
    fn origin(x: u8, y: u8) -> Origin {
        // [Compute] x − 7 + 15 = 15·(cx + 1) + ox, always non-negative
        let moved: Moved = upcast(add::<_, _, MoveColumn>(x, 8));
        let (qx, ox) = div_rem::<_, _, SplitMoved>(moved, 15);
        // [Compute] y − 7 (odd y) or y − 8 (even y), plus 15: y + 7 + (y mod 2)
        let (_, odd) = div_rem::<_, _, Parity>(y, 2);
        let moved = add::<_, _, MoveRow>(add::<_, _, RoundRow>(y, odd), 7);
        let (qy, oy) = div_rem::<_, _, SplitMoved>(moved, 15);
        Origin {
            cx: upcast(sub::<_, _, ChunkIndex>(qx, 1)),
            cy: upcast(sub::<_, _, ChunkIndex>(qy, 1)),
            ox: upcast(ox),
            oy: upcast(oy),
        }
    }

    /// The window tile of a location tile.
    /// # Arguments
    /// * `self` - The origin of the window
    /// * `x` - The column of the tile in the location
    /// * `y` - The row of the tile in the location
    /// # Returns
    /// * `dy·15 + dx` for the tile `(dx, dy)` of the window, `None` outside the window
    #[feature("bounded-int-utils")]
    fn local(self: @Origin, x: u8, y: u8) -> Option<u8> {
        let origin = *self;
        // [Compute] On signed coordinates, bounded for any origin: tested before any conversion
        let gx = add::<_, _, OriginStart>(mul::<_, _, ChunkStart>(origin.cx, 15), origin.ox);
        let gy = add::<_, _, OriginStart>(mul::<_, _, ChunkStart>(origin.cy, 15), origin.oy);
        let dx = match constrain::<_, 0, Sign>(sub::<_, _, Difference>(x, gx)) {
            Ok(_) => { return Option::None; },
            Err(ahead) => match constrain::<_, 15, InColumns>(ahead) {
                Ok(dx) => dx,
                Err(_) => { return Option::None; },
            },
        };
        let dy = match constrain::<_, 0, Sign>(sub::<_, _, Difference>(y, gy)) {
            Ok(_) => { return Option::None; },
            Err(ahead) => match constrain::<_, 16, InRows>(ahead) {
                Ok(dy) => dy,
                Err(_) => { return Option::None; },
            },
        };
        // [Return] dy·15 + dx, below 240
        Option::Some(upcast(add::<_, _, TileIndex>(mul::<_, _, RowStart>(dy, 15), dx)))
    }

    /// Assemble one layer of the window from the chunks it overlaps.
    /// # Arguments
    /// * `chunks` - The chunks `(cx, cy)`, `(cx + 1, cy)`, `(cx, cy + 1)`, `(cx + 1, cy + 1)`;
    ///   `None` for a void chunk (D-134), assembled as wall without a read; `[1]` and `[3]` are
    ///   ignored when `ox == 0`. Bits at and above 225 are ignored
    /// * `ox` - The column of the origin in its chunk
    /// * `oy` - The row of the origin in its chunk
    /// * `odd_chunk_row` - Whether `cy` is odd
    /// # Returns
    /// * The layer of the window, 15 × 16: bit `dy·15 + dx` is the tile
    ///   `(15·cx + ox + dx, 15·cy + oy + dy)` of the location
    /// # Panics
    /// * `'Assembly: invalid offset'` when `ox >= 15` or `oy >= 15`
    /// * `'Assembly: odd origin'` when `oy + cy` is odd (the origin is on an odd global row)
    ///
    /// A void chunk is `Option::None` (D-134, plan §14), where the plan's sketch passed an absent
    /// chunk as the value 0: the caller states that the chunk is void and reads nothing for it.
    /// `Some(0)` assembles as wall as well.
    fn assemble(chunks: [Option<felt252>; 4], ox: u8, oy: u8, odd_chunk_row: bool) -> felt252 {
        // [Check] Offset and parity
        AssemblyAssert::assert_valid_offset(ox, oy);
        AssemblyAssert::assert_even_origin(oy, odd_chunk_row);
        // [Return] One layer
        let masks = AssemblyInternal::masks(ox, oy);
        AssemblyInternal::layer(chunks, @masks)
    }

    /// Assemble both layers of the window, the ring of the window imposed as wall on the
    /// terrain.
    /// # Arguments
    /// * `terrain` - The terrain of the chunks, as for `assemble`
    /// * `occupied` - The occupancy of the chunks, as for `assemble`
    /// * `origin` - The origin of the window
    /// * `seed` - The seed of the returned map
    /// # Returns
    /// * The map of 15 × 16 whose grid is the terrain, its ring wall, and the occupancy, its
    ///   ring kept
    /// # Panics
    /// * `'Assembly: invalid offset'` when `ox >= 15` or `oy >= 15`
    /// * `'Assembly: odd origin'` when `oy + cy` is odd
    fn window(
        terrain: [Option<felt252>; 4],
        occupied: [Option<felt252>; 4],
        origin: @Origin,
        seed: felt252,
    ) -> (HexMap, felt252) {
        let origin = *origin;
        // [Check] Offset and parity, once for both layers
        AssemblyAssert::assert_valid_offset(origin.ox, origin.oy);
        // [Compute] The parity of cy, on a non-negative value of the same parity
        let row: i16 = origin.cy.into() + 128;
        let row: u16 = row.try_into().unwrap();
        let (_, odd) = DivRem::div_rem(row, 2);
        AssemblyAssert::assert_even_origin(origin.oy, odd == 1);
        // [Compute] Both layers, the masks shared
        let masks = AssemblyInternal::masks(origin.ox, origin.oy);
        let grid = AssemblyInternal::layer(terrain, @masks);
        let occupied = AssemblyInternal::layer(occupied, @masks);
        // [Return] The ring of the terrain is wall
        let grid = Bits::to_felt(Bits::and(grid.into(), INTERIOR));
        (HexMapTrait::new(grid, WIDTH, HEIGHT, seed), occupied)
    }
}

#[generate_trait]
pub impl AssemblyAssert of AssemblyAssertTrait {
    /// Assert that the offset lies in a chunk.
    /// # Arguments
    /// * `ox` - The column of the origin in its chunk
    /// * `oy` - The row of the origin in its chunk
    /// # Panics
    /// * `'Assembly: invalid offset'` when `ox >= 15` or `oy >= 15`
    #[inline]
    fn assert_valid_offset(ox: u8, oy: u8) {
        assert(ox < CHUNK && oy < CHUNK, errors::ASSEMBLY_INVALID_OFFSET);
    }

    /// Assert that the origin row `15·cy + oy` is even, that is `oy + cy` even.
    /// # Arguments
    /// * `oy` - The row of the origin in its chunk
    /// * `odd_chunk_row` - Whether `cy` is odd
    /// # Panics
    /// * `'Assembly: odd origin'` when `oy + cy` is odd
    #[inline]
    fn assert_even_origin(oy: u8, odd_chunk_row: bool) {
        let (_, odd) = DivRem::div_rem(oy, 2);
        assert((odd == 1) == odd_chunk_row, errors::ASSEMBLY_ODD_ORIGIN);
    }
}

#[generate_trait]
impl AssemblyInternal of AssemblyInternalTrait {
    /// The rectangles and the shifts of an offset, `ox, oy < 15`.
    ///
    /// The chunk `(cx, cy)` gives its rows `[oy, 15)`, which land on the window's rows
    /// `[0, 15 − oy)`: a shift by `−(15·oy + ox)`; the chunk `(cx + 1, cy)` is first shifted
    /// by `+15` (its column `c < ox` lands on the column `15 + c` of the row below, which is the
    /// window's column `15 − ox + c` after the same shift). The chunks of the row `cy + 1` give
    /// their rows `[0, oy + 1)`, which land on the window's rows `[15 − oy, 16)`: a shift by
    /// `225 − (15·oy + ox)`, the West chunk again first by `+15`.
    #[inline(always)]
    fn masks(ox: u8, oy: u8) -> Masks {
        let from = *COL_FROM.span().at(ox.into());
        let lower = *ROW_FROM_15.span().at(oy.into());
        let upper = *ROW_TO_15.span().at(oy.into() + 1);
        let start = oy * CHUNK + ox;
        let down = Bits::inv(start);
        let up = Bits::pow(TILES - start);
        if ox == 0 {
            return Masks {
                split: false,
                origin: (from * lower).into(),
                west: 0,
                north: (from * upper).into(),
                north_west: 0,
                down,
                up,
            };
        }
        let to = *COL_TO.span().at(ox.into());
        Masks {
            split: true,
            origin: (from * lower).into(),
            west: (to * lower).into(),
            north: (from * upper).into(),
            north_west: (to * upper).into(),
            down,
            up,
        }
    }

    /// One layer: every piece masked, the pieces of a row of chunks added, each row shifted.
    /// Exact: the lower pieces have no bit below `15·oy + ox` and the upper pieces no bit at or
    /// above `15·(oy + 1) + ox`, so the window has no bit at or above 240.
    #[inline(always)]
    fn layer(chunks: [Option<felt252>; 4], masks: @Masks) -> felt252 {
        let masks = *masks;
        let [origin, west, north, north_west] = chunks;
        if !masks.split {
            return Self::piece(origin, masks.origin) * masks.down
                + Self::piece(north, masks.north) * masks.up;
        }
        let lower = Self::piece(origin, masks.origin) + Self::piece(west, masks.west) * ROW;
        let upper = Self::piece(north, masks.north)
            + Self::piece(north_west, masks.north_west) * ROW;
        lower * masks.down + upper * masks.up
    }

    /// The rectangle of one chunk, wall for a void chunk (not read).
    #[inline(always)]
    fn piece(chunk: Option<felt252>, mask: u256) -> felt252 {
        match chunk {
            Option::Some(chunk) => Bits::to_felt(Bits::and(chunk.into(), mask)),
            Option::None => 0,
        }
    }
}
