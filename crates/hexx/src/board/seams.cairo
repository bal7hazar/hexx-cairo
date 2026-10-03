//! N-2, seams (plan §6.3): the sides of a board and the openings between two neighbouring boards
//! of the same dimensions, with the global parity of the rows.
//!
//! `far` lies beyond `near`'s `side`, and `far`'s opposite side touches it: for `Side::East`,
//! `far` lies to the East (lower `x`) and its column `W − 1` faces `near`'s column 0; for
//! `Side::North`, `far` lies to the North and its row 0 faces `near`'s row `H − 1`. `odd` states
//! that `near`'s local row 0 is a global odd row (the parity flag of plan §3.3, a parameter, never
//! a field of `HexMap`).
//! A tile of `near`'s side is open across the seam when it is open and one of its six neighbours,
//! from the neighbour table with the global parity of its row, lies in `far` and is open there.
//! The four corners of a chunk are wall (D-134), so no corner is an opening on the game's chunks;
//! the functions test a corner like any other tile of its side.
//!
//! No loop: masked shifts. A vertical seam (East, West) has up to three contacts per tile, the
//! straight one and, on the rows of one global parity, the two diagonals; a horizontal seam
//! (South, North) has two. The contact sets overlap, so every union is an OR. Every shift is a
//! field product, exact because the bits it would push out of `0..W·H` are cleared first
//! (`SeamInternal`).
//!
//! Mirrors nothing in `hexx`: an extension (plan §6.3, N-2).

// Core imports

use core::felt252_div;

// Internal imports

use hexx::board::bits::Bits;

// Constants

/// 1/2 in the field.
const INV_2: felt252 = 0x400000000000008800000000000000000000000000000000000000000000001;

/// A side of a board, named as the directions of the board name it (`+x` is West, `+y` North).
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub enum Side {
    /// Column 0, the low `x` side.
    East,
    /// Row `H − 1`.
    North,
    /// Column `W − 1`.
    West,
    /// Row 0.
    South,
}

#[generate_trait]
pub impl SeamImpl of SeamTrait {
    /// The mask of one side of a board, corners included.
    /// # Arguments
    /// * `width` - The width of the board, `W ≥ 3`
    /// * `height` - The height of the board, `H ≥ 3`, `W · H ≤ 251`
    /// * `side` - The side
    /// # Returns
    /// * The bits of the side: column 0 (East), column `W − 1` (West), row 0 (South) or row
    ///   `H − 1` (North)
    ///
    /// The dimensions are not checked: a board outside the domain (e.g. `width * height` above
    /// `u8`, `height = 0`) is the caller's error and panics on overflow, as in `HexagonTrait`.
    ///
    /// Mirrors nothing in `hexx`: an extension (N-2).
    fn side(width: u8, height: u8, side: Side) -> felt252 {
        let row = Bits::pow(width);
        match side {
            Side::East => SeamInternal::column(row, Bits::pow(width * height)),
            Side::West => SeamInternal::column(row, Bits::pow(width * height)) * row * INV_2,
            Side::South => row - 1,
            Side::North => (row - 1) * Bits::pow(width * (height - 1)),
        }
    }

