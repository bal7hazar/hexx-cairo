//! Tests of N-3, the assembly of the window (plan §6.4): the contract against a scalar oracle on
//! global coordinates, the regression cases R-N3-*, void chunks (D-134), odd origins refused, the
//! adventurer on local `(7, 7)` or `(7, 8)` (D-120).

// Core imports

use core::poseidon::hades_permutation;
use hexx::board::assembly::{AssemblyTrait, Origin};
use hexx::board::bits::Bits;
use hexx::board::map::HexMap;

// Constants

/// Added to a global coordinate before a division by 15, so that the division is Euclidean: the
/// coordinates of the tests are at least `-150`.
const SHIFT: i16 = 150;

// Oracle

/// The plain version of the contract (plan §6.4), tile by tile, on signed global coordinates.
#[generate_trait]
pub impl Oracle of OracleTrait {
    /// The definition of `origin`: the window's origin in global coordinates, `(x − 7, y − 7)`
    /// when `y` is odd and `(x − 7, y − 8)` when `y` is even.
    fn start(x: u8, y: u8) -> (i16, i16) {
        let (_, odd) = DivRem::div_rem(y, 2);
        let x: i16 = x.into();
        let y: i16 = y.into();
        (x - 7, if odd == 1 {
            y - 7
        } else {
            y - 8
        })
    }

    /// The Euclidean quotient and remainder of a global coordinate by 15.
    fn split(value: i16) -> (i16, i16) {
        let shifted: u16 = (value + SHIFT).try_into().unwrap();
        let (quotient, remainder) = DivRem::div_rem(shifted, 15);
        (quotient.try_into().unwrap() - 10, remainder.try_into().unwrap())
    }

    /// The tile of the location at global `(gx, gy)`: the bit of the chunk that holds it, wall
    /// for a void chunk. `chunks` are those of `(cx, cy)`, `(cx + 1, cy)`, `(cx, cy + 1)`,
    /// `(cx + 1, cy + 1)`.
    fn tile(chunks: @Array<Option<u256>>, cx: i16, cy: i16, gx: i16, gy: i16) -> bool {
        let (qx, lx) = Self::split(gx);
        let (qy, ly) = Self::split(gy);
        let kx = qx - cx;
        let ky = qy - cy;
        assert!(kx == 0 || kx == 1);
        assert!(ky == 0 || ky == 1);
        let role: u32 = (ky * 2 + kx).try_into().unwrap();
        match *chunks.at(role) {
            Option::Some(chunk) => Bits::get(chunk, (ly * 15 + lx).try_into().unwrap()),
            Option::None => false,
        }
    }

    /// The window of origin `(15·cx + ox, 15·cy + oy)`, tile by tile: the assembly, and the same
    /// with the ring of the window left as wall.
    fn window(
        chunks: [Option<felt252>; 4], cx: i16, cy: i16, ox: u8, oy: u8,
    ) -> (felt252, felt252) {
        let [a, b, c, d] = chunks;
        let chunks: Array<Option<u256>> = array![
            Self::wide(a), Self::wide(b), Self::wide(c), Self::wide(d),
        ];
        let gx: i16 = 15 * cx + ox.into();
        let gy: i16 = 15 * cy + oy.into();
        let mut all: felt252 = 0;
        let mut inner: felt252 = 0;
        let mut dy: u8 = 0;
        while dy != 16 {
            let mut dx: u8 = 0;
            while dx != 15 {
                if Self::tile(@chunks, cx, cy, gx + dx.into(), gy + dy.into()) {
                    let bit = Bits::pow(dy * 15 + dx);
                    all += bit;
                    if dx != 0 && dx != 14 && dy != 0 && dy != 15 {
                        inner += bit;
                    }
                }
                dx += 1;
            }
            dy += 1;
        }
        (all, inner)
    }

    fn wide(chunk: Option<felt252>) -> Option<u256> {
        match chunk {
            Option::Some(chunk) => Option::Some(chunk.into()),
            Option::None => Option::None,
        }
    }

