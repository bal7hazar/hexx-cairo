//! Tests of N-4, the cut of a board by a mask (plan §6.5, as reversed by §14, D-23): `cut(grid,
//! mask) = grid & mask`, the bits at or above `W · H` cleared, the ring kept. The contract against
//! the per-tile oracle on 7 × 7, 15 × 15 and 15 × 16, the regression cases R-N4-* rewritten, a
//! cut board through the finders, and the gas of the call.

// Core imports

use core::dict::{Felt252Dict, Felt252DictTrait};
use core::poseidon::hades_permutation;

// Internal imports

use hexx::board::bits::Bits;
use hexx::board::cut::CutTrait;
use hexx::board::direction::Direction;
use hexx::board::layout::LayoutTrait;
use hexx::board::map::{HexMap, HexMapTrait};

// Constants

const SEED: felt252 = 'CUT';

const DIRECTIONS: [Direction; 6] = [
    Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
    Direction::SouthWest, Direction::SouthEast,
];

// Oracle

/// The plain version of the contract, tile by tile.
#[generate_trait]
pub impl Oracle of OracleTrait {
    /// `cut` against its definition on every tile of the board: the tile keeps its state iff its
    /// bit is set in the mask, and no bit at or above `W · H` is left.
    fn check(map: HexMap, mask: felt252) {
        let cut = map.cut(mask);
        assert!(cut.width == map.width && cut.height == map.height && cut.seed == map.seed);
        let (grid, mask): (u256, u256) = (map.grid.into(), mask.into());
        let cut_grid: u256 = cut.grid.into();
        let size: u8 = map.width * map.height;
        let mut tile: u8 = 0;
        while tile != size {
            let expected = Bits::get(grid, tile) && Bits::get(mask, tile);
            assert!(Bits::get(cut_grid, tile) == expected, "tile {}", tile);
            assert!(cut.is_walkable(tile) == expected, "tile {}", tile);
            tile += 1;
        }
        let board: u256 = LayoutTrait::board(map.width, map.height).into();
        assert!(cut_grid <= board, "bits at or above W * H");
    }

    /// 32 seeded pairs (grid, mask) of noise over the whole felt (bits at or above `W · H`
    /// included, which `cut` must clear), and the pairs of a sparser grid and a sparser mask.
    fn check_size(width: u8, height: u8) {
        let mut seed: felt252 = 0;
        while seed != 32 {
            let (grid, mask, _) = hades_permutation(seed, width.into(), height.into());
            Self::check(HexMapTrait::new(grid, width, height, seed), mask);
            seed += 1;
        }
        // [Check] The extremes: nothing kept, everything kept
        let (grid, _, _) = hades_permutation(64, width.into(), height.into());
        let map = HexMapTrait::new(grid, width, height, 64);
        Self::check(map, 0);
        Self::check(map, LayoutTrait::board(width, height));
        Self::check(map, Bits::pow(251) - 1);
    }

    /// The scalar breadth-first search of the tests: `Some(steps)` from `from` to `to` through the
    /// walkable interior tiles; an open edge tile ends a path only, as in `Bfs`.
    fn distances(map: HexMap, from: u8) -> Felt252Dict<u8> {
        let interior: u256 = LayoutTrait::interior(map.width, map.height).into();
        let open: u256 = map.grid.into();
        let mut distances: Felt252Dict<u8> = Default::default();
        distances.insert(from.into(), 1);
        let mut queue: Array<u8> = array![from];
        while let Option::Some(current) = queue.pop_front() {
            let next = distances.get(current.into()) + 1;
            for direction in DIRECTIONS.span() {
                if let Option::Some(tile) =
                    LayoutTrait::neighbor(map.width, map.height, current, *direction) {
                    if Bits::get(open, tile) && distances.get(tile.into()) == 0 {
                        distances.insert(tile.into(), next);
                        if Bits::get(interior, tile) {
                            queue.append(tile);
                        }
                    }
                }
            }
        }
        distances
    }