    /// The tiles of `near`'s side that are open and adjacent, across the seam, to an open tile of
    /// `far`, the neighbouring board whose opposite side touches `side`.
    /// # Arguments
    /// * `width` - The width of both boards, `W ≥ 3`
    /// * `height` - The height of both boards, `H ≥ 3`, `W · H ≤ 251`
    /// * `near` - The board whose side is tested; its bits at or above `W · H` have no effect
    /// * `far` - The neighbouring board; its bits at or above `W · H` have no effect
    /// * `side` - The side of `near` that `far` touches
    /// * `odd` - Whether `near`'s local row 0 is a global odd row
    /// # Returns
    /// * The openings, a subset of `SeamTrait::side(width, height, side)`
    ///
    /// The dimensions are not checked: a board outside the domain (e.g. `width * height` above
    /// `u8`, `height = 0`) is the caller's error and panics on overflow, as in `HexagonTrait`.
    ///
    /// Mirrors nothing in `hexx`: an extension (N-2).
    fn openings(
        width: u8, height: u8, near: felt252, far: felt252, side: Side, odd: bool,
    ) -> felt252 {
        match side {
            Side::East => SeamInternal::vertical(width, height, near, far, true, odd),
            Side::West => SeamInternal::vertical(width, height, near, far, false, odd),
            Side::South => {
                // [Compute] Row 0 lies in the low limb (`W ≤ 83`)
                let contacts = SeamInternal::band(width, height, far, true, odd);
                let near: u256 = near.into();
                let (low, _, _) = Bits::bitwise(near.low, contacts);
                low.into()
            },
            Side::North => {
                // [Compute] Row `H − 1` is globally odd iff `odd XOR (H − 1 odd)`
                let parity = odd != (height % 2 == 0);
                let contacts = SeamInternal::band(width, height, far, false, parity);
                let shifted: felt252 = contacts.into() * Bits::pow(width * (height - 1));
                Bits::to_felt(Bits::and(near.into(), shifted.into()))
            },
        }
    }

    /// Whether the seam is passable: some tile of `near`'s side is open across it.
    /// # Arguments
    /// * `width` - The width of both boards
    /// * `height` - The height of both boards
    /// * `near` - The board whose side is tested
    /// * `far` - The neighbouring board
    /// * `side` - The side of `near` that `far` touches
    /// * `odd` - Whether `near`'s local row 0 is a global odd row
    /// # Returns
    /// * `openings(width, height, near, far, side, odd) != 0`
    ///
    /// The dimensions are not checked: a board outside the domain (e.g. `width * height` above
    /// `u8`, `height = 0`) is the caller's error and panics on overflow, as in `HexagonTrait`.
    ///
    /// Mirrors nothing in `hexx`: an extension (N-2).
    #[inline]
    fn is_open_across(
        width: u8, height: u8, near: felt252, far: felt252, side: Side, odd: bool,
    ) -> bool {
        Self::openings(width, height, near, far, side, odd) != 0
    }
}

#[generate_trait]
impl SeamInternal of SeamInternalTrait {
    /// Column 0, `(2^(W·H) − 1) / (2^W − 1)`, an exact field division.
    /// # Arguments
    /// * `row` - `2^W`
    /// * `board` - `2^(W·H)`
    /// # Returns
    /// * The bits of column 0
    #[inline]
    fn column(row: felt252, board: felt252) -> felt252 {
        felt252_div(board - 1, (row - 1).try_into().unwrap())
    }