    /// Four chunks of noise over the whole felt (bits at and above 225 included, which the
    /// assembly must ignore).
    fn chunks(seed: felt252) -> [Option<felt252>; 4] {
        let (a, b, c) = hades_permutation(seed, 1, 2);
        let (d, _, _) = hades_permutation(seed, 2, 2);
        [Option::Some(a), Option::Some(b), Option::Some(c), Option::Some(d)]
    }

    /// Every bit of the felt set: a full chunk, with bits at and above 225 that must be ignored.
    fn full() -> Option<felt252> {
        Option::Some(Bits::pow(251) - 1)
    }

    /// The same chunks, those whose bit is set in `void` passed as void.
    fn voided(chunks: [Option<felt252>; 4], void: u8) -> [Option<felt252>; 4] {
        let [a, b, c, d] = chunks;
        let (_, v0) = DivRem::div_rem(void, 2);
        let (_, v1) = DivRem::div_rem(void / 2, 2);
        let (_, v2) = DivRem::div_rem(void / 4, 2);
        let (_, v3) = DivRem::div_rem(void / 8, 2);
        [
            if v0 == 1 {
                Option::None
            } else {
                a
            }, if v1 == 1 {
                Option::None
            } else {
                b
            },
            if v2 == 1 {
                Option::None
            } else {
                c
            }, if v3 == 1 {
                Option::None
            } else {
                d
            },
        ]
    }

    /// `assemble` and `window` against the oracle at one offset, on 4 chunks and on 2 (the
    /// chunks `(cx + 1, ·)` void), with a chunk row of the parity the origin allows.
    fn check_offset(ox: u8, oy: u8, seed: felt252) {
        let (_, odd) = DivRem::div_rem(oy, 2);
        let odd_chunk_row = odd == 1;
        // [Setup] Chunk indices of both parities and both signs
        let cx: i16 = if ox < 8 {
            -1
        } else {
            16
        };
        let cy: i16 = if odd_chunk_row {
            -1
        } else {
            6
        };
        let terrain = Self::chunks(seed);
        let occupied = Self::chunks(seed + 1);
        let two = Self::voided(terrain, 0b1010);
        // [Check] 4 chunks, one layer
        let (expected, inner) = Self::window(terrain, cx, cy, ox, oy);
        assert!(AssemblyTrait::assemble(terrain, ox, oy, odd_chunk_row) == expected);
        // [Check] 2 chunks, one layer
        let (expected_two, _) = Self::window(two, cx, cy, ox, oy);
        assert!(AssemblyTrait::assemble(two, ox, oy, odd_chunk_row) == expected_two);
        // [Check] Both layers, the ring imposed on the terrain only
        let (expected_occupied, _) = Self::window(occupied, cx, cy, ox, oy);
        let origin = Origin { cx: cx.try_into().unwrap(), cy: cy.try_into().unwrap(), ox, oy };
        let (map, occupied) = AssemblyTrait::window(terrain, occupied, @origin, seed);
        assert!(map.width == 15 && map.height == 16 && map.seed == seed);
        assert!(map.grid == inner);
        assert!(occupied == expected_occupied);
    }

    /// Every offset `ox` at the offset row `oy`.
    fn check_row(oy: u8) {
        let mut ox: u8 = 0;
        while ox != 15 {
            Self::check_offset(ox, oy, (oy * 15 + ox).into());
            ox += 1;
        }
    }

    /// `origin` against its definition, and the adventurer on local `(7, 7)` or `(7, 8)`, for
    /// every `x` of `[from, to)` and every `y`.
    fn check_origins(from: u16, to: u16) {
        let mut x = from;
        while x != to {
            let mut y: u16 = 0;
            while y != 256 {
                let (x8, y8): (u8, u8) = (x.try_into().unwrap(), y.try_into().unwrap());
                let origin = AssemblyTrait::origin(x8, y8);
                let (gx, gy) = Self::start(x8, y8);
                assert!(origin.ox < 15 && origin.oy < 15);
                assert!(15 * Into::<i8, i16>::into(origin.cx) + origin.ox.into() == gx);
                assert!(15 * Into::<i8, i16>::into(origin.cy) + origin.oy.into() == gy);
                // [Check] Never an odd origin: oy + cy even
                let row: i16 = Into::<i8, i16>::into(origin.cy) + origin.oy.into() + SHIFT;
                let row: u16 = row.try_into().unwrap();
                let (_, odd) = DivRem::div_rem(row, 2);
                assert!(odd == 0);
                // [Check] D-120: local (7, 7) on an odd row, (7, 8) on an even one
                let (_, odd_row) = DivRem::div_rem(y, 2);
                let expected = if odd_row == 1 {
                    7 * 15 + 7
                } else {
                    8 * 15 + 7
                };
                assert!(origin.local(x8, y8) == Option::Some(expected));
                y += 1;
            }
            x += 1;
        }
    }