    /// `distance_to` from `from` to every walkable tile of the cut board against the scalar search.
    fn check_finders(map: HexMap, from: u8) {
        let mut distances = Self::distances(map, from);
        let mut to: u8 = 0;
        while to != map.width * map.height {
            if map.is_walkable(to) {
                let distance = distances.get(to.into());
                let expected = if distance == 0 {
                    Option::None
                } else {
                    Option::Some(distance - 1)
                };
                assert!(map.distance_to(from, to) == expected, "{} -> {}", from, to);
            }
            to += 1;
        }
    }

    /// The cave of 15 × 15 of a seed, opened on the edge tile 7, cut by the hexagon of radius 6
    /// plus that tile: the cut board, whose ring is not all wall.
    fn cave(seed: felt252) -> HexMap {
        let mut map = HexMapTrait::new_cave(15, 15, 3, seed);
        map.open_with_corridor(7, 0);
        let cut = map.cut(LayoutTrait::hexagon(6) + Bits::pow(7));
        assert!(cut.is_walkable(7));
        cut
    }

    /// The first walkable interior tile of a board.
    fn interior_tile(map: HexMap) -> u8 {
        let interior: u256 = LayoutTrait::interior(map.width, map.height).into();
        let mut tile: u8 = 0;
        while !(map.is_walkable(tile) && Bits::get(interior, tile)) {
            tile += 1;
        }
        tile
    }
}

// Contract against the oracle

#[test]
#[available_gas(l2_gas: 37082297)]
fn test_cut_oracle_7x7() {
    Oracle::check_size(7, 7);
}

#[test]
#[available_gas(l2_gas: 176507175)]
fn test_cut_oracle_15x15() {
    Oracle::check_size(15, 15);
}

#[test]
#[available_gas(l2_gas: 188417855)]
fn test_cut_oracle_15x16() {
    Oracle::check_size(15, 16);
}

// Regression cases of the plan, rewritten for `grid & mask` (§14, D-23)

/// R-N4-1: 7 × 7, `new_cave(7, 7, 3, s)` then `open_with_corridor(3, 0)`. The entrance `3` is an
/// edge tile, not a corner: it is open on the ring. With `mask = 2^49 − 1` (the whole board)
/// every tile is inside the mask, so the cut is the identity and the ring tile stays open (the
/// plan's §6.5 gave `grid − 2^3`). A mask without bit 3 removes exactly that bit.
#[test]
#[available_gas(l2_gas: 1129082)]
fn test_cut_r_n4_1_open_edge_tile_stays_open() {
    let mut map = HexMapTrait::new_cave(7, 7, 3, SEED);
    map.open_with_corridor(3, 0);
    assert!(map.is_walkable(3));
    assert!(map.grid == 0xc38f0c08);
    let whole = Bits::pow(49) - 1;
    let cut = map.cut(whole);
    assert!(cut.grid == 0xc38f0c08);
    assert!(cut.is_walkable(3));
    // [Check] Outside the mask, the tile goes
    let cut = map.cut(whole - Bits::pow(3));
    assert!(cut.grid == 0xc38f0c00);
    assert!(!cut.is_walkable(3));
    // [Check] Only the ring bit 3 is in the mask: the ring tile is all that is left
    assert!(map.cut(Bits::pow(3)).grid == Bits::pow(3));
    Oracle::check(map, whole);
}

/// R-N4-2: `cut(m, mask) == cut(m, mask & (2^(W·H) − 1))`, the bits of the mask at or above
/// `W · H` are ignored (the mask itself is not).
#[test]
#[available_gas(l2_gas: 1274585)]
fn test_cut_r_n4_2_high_bits_ignored() {
    let sizes = array![(7_u8, 7_u8), (15, 15), (15, 16), (3, 3), (16, 15)];
    for size in sizes {
        let (width, height) = size;
        let board = LayoutTrait::board(width, height);
        let board_wide: u256 = board.into();
        let mut seed: felt252 = 0;
        while seed != 8 {
            let (grid, mask, _) = hades_permutation(seed, 7, 7);
            let map = HexMapTrait::new(grid, width, height, seed);
            let masked: felt252 = Bits::to_felt(Bits::and(mask.into(), board_wide));
            let (lhs, rhs) = (map.cut(mask), map.cut(masked));
            assert!(lhs.grid == rhs.grid);
            assert!(lhs.width == rhs.width && lhs.height == rhs.height && lhs.seed == rhs.seed);
            seed += 1;
        }
    }
}