    /// The contacts of a vertical seam, in `near`'s column, as three products: the straight
    /// contacts, those from the northern diagonal and those from the southern one.
    ///
    /// `far`'s column `F` (`W − 1` for East, 0 for West) is masked three times: whole (`all`); on
    /// the rows of the diagonals' sources without row 0 (`north`: a source `s` reaches the tile
    /// of row `s − 1`); on the same rows without row `H − 1` (`south`: `s` reaches row `s +
    /// 1`).
    /// The sources are the rows whose global parity is opposite to the rows that have diagonals
    /// across the seam: globally odd rows for East (its tiles on globally even rows have them),
    /// globally even rows for West. Each set is then shifted to `near`'s column `C`, by
    /// `2^(C − F)`, `2^(C − F − W)` and `2^(C − F + W)`:
    /// * East, `F = W − 1`, `C = 0`: `all · 2^−(W−1)` (every bit at `≥ W − 1`), `north
    /// ·
    ///   2^−(2W−1)` (row 0 cleared: every bit at `≥ 2W − 1`), `south · 2` (row `H − 1`
    ///   cleared:
    ///   below `2^((H−1)W + 1) ≤ 2^(W·H)`);
    /// * West, `F = 0`, `C = W − 1`: `all · 2^(W−1)` (below `2^(W·H)`), `north / 2` (row 0
    ///   cleared: every bit at `≥ W`), `south · 2^(2W−1)` (row `H − 1` cleared: below
    ///   `2^((H−2)W + 2W − 1) = 2^(W·H − 1)`).
    /// Every product is exact and below `2^(W·H) ≤ 2^250`.
    /// # Arguments
    /// * `width` - The width of both boards
    /// * `height` - The height of both boards
    /// * `far` - The neighbouring board
    /// * `east` - East seam (`near`'s column 0), else West
    /// * `odd` - Whether `near`'s local row 0 is a global odd row
    /// # Returns
    /// * The three contact sets, each a subset of `near`'s column `C`
    #[inline]
    fn contacts(
        width: u8, height: u8, far: felt252, east: bool, odd: bool,
    ) -> (felt252, felt252, felt252) {
        let row = Bits::pow(width);
        let board = Bits::pow(width * height);
        let down = Bits::inv(width);
        // [Compute] Column 0 on the local even rows, `(2^(2W·⌈H/2⌉) − 1) / (2^(2W) − 1)`,
        // exact as in `LayoutTrait::even`; the whole column from it, and the bit of row `H − 1`
        let tall = height % 2 == 1;
        let top = if tall {
            board * row
        } else {
            board
        };
        let evens = felt252_div(top - 1, (row * row - 1).try_into().unwrap());
        let column = if tall {
            evens * (1 + row) - board
        } else {
            evens * (1 + row)
        };
        let last = board * down;
        // [Compute] The sources of the diagonals: the local even rows when they are globally odd
        // (East) or globally even (West); row `H − 1` is a local even row iff `H` is odd
        let (north, south) = if east == odd {
            (evens - 1, if tall {
                evens - last
            } else {
                evens
            })
        } else {
            let odds = column - evens;
            (odds, if tall {
                odds
            } else {
                odds - last
            })
        };
        // [Compute] The three masks of `far`'s column, then the shifts to `near`'s column
        let half = row * INV_2;
        let (offset, straight, northern, southern) = if east {
            let back = down + down;
            (half, back, back * down, 2)
        } else {
            (1, half, INV_2, half * row)
        };
        let far: u256 = far.into();
        let all = Bits::and(far, (column * offset).into());
        let north = Bits::and(all, (north * offset).into());
        let south = Bits::and(all, (south * offset).into());
        (
            Bits::to_felt(all) * straight,
            Bits::to_felt(north) * northern,
            Bits::to_felt(south) * southern,
        )
    }

    /// `openings` on a vertical seam: `near & (all | north | south)`.
    /// # Arguments
    /// * `width` - The width of both boards
    /// * `height` - The height of both boards
    /// * `near` - The board whose side is tested
    /// * `far` - The neighbouring board
    /// * `east` - East seam, else West
    /// * `odd` - Whether `near`'s local row 0 is a global odd row
    /// # Returns
    /// * The openings
    #[inline]
    fn vertical(
        width: u8, height: u8, near: felt252, far: felt252, east: bool, odd: bool,
    ) -> felt252 {
        let (all, north, south) = Self::contacts(width, height, far, east, odd);
        let contacts = Bits::or(Bits::or(all.into(), north.into()), south.into());
        Bits::to_felt(Bits::and(near.into(), contacts))
    }