    /// `local` against its definition on every tile of the window of the adventurer at `(x, y)`
    /// and on a margin of 2 tiles around it (clipped to the location).
    fn check_local(x: u8, y: u8) {
        let origin = AssemblyTrait::origin(x, y);
        let (gx, gy) = Self::start(x, y);
        let mut ty: i16 = gy - 2;
        while ty != gy + 18 {
            let mut tx: i16 = gx - 2;
            while tx != gx + 17 {
                if tx >= 0 && tx < 256 && ty >= 0 && ty < 256 {
                    let dx = tx - gx;
                    let dy = ty - gy;
                    let expected = if dx >= 0 && dx < 15 && dy >= 0 && dy < 16 {
                        Option::Some((dy * 15 + dx).try_into().unwrap())
                    } else {
                        Option::None
                    };
                    assert!(
                        origin.local(tx.try_into().unwrap(), ty.try_into().unwrap()) == expected,
                    );
                }
                tx += 1;
            }
            ty += 1;
        }
    }
}

// Contract against the oracle: the 225 offsets, 4 and 2 chunks, both layers

#[test]
#[available_gas(l2_gas: 351725399)]
fn test_assembly_offsets_row_0() {
    Oracle::check_row(0);
}

#[test]
#[available_gas(l2_gas: 351837560)]
fn test_assembly_offsets_row_1() {
    Oracle::check_row(1);
}

#[test]
#[available_gas(l2_gas: 351748908)]
fn test_assembly_offsets_row_2() {
    Oracle::check_row(2);
}

#[test]
#[available_gas(l2_gas: 351991353)]
fn test_assembly_offsets_row_3() {
    Oracle::check_row(3);
}

#[test]
#[available_gas(l2_gas: 352043948)]
fn test_assembly_offsets_row_4() {
    Oracle::check_row(4);
}

#[test]
#[available_gas(l2_gas: 352067804)]
fn test_assembly_offsets_row_5() {
    Oracle::check_row(5);
}

#[test]
#[available_gas(l2_gas: 352668120)]
fn test_assembly_offsets_row_6() {
    Oracle::check_row(6);
}

#[test]
#[available_gas(l2_gas: 351632022)]
fn test_assembly_offsets_row_7() {
    Oracle::check_row(7);
}

#[test]
#[available_gas(l2_gas: 352277667)]
fn test_assembly_offsets_row_8() {
    Oracle::check_row(8);
}

#[test]
#[available_gas(l2_gas: 351864366)]
fn test_assembly_offsets_row_9() {
    Oracle::check_row(9);
}

#[test]
#[available_gas(l2_gas: 352120629)]
fn test_assembly_offsets_row_10() {
    Oracle::check_row(10);
}

#[test]
#[available_gas(l2_gas: 352581558)]
fn test_assembly_offsets_row_11() {
    Oracle::check_row(11);
}

#[test]
#[available_gas(l2_gas: 352761171)]
fn test_assembly_offsets_row_12() {
    Oracle::check_row(12);
}

#[test]
#[available_gas(l2_gas: 352975098)]
fn test_assembly_offsets_row_13() {
    Oracle::check_row(13);
}

#[test]
#[available_gas(l2_gas: 352753863)]
fn test_assembly_offsets_row_14() {
    Oracle::check_row(14);
}

// Void chunks (D-134)