/// R-N4-3: 7 × 7 with the single floor tile `(3, 3)` (index 24): the mask `2^49` keeps no tile of
/// the board, the grid is empty; so is every mask of high bits only.
#[test]
#[available_gas(l2_gas: 76065)]
fn test_cut_r_n4_3_high_bits_only() {
    let map = HexMapTrait::new(Bits::pow(24), 7, 7, SEED);
    assert!(map.cut(Bits::pow(49)).grid == 0);
    assert!(map.cut(Bits::pow(250)).grid == 0);
    assert!(map.cut(Bits::pow(251) - Bits::pow(49)).grid == 0);
    // [Check] The tile is kept by a mask that holds it, whatever else the mask holds
    assert!(map.cut(Bits::pow(24)).grid == Bits::pow(24));
    assert!(map.cut(Bits::pow(24) + Bits::pow(49)).grid == Bits::pow(24));
    // [Check] A grid with a bit at or above `W · H` loses it, mask or not
    let stray = HexMapTrait::new(Bits::pow(24) + Bits::pow(49), 7, 7, SEED);
    assert!(stray.cut(Bits::pow(251) - 1).grid == Bits::pow(24));
}

// A cut board is a valid board for the finders

/// A cave cut by an outline that keeps the open edge tile 7: `distance_to` from that edge tile and
/// from an interior tile agrees with the scalar breadth-first search on every walkable tile.
#[test]
#[available_gas(l2_gas: 33536697)]
fn test_cut_finders_from_edge_tile_30() {
    Oracle::check_finders(Oracle::cave(30), 7);
}

#[test]
#[available_gas(l2_gas: 27525398)]
fn test_cut_finders_from_interior_tile_30() {
    let map = Oracle::cave(30);
    Oracle::check_finders(map, Oracle::interior_tile(map));
}

#[test]
#[available_gas(l2_gas: 40116689)]
fn test_cut_finders_from_edge_tile_31() {
    Oracle::check_finders(Oracle::cave(31), 7);
}

#[test]
#[available_gas(l2_gas: 33663445)]
fn test_cut_finders_from_interior_tile_31() {
    let map = Oracle::cave(31);
    Oracle::check_finders(map, Oracle::interior_tile(map));
}

// Gas: a call against two calls of one opaque input, the difference is the second call

#[generate_trait]
impl Inputs of InputsTrait {
    /// The inputs of both calls, opaque to the compiler (`#[inline(never)]`, as in
    /// `bench_assembly`): the map of 15 × 16 and two masks.
    #[inline(never)]
    fn get() -> (HexMap, felt252, felt252) {
        let grid = 0x5a3c1f0e7d2b4968a1c3e5f7092b4d6f8a1c3e5f7092b4d6f8a1c3e5f7092b4;
        let mask = 0x2f7e4d1c9b8a7f6e5d4c3b2a19087f6e5d4c3b2a19087f6e5d4c3b2a1908;
        (HexMapTrait::new(grid, 15, 16, SEED), mask, 0x13579bdf02468ace13579bdf02468a)
    }
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 20698)]
fn bench_cut_once() {
    let (map, mask, _) = Inputs::get();
    assert!(map.cut(mask).grid != 0);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 31326)]
fn bench_cut_twice() {
    let (map, mask, other) = Inputs::get();
    assert!(map.cut(mask).grid != 0);
    assert!(map.cut(other).grid != 0);
}