    /// The contacts of a horizontal seam, in row-0 frame: bit `x` is set when `far`'s facing row
    /// is open at `x` or at the diagonal neighbour, `x − 1` when `near`'s side row is globally
    /// even and `x + 1` when it is odd.
    ///
    /// With `R` the facing row of `far` brought to bits `0..W` (`(far & ROW_LAST) / 2^(W(H−1))`,
    /// exact: every bit at `≥ W(H − 1)`; or `far & ROW_0`), `J = R | 2R` holds at bit `x` the
    /// contacts `x` and `x − 1`, and at bit `x + 1` the contacts `x` and `x + 1`: the even row
    /// keeps `J`'s bits `0..W` (bit `W`, from `x = W − 1`, is dropped), the odd row takes `J / 2`
    /// (bit 0 dropped by the integer division).
    /// # Arguments
    /// * `width` - The width of both boards
    /// * `height` - The height of both boards
    /// * `far` - The neighbouring board
    /// * `south` - South seam (`far`'s row `H − 1`), else North (`far`'s row 0)
    /// * `odd` - Whether `near`'s side row is a global odd row
    /// # Returns
    /// * The contacts, below `2^W`
    #[inline]
    fn band(width: u8, height: u8, far: felt252, south: bool, odd: bool) -> u128 {
        let row = Bits::pow(width);
        let limit: u128 = row.try_into().unwrap();
        let far: u256 = far.into();
        let facing: u128 = if south {
            let last = Bits::pow(width * (height - 1));
            let band = Bits::and(far, ((row - 1) * last).into());
            felt252_div(Bits::to_felt(band), last.try_into().unwrap()).try_into().unwrap()
        } else {
            let (band, _, _) = Bits::bitwise(far.low, limit - 1);
            band
        };
        let (_, _, joined) = Bits::bitwise(facing, facing + facing);
        if odd {
            joined / 2
        } else if joined >= limit {
            joined - limit
        } else {
            joined
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use hexx::board::bits::Bits;
    use hexx::board::layout::LayoutTrait;
    use super::{SeamInternal, SeamTrait, Side};

    /// Every dimension class of the domain (plan §6.3, "Domain").
    const CLASSES: [(u8, u8); 10] = [
        (15, 15), (15, 16), (16, 15), (17, 14), (19, 13), (25, 10), (83, 3), (3, 83), (7, 7),
        (3, 3),
    ];
    /// The four sides.
    const SIDES: [Side; 4] = [Side::East, Side::North, Side::West, Side::South];
    /// Seeded pairs of boards per side and parity.
    const PAIRS: u32 = 32;

    // Oracles

    #[generate_trait]
    impl Oracle of OracleTrait {
        /// `openings` by its definition (plan §6.3, "Oracle"), on signed global coordinates with
        /// `near`'s tile `(0, 0)` at the origin: for every open tile of `near`'s side, its six
        /// neighbours from the neighbour table with the global parity of its row, each looked up
        /// bit by bit in `far` when it falls inside `far`. No board of `2W × H` is built.
        fn openings(
            width: u8, height: u8, near: felt252, far: felt252, side: Side, odd: bool,
        ) -> felt252 {
            let (w, h): (i32, i32) = (width.into(), height.into());
            // [Compute] `far`'s tile `(0, 0)` in global coordinates
            let (fx, fy): (i32, i32) = match side {
                Side::East => (-w, 0),
                Side::West => (w, 0),
                Side::South => (0, -h),
                Side::North => (0, h),
            };
            // [Compute] The tiles of the side: `count` tiles from `first`, `step` apart
            let (count, first, step) = match side {
                Side::East => (height, 0, width),
                Side::West => (height, width - 1, width),
                Side::South => (width, 0, 1),
                Side::North => (width, width * (height - 1), 1),
            };
            let near: u256 = near.into();
            let far: u256 = far.into();
            let mut openings: felt252 = 0;
            let mut k: u8 = 0;
            while k != count {
                let position = first + k * step;
                k += 1;
                if !Bits::get(near, position) {
                    continue;
                }
                let x: i32 = (position % width).into();
                let y: i32 = (position / width).into();
                // [Compute] The global parity of the row, then the neighbour table (`E`, `W`,
                // `NE`, `NW`, `SE`, `SW`)
                let shift: i32 = if odd {
                    1
                } else {
                    0
                };
                let offsets: [(i32, i32); 6] = if (y + shift) % 2 == 0 {
                    [(-1, 0), (1, 0), (-1, 1), (0, 1), (-1, -1), (0, -1)]
                } else {
                    [(-1, 0), (1, 0), (0, 1), (1, 1), (0, -1), (1, -1)]
                };
                let mut open = false;
                for (dx, dy) in offsets.span() {
                    let (lx, ly) = (x + *dx - fx, y + *dy - fy);
                    if lx >= 0 && lx < w && ly >= 0 && ly < h {
                        if Bits::get(far, (ly * w + lx).try_into().unwrap()) {
                            open = true;
                        }
                    }
                }
                if open {
                    openings += Bits::pow(position);
                }
            }
            openings
        }

        /// The side by its definition: every tile whose column or row is the side's.
        fn side(width: u8, height: u8, side: Side) -> felt252 {
            let mut mask: felt252 = 0;
            let mut position: u8 = 0;
            while position != width * height {
                let (x, y) = (position % width, position / width);
                let on = match side {
                    Side::East => x == 0,
                    Side::West => x == width - 1,
                    Side::South => y == 0,
                    Side::North => y == height - 1,
                };
                if on {
                    mask += Bits::pow(position);
                }
                position += 1;
            }
            mask
        }

        /// The four corners.
        fn corners(width: u8, height: u8) -> felt252 {
            let size = width * height;
            1 + Bits::pow(width - 1) + Bits::pow(size - width) + Bits::pow(size - 1)
        }

        /// The next state of a 64-bit linear congruential generator (Knuth's MMIX constants).
        fn next(state: u64) -> u64 {
            let product: u128 = state.into() * 6364136223846793005 + 1442695040888963407;
            (product % 0x10000000000000000).try_into().unwrap()
        }

        /// A seeded board: the AND of `rounds` draws of 256 bits, restricted to the board. Each
        /// draw is eight words of 32 bits, each the high half of a new state: the low bits of a
        /// power-of-two LCG have short periods, and taken whole they left tiles such as `(0, 0)`
        /// closed in every board (review of M1-T7).
        fn board(width: u8, height: u8, ref state: u64, rounds: u32) -> felt252 {
            let mut value: u256 = LayoutTrait::board(width, height).into();
            let mut round: u32 = 0;
            while round != rounds {
                let mut limbs: Array<u128> = array![];
                let mut limb: u32 = 0;
                while limb != 2 {
                    let mut word: u128 = 0;
                    let mut index: u32 = 0;
                    while index != 4 {
                        state = Self::next(state);
                        let high: u128 = (state / 0x100000000).into();
                        word = word * 0x100000000 + high;
                        index += 1;
                    }
                    limbs.append(word);
                    limb += 1;
                }
                let draw = u256 { low: *limbs[0], high: *limbs[1] };
                value = Bits::and(value, draw);
                round += 1;
            }
            Bits::to_felt(value)
        }

        /// One dimension class against the oracle: every side, both parities, the four
        /// full/empty combinations and 32 seeded pairs (densities 1/2, 1/4 and 1/8 in turn), in
        /// which every tile of every side is open at least once in `near` and once in `far`;
        /// `is_open_across` with it; and D-134: the same pairs with the four corners of both
        /// boards cleared give no corner.
        fn check(width: u8, height: u8, seed: u64) {
            let board = LayoutTrait::board(width, height);
            let corners = Self::corners(width, height);
            let inside: u256 = (board - corners).into();
            let mut state = seed;
            for side in SIDES.span() {
                let side = *side;
                for odd in [false, true].span() {
                    let odd = *odd;
                    let mut pairs: Array<(felt252, felt252)> = array![
                        (board, board), (board, 0), (0, board), (0, 0),
                    ];
                    let mut nears: u256 = 0;
                    let mut fars: u256 = 0;
                    let mut index: u32 = 0;
                    while index != PAIRS {
                        let rounds = 1 + index % 3;
                        let near = Self::board(width, height, ref state, rounds);
                        let far = Self::board(width, height, ref state, rounds);
                        nears = Bits::or(nears, near.into());
                        fars = Bits::or(fars, far.into());
                        pairs.append((near, far));
                        index += 1;
                    }
                    // Coverage: every tile of the side, and of the side `far` presents, is open
                    // in at least one seeded `near` and one seeded `far`
                    for mask in SIDES.span() {
                        let mask: u256 = SeamTrait::side(width, height, *mask).into();
                        assert!(Bits::and(nears, mask) == mask, "{} x {}: near", width, height);
                        assert!(Bits::and(fars, mask) == mask, "{} x {}: far", width, height);
                    }
                    for (near, far) in pairs.span() {
                        let (near, far) = (*near, *far);
                        let expected = Self::openings(width, height, near, far, side, odd);
                        let openings = SeamTrait::openings(width, height, near, far, side, odd);
                        assert!(
                            openings == expected,
                            "{} x {}, {:?}, odd {}: {} != {}",
                            width,
                            height,
                            side,
                            odd,
                            openings,
                            expected,
                        );
                        assert!(
                            SeamTrait::is_open_across(
                                width, height, near, far, side, odd,
                            ) == (expected != 0),
                        );
                        // D-134: chunks whose corners are wall have no corner in `openings`
                        let near = Bits::to_felt(Bits::and(near.into(), inside));
                        let far = Bits::to_felt(Bits::and(far.into(), inside));
                        let openings = SeamTrait::openings(width, height, near, far, side, odd);
                        assert!(Bits::and(openings.into(), corners.into()) == 0);
                    }
                }
            }
        }
    }

    // Regression cases (plan §6.3)

    /// R-N2-1: the contact sets overlap; an addition would clear tiles.
    #[test]
    #[available_gas(l2_gas: 25129)]
    fn test_seams_r_n2_1_south_overlap() {
        let board = LayoutTrait::board(15, 15);
        assert!(SeamTrait::openings(15, 15, board, board, Side::South, false) == 0x7fff);
    }

    /// R-N2-2: West, the single tile `(0, 15)` of `far` opens `(14, 15)` only, through the
    /// straight contact; its lower diagonal would reach bit 254 without its mask.
    #[test]
    #[available_gas(l2_gas: 44107)]
    fn test_seams_r_n2_2_west_last_row() {
        let board = LayoutTrait::board(15, 16);
        let far = Bits::pow(225);
        assert!(SeamTrait::openings(15, 16, board, far, Side::West, false) == Bits::pow(239));
    }

    /// R-N2-3: East, `odd = false`, `far`'s `(14, 5)` opens `(0, 4)`, `(0, 5)` and `(0, 6)`.
    #[test]
    #[available_gas(l2_gas: 47404)]
    fn test_seams_r_n2_3_east_even() {
        let board = LayoutTrait::board(15, 15);
        let expected = Bits::pow(60) + Bits::pow(75) + Bits::pow(90);
        assert!(SeamTrait::openings(15, 15, board, Bits::pow(89), Side::East, false) == expected);
    }

    /// R-N2-3b: the same with `odd = true` opens `(0, 5)` only.
    #[test]
    #[available_gas(l2_gas: 45157)]
    fn test_seams_r_n2_3b_east_odd() {
        let board = LayoutTrait::board(15, 15);
        assert!(
            SeamTrait::openings(15, 15, board, Bits::pow(89), Side::East, true) == Bits::pow(75),
        );
    }

    /// R-N2-4: North, 15 × 16, `odd = true` (row 15 globally even): `far`'s `(7, 0)` opens
    /// `(7, 15)` and `(8, 15)`.
    #[test]
    #[available_gas(l2_gas: 28783)]
    fn test_seams_r_n2_4_north_odd() {
        let board = LayoutTrait::board(15, 16);
        let expected = Bits::pow(232) + Bits::pow(233);
        assert!(SeamTrait::openings(15, 16, board, Bits::pow(7), Side::North, true) == expected);
    }

    /// D-134 on full chunks: with the corners of both boards as wall, every side keeps its
    /// tiles but its two corners, on every dimension class and both parities.
    #[test]
    #[available_gas(l2_gas: 3668343)]
    fn test_seams_d134_corners() {
        for (width, height) in CLASSES.span() {
            let (width, height) = (*width, *height);
            let open = LayoutTrait::board(width, height) - Oracle::corners(width, height);
            for side in SIDES.span() {
                let mask = SeamTrait::side(width, height, *side);
                let expected = Bits::to_felt(Bits::and(mask.into(), open.into()));
                assert!(SeamTrait::openings(width, height, open, open, *side, false) == expected);
                assert!(SeamTrait::openings(width, height, open, open, *side, true) == expected);
            }
        }
    }

    // Exactness (AC-2)

    /// Every product of the vertical seams on a full `far`, the case that sets every bit a
    /// product can move: each lies in `near`'s column, so none reached `2^251` or wrapped (a
    /// wrapped product is a felt with bits far above `W · H`). 15 × 16 West, whose lower diagonal
    /// is the one of R-N2-2, is among them. The bands of the horizontal seams are below `2^W`.
    #[test]
    #[available_gas(l2_gas: 3336039)]
    fn test_seams_products_exact() {
        for (width, height) in CLASSES.span() {
            let (width, height) = (*width, *height);
            let far = LayoutTrait::board(width, height);
            let row: u128 = Bits::pow(width).try_into().unwrap();
            for odd in [false, true].span() {
                let odd = *odd;
                for east in [true, false].span() {
                    let side = if *east {
                        Side::East
                    } else {
                        Side::West
                    };
                    let column: u256 = SeamTrait::side(width, height, side).into();
                    let (all, north, south) = SeamInternal::contacts(
                        width, height, far, *east, odd,
                    );
                    for product in [all, north, south].span() {
                        assert!(Bits::or((*product).into(), column) == column);
                    }
                    // The straight contacts of a full board: the whole column
                    let all: u256 = all.into();
                    assert!(all == column);
                }
                for south in [true, false].span() {
                    assert!(SeamInternal::band(width, height, far, *south, odd) < row);
                }
            }
        }
    }

    // Sides

    /// `side` against its definition on every dimension class.
    #[test]
    #[available_gas(l2_gas: 47174568)]
    fn test_seams_side() {
        for (width, height) in CLASSES.span() {
            let (width, height) = (*width, *height);
            for side in SIDES.span() {
                assert!(
                    SeamTrait::side(width, height, *side) == Oracle::side(width, height, *side),
                );
            }
        }
    }

    // Oracle (plan §6.3): one test per dimension class, under the step limit

    #[test]
    #[available_gas(l2_gas: 312832681)]
    fn test_seams_oracle_15x15() {
        Oracle::check(15, 15, 'n2 15x15');
    }

    #[test]
    #[available_gas(l2_gas: 320229394)]
    fn test_seams_oracle_15x16() {
        Oracle::check(15, 16, 'n2 15x16');
    }

    #[test]
    #[available_gas(l2_gas: 323015034)]
    fn test_seams_oracle_16x15() {
        Oracle::check(16, 15, 'n2 16x15');
    }

    #[test]
    #[available_gas(l2_gas: 318405462)]
    fn test_seams_oracle_17x14() {
        Oracle::check(17, 14, 'n2 17x14');
    }

    #[test]
    #[available_gas(l2_gas: 325551405)]
    fn test_seams_oracle_19x13() {
        Oracle::check(19, 13, 'n2 19x13');
    }

    #[test]
    #[available_gas(l2_gas: 342128402)]
    fn test_seams_oracle_25x10() {
        Oracle::check(25, 10, 'n2 25x10');
    }

    #[test]
    #[available_gas(l2_gas: 612242162)]
    fn test_seams_oracle_83x3() {
        Oracle::check(83, 3, 'n2 83x3');
    }

    #[test]
    #[available_gas(l2_gas: 590612488)]
    fn test_seams_oracle_3x83() {
        Oracle::check(3, 83, 'n2 3x83');
    }

    #[test]
    #[available_gas(l2_gas: 230045537)]
    fn test_seams_oracle_7x7() {
        Oracle::check(7, 7, 'n2 7x7');
    }

    #[test]
    #[available_gas(l2_gas: 189083552)]
    fn test_seams_oracle_3x3() {
        Oracle::check(3, 3, 'n2 3x3');
    }

    // Benchmarks on 15 × 16, the worst cases of plan §6.3: the difference between two calls and
    // one, the method of `bench_assembly`. Every case performs a fixed sequence of operations
    // whatever the bitmaps.

    #[derive(Copy, Drop)]
    struct Bench {
        /// Two pairs `(near, far)`: both boards fully open, then `near` full and `far` full but
        /// its tile 0.
        pairs: [(felt252, felt252); 2],
    }

    #[generate_trait]
    impl Inputs of InputsTrait {
        /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
        #[inline(never)]
        fn get() -> Bench {
            let board = LayoutTrait::board(15, 16);
            Bench { pairs: [(board, board), (board, board - 1)] }
        }

        /// The same pairs on a chunk of 15 × 15.
        #[inline(never)]
        fn chunk() -> Bench {
            let board = LayoutTrait::board(15, 15);
            Bench { pairs: [(board, board), (board, board - 1)] }
        }
    }

    /// `openings`, East, `odd = true`, on a chunk of 15 × 15: an odd height takes the longer
    /// arms of `SeamInternal::contacts` (review of M1-T7).
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 45220)]
    fn bench_seams_openings_east_chunk_odd_once() {
        let bench = Inputs::chunk();
        let [(near, far), _] = bench.pairs;
        assert!(SeamTrait::openings(15, 15, near, far, Side::East, true) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 79131)]
    fn bench_seams_openings_east_chunk_odd_twice() {
        let bench = Inputs::chunk();
        let [(near, far), (other, next)] = bench.pairs;
        assert!(SeamTrait::openings(15, 15, near, far, Side::East, true) != 0);
        assert!(SeamTrait::openings(15, 15, other, next, Side::East, true) != 0);
    }