/// Every subset of void chunks (1, 2 and 3 void among them, and all 4) at offsets of 4 chunks
/// of both parities, and at an offset of 2 chunks.
#[test]
#[available_gas(l2_gas: 651317439)]
fn test_assembly_void_chunks() {
    let offsets = array![(7_u8, 7_u8, -1_i16, 5_i16), (3, 8, 2, 0), (0, 14, 0, 4)];
    for offset in offsets {
        let (ox, oy, cx, cy) = offset;
        let (_, odd) = DivRem::div_rem(oy, 2);
        let terrain = Oracle::chunks(oy.into());
        let occupied = Oracle::chunks(ox.into() + 100);
        let origin = Origin { cx: cx.try_into().unwrap(), cy: cy.try_into().unwrap(), ox, oy };
        let mut void: u8 = 1;
        while void != 16 {
            let chunks = Oracle::voided(terrain, void);
            let others = Oracle::voided(occupied, 15 - void);
            let (expected, inner) = Oracle::window(chunks, cx, cy, ox, oy);
            let (expected_others, _) = Oracle::window(others, cx, cy, ox, oy);
            assert!(AssemblyTrait::assemble(chunks, ox, oy, odd == 1) == expected);
            let (map, occupied) = AssemblyTrait::window(chunks, others, @origin, 0);
            assert!(map.grid == inner);
            assert!(occupied == expected_others);
            void += 1;
        }
    }
}

/// Four void chunks: a window of wall, both layers.
#[test]
#[available_gas(l2_gas: 51499)]
fn test_assembly_all_void() {
    let void = [Option::None, Option::None, Option::None, Option::None];
    let origin = AssemblyTrait::origin(0, 0);
    assert!(AssemblyTrait::assemble(void, 8, 7, true) == 0);
    let (map, occupied) = AssemblyTrait::window(void, void, @origin, 'seed');
    assert!(map.grid == 0 && occupied == 0);
}

// Regression cases of the plan

/// R-N3-1: `origin(0, 0)`, `(7, 8)`, `(7, 7)`, `(255, 255)`.
#[test]
#[available_gas(l2_gas: 14406)]
fn test_assembly_r_n3_1_origin() {
    assert!(AssemblyTrait::origin(0, 0) == Origin { cx: -1, cy: -1, ox: 8, oy: 7 });
    assert!(AssemblyTrait::origin(7, 8) == Origin { cx: 0, cy: 0, ox: 0, oy: 0 });
    assert!(AssemblyTrait::origin(7, 7) == Origin { cx: 0, cy: 0, ox: 0, oy: 0 });
    assert!(AssemblyTrait::origin(255, 255) == Origin { cx: 16, cy: 16, ox: 8, oy: 8 });
}

/// R-N3-2: `local` of the origin of `(0, 0)` and `(255, 255)`.
#[test]
#[available_gas(l2_gas: 14406)]
fn test_assembly_r_n3_2_local() {
    let origin = AssemblyTrait::origin(0, 0);
    assert!(origin.local(0, 0) == Option::Some(127));
    assert!(origin.local(7, 7) == Option::Some(239));
    assert!(origin.local(8, 8) == Option::None);
    assert!(AssemblyTrait::origin(255, 255).local(0, 0) == Option::None);
}

/// R-N3-3: `oy = 14` (the upper chunks give all their 15 rows) and `ox = 0` (two chunks).
#[test]
#[available_gas(l2_gas: 119215081)]
fn test_assembly_r_n3_3_edges() {
    Oracle::check_offset(0, 14, 'R-N3-3');
    Oracle::check_offset(7, 14, 'R-N3-3');
    Oracle::check_offset(14, 14, 'R-N3-3');
    Oracle::check_offset(0, 0, 'R-N3-3');
    Oracle::check_offset(0, 7, 'R-N3-3');
}

/// R-N3-4: an absent chunk passed as 0 contributes wall, as a void one does.
#[test]
#[available_gas(l2_gas: 8099751)]
fn test_assembly_r_n3_4_zero_chunk() {
    let full = Oracle::full();
    let zero = AssemblyTrait::assemble([full, Option::Some(0), full, full], 7, 7, true);
    let void = AssemblyTrait::assemble([full, Option::None, full, full], 7, 7, true);
    let (expected, _) = Oracle::window([full, Option::None, full, full], -1, -1, 7, 7);
    assert!(zero == expected && void == expected);
    // [Check] The window of four full chunks is the whole window
    let all = AssemblyTrait::assemble([full, full, full, full], 7, 7, true);
    assert!(all == Bits::pow(240) - 1);
}

/// The ring of the window is wall on the terrain of four full chunks, and kept on the occupancy.
#[test]
#[available_gas(l2_gas: 76823)]
fn test_assembly_window_ring() {
    let full = Oracle::full();
    let chunks = [full, full, full, full];
    let (map, occupied) = AssemblyTrait::window(
        chunks, chunks, @Origin { cx: 3, cy: 3, ox: 7, oy: 7 }, 'seed',
    );
    let HexMap { width, height, grid, seed } = map;
    assert!(width == 15 && height == 16 && seed == 'seed');
    assert!(grid == hexx::board::layout::LayoutTrait::interior(15, 16));
    assert!(occupied == Bits::pow(240) - 1);
}

// Origins (AC-2, D-120)

#[test]
#[available_gas(l2_gas: 394823163)]
fn test_assembly_origins_0() {
    Oracle::check_origins(0, 64);
}

#[test]
#[available_gas(l2_gas: 394823163)]
fn test_assembly_origins_1() {
    Oracle::check_origins(64, 128);
}

#[test]
#[available_gas(l2_gas: 394823163)]
fn test_assembly_origins_2() {
    Oracle::check_origins(128, 192);
}

#[test]
#[available_gas(l2_gas: 394823163)]
fn test_assembly_origins_3() {
    Oracle::check_origins(192, 256);
}

/// `local` round trip on the windows of adventurers at the corners, the edges of chunks and the
/// middle of the location.
#[test]
#[available_gas(l2_gas: 309961145)]
fn test_assembly_local() {
    let coordinates = array![0_u8, 7, 8, 15, 128, 247, 248, 255];
    for x in coordinates.span() {
        for y in coordinates.span() {
            Oracle::check_local(*x, *y);
        }
    }
}

// Refusals

#[test]
#[available_gas(l2_gas: 18378)]
#[should_panic(expected: 'Assembly: odd origin')]
fn test_assembly_revert_odd_origin_even_row() {
    // oy = 1 on an even chunk row: the origin row 15·cy + 1 is odd
    AssemblyTrait::assemble(Oracle::chunks(1), 7, 1, false);
}

#[test]
#[available_gas(l2_gas: 18378)]
#[should_panic(expected: 'Assembly: odd origin')]
fn test_assembly_revert_odd_origin_odd_row() {
    // oy = 8 on an odd chunk row: 15·cy + 8 is odd
    AssemblyTrait::assemble(Oracle::chunks(1), 0, 8, true);
}

#[test]
#[available_gas(l2_gas: 18378)]
#[should_panic(expected: 'Assembly: odd origin')]
fn test_assembly_revert_window_odd_origin() {
    // cy = -1, oy = 8: the origin row is -7
    let chunks = Oracle::chunks(1);
    AssemblyTrait::window(chunks, chunks, @Origin { cx: 0, cy: -1, ox: 3, oy: 8 }, 0);
}

#[test]
#[available_gas(l2_gas: 18378)]
#[should_panic(expected: 'Assembly: invalid offset')]
fn test_assembly_revert_invalid_ox() {
    AssemblyTrait::assemble(Oracle::chunks(1), 15, 0, false);
}

#[test]
#[available_gas(l2_gas: 18378)]
#[should_panic(expected: 'Assembly: invalid offset')]
fn test_assembly_revert_invalid_oy() {
    AssemblyTrait::assemble(Oracle::chunks(1), 0, 15, true);
}

#[test]
#[available_gas(l2_gas: 18378)]
#[should_panic(expected: 'Assembly: invalid offset')]
fn test_assembly_revert_window_invalid_offset() {
    let chunks = Oracle::chunks(1);
    AssemblyTrait::window(chunks, chunks, @Origin { cx: 0, cy: 0, ox: 0, oy: 16 }, 0);
}