    /// `openings`, East, `odd = false` (three contacts on every even row), both fully open.
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 45010)]
    fn bench_seams_openings_east_once() {
        let bench = Inputs::get();
        let [(near, far), _] = bench.pairs;
        assert!(SeamTrait::openings(15, 16, near, far, Side::East, false) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 78711)]
    fn bench_seams_openings_east_twice() {
        let bench = Inputs::get();
        let [(near, far), (other, next)] = bench.pairs;
        assert!(SeamTrait::openings(15, 16, near, far, Side::East, false) != 0);
        assert!(SeamTrait::openings(15, 16, other, next, Side::East, false) != 0);
    }

    /// `openings`, South, `odd = true` (the horizontal seam of plan §7).
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 27796)]
    fn bench_seams_openings_south_once() {
        let bench = Inputs::get();
        let [(near, far), _] = bench.pairs;
        assert!(SeamTrait::openings(15, 16, near, far, Side::South, true) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 44283)]
    fn bench_seams_openings_south_twice() {
        let bench = Inputs::get();
        let [(near, far), (other, next)] = bench.pairs;
        assert!(SeamTrait::openings(15, 16, near, far, Side::South, true) != 0);
        assert!(SeamTrait::openings(15, 16, other, next, Side::South, true) != 0);
    }

    /// `openings`, North, `odd = true` (the two-contact worst case of plan §6.3).
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 27618)]
    fn bench_seams_openings_north_once() {
        let bench = Inputs::get();
        let [(near, far), _] = bench.pairs;
        assert!(SeamTrait::openings(15, 16, near, far, Side::North, true) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 43926)]
    fn bench_seams_openings_north_twice() {
        let bench = Inputs::get();
        let [(near, far), (other, next)] = bench.pairs;
        assert!(SeamTrait::openings(15, 16, near, far, Side::North, true) != 0);
        assert!(SeamTrait::openings(15, 16, other, next, Side::North, true) != 0);
    }

    /// `is_open_across`, as the East case of `openings`.
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 45010)]
    fn bench_seams_is_open_across_once() {
        let bench = Inputs::get();
        let [(near, far), _] = bench.pairs;
        assert!(SeamTrait::is_open_across(15, 16, near, far, Side::East, false));
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 78711)]
    fn bench_seams_is_open_across_twice() {
        let bench = Inputs::get();
        let [(near, far), (other, next)] = bench.pairs;
        assert!(SeamTrait::is_open_across(15, 16, near, far, Side::East, false));
        assert!(SeamTrait::is_open_across(15, 16, other, next, Side::East, false));
    }

    /// `side`, West (two lookups, a division and two products, the dearest arm).
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 14721)]
    fn bench_seams_side_once() {
        let bench = Inputs::get();
        let [(near, _), _] = bench.pairs;
        assert!(SeamTrait::side(15, 16, Side::West) != near);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 18753)]
    fn bench_seams_side_twice() {
        let bench = Inputs::get();
        let [(near, _), (other, _)] = bench.pairs;
        assert!(SeamTrait::side(15, 16, Side::West) != near);
        assert!(SeamTrait::side(15, 16, Side::West) != other);
    }
}
